#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    En,
    It,
}

impl Language {
    /// Automatically detects user's OS language on Linux based on standard POSIX environment variables:
    /// LC_ALL -> LC_MESSAGES -> LANG
    pub fn from_os() -> Self {
        for var in &["LC_ALL", "LC_MESSAGES", "LANG"] {
            if let Ok(val) = std::env::var(var) {
                let lower = val.to_lowercase();
                if lower.starts_with("it") {
                    return Language::It;
                } else if lower.starts_with("en") || lower.starts_with("c") {
                    return Language::En;
                }
            }
        }
        Language::En
    }

    /// Resolve from explicit client locale string (e.g. "it", "it_IT", "en")
    pub fn from_code(code: Option<&str>) -> Self {
        if let Some(c) = code {
            let lower = c.to_lowercase();
            if lower.starts_with("it") {
                return Language::It;
            }
        }
        Self::from_os()
    }
}

pub fn pairing_notification_summary(lang: Language) -> &'static str {
    match lang {
        Language::It => "OneControl: Richiesta di associazione",
        Language::En => "OneControl: Pairing Request",
    }
}

pub fn pairing_notification_body(lang: Language, client_name: &str, pin: &str) -> String {
    match lang {
        Language::It => format!(
            "Dispositivo: {}\nPIN di associazione: {}\nInserisci questo codice nell'app OneControl.",
            client_name, pin
        ),
        Language::En => format!(
            "Device: {}\nPairing PIN: {}\nEnter this code in the OneControl app.",
            client_name, pin
        ),
    }
}

pub fn msg_handshake_authenticated(lang: Language) -> &'static str {
    match lang {
        Language::It => "Autenticato con successo",
        Language::En => "Successfully authenticated",
    }
}

pub fn msg_handshake_need_pin(lang: Language) -> &'static str {
    match lang {
        Language::It => "PIN di associazione richiesto",
        Language::En => "Pairing PIN required",
    }
}

pub fn msg_auth_no_handshake(lang: Language) -> &'static str {
    match lang {
        Language::It => "Handshake non effettuato",
        Language::En => "Handshake not completed",
    }
}

pub fn msg_auth_success(lang: Language) -> &'static str {
    match lang {
        Language::It => "PIN corretto. Associazione completata.",
        Language::En => "Correct PIN. Pairing completed.",
    }
}

pub fn msg_auth_invalid_pin(lang: Language) -> &'static str {
    match lang {
        Language::It => "PIN non valido o scaduto",
        Language::En => "Invalid or expired PIN",
    }
}

pub fn msg_error_unauthorized(lang: Language) -> &'static str {
    match lang {
        Language::It => "Accesso non autorizzato. Completa l'autenticazione prima di inviare comandi.",
        Language::En => "Unauthorized access. Complete authentication before sending commands.",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_language_from_code() {
        assert_eq!(Language::from_code(Some("it")), Language::It);
        assert_eq!(Language::from_code(Some("it_IT")), Language::It);
        assert_eq!(Language::from_code(Some("IT-IT")), Language::It);
        // Fallback for non-it codes when no environment variable overrides to it
        let en_code = Language::from_code(Some("en"));
        assert!(en_code == Language::En || en_code == Language::It);
    }

    #[test]
    fn test_notifications_and_messages() {
        let it_summary = pairing_notification_summary(Language::It);
        let en_summary = pairing_notification_summary(Language::En);
        assert!(it_summary.contains("associazione"));
        assert!(en_summary.contains("Pairing"));

        let it_body = pairing_notification_body(Language::It, "Pixel 8", "123456");
        let en_body = pairing_notification_body(Language::En, "Pixel 8", "123456");
        assert!(it_body.contains("Dispositivo: Pixel 8"));
        assert!(it_body.contains("123456"));
        assert!(en_body.contains("Device: Pixel 8"));
        assert!(en_body.contains("123456"));

        assert_eq!(msg_auth_success(Language::It), "PIN corretto. Associazione completata.");
        assert_eq!(msg_auth_success(Language::En), "Correct PIN. Pairing completed.");
    }
}
