use std::collections::HashSet;
use evdev::uinput::{VirtualDevice, VirtualDeviceBuilder};
use evdev::{AttributeSet, EventType, InputEvent, Key, RelativeAxisType};
use tracing::{info, warn};

use super::{InputBackend, InputResult};
use crate::protocol::{ButtonAction, KeyAction, MouseButtonType};

pub struct LinuxUinputBackend {
    mouse_dev: VirtualDevice,
    keyboard_dev: VirtualDevice,
    pressed_keys: HashSet<Key>,
    pressed_mouse_buttons: HashSet<Key>,
}

impl LinuxUinputBackend {
    pub fn new() -> InputResult<Self> {
        info!("Initializing Linux uinput virtual devices...");

        // 1. Setup Virtual Mouse
        let mut rel_axes = AttributeSet::<RelativeAxisType>::new();
        rel_axes.insert(RelativeAxisType::REL_X);
        rel_axes.insert(RelativeAxisType::REL_Y);
        rel_axes.insert(RelativeAxisType::REL_WHEEL);
        rel_axes.insert(RelativeAxisType::REL_HWHEEL);

        let mut mouse_keys = AttributeSet::<Key>::new();
        mouse_keys.insert(Key::BTN_LEFT);
        mouse_keys.insert(Key::BTN_RIGHT);
        mouse_keys.insert(Key::BTN_MIDDLE);
        mouse_keys.insert(Key::BTN_SIDE);
        mouse_keys.insert(Key::BTN_EXTRA);

        let mouse_dev = VirtualDeviceBuilder::new()?
            .name("OneControl Virtual Mouse")
            .with_relative_axes(&rel_axes)?
            .with_keys(&mouse_keys)?
            .build()?;

        // 2. Setup Virtual Keyboard
        let mut kb_keys = AttributeSet::<Key>::new();

        // Letters A-Z
        let letters = [
            Key::KEY_A, Key::KEY_B, Key::KEY_C, Key::KEY_D, Key::KEY_E, Key::KEY_F, Key::KEY_G,
            Key::KEY_H, Key::KEY_I, Key::KEY_J, Key::KEY_K, Key::KEY_L, Key::KEY_M, Key::KEY_N,
            Key::KEY_O, Key::KEY_P, Key::KEY_Q, Key::KEY_R, Key::KEY_S, Key::KEY_T, Key::KEY_U,
            Key::KEY_V, Key::KEY_W, Key::KEY_X, Key::KEY_Y, Key::KEY_Z,
        ];
        for k in letters {
            kb_keys.insert(k);
        }

        // Numbers 0-9
        let numbers = [
            Key::KEY_0, Key::KEY_1, Key::KEY_2, Key::KEY_3, Key::KEY_4,
            Key::KEY_5, Key::KEY_6, Key::KEY_7, Key::KEY_8, Key::KEY_9,
        ];
        for k in numbers {
            kb_keys.insert(k);
        }

        // Modifiers & special keys
        let specials = [
            Key::KEY_LEFTCTRL, Key::KEY_RIGHTCTRL,
            Key::KEY_LEFTSHIFT, Key::KEY_RIGHTSHIFT,
            Key::KEY_LEFTALT, Key::KEY_RIGHTALT,
            Key::KEY_LEFTMETA, Key::KEY_RIGHTMETA,
            Key::KEY_TAB, Key::KEY_ENTER, Key::KEY_ESC, Key::KEY_BACKSPACE,
            Key::KEY_SPACE, Key::KEY_CAPSLOCK,
            Key::KEY_PRINT, // STAMP / PrintScreen
            Key::KEY_SCROLLLOCK, Key::KEY_PAUSE,
            Key::KEY_INSERT, Key::KEY_DELETE,
            Key::KEY_HOME, Key::KEY_END,
            Key::KEY_PAGEUP, Key::KEY_PAGEDOWN,
            Key::KEY_UP, Key::KEY_DOWN, Key::KEY_LEFT, Key::KEY_RIGHT,
            // Function keys
            Key::KEY_F1, Key::KEY_F2, Key::KEY_F3, Key::KEY_F4,
            Key::KEY_F5, Key::KEY_F6, Key::KEY_F7, Key::KEY_F8,
            Key::KEY_F9, Key::KEY_F10, Key::KEY_F11, Key::KEY_F12,
            // Punctuation & symbols
            Key::KEY_MINUS, Key::KEY_EQUAL, Key::KEY_LEFTBRACE, Key::KEY_RIGHTBRACE,
            Key::KEY_SEMICOLON, Key::KEY_APOSTROPHE, Key::KEY_GRAVE, Key::KEY_BACKSLASH,
            Key::KEY_COMMA, Key::KEY_DOT, Key::KEY_SLASH,
            // Media keys
            Key::KEY_MUTE, Key::KEY_VOLUMEUP, Key::KEY_VOLUMEDOWN, Key::KEY_PLAYPAUSE,
        ];
        for k in specials {
            kb_keys.insert(k);
        }

        let keyboard_dev = VirtualDeviceBuilder::new()?
            .name("OneControl Virtual Keyboard")
            .with_keys(&kb_keys)?
            .build()?;

        info!("Linux uinput virtual mouse and keyboard initialized successfully");

        Ok(Self {
            mouse_dev,
            keyboard_dev,
            pressed_keys: HashSet::new(),
            pressed_mouse_buttons: HashSet::new(),
        })
    }

    fn emit_mouse(&mut self, events: &[InputEvent]) -> InputResult<()> {
        self.mouse_dev.emit(events)?;
        Ok(())
    }

    fn emit_keyboard(&mut self, events: &[InputEvent]) -> InputResult<()> {
        self.keyboard_dev.emit(events)?;
        Ok(())
    }
}

impl InputBackend for LinuxUinputBackend {
    fn move_mouse_relative(&mut self, dx: i32, dy: i32) -> InputResult<()> {
        let events = [
            InputEvent::new(EventType::RELATIVE, RelativeAxisType::REL_X.0, dx),
            InputEvent::new(EventType::RELATIVE, RelativeAxisType::REL_Y.0, dy),
        ];
        self.emit_mouse(&events)?;
        Ok(())
    }

    fn mouse_button(&mut self, button: MouseButtonType, action: ButtonAction) -> InputResult<()> {
        let key = match button {
            MouseButtonType::Left => Key::BTN_LEFT,
            MouseButtonType::Right => Key::BTN_RIGHT,
            MouseButtonType::Middle => Key::BTN_MIDDLE,
        };

        match action {
            ButtonAction::Press => {
                self.pressed_mouse_buttons.insert(key);
                self.emit_mouse(&[InputEvent::new(EventType::KEY, key.0, 1)])?;
            }
            ButtonAction::Release => {
                self.pressed_mouse_buttons.remove(&key);
                self.emit_mouse(&[InputEvent::new(EventType::KEY, key.0, 0)])?;
            }
            ButtonAction::Click => {
                self.pressed_mouse_buttons.remove(&key);
                self.emit_mouse(&[InputEvent::new(EventType::KEY, key.0, 1)])?;
                std::thread::sleep(std::time::Duration::from_millis(50));
                self.emit_mouse(&[InputEvent::new(EventType::KEY, key.0, 0)])?;
            }
        }
        Ok(())
    }

    fn mouse_scroll(&mut self, dx: i32, dy: i32) -> InputResult<()> {
        let mut events = Vec::new();
        if dy != 0 {
            // In Linux uinput, positive REL_WHEEL is scroll up, negative is down
            events.push(InputEvent::new(EventType::RELATIVE, RelativeAxisType::REL_WHEEL.0, dy));
        }
        if dx != 0 {
            events.push(InputEvent::new(EventType::RELATIVE, RelativeAxisType::REL_HWHEEL.0, dx));
        }
        if !events.is_empty() {
            self.emit_mouse(&events)?;
        }
        Ok(())
    }

    fn key_event(&mut self, key_str: &str, action: KeyAction) -> InputResult<()> {
        let key = map_key_string(key_str);
        match key {
            Some(k) => {
                match action {
                    KeyAction::Down => {
                        self.pressed_keys.insert(k);
                        self.emit_keyboard(&[InputEvent::new(EventType::KEY, k.0, 1)])?;
                    }
                    KeyAction::Up => {
                        self.pressed_keys.remove(&k);
                        self.emit_keyboard(&[InputEvent::new(EventType::KEY, k.0, 0)])?;
                    }
                    KeyAction::Press => {
                        self.pressed_keys.remove(&k);
                        self.emit_keyboard(&[InputEvent::new(EventType::KEY, k.0, 1)])?;
                        std::thread::sleep(std::time::Duration::from_millis(15));
                        self.emit_keyboard(&[InputEvent::new(EventType::KEY, k.0, 0)])?;
                    }
                }
            }
            None => {
                warn!("Unknown key requested: {}", key_str);
            }
        }
        Ok(())
    }

    fn text_input(&mut self, text: &str) -> InputResult<()> {
        for ch in text.chars() {
            self.send_char(ch)?;
        }
        Ok(())
    }

    fn release_all(&mut self) -> InputResult<()> {
        let mut mouse_events = Vec::new();
        for btn in self.pressed_mouse_buttons.drain() {
            mouse_events.push(InputEvent::new(EventType::KEY, btn.0, 0));
        }
        if !mouse_events.is_empty() {
            self.emit_mouse(&mouse_events)?;
        }

        let mut kb_events = Vec::new();
        for k in self.pressed_keys.drain() {
            kb_events.push(InputEvent::new(EventType::KEY, k.0, 0));
        }
        if !kb_events.is_empty() {
            self.emit_keyboard(&kb_events)?;
        }

        Ok(())
    }
}

impl LinuxUinputBackend {
    fn send_char(&mut self, ch: char) -> InputResult<()> {
        // Map common ASCII characters to keycode and shift requirement
        let (key, shift) = match ch {
            'a'..='z' => (letter_to_key(ch), false),
            'A'..='Z' => (letter_to_key(ch.to_ascii_lowercase()), true),
            '0' => (Some(Key::KEY_0), false),
            '1' => (Some(Key::KEY_1), false),
            '2' => (Some(Key::KEY_2), false),
            '3' => (Some(Key::KEY_3), false),
            '4' => (Some(Key::KEY_4), false),
            '5' => (Some(Key::KEY_5), false),
            '6' => (Some(Key::KEY_6), false),
            '7' => (Some(Key::KEY_7), false),
            '8' => (Some(Key::KEY_8), false),
            '9' => (Some(Key::KEY_9), false),
            ' ' => (Some(Key::KEY_SPACE), false),
            '\n' | '\r' => (Some(Key::KEY_ENTER), false),
            '\t' => (Some(Key::KEY_TAB), false),
            '.' => (Some(Key::KEY_DOT), false),
            ',' => (Some(Key::KEY_COMMA), false),
            '-' => (Some(Key::KEY_MINUS), false),
            '/' => (Some(Key::KEY_SLASH), false),
            '=' => (Some(Key::KEY_EQUAL), false),
            ';' => (Some(Key::KEY_SEMICOLON), false),
            '\'' => (Some(Key::KEY_APOSTROPHE), false),
            '`' => (Some(Key::KEY_GRAVE), false),
            '\\' => (Some(Key::KEY_BACKSLASH), false),
            '[' => (Some(Key::KEY_LEFTBRACE), false),
            ']' => (Some(Key::KEY_RIGHTBRACE), false),
            // Shifted common symbols (standard US layout mappings)
            '!' => (Some(Key::KEY_1), true),
            '@' => (Some(Key::KEY_2), true),
            '#' => (Some(Key::KEY_3), true),
            '$' => (Some(Key::KEY_4), true),
            '%' => (Some(Key::KEY_5), true),
            '^' => (Some(Key::KEY_6), true),
            '&' => (Some(Key::KEY_7), true),
            '*' => (Some(Key::KEY_8), true),
            '(' => (Some(Key::KEY_9), true),
            ')' => (Some(Key::KEY_0), true),
            '_' => (Some(Key::KEY_MINUS), true),
            '+' => (Some(Key::KEY_EQUAL), true),
            ':' => (Some(Key::KEY_SEMICOLON), true),
            '"' => (Some(Key::KEY_APOSTROPHE), true),
            '<' => (Some(Key::KEY_COMMA), true),
            '>' => (Some(Key::KEY_DOT), true),
            '?' => (Some(Key::KEY_SLASH), true),
            '{' => (Some(Key::KEY_LEFTBRACE), true),
            '}' => (Some(Key::KEY_RIGHTBRACE), true),
            '~' => (Some(Key::KEY_GRAVE), true),
            '|' => (Some(Key::KEY_BACKSLASH), true),
            _ => (None, false),
        };

        if let Some(k) = key {
            if shift {
                self.emit_keyboard(&[InputEvent::new(EventType::KEY, Key::KEY_LEFTSHIFT.0, 1)])?;
                std::thread::sleep(std::time::Duration::from_millis(5));
            }
            self.emit_keyboard(&[InputEvent::new(EventType::KEY, k.0, 1)])?;
            std::thread::sleep(std::time::Duration::from_millis(15));
            self.emit_keyboard(&[InputEvent::new(EventType::KEY, k.0, 0)])?;
            if shift {
                std::thread::sleep(std::time::Duration::from_millis(5));
                self.emit_keyboard(&[InputEvent::new(EventType::KEY, Key::KEY_LEFTSHIFT.0, 0)])?;
            }
        }
        Ok(())
    }
}

fn letter_to_key(ch: char) -> Option<Key> {
    match ch {
        'a' => Some(Key::KEY_A),
        'b' => Some(Key::KEY_B),
        'c' => Some(Key::KEY_C),
        'd' => Some(Key::KEY_D),
        'e' => Some(Key::KEY_E),
        'f' => Some(Key::KEY_F),
        'g' => Some(Key::KEY_G),
        'h' => Some(Key::KEY_H),
        'i' => Some(Key::KEY_I),
        'j' => Some(Key::KEY_J),
        'k' => Some(Key::KEY_K),
        'l' => Some(Key::KEY_L),
        'm' => Some(Key::KEY_M),
        'n' => Some(Key::KEY_N),
        'o' => Some(Key::KEY_O),
        'p' => Some(Key::KEY_P),
        'q' => Some(Key::KEY_Q),
        'r' => Some(Key::KEY_R),
        's' => Some(Key::KEY_S),
        't' => Some(Key::KEY_T),
        'u' => Some(Key::KEY_U),
        'v' => Some(Key::KEY_V),
        'w' => Some(Key::KEY_W),
        'x' => Some(Key::KEY_X),
        'y' => Some(Key::KEY_Y),
        'z' => Some(Key::KEY_Z),
        _ => None,
    }
}

fn map_key_string(s: &str) -> Option<Key> {
    match s.to_uppercase().as_str() {
        "CTRL" | "LEFTCTRL" | "KEY_LEFTCTRL" => Some(Key::KEY_LEFTCTRL),
        "RIGHTCTRL" | "KEY_RIGHTCTRL" => Some(Key::KEY_RIGHTCTRL),
        "SHIFT" | "LEFTSHIFT" | "KEY_LEFTSHIFT" => Some(Key::KEY_LEFTSHIFT),
        "RIGHTSHIFT" | "KEY_RIGHTSHIFT" => Some(Key::KEY_RIGHTSHIFT),
        "ALT" | "LEFTALT" | "KEY_LEFTALT" => Some(Key::KEY_LEFTALT),
        "ALTGR" | "RIGHTALT" | "KEY_RIGHTALT" => Some(Key::KEY_RIGHTALT),
        "SUPER" | "META" | "WIN" | "CMD" | "KEY_LEFTMETA" => Some(Key::KEY_LEFTMETA),
        "TAB" | "KEY_TAB" => Some(Key::KEY_TAB),
        "ENTER" | "RETURN" | "KEY_ENTER" => Some(Key::KEY_ENTER),
        "ESC" | "ESCAPE" | "KEY_ESC" => Some(Key::KEY_ESC),
        "BACKSPACE" | "KEY_BACKSPACE" => Some(Key::KEY_BACKSPACE),
        "SPACE" | "KEY_SPACE" => Some(Key::KEY_SPACE),
        "STAMP" | "PRINT" | "PRINTSCREEN" | "KEY_PRINT" => Some(Key::KEY_PRINT),
        "DELETE" | "DEL" | "KEY_DELETE" => Some(Key::KEY_DELETE),
        "INSERT" | "INS" | "KEY_INSERT" => Some(Key::KEY_INSERT),
        "HOME" | "KEY_HOME" => Some(Key::KEY_HOME),
        "END" | "KEY_END" => Some(Key::KEY_END),
        "PAGEUP" | "PGUP" | "KEY_PAGEUP" => Some(Key::KEY_PAGEUP),
        "PAGEDOWN" | "PGDN" | "KEY_PAGEDOWN" => Some(Key::KEY_PAGEDOWN),
        "UP" | "ARROWUP" | "KEY_UP" => Some(Key::KEY_UP),
        "DOWN" | "ARROWDOWN" | "KEY_DOWN" => Some(Key::KEY_DOWN),
        "LEFT" | "ARROWLEFT" | "KEY_LEFT" => Some(Key::KEY_LEFT),
        "RIGHT" | "ARROWRIGHT" | "KEY_RIGHT" => Some(Key::KEY_RIGHT),
        "F1" | "KEY_F1" => Some(Key::KEY_F1),
        "F2" | "KEY_F2" => Some(Key::KEY_F2),
        "F3" | "KEY_F3" => Some(Key::KEY_F3),
        "F4" | "KEY_F4" => Some(Key::KEY_F4),
        "F5" | "KEY_F5" => Some(Key::KEY_F5),
        "F6" | "KEY_F6" => Some(Key::KEY_F6),
        "F7" | "KEY_F7" => Some(Key::KEY_F7),
        "F8" | "KEY_F8" => Some(Key::KEY_F8),
        "F9" | "KEY_F9" => Some(Key::KEY_F9),
        "F10" | "KEY_F10" => Some(Key::KEY_F10),
        "F11" | "KEY_F11" => Some(Key::KEY_F11),
        "F12" | "KEY_F12" => Some(Key::KEY_F12),
        "MUTE" | "KEY_MUTE" => Some(Key::KEY_MUTE),
        "VOLUP" | "VOLUMEUP" | "KEY_VOLUMEUP" => Some(Key::KEY_VOLUMEUP),
        "VOLDOWN" | "VOLUMEDOWN" | "KEY_VOLUMEDOWN" => Some(Key::KEY_VOLUMEDOWN),
        "PLAYPAUSE" | "KEY_PLAYPAUSE" => Some(Key::KEY_PLAYPAUSE),
        _ => None,
    }
}
