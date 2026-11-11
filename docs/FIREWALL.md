# Firewall Configuration (firewalld / firewall-cmd)

OneControl uses port **53842** to operate over the local network:
- **53842/tcp**: Low-latency persistent connection (binary WebSocket) for keyboard and mouse commands, and authentication.
- **53842/udp**: Auto-discovery service (beacon and probe requests allowing smartphone apps to automatically locate the PC on the LAN).

---

## 1. Opening Ports on Linux PC

Run the following commands in the terminal:

```bash
# 1. Open the TCP port for control commands
sudo firewall-cmd --permanent --add-port=53842/tcp

# 2. Open the UDP port for auto-discovery
sudo firewall-cmd --permanent --add-port=53842/udp

# 3. Reload firewall configuration to apply changes
sudo firewall-cmd --reload
```

---

## 2. Verifying Open Ports

To confirm that the ports have been registered and are active:

```bash
sudo firewall-cmd --list-ports
```

The output should include:
```text
53842/tcp 53842/udp
```

---

## 3. Restricting to Local Subnet Only (Optional / Advanced Security)

If your network interface is bound to the `home` zone or you wish to restrict access strictly to your LAN subnet (e.g. `192.168.1.0/24`):

```bash
# Rich rule for TCP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="53842" protocol="tcp" accept'

# Rich rule for UDP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="53842" protocol="udp" accept'

# Reload
sudo firewall-cmd --reload
```

---

## 4. Closing / Removing Ports (in the future)

If you ever wish to remove these rules:

```bash
sudo firewall-cmd --permanent --remove-port=53842/tcp
sudo firewall-cmd --permanent --remove-port=53842/udp
sudo firewall-cmd --reload
```
