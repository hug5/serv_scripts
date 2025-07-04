#!/bin/bash

# // 2025-07-02 Wed 22:23
# Run script as root or sudo:

# --- Security Hardening ---
set -euo pipefail  # Exit on error, undefined variables, and pipeline failures
  # -e :
    # instructs bash to immediately exit if any command [1] has a non-zero exit status. You wouldn't want to set this for your command-line shell, but in a script it's massively helpful.
  # -u :
    # Affects variables. When set, a reference to any variable you haven't previously defined - with the exceptions of $* and $@ - is an error, and causes the program to immediately exit.
  # -o pipefail :
    # This setting prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
  # https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425?permalink_comment_id=3935570

#------------------------------------------------
### Configure ufw, sshd_config, fail2ban
#------------------------------------------------

# --- User Configuration ---

# Create /swapfile?
CREATE_SWAP=true

# 128M * N
# 4=512M; 5=640M; 6=768M
SWAPCOUNT=5

# swapfile swappiness
SWAPPINESS=20
# file cache_pressure; file manager inode cache
CACHE_PRESSURE=50



#------------------------------------------------

# --- Begin Script ---
echo -e "⚙️  Begin Server Setup Script #2\n"

read -rp "Confirm to continue [Y/n]: " CHOICE
case "$CHOICE" in
  n|N )
      exit
      ;;
  y|Y|* )
      echo "Alright... here we go!"
      ;;
esac


# --- UFW ---
# Single command for 5522, 443, 80:
sleep 1; echo "•"
echo ">>> Setting UFW..."
echo ">>> Enable ports 5522, 443, 80"
sudo ufw limit 5522/tcp
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp

sudo ufw enable
sudo systemctl enable ufw
sudo systemctl start ufw



# --- sshd_config ---
# Configure /etc/ssh/sshd_config
sleep 1; echo "•"
echo ">>> Setting sshd_config file..."
sudo sed -i "s/#Port 22/Port 5522/" /etc/ssh/sshd_config
# sudo sed -i "/#Port 22/a Port 5522" /etc/ssh/sshd_config
  # find #Port22 and append to it, not substitute; also note no ending /
  # Better to replace; on repeat, will then add multiple entries;
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config

echo ">>> Restart ssh..."
sudo systemctl restart ssh


# --- fail2ban ---
sleep 1; echo "•"
echo ">>> Setting fail2ban..."
sudo cp /etc/fail2ban/fail2ban.{conf,local}
sudo cp /etc/fail2ban/jail.{conf,local}

# fail2ban.local
# allowipv6 = auto
sudo sed -i "s/#allowipv6 = auto/allowipv6 = auto/" /etc/fail2ban/fail2ban.local
# dbpurgeage = 1d
sudo sed -i "s/dbpurgeage = 1d/dbpurgeage = 8d/" /etc/fail2ban/fail2ban.local


# jail.local
echo ">>> Enabling jails: sshd, recidive"
sudo sed -i "/^\[sshd\]/a enabled = true" /etc/fail2ban/jail.local
sudo sed -i "/^\[recidive\]/a enabled = true" /etc/fail2ban/jail.local

sudo systemctl restart fail2ban


# --- Create Swapfile ---
sleep 1; echo "•"
if [[ "$CREATE_SWAP" == true ]]; then

    # swappiness
    echo ">>> Creating swapfile"

    # In case there is a preexisting ACTIVE swapfile; then swapoff
    if [[ -f /swapfile ]] && sudo swapon | grep /swapfil &>/dev/null; then
        sudo swapoff /swapfile
    fi

    # Create file to use as swap:
    sudo touch /swapfile
    sudo chmod 600 /swapfile

    # 640M swap
    sudo dd if=/dev/zero of=/swapfile bs=128M count=$SWAPCOUNT

    # Designate the file as a swapfile
    sudo mkswap /swapfile
    # Enable the swap; good until next boot;
    sudo swapon /swapfile

    # Add fstab entry
    if ! grep "^/swapfile" /etc/fstab; then
      echo "/swapfile  none  swap  sw  0  0" | sudo tee -a /etc/fstab
    fi


else
    echo ">>> Skipping swapfile"
fi


# --- swappiness + cache_pressure ---
sleep 1; echo "•"
# swappiness
echo ">>> Setting swappiness"
if ! grep vm.swappiness /etc/sysctl.conf; then
  # Set swappiness
  echo "vm.swappiness=$SWAPPINESS" | sudo tee -a /etc/sysctl.conf
fi

# vfs_cache_pressure
echo ">>> Setting cache_pressure"
if ! grep vm.vfs_cache_pressure /etc/sysctl.conf; then
  # Cache Pressure Setting
  echo "vm.vfs_cache_pressure=$CACHE_PRESSURE" | sudo tee -a /etc/sysctl.conf
fi

# Effectuate changed settings
sudo sysctl -p



# --- Validation ---
sleep 1; echo "•"
echo ">>> Verification. Check results:"

sudo ufw status
sudo systemctl status fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client status recidive
sudo systemctl status ssh
free -h
swapon
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure


# --- Close ---
echo -e "\n\n🛠️  Config Complete: ufw, ssh, fail2ban, swap + cache_pressure."




