use super::{InputBackend, InputResult};
use crate::protocol::{ButtonAction, KeyAction, MouseButtonType};

pub struct WindowsInputBackend;

impl WindowsInputBackend {
    pub fn new() -> InputResult<Self> {
        Ok(Self)
    }
}

impl InputBackend for WindowsInputBackend {
    fn move_mouse_relative(&mut self, _dx: i32, _dy: i32) -> InputResult<()> {
        // Will use SendInput with MOUSEEVENTF_MOVE
        unimplemented!("Windows backend will be implemented using Win32 SendInput API");
    }

    fn mouse_button(&mut self, _button: MouseButtonType, _action: ButtonAction) -> InputResult<()> {
        unimplemented!("Windows backend will be implemented using Win32 SendInput API");
    }

    fn mouse_scroll(&mut self, _dx: i32, _dy: i32) -> InputResult<()> {
        unimplemented!("Windows backend will be implemented using Win32 SendInput API");
    }

    fn key_event(&mut self, _key: &str, _action: KeyAction) -> InputResult<()> {
        unimplemented!("Windows backend will be implemented using Win32 SendInput API");
    }

    fn text_input(&mut self, _text: &str) -> InputResult<()> {
        unimplemented!("Windows backend will be implemented using Win32 SendInput API");
    }

    fn release_all(&mut self) -> InputResult<()> {
        Ok(())
    }
}
