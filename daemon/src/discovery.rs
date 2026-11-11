use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::net::UdpSocket;
use tracing::{debug, error, info, warn};

use crate::config::Config;
use crate::protocol::{DiscoveryBeacon, DISCOVERY_MAGIC_BEACON, DISCOVERY_MAGIC_REQUEST};

pub async fn start_discovery_service(config: Arc<Config>) {
    let port = config.port;

    // Create a socket configured with SO_REUSEADDR and SO_BROADCAST
    let socket = match create_udp_socket(port) {
        Ok(s) => s,
        Err(e) => {
            error!("Failed to create UDP discovery socket: {}", e);
            return;
        }
    };

    let udp = match UdpSocket::from_std(socket.into()) {
        Ok(u) => Arc::new(u),
        Err(e) => {
            error!("Failed to convert std UDP socket to tokio: {}", e);
            return;
        }
    };

    info!("UDP Discovery responder listening on 0.0.0.0:{}", port);

    // Task 1: Periodic broadcast beacon
    let udp_beacon = udp.clone();
    let config_beacon = config.clone();
    tokio::spawn(async move {
        let broadcast_addr: SocketAddr = format!("255.255.255.255:{}", port).parse().unwrap();
        let beacon = DiscoveryBeacon {
            magic: DISCOVERY_MAGIC_BEACON.to_string(),
            hostname: config_beacon.device_name.clone(),
            port,
            os: std::env::consts::OS.to_string(),
            version: env!("CARGO_PKG_VERSION").to_string(),
        };

        let beacon_bytes = match serde_json::to_vec(&beacon) {
            Ok(b) => b,
            Err(e) => {
                error!("Failed to serialize beacon: {}", e);
                return;
            }
        };

        loop {
            if let Err(e) = udp_beacon.send_to(&beacon_bytes, broadcast_addr).await {
                debug!("Failed to send UDP broadcast beacon: {}", e);
            }
            tokio::time::sleep(Duration::from_secs(3)).await;
        }
    });

    // Task 2: Listen for discovery requests and reply immediately
    let beacon_reply = DiscoveryBeacon {
        magic: DISCOVERY_MAGIC_BEACON.to_string(),
        hostname: config.device_name.clone(),
        port,
        os: std::env::consts::OS.to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
    };
    let reply_bytes = match serde_json::to_vec(&beacon_reply) {
        Ok(b) => b,
        Err(e) => {
            error!("Failed to serialize discovery reply: {}", e);
            return;
        }
    };

    let mut buf = [0u8; 1024];
    loop {
        match udp.recv_from(&mut buf).await {
            Ok((len, peer_addr)) => {
                let msg = String::from_utf8_lossy(&buf[..len]);
                if msg.contains(DISCOVERY_MAGIC_REQUEST) {
                    debug!("Received discovery request from {}, sending reply", peer_addr);
                    if let Err(e) = udp.send_to(&reply_bytes, peer_addr).await {
                        warn!("Failed to send discovery reply to {}: {}", peer_addr, e);
                    }
                }
            }
            Err(e) => {
                warn!("UDP recv_from error: {}", e);
                tokio::time::sleep(Duration::from_millis(500)).await;
            }
        }
    }
}

fn create_udp_socket(port: u16) -> std::io::Result<Socket> {
    let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;
    socket.set_reuse_address(true)?;
    socket.set_broadcast(true)?;
    socket.set_nonblocking(true)?;

    let addr: SocketAddr = format!("0.0.0.0:{}", port).parse().unwrap();
    socket.bind(&addr.into())?;
    Ok(socket)
}
