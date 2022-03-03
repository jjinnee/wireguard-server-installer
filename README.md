### Environments
- Ubuntu 20.04 (OCI) ✅ 1/17/2022
- Ubuntu 20.04 (Lightsail) ✅ 1/17/2022

You can run on other linux when you delete lines 16 through 29

There is no guarantee that it will work properly.


### Preview
![1](https://user-images.githubusercontent.com/46839654/149745326-20858cbe-1259-45b5-817a-cc016cdbb730.png)

### Usage

Download & run

    ##
    # Interactive mode
    ##
    curl -o wg-installer.sh https://raw.githubusercontent.com/jjinnee/wireguard-server-installer/main/install.sh && chmod +x wg-installer.sh && bash wg-installer.sh
    
    ##
    # No-interactive mode
    # -------------------
    # DEFAULT_INTERFACE=$(ip route | sed -n 1p | awk '{print $5}')
    # PUBLIC_SERVER_IP=$(curl -s ip-api.com)
    # WIREGUARD_SUBNET="10.13.13.1/24"
    # SERVER_PORT=51820
    # PEER_COUNT=1
    ##
    curl -o wg-installer.sh https://raw.githubusercontent.com/jjinnee/wireguard-server-installer/main/default.sh | bash
    
You can start, stop, view, and remove with command.

    $ wghelp
