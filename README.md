# WireGuard MikroTik config generator

![visitors](https://visitor-badge.laobi.icu/badge?page_id=IgorKha.wireguard-mikrotik)

**This project is a bash script that aims to configure a [WireGuard](https://www.wireguard.com/) VPN on a MikroTik, as easily as possible!**

WireGuard is a point-to-point VPN that can be used in different ways. Here, we mean a VPN as in: the client will forward all its traffic trough an encrypted tunnel to the server.
The server will apply NAT to the client's traffic so it will appear as if the client is browsing the web with the server's IP.

The script supports both IPv4 and IPv6. Please check the [issues](https://github.com/angristan/wireguard-install/issues) for ongoing development, bugs and planned features!

Part of this script based on [this repo](https://github.com/angristan/wireguard-install)

## Requirements

Packages:

- wireguard
- qrencode
- iptables (optional)
- resolvconf (optional)

Supported distributions:

- Ubuntu >= 16.04
- Debian >= 10
- Fedora
- CentOS
- Arch Linux
- Oracle Linux

## Usage

Download and execute the script on superuser. Answer the questions asked by the script and it will take care of the rest.

```bash
curl -O https://raw.githubusercontent.com/IgorKha/wireguard-mikrotik/master/wireguard-mikrotik.sh
chmod +x wireguard-mikrotik.sh
./wireguard-mikrotik.sh
```

It will install WireGuard (kernel module and tools), create a server configuration file (MikroTik) and a client configuration file.

Run the script again to add clients (enter exist interface name) or create new server (enter new interface name)!

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
│   │   │   └── wg0.rsc - past in your mikrotik console
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
