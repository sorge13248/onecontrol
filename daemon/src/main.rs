use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{error, info};
use tracing_subscriber::EnvFilter;

mod auth;
mod config;
mod discovery;
mod i18n;
mod input;
mod protocol;
mod server;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() > 1 && (args[1] == "--version" || args[1] == "-v" || args[1] == "-V") {
        println!("onecontrol-daemon {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }

    // Initialize logging
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,onecontrol_daemon=debug"));
    tracing_subscriber::fmt().with_env_filter(filter).init();

    info!("=== Starting OneControl Host Daemon v{} ===", env!("CARGO_PKG_VERSION"));

    // Load configuration
    let config = Arc::new(config::Config::load_or_create());
    info!(
        "Host name: '{}', Port: {}, Require Auth: {}",
        config.device_name, config.port, config.require_auth
    );

    // Initialize virtual input devices (uinput on Linux)
    let backend = match input::create_default_backend() {
        Ok(b) => Arc::new(Mutex::new(b)),
        Err(e) => {
            error!("Failed to initialize virtual input devices: {}", e);
            error!("Ensure /dev/uinput is readable and writable by your user (e.g. udev rule or ACL).");
            return Err(e);
        }
    };

    let auth = Arc::new(auth::AuthManager::new(config.require_auth));

    // Start UDP discovery responder
    if config.discovery_enabled {
        let disc_config = config.clone();
        tokio::spawn(async move {
            discovery::start_discovery_service(disc_config).await;
        });
    }

    // Start WebSocket & TCP control server
    let server_config = config.clone();
    let server_backend = backend.clone();
    let server_auth = auth.clone();

    tokio::select! {
        _ = server::run_server(server_config, server_backend, server_auth) => {},
        _ = tokio::signal::ctrl_c() => {
            info!("Received Ctrl+C, shutting down OneControl daemon gracefully...");
        }
    }

    // Release all keys before exit
    let mut b = backend.lock().await;
    let _ = b.release_all();
    info!("OneControl daemon stopped.");

    Ok(())
}
