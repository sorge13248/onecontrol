use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    Handshake {
        client_id: String,
        client_name: String,
        token: Option<String>,
        #[serde(default)]
        locale: Option<String>,
    },
    AuthPin {
        pin: String,
    },
    Ping,
    MouseMove {
        dx: i32,
        dy: i32,
    },
    MouseButton {
        button: MouseButtonType,
        action: ButtonAction,
    },
    MouseScroll {
        dx: i32,
        dy: i32,
    },
    KeyEvent {
        key: String,
        action: KeyAction,
    },
    TextInput {
        text: String,
    },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MouseButtonType {
    Left,
    Right,
    Middle,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ButtonAction {
    Press,
    Release,
    Click,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum KeyAction {
    Down,
    Up,
    Press,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    HandshakeAck {
        status: AuthStatus,
        server_name: String,
        token: Option<String>,
        message: String,
    },
    AuthAck {
        success: bool,
        token: Option<String>,
        message: String,
    },
    Pong,
    Error {
        message: String,
    },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AuthStatus {
    Authenticated,
    NeedPin,
    Rejected,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoveryBeacon {
    pub magic: String,
    pub hostname: String,
    pub port: u16,
    pub os: String,
    pub version: String,
}

pub const DISCOVERY_MAGIC_REQUEST: &str = "ONECONTROL_DISCOVERY";
pub const DISCOVERY_MAGIC_BEACON: &str = "ONECONTROL_BEACON";
pub const DEFAULT_PORT: u16 = 53842;
