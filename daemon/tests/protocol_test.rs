use serde_json::json;

#[test]
fn test_protocol_serialization() {
    let handshake_json = json!({
        "type": "handshake",
        "client_id": "test_client_1",
        "client_name": "Test Phone",
        "token": null,
        "locale": "it"
    });

    let s = handshake_json.to_string();
    assert!(s.contains("test_client_1"));
    assert!(s.contains("\"locale\":\"it\""));

    let mouse_move_json = json!({
        "type": "mouse_move",
        "dx": 15,
        "dy": -8
    });
    assert!(mouse_move_json.to_string().contains("15"));
}

#[test]
fn test_key_event_format() {
    let key_event = json!({
        "type": "key_event",
        "key": "CTRL",
        "action": "down"
    });
    let s = key_event.to_string();
    assert!(s.contains("key_event"));
    assert!(s.contains("CTRL"));
}

#[test]
fn test_mouse_button_format() {
    for (btn, act) in [
        ("left", "click"),
        ("right", "click"),
        ("middle", "click"),
        ("left", "press"),
        ("left", "release"),
    ] {
        let msg = json!({
            "type": "mouse_button",
            "button": btn,
            "action": act,
        });
        let s = msg.to_string();
        assert!(s.contains(btn));
        assert!(s.contains(act));
    }
}
