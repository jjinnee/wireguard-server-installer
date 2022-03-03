#!/bin/bash

#----------------------
# text color
#----------------------
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BG_GREEN="\e[1;42m"
BG_YELLOW="\e[1;43m"
BG_CYAN="\e[1;46m"
NC="\e[0m"

#----------------------
# check os
#----------------------
if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
fi

if [ "$OS" != "Ubuntu" ]; then
        echo "This script seems to be running on an unsupported distribution."
        echo "Supported distribution is Ubuntu."
        exit
fi

#----------------------
# ENV
#----------------------
# NETWORK_INTERFACE : Interface you use internet
# PUBLIC_SERVER_IP : Public server ip
# WIREGUARD_SUBNET : Wireguard subnet
# SERVER_PORT : Wireguard server port
# SERVER_PRIVATE_KEY
# SERVER_PUBLIC_KEY
# SERVER_KEYS_DIR : Where you save the keys
# CLIENT_PRIVATE_KEY : Client private key
# CLIENT_PUBLIC_KEY : Client public key
# PEER_COUNT
# PEERS_SAVE_DIR

#----------------------
# Questions
#----------------------
DEFAULT_INTERFACE=$(ip route | sed -n 1p | awk '{print $5}')

EXPECTED_IP=$(curl -s ip-api.com | grep -Eo '(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])')
PUBLIC_SERVER_IP=$EXPECTED_IP

WIREGUARD_SUBNET="10.13.13.1/24"

SERVER_PORT=51820

PEER_COUNT=1

#----------------------
# Update
#----------------------
sudo apt update

#----------------------
# Install wireguard
#----------------------
sudo apt install wireguard qrencode -y

#----------------------
# Generate keys
#----------------------
SERVER_KEYS_DIR="/etc/wireguard"

umask 077

SERVER_PRIVATE_KEY=$(wg genkey | sudo tee $SERVER_KEYS_DIR/private.key)
SERVER_PUBLIC_KEY=$(sudo cat $SERVER_KEYS_DIR/private.key | wg pubkey | sudo tee $SERVER_KEYS_DIR/public.key)

umask 002

#----------------------
# Edit sysctl.conf
#----------------------
sudo sed -ie 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

sudo sysctl -p

#----------------------
# Create wg0.conf
#----------------------
umask 077

cat << EOF | sudo tee $SERVER_KEYS_DIR/wg0.conf
[Interface]
Address = $WIREGUARD_SUBNET
SaveConfig = true
PostUp = iptables -I FORWARD -i wg0 -o $NETWORK_INTERFACE -j ACCEPT; iptables -I FORWARD -i $NETWORK_INTERFACE -o wg0 -j ACCEPT; iptables -t nat -I POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o $NETWORK_INTERFACE -j ACCEPT; iptables -D FORWARD -i $NETWORK_INTERFACE -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIVATE_KEY
EOF

umask 002

#----------------------
# Create peer.conf
#----------------------
## example : separateIP 1.2.3.4/24 2 => 2
separateIP() {
        echo $1 | cut -d '/' -f 1 | cut -d '.' -f $2
}

PEERS_SAVE_DIR="$HOME/wireguard"
CURRENT_ALLOWED_IP="$WIREGUARD_SUBNET"

mkdir $PEERS_SAVE_DIR

for ((i=0; i < $PEER_COUNT; i++)); do
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

A=$(separateIP $CURRENT_ALLOWED_IP 1)
B=$(separateIP $CURRENT_ALLOWED_IP 2)
C=$(separateIP $CURRENT_ALLOWED_IP 3)
D=$(separateIP $CURRENT_ALLOWED_IP 4)
D=$((D + 1))
CURRENT_ALLOWED_IP="${A}.${B}.${C}.${D}/32"

cat << EOF | sudo tee -a $SERVER_KEYS_DIR/wg0.conf

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CURRENT_ALLOWED_IP
EOF

cat << EOF | tee ${PEERS_SAVE_DIR}/peer$((i + 1)).conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CURRENT_ALLOWED_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $PUBLIC_SERVER_IP:$SERVER_PORT
EOF
done

#----------------------
# Create wireguard manager
#----------------------
cat << EOF | sudo tee /usr/local/bin/wghelp
#!/bin/bash

#----------------------
# text color
#----------------------
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BG_RED="\e[1;41m"
BG_GREEN="\e[1;42m"
BG_YELLOW="\e[1;43m"
BG_MAGENTA="\e[1;45m"
BG_CYAN="\e[1;46m"
NC="\e[0m"

#----------------------
# START
#----------------------
echo -e "\${BG_GREEN} CHOOSE ONE \${NC}"
sudo wg && echo
echo -e "\t1 - Start wg0.service"
echo -e "\t2 - Stop wg0.service"
echo -e "\t3 - View clients info"
echo -e "\t4 - Remove wireguard"
echo -e "\t\${YELLOW}Remove and reinstall to reset wireguard\${NC}"

read -p "Answer [Default : Exit] : " ANSWER
[ -z \$ANSWER ] && exit

echo

if [[ \$ANSWER == 1 ]]; then
    wg-quick up wg0
    sudo wg
fi

if [[ \$ANSWER == 2 ]]; then
    wg-quick down wg0
    sudo wg
fi

if [[ \$ANSWER == 3 ]]; then
    echo -e "\${BG_CYAN} SELECT PROFILE \${NC}"
    for file in \$(ls \$HOME/wireguard); do
        echo -e "\t\$(echo \$file | cut -d '.' -f 1)"
    done

    read -p "Filename [exit] : " FILENAME
    [ -z \$FILENAME ] && exit

    echo
    echo -e "\${BG_YELLOW} RESULT \${NC}"
    cat \$HOME/wireguard/\${FILENAME}.conf
    echo
    qrencode -t ansiutf8 < \$HOME/wireguard/\${FILENAME}.conf
fi

if [[ \$ANSWER == 4 ]]; then
    wg-quick down wg0
    sudo systemctl disable wg-quick@wg0.service
    sudo apt purge wireguard qrencode -y
    sudo apt autoremove -y
    sudo sed -ie 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sudo sysctl -p
    sudo rm -r /etc/wireguard
    rm -r \$HOME/wireguard
    sudo rm /usr/local/bin/wghelp
fi
EOF
sudo chmod +x /usr/local/bin/wghelp

clear
#----------------------
# Start wg0.service
#----------------------
sudo systemctl enable wg-quick@wg0.service
wg-quick up wg0

echo
echo -e "${BG_GREEN} USAGE ${NC}"
echo -e "You can manage wireguard with command"
echo -e "\t${GREEN}$ wghelp${NC}"
echo
