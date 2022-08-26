#!/bin/bash

BLUE='\033[0;34m'
NC='\033[0m'
INFO="${BLUE}[i]${NC}"

function installWireGuard() {

    #? Check root user
    if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 13
	fi

    #? Check OS version
    if [[ -e /etc/debian_version ]]; then
        # shellcheck source=/dev/null
		source /etc/os-release
		OS="${ID}" # debian or ubuntu
		if [[ ${ID} == "debian" || ${ID} == "raspbian" ]]; then
			if [[ ${VERSION_ID} -lt 10 ]]; then
				echo "Your version of Debian (${VERSION_ID}) is not supported. Please use Debian 10 Buster or later"
				exit 95
			fi
			OS=debian #* overwrite if raspbian
		fi
	elif [[ -e /etc/fedora-release ]]; then
        # shellcheck source=/dev/null
		source /etc/os-release
		OS="${ID}"
	elif [[ -e /etc/centos-release ]]; then
        # shellcheck source=/dev/null
		source /etc/os-release
		OS=centos
	elif [[ -e /etc/oracle-release ]]; then
        # shellcheck source=/dev/null
		source /etc/os-release
		OS=oracle
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS, Oracle or Arch Linux system"
		exit 95
	fi
    
	#? Install WireGuard tools and module
	if [[ ${OS} == 'ubuntu' ]] || [[ ${OS} == 'debian' && ${VERSION_ID} -gt 10 ]]; then
		apt-get update
		apt-get install -y wireguard qrencode
	elif [[ ${OS} == 'debian' ]]; then
		if ! grep -rqs "^deb .* buster-backports" /etc/apt/; then
			echo "deb http://deb.debian.org/debian buster-backports main" >/etc/apt/sources.list.d/backports.list
			apt-get update
		fi
		apt update
		apt-get install -y qrencode
		apt-get install -y -t buster-backports wireguard
	elif [[ ${OS} == 'fedora' ]]; then
		if [[ ${VERSION_ID} -lt 32 ]]; then
			dnf install -y dnf-plugins-core
			dnf copr enable -y jdoss/wireguard
			dnf install -y wireguard-dkms
		fi
		dnf install -y wireguard-tools qrencode
	elif [[ ${OS} == 'centos' ]]; then
		yum -y install epel-release elrepo-release
		if [[ ${VERSION_ID} -eq 7 ]]; then
			yum -y install yum-plugin-elrepo
		fi
		yum -y install kmod-wireguard wireguard-tools qrencode
	elif [[ ${OS} == 'oracle' ]]; then
		dnf install -y oraclelinux-developer-release-el8
		dnf config-manager --disable -y ol8_developer
		dnf config-manager --enable -y ol8_developer_UEKR6
		dnf config-manager --save -y --setopt=ol8_developer_UEKR6.includepkgs='wireguard-tools*'
		dnf install -y wireguard-tools qrencode
	elif [[ ${OS} == 'arch' ]]; then
		pacman -Sq --needed --noconfirm wireguard-tools qrencode
	fi

}

function installCheck() {
	if ! command -v wg &> /dev/null
	then
	    echo "You must have \"wireguard-tools\" and \"qrencode\" installed."
    	read -n1 -r -p "Press any key to continue and install needed packages..."
		installWireGuard
	fi
}

function serverName() {
	until [[ ${SERVER_WG_NIC} =~ ^[a-zA-Z0-9_]+$ && ${#SERVER_WG_NIC} -lt 16 ]]; do
            read -rp "WireGuard interface name (server name): " -e -i wg0 SERVER_WG_NIC
    done
}

function installQuestions() {
	echo "Welcome to WireGuard-MikroTik configurator!"
	echo "The git repository is available at: https://github.com/IgorKha/wireguard-mikrotik"
	echo ""
	echo "I need to ask you a few questions before starting the setup."
	echo "You can leave the default options and just press enter if you are ok with them."
	echo ""

	# Detect public IPv4 or IPv6 address and pre-fill for the user
    SERVER_PUB_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    if [[ -z ${SERVER_PUB_IP} ]]; then
            # Detect public IPv6 address
            SERVER_PUB_IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
    fi
    read -rp "IPv4 or IPv6 public address: " -e -i "${SERVER_PUB_IP}" SERVER_PUB_IP

    until [[ ${SERVER_WG_IPV4} =~ ^([0-9]{1,3}\.){3} ]]; do
        read -rp "Server's WireGuard IPv4: " -e -i 10."$(shuf -i 0-250 -n 1)"."$(shuf -i 0-250 -n 1)".1 SERVER_WG_IPV4
    done

    until [[ ${SERVER_WG_IPV6} =~ ^([a-f0-9]{1,4}:){3,4}: ]]; do
        read -rp "Server's WireGuard IPv6: " -e -i fd42:"$(shuf -i 10-90 -n 1)":"$(shuf -i 10-90 -n 1)"::1 SERVER_WG_IPV6
    done

    # Generate random number within private ports range
    RANDOM_PORT=$(shuf -i49152-65535 -n1)
    until [[ ${SERVER_PORT} =~ ^[0-9]+$ ]] && [ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ]; do
        read -rp "Server's WireGuard port [1-65535]: " -e -i "${RANDOM_PORT}" SERVER_PORT
    done

    # Adguard DNS by default
    until [[ ${CLIENT_DNS_1} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
        read -rp "First DNS resolver to use for the clients: " -e -i 94.140.14.14 CLIENT_DNS_1
    done
    until [[ ${CLIENT_DNS_2} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
        read -rp "Second DNS resolver to use for the clients (optional): " -e -i 94.140.15.15 CLIENT_DNS_2
        if [[ ${CLIENT_DNS_2} == "" ]]; then
            CLIENT_DNS_2="${CLIENT_DNS_1}"
        fi
    done

    echo ""
    echo "Okay, that was all I needed. We are ready to setup your WireGuard server now."
    echo "You will be able to generate a client at the end of the installation."
    read -n1 -r -p "Press any key to continue..."

}

function newInterface() {
	# Run setup questions first
	installQuestions

	# Make sure the directory exists (this does not seem the be the case on fedora)
	mkdir -p "$(pwd)"/wireguard/"${SERVER_WG_NIC}"/mikrotik >/dev/null 2>&1

	SERVER_PRIV_KEY=$(wg genkey)
	SERVER_PUB_KEY=$(echo "${SERVER_PRIV_KEY}" | wg pubkey)

	# Save WireGuard settings #SERVER_PUB_NIC=${SERVER_PUB_NIC}
	echo "SERVER_PUB_IP=${SERVER_PUB_IP}

SERVER_WG_NIC=${SERVER_WG_NIC}
SERVER_WG_IPV4=${SERVER_WG_IPV4}
SERVER_WG_IPV6=${SERVER_WG_IPV6}
SERVER_PORT=${SERVER_PORT}
SERVER_PRIV_KEY=${SERVER_PRIV_KEY}
SERVER_PUB_KEY=${SERVER_PUB_KEY}
CLIENT_DNS_1=${CLIENT_DNS_1}
CLIENT_DNS_2=${CLIENT_DNS_2}" > "$(pwd)/wireguard/${SERVER_WG_NIC}/params"

    # Save WireGuard settings to the MikroTik
    echo "# WireGuard interface configure
/interface wireguard
add listen-port=${SERVER_PORT} mtu=1420 name=${SERVER_WG_NIC} private-key=\\
    \"${SERVER_PRIV_KEY}\"
/ip firewall filter
add action=accept chain=input comment=wg-${SERVER_WG_NIC} dst-port=${SERVER_PORT} protocol=udp
/ip firewall filter move [/ip firewall filter find comment=wg-${SERVER_WG_NIC}] 1
/ip address
add address=${SERVER_WG_IPV4}/24 comment=wg-${SERVER_WG_NIC} interface=${SERVER_WG_NIC}
    " > "$(pwd)/wireguard/${SERVER_WG_NIC}/mikrotik/${SERVER_WG_NIC}.rsc"


	# Add server interface
	echo "[Interface]
Address = ${SERVER_WG_IPV4}/24,${SERVER_WG_IPV6}/64
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIV_KEY}" > "$(pwd)/wireguard/${SERVER_WG_NIC}/${SERVER_WG_NIC}.conf"

	newClient
	echo -e "${INFO} MikroTik interface config available in $(pwd)/wireguard/${SERVER_WG_NIC}/mikrotik/${SERVER_WG_NIC}.rsc"
	echo -e "${INFO} If you want to add more clients, you simply need to run this script another time!"

}

function newClient() {
	ENDPOINT="${SERVER_PUB_IP}:${SERVER_PORT}"

	echo ""
	echo "Tell me a name for the client."
	echo "The name must consist of alphanumeric character. It may also include an underscore or a dash and can't exceed 15 chars."

	until [[ ${CLIENT_NAME} =~ ^[a-zA-Z0-9_-]+$ && ${CLIENT_EXISTS} == '0' && ${#CLIENT_NAME} -lt 16 ]]; do
		read -rp "Client name: " -e CLIENT_NAME
		CLIENT_EXISTS=$(grep -c -E "^### Client ${CLIENT_NAME}\$" "$(pwd)/wireguard/${SERVER_WG_NIC}/${SERVER_WG_NIC}.conf")

		if [[ ${CLIENT_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified name was already created, please choose another name."
			echo ""
		fi
	done

	for DOT_IP in {2..254}; do
		DOT_EXISTS=$(grep -c "${SERVER_WG_IPV4::-1}${DOT_IP}" "$(pwd)/wireguard/${SERVER_WG_NIC}/${SERVER_WG_NIC}.conf")
		if [[ ${DOT_EXISTS} == '0' ]]; then
			break
		fi
	done

	if [[ ${DOT_EXISTS} == '1' ]]; then
		echo ""
		echo "The subnet configured supports only 253 clients."
		exit 99
	fi

	BASE_IP=$(echo "$SERVER_WG_IPV4" | awk -F '.' '{ print $1"."$2"."$3 }')
	until [[ ${IPV4_EXISTS} == '0' ]]; do
		read -rp "Client's WireGuard IPv4: ${BASE_IP}." -e -i "${DOT_IP}" DOT_IP
		CLIENT_WG_IPV4="${BASE_IP}.${DOT_IP}"
		IPV4_EXISTS=$(grep -c "$CLIENT_WG_IPV4/24" "$(pwd)/wireguard/${SERVER_WG_NIC}/${SERVER_WG_NIC}.conf")

		if [[ ${IPV4_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified IPv4 was already created, please choose another IPv4."
			echo ""
		fi
	done

	BASE_IP=$(echo "$SERVER_WG_IPV6" | awk -F '::' '{ print $1 }')
	until [[ ${IPV6_EXISTS} == '0' ]]; do
		read -rp "Client's WireGuard IPv6: ${BASE_IP}::" -e -i "${DOT_IP}" DOT_IP
		CLIENT_WG_IPV6="${BASE_IP}::${DOT_IP}"
		IPV6_EXISTS=$(grep -c "${CLIENT_WG_IPV6}/64" "$(pwd)/wireguard/${SERVER_WG_NIC}/${SERVER_WG_NIC}.conf")

		if [[ ${IPV6_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified IPv6 was already created, please choose another IPv6."
			echo ""
		fi
	done

	# Generate key pair for the client
	CLIENT_PRIV_KEY=$(wg genkey)
	CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)
	CLIENT_PRE_SHARED_KEY=$(wg genpsk)

    mkdir -p "$(pwd)/wireguard/${SERVER_WG_NIC}/client/${CLIENT_NAME}" >/dev/null 2>&1
	HOME_DIR="$(pwd)/wireguard/${SERVER_WG_NIC}/client/${CLIENT_NAME}"
	
	# Create client file and add the server as a peer
	echo "[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128
DNS = ${CLIENT_DNS_1},${CLIENT_DNS_2}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = 0.0.0.0/0,::/0" >>"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"

    # Add the client as a peer to the MikroTik (to client folder)
    echo "# WireGuard client peer configure
/interface wireguard peers
add allowed-address=${CLIENT_WG_IPV4}/32 comment=\\
    ${SERVER_WG_NIC}-client-${CLIENT_NAME} interface=${SERVER_WG_NIC} \\
    preshared-key=\"${CLIENT_PRE_SHARED_KEY}\" public-key=\\
    \"${CLIENT_PUB_KEY}\"
    " >"${HOME_DIR}/mikrotik-peer-${SERVER_WG_NIC}-client-${CLIENT_NAME}.rsc"

    # Add the client as a peer to the MikroTik
    echo "# WireGuard client peer configure
/interface wireguard peers
add allowed-address=${CLIENT_WG_IPV4}/32 comment=\\
    ${SERVER_WG_NIC}-client-${CLIENT_NAME} interface=${SERVER_WG_NIC} \\
    preshared-key=\"${CLIENT_PRE_SHARED_KEY}\" public-key=\\
    \"${CLIENT_PUB_KEY}\"
    " >> "$(pwd)/wireguard/${SERVER_WG_NIC}/mikrotik/${SERVER_WG_NIC}.rsc"

	# Add the client as a peer to the server
	echo -e "\n### Client ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
AllowedIPs = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128" >>"$(pwd)/wireguard/${SERVER_WG_NIC}/${SERVER_WG_NIC}.conf"

	echo -e "\nHere is your client config file as a QR Code:"

	qrencode -t ansiutf8 -l L <"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"
    qrencode -l L -s 6 -d 225 -o "${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.png" <"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"

	echo -e "${INFO} Config available in ${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"
    echo -e "${INFO} QR is also available in ${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.png"
	echo -e "${INFO} MikroTik peer config available in ${HOME_DIR}/mikrotik-${SERVER_WG_NIC}-client-${CLIENT_NAME}.rsc"
}

function manageMenu() {
	echo "Welcome to WireGuard-MikroTik configurator!"
	echo "The git repository is available at: https://github.com/IgorKha/wireguard-mikrotik"
	echo ""
	echo "It looks like this WireGuard interface is already."
	echo ""
	echo "What do you want to do?"
	echo "   1) Add a new client"
	echo "   2) Exit"
	until [[ ${MENU_OPTION} =~ ^[1-4]$ ]]; do
		read -rp "Select an option [1-2]: " MENU_OPTION
	done
	case "${MENU_OPTION}" in
	1)
		newClient
		;;
	2)
		exit 0
		;;
	esac
}

#? Check for root, OS, WireGuard
installCheck 

#? Check server exist
serverName

#? Check if WireGuard is already installed and load params
if [[ -e $(pwd)/wireguard/${SERVER_WG_NIC}/params ]]; then
	# shellcheck source=/dev/null
	source "$(pwd)/wireguard/${SERVER_WG_NIC}/params"
	manageMenu
else
	newInterface
fi
