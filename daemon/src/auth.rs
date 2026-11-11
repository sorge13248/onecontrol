use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{info, warn};

use crate::config::Config;
use crate::i18n::{self, Language};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AuthStore {
    // client_id -> token
    pub authorized_tokens: HashMap<String, String>,
}

pub struct AuthManager {
    store: Arc<Mutex<AuthStore>>,
    // client_id -> pending PIN
    pending_pins: Arc<Mutex<HashMap<String, String>>>,
    require_auth: bool,
}

impl AuthManager {
    pub fn new(require_auth: bool) -> Self {
        let store = Self::load_store();
        Self {
            store: Arc::new(Mutex::new(store)),
            pending_pins: Arc::new(Mutex::new(HashMap::new())),
            require_auth,
        }
    }

    fn store_path() -> std::path::PathBuf {
        Config::config_dir().join("authorized_clients.json")
    }

    fn load_store() -> AuthStore {
        let path = Self::store_path();
        if path.exists() {
            if let Ok(content) = fs::read_to_string(&path) {
                if let Ok(store) = serde_json::from_str::<AuthStore>(&content) {
                    return store;
                }
            }
        }
        AuthStore::default()
    }

    async fn save_store(store: &AuthStore) {
        let path = Self::store_path();
        if let Ok(content) = serde_json::to_string_pretty(store) {
            let _ = fs::write(&path, content);
        }
    }

    pub async fn verify_token(&self, client_id: &str, token: Option<&str>) -> bool {
        if !self.require_auth {
            return true;
        }

        if let Some(tok) = token {
            let store = self.store.lock().await;
            if let Some(saved) = store.authorized_tokens.get(client_id) {
                return saved == tok;
            }
        }
        false
    }

    pub async fn request_pin(&self, client_id: &str, client_name: &str) -> String {
        let pin_str = {
            let mut rng = rand::thread_rng();
            let pin: u32 = rng.gen_range(100000..999999);
            pin.to_string()
        };

        let mut pins = self.pending_pins.lock().await;
        pins.insert(client_id.to_string(), pin_str.clone());

        info!(
            "PAIRING REQUEST: Client '{}' ({}) requires PIN: {}",
            client_name, client_id, pin_str
        );

        // Show desktop notification on Linux via DBus respecting OS language
        let host_lang = Language::from_os();
        let notify_summary = i18n::pairing_notification_summary(host_lang);
        let notify_body = i18n::pairing_notification_body(host_lang, client_name, &pin_str);

        tokio::task::spawn_blocking(move || {
            let icon_str = get_notification_icon();
            if let Err(e) = notify_rust::Notification::new()
                .appname("OneControl")
                .summary(notify_summary)
                .body(&notify_body)
                .icon(&icon_str)
                .timeout(notify_rust::Timeout::Milliseconds(30000))
                .show()
            {
                warn!("Could not show desktop notification: {}", e);
            }
        });

        pin_str
    }

    pub async fn verify_pin(&self, client_id: &str, pin: &str) -> Option<String> {
        let mut pins = self.pending_pins.lock().await;
        if let Some(expected) = pins.get(client_id) {
            if expected == pin {
                pins.remove(client_id);

                // Generate new token
                let token = {
                    let mut rng = rand::thread_rng();
                    let token_bytes: [u8; 16] = rng.gen();
                    hex_encode(&token_bytes)
                };

                let mut store = self.store.lock().await;
                store
                    .authorized_tokens
                    .insert(client_id.to_string(), token.clone());
                Self::save_store(&store).await;

                info!("Client '{}' successfully paired!", client_id);
                return Some(token);
            }
        }
        None
    }
}

fn hex_encode(data: &[u8]) -> String {
    data.iter().map(|b| format!("{:02x}", b)).collect()
}

fn get_notification_icon() -> String {
    // 1. Look for installed application icon in standard user data directory
    if let Some(mut p) = dirs::data_local_dir() {
        p.push("icons");
        p.push("hicolor");
        p.push("512x512");
        p.push("apps");
        p.push("onecontrol.png");
        if p.exists() {
            return p.to_string_lossy().to_string();
        }
    }

    if let Some(mut p) = dirs::data_local_dir() {
        p.push("onecontrol");
        p.push("onecontrol.png");
        if p.exists() {
            return p.to_string_lossy().to_string();
        }
    }

    // 2. Look for project relative asset (during development/local run)
    let candidates = [
        "assets/icons/onecontrol.png",
        "../assets/icons/onecontrol.png",
        "/usr/share/icons/hicolor/512x512/apps/onecontrol.png",
    ];
    for c in candidates {
        let path = std::path::Path::new(c);
        if path.exists() {
            if let Ok(abs) = std::fs::canonicalize(path) {
                return abs.to_string_lossy().to_string();
            }
        }
    }

    // 3. Fallback to icon theme name
    "onecontrol".to_string()
}
