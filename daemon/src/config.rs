use std::fs;
use std::path::PathBuf;
use serde::{Deserialize, Serialize};
use tracing::info;

use crate::protocol::DEFAULT_PORT;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub port: u16,
    pub require_auth: bool,
    pub device_name: String,
    pub discovery_enabled: bool,
}

impl Default for Config {
    fn default() -> Self {
        let hostname = hostname::get()
            .map(|h| h.to_string_lossy().to_string())
            .unwrap_or_else(|_| "OneControl-Host".to_string());

        Self {
            port: DEFAULT_PORT,
            require_auth: true,
            device_name: hostname,
            discovery_enabled: true,
        }
    }
}

impl Config {
    pub fn config_dir() -> PathBuf {
        if let Some(mut p) = dirs::config_dir() {
            p.push("onecontrol");
            if fs::create_dir_all(&p).is_ok() {
                return p;
            }
        }
        let fallback = PathBuf::from(".onecontrol");
        let _ = fs::create_dir_all(&fallback);
        fallback
    }

    pub fn load_or_create() -> Self {
        let dir = Self::config_dir();
        let file_path = dir.join("config.json");
        if file_path.exists() {
            if let Ok(content) = fs::read_to_string(&file_path) {
                if let Ok(config) = serde_json::from_str::<Config>(&content) {
                    return config;
                }
            }
        }

        let default_config = Self::default();
        if let Ok(content) = serde_json::to_string_pretty(&default_config) {
            let _ = fs::write(&file_path, content);
            info!("Created default configuration at {:?}", file_path);
        }

        default_config
    }
}
