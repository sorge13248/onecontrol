use crate::protocol::{ButtonAction, KeyAction, MouseButtonType};
use std::error::Error;

pub type InputResult<T> = Result<T, Box<dyn Error + Send + Sync>>;

pub trait InputBackend: Send + Sync {
    fn move_mouse_relative(&mut self, dx: i32, dy: i32) -> InputResult<()>;
    fn mouse_button(&mut self, button: MouseButtonType, action: ButtonAction) -> InputResult<()>;
    fn mouse_scroll(&mut self, dx: i32, dy: i32) -> InputResult<()>;
    fn key_event(&mut self, key: &str, action: KeyAction) -> InputResult<()>;
    fn text_input(&mut self, text: &str) -> InputResult<()>;
    fn release_all(&mut self) -> InputResult<()>;
}

#[cfg(target_os = "linux")]
pub mod linux;

#[cfg(target_os = "windows")]
pub mod windows;

#[cfg(target_os = "macos")]
pub mod macos;

#[cfg(target_os = "linux")]
pub fn create_default_backend() -> InputResult<Box<dyn InputBackend>> {
    Ok(Box::new(linux::LinuxUinputBackend::new()?))
}

#[cfg(target_os = "windows")]
pub fn create_default_backend() -> InputResult<Box<dyn InputBackend>> {
    Ok(Box::new(windows::WindowsInputBackend::new()?))
}

#[cfg(target_os = "macos")]
pub fn create_default_backend() -> InputResult<Box<dyn InputBackend>> {
    Ok(Box::new(macos::MacOsInputBackend::new()?))
}

#[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
pub fn create_default_backend() -> InputResult<Box<dyn InputBackend>> {
    compile_error!("Unsupported operating system");
}
