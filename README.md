# WireGuard MikroTik config generator

![visitors](https://visitor-badge.laobi.icu/badge?page_id=IgorKha.wireguard-mikrotik)

**This project is a bash script designed to simplify the configuration of a [WireGuard](https://www.wireguard.com/) VPN on a MikroTik device.**

WireGuard is a point-to-point VPN protocol that offers various usage possibilities. In this context, we refer to a VPN where the client's traffic is securely tunneled to the server. The server applies NAT to the client's traffic, making it appear as though the client is accessing the internet using the server's IP address.

The script fully supports both IPv4 and IPv6. Please refer to the [issues](https://github.com/IgorKha/wireguard-mikrotik/issues) section for ongoing development, bug reports, and planned features.

A portion of this script is based on the following repository: [wireguard-install](https://github.com/angristan/wireguard-install)

For monitoring the performance of your MikroTik device, you can use [Grafana-MikroTik](https://github.com/IgorKha/Grafana-Mikrotik) to visualize measurements.

## Requirements

Packages:

- wireguard-tools
- qrencode

Supported distributions:

- Ubuntu >= 16.04
- Debian >= 10
- Fedora
- CentOS
- Arch Linux
- Oracle Linux
- macOS (experimental) [**requires** [**brew**](https://brew.sh) package manager]

## Usage

Download and execute the script on superuser. Answer the questions asked by the script and it will take care of the rest.

```bash
curl -O https://raw.githubusercontent.com/IgorKha/wireguard-mikrotik/master/wireguard-mikrotik.sh
chmod +x wireguard-mikrotik.sh
./wireguard-mikrotik.sh
```

Once run, the script will create a "wireguard" folder with your settings.

Run the script again to add clients (enter exist interface name) or create new server (enter new interface name)!

[![asciicast](https://asciinema.org/a/64wco1fA8k251anGsSQDcH9jW.svg)](https://asciinema.org/a/64wco1fA8k251anGsSQDcH9jW)

## Structure

```text
.
├── wireguard
│   ├── wg0 - WireGuard interface name (server name)
│   │   ├── client - clients config folder
│   │   │   └── user1
│   │   │       ├── mikrotik-peer-wg0-client-user1.rsc  - MikroTik peer config [server side]
│   │   │       ├── wg0-client-user1.conf - config file for your client
│   │   │       └── wg0-client-user1.png - and QR client config
│   │   ├── mikrotik
│   │   │   └── wg0.rsc - paste in your mikrotik console
│   │   ├── params
│   │   └── wg0.conf
│   └── wg1 - WireGuard interface name (server name)
│       ├── client - clients config folder
│       │   ├── user1
│       │   │   ├── mikrotik-peer-wg1-client-user1.rsc
│       │   │   ├── wg1-client-user1.conf
│       │   │   └── wg1-client-user1.png
│       │   └── user2
│       │       ├── mikrotik-peer-wg1-client-user2.rsc
│       │       ├── wg1-client-user2.conf
│       │       └── wg1-client-user2.png
│       ├── mikrotik
│       │   └── wg1.rsc
│       ├── params
│       └── wg1.conf
└── wireguard-mikrotik.sh
```
