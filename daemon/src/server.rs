use std::net::SocketAddr;
use std::sync::Arc;
use futures_util::{SinkExt, StreamExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio_tungstenite::tungstenite::Message;
use tracing::{debug, error, info, warn};

use crate::auth::AuthManager;
use crate::config::Config;
use crate::i18n::{self, Language};
use crate::input::InputBackend;
use crate::protocol::{AuthStatus, ClientMessage, ServerMessage};

pub async fn run_server(
    config: Arc<Config>,
    backend: Arc<Mutex<Box<dyn InputBackend>>>,
    auth: Arc<AuthManager>,
) {
    let addr = format!("0.0.0.0:{}", config.port);
    let listener = match TcpListener::bind(&addr).await {
        Ok(l) => l,
        Err(e) => {
            error!("Failed to bind TCP server on {}: {}", addr, e);
            return;
        }
    };

    info!("OneControl TCP/WebSocket server listening on {}", addr);

    loop {
        match listener.accept().await {
            Ok((stream, peer_addr)) => {
                debug!("Incoming connection from {}", peer_addr);

                // Enable TCP_NODELAY for sub-millisecond response times
                if let Err(e) = stream.set_nodelay(true) {
                    warn!("Failed to set TCP_NODELAY on stream: {}", e);
                }

                let backend_clone = backend.clone();
                let auth_clone = auth.clone();
                let config_clone = config.clone();

                tokio::spawn(async move {
                    if let Err(e) = handle_connection(stream, peer_addr, config_clone, backend_clone, auth_clone).await {
                        debug!("Connection from {} closed with error: {}", peer_addr, e);
                    } else {
                        debug!("Connection from {} closed cleanly", peer_addr);
                    }
                });
            }
            Err(e) => {
                warn!("Accept failed: {}", e);
            }
        }
    }
}

async fn handle_connection(
    stream: TcpStream,
    peer_addr: SocketAddr,
    config: Arc<Config>,
    backend: Arc<Mutex<Box<dyn InputBackend>>>,
    auth: Arc<AuthManager>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let ws_stream = tokio_tungstenite::accept_async(stream).await?;
    let (mut ws_sender, mut ws_receiver) = ws_stream.split();

    let mut is_authenticated = false;
    let mut current_client_id: Option<String> = None;
    let mut client_lang = Language::from_os();

    while let Some(msg_result) = ws_receiver.next().await {
        let msg = match msg_result {
            Ok(m) => m,
            Err(e) => {
                warn!("WebSocket read error from {}: {}", peer_addr, e);
                break;
            }
        };

        if msg.is_close() {
            info!("Client {} requested close", peer_addr);
            break;
        }

        let text = match msg.to_text() {
            Ok(t) => t,
            Err(_) => continue,
        };

        let client_msg: ClientMessage = match serde_json::from_str(text) {
            Ok(m) => m,
            Err(e) => {
                warn!("Invalid message JSON from {}: {}", peer_addr, e);
                let err = ServerMessage::Error {
                    message: format!("Malformed message: {}", e),
                };
                let _ = ws_sender.send(Message::Text(serde_json::to_string(&err)?)).await;
                continue;
            }
        };

        match client_msg {
            ClientMessage::Handshake { client_id, client_name, token, locale } => {
                current_client_id = Some(client_id.clone());
                client_lang = Language::from_code(locale.as_deref());
                let verified = auth.verify_token(&client_id, token.as_deref()).await;

                if verified {
                    is_authenticated = true;
                    info!("Client '{}' ({}) authenticated via token", client_name, client_id);
                    let ack = ServerMessage::HandshakeAck {
                        status: AuthStatus::Authenticated,
                        server_name: config.device_name.clone(),
                        token: None,
                        message: i18n::msg_handshake_authenticated(client_lang).to_string(),
                    };
                    ws_sender.send(Message::Text(serde_json::to_string(&ack)?)).await?;
                } else {
                    let _ = auth.request_pin(&client_id, &client_name).await;
                    let ack = ServerMessage::HandshakeAck {
                        status: AuthStatus::NeedPin,
                        server_name: config.device_name.clone(),
                        token: None,
                        message: i18n::msg_handshake_need_pin(client_lang).to_string(),
                    };
                    ws_sender.send(Message::Text(serde_json::to_string(&ack)?)).await?;
                }
            }

            ClientMessage::AuthPin { pin } => {
                let client_id = match &current_client_id {
                    Some(id) => id.as_str(),
                    None => {
                        let ack = ServerMessage::AuthAck {
                            success: false,
                            token: None,
                            message: i18n::msg_auth_no_handshake(client_lang).to_string(),
                        };
                        ws_sender.send(Message::Text(serde_json::to_string(&ack)?)).await?;
                        continue;
                    }
                };

                if let Some(new_token) = auth.verify_pin(client_id, &pin).await {
                    is_authenticated = true;
                    let ack = ServerMessage::AuthAck {
                        success: true,
                        token: Some(new_token),
                        message: i18n::msg_auth_success(client_lang).to_string(),
                    };
                    ws_sender.send(Message::Text(serde_json::to_string(&ack)?)).await?;
                } else {
                    let ack = ServerMessage::AuthAck {
                        success: false,
                        token: None,
                        message: i18n::msg_auth_invalid_pin(client_lang).to_string(),
                    };
                    ws_sender.send(Message::Text(serde_json::to_string(&ack)?)).await?;
                }
            }

            ClientMessage::Ping => {
                ws_sender.send(Message::Text(serde_json::to_string(&ServerMessage::Pong)?)).await?;
            }

            // Input commands require authentication
            other => {
                if !is_authenticated {
                    let err = ServerMessage::Error {
                        message: i18n::msg_error_unauthorized(client_lang).to_string(),
                    };
                    ws_sender.send(Message::Text(serde_json::to_string(&err)?)).await?;
                    continue;
                }

                let mut b = backend.lock().await;
                match other {
                    ClientMessage::MouseMove { dx, dy } => {
                        if let Err(e) = b.move_mouse_relative(dx, dy) {
                            debug!("Mouse move error: {}", e);
                        }
                    }
                    ClientMessage::MouseButton { button, action } => {
                        debug!("Mouse button event: {:?} {:?}", button, action);
                        if let Err(e) = b.mouse_button(button, action) {
                            debug!("Mouse button error: {}", e);
                        }
                    }
                    ClientMessage::MouseScroll { dx, dy } => {
                        if let Err(e) = b.mouse_scroll(dx, dy) {
                            debug!("Mouse scroll error: {}", e);
                        }
                    }
                    ClientMessage::KeyEvent { key, action } => {
                        if let Err(e) = b.key_event(&key, action) {
                            debug!("Key event error: {}", e);
                        }
                    }
                    ClientMessage::TextInput { text } => {
                        if let Err(e) = b.text_input(&text) {
                            debug!("Text input error: {}", e);
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    // Safety: ensure any held modifiers or mouse buttons are released upon disconnection
    info!("Releasing any held keys and buttons for peer {}", peer_addr);
    let mut b = backend.lock().await;
    let _ = b.release_all();

    Ok(())
}
