use super::{InputBackend, InputResult};
use crate::protocol::{ButtonAction, KeyAction, MouseButtonType};

pub struct MacOsInputBackend;

impl MacOsInputBackend {
    pub fn new() -> InputResult<Self> {
        Ok(Self)
    }
}

impl InputBackend for MacOsInputBackend {
    fn move_mouse_relative(&mut self, _dx: i32, _dy: i32) -> InputResult<()> {
        // Will use CoreGraphics CGEventCreateMouseEvent
        unimplemented!("macOS backend will be implemented using CoreGraphics API");
    }

    fn mouse_button(&mut self, _button: MouseButtonType, _action: ButtonAction) -> InputResult<()> {
        unimplemented!("macOS backend will be implemented using CoreGraphics API");
    }

    fn mouse_scroll(&mut self, _dx: i32, _dy: i32) -> InputResult<()> {
        unimplemented!("macOS backend will be implemented using CoreGraphics API");
    }

    fn key_event(&mut self, _key: &str, _action: KeyAction) -> InputResult<()> {
        unimplemented!("macOS backend will be implemented using CoreGraphics API");
    }

    fn text_input(&mut self, _text: &str) -> InputResult<()> {
        unimplemented!("macOS backend will be implemented using CoreGraphics API");
    }

    fn release_all(&mut self) -> InputResult<()> {
        Ok(())
    }
}
