#!/bin/bash

# // 2025-07-01 Tue 23:33
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
### Initial Server Setup #1
#------------------------------------------------
# Create users, passwords, locale, timezone,
# hostname, hosts, ssh key, install programs,
# clone serv_dot


# --- User Configuration ---

NEW_USER="h2"
HOSTNAME="rail"

## Choose public ssh key to use:
## Linode
#SSH_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIND3WdyM/uNlOPA3hnGI1NojU0GAhnya5LmEIXsTpkSZ linode"

## Vultr
SSH_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJvRchOMU0BxUkl3homRaW91rFbM6TAFryqCkqzOk1gD vultr"

## DigitalOcean
#SSH_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCkSINhno1wkFfqjounBUilwg4rhDf2X8DKDix1IRAr digitalocean"


# Heredoc
# /etc/hosts setting:
# EOF without quotes you can use variables, etc;
# pass through sed to remove leading spaces
HOSTS=$(cat << EOF | sed 's/^[[:space:]]*//'

    127.0.0.1         localhost localhost.localdomain
    127.0.1.1         rail rail.paperdrift.com
    149.28.206.8      rail rail.paperdrift.com

    # For IPv6
    2001:19f0:ac00:4d1e:5400:04ff:fee2:4aba  rail rail.paperdrift.com

    # The following lines are desirable for IPv6 capable hosts
    ::1     localhost ip6-localhost ip6-loopback
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters

EOF
)


# - - - - - - - - - - - - - -
# - - - - - - - - - - - - - -

# These you shouldn't have to touch:
TIMEZONE="UTC"
LOCALE_LANG="en_US.UTF-8"
LOCALE_LANGUAGE="en_US:en"
SSH_DIR="/home/$NEW_USER/.ssh"


#------------------------------------------------

if [[ -z "$NEW_USER" ]] || [[ -z "$HOSTNAME" ]] || [[ -z "$SSH_PUB" ]]; then
    echo "Please provide a new user, hostname and SSH public key."
    exit
fi


# --- Begin Script ---
echo -e "⚙️  Begin Server Setup Script #1\n"

read -rp "Confirm to continue [Y/n]: " CHOICE
case "$CHOICE" in
  n|N )
      exit
      ;;
  y|Y|* )
      echo -e "Alright... here we go!\n\n"
      ;;
esac


# --- Root Setup ---
echo "•"
read -rp "Set root PW? [y/N]: " CHOICE
case "$CHOICE" in
  y|Y )
      echo ">>> Set root password:"
      passwd root
      echo ">>> Setting root shell to bash..."
      chsh -s /bin/bash root
        # -s : name of shell
      ;;
  n|N|* )
      echo ">>> Skipping root password."
      ;;
esac


# --- User Creation ---
sleep 1; echo "•"
# getent exits with 0 or 2: Unlike id, it doesn’t trigger -e on "not found".
if ! getent passwd "$NEW_USER" &>/dev/null; then
    echo ">>> Creating user: $NEW_USER"
    useradd -s /bin/bash -mG sudo "$NEW_USER"
    echo ">>> Set password for $NEW_USER:"
    passwd "$NEW_USER"
else
    echo ">>> User already exists: $NEW_USER. Skipping."
fi


# --- apt update & upgrade ---
echo "•"
echo ">>> apt update && update upgrade:"
apt update -y && apt upgrade -y



# --- Locale Language ---
sleep 1; echo "•"
echo ">>> Setting locale to $LOCALE_LANG..."
localectl set-locale LANG="$LOCALE_LANG" LANGUAGE="$LOCALE_LANGUAGE"


# --- Timezone ---
sleep 1; echo "•"
echo ">>> Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"
echo "$TIMEZONE" | sudo tee /etc/timezone
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime


# --- Sync NTP clock ---
sleep 1; echo "•"
echo ">>> Set NTP Service..."

declare NTP_ENABLED=true
# Check that systemd-timesynd is installed; only vultr has this problem;
# if systemctl status systemd-timesyncd 2>&1 | grep "could not be found" &>/dev/null; then
echo ">>> Synchronize System Clock..."
if ! systemctl status systemd-timesyncd &>/dev/null; then
    # systemctl status systemd-timesyncd
    # dpkg -l | grep systemd-timesyncd
    # timedatectl timesync-status

    echo ">>> Installing systemd-timesyncd"
    apt install -y systemd-timesyncd
    echo ">>> Enabling systemd-timesync"

    echo "[Time]
    NTP=pool.ntp.org
    FallbackNTP=ntp.ubuntu.com" > /etc/systemd/timesyncd.conf

    systemctl enable --now systemd-timesyncd # enable + start
    systemctl restart systemd-timesyncd

    if [[ $(timedatectl show | grep 'NTPSynchronized=yes') ]]; then
        echo ">>> NTP enabled"
        NTP_ENABLED=true
    else
        echo ">>> NTP failed"
        NTP_ENABLED=false
    fi
    # systemctl status systemd-timesyncd
    # echo ">>> Sleep 5"
    # sleep 5
    # systemctl is-enabled systemd-timesyncd
else
  timedatectl set-ntp true &>/dev/null && echo ">>> NTP enabled" && break
  # echo ">>> Synchronize System Clock..."
  # timedatectl set-ntp true &>/dev/null
  # for i in {1..5}; do
  #     sleep 5
  #     if systemctl is-active --quiet systemd-timesyncd; then
  #         timedatectl set-ntp true &>/dev/null && echo ">>> NTP enabled" && break
  #     fi
  #     # timedatectl status  # Try running some command to 'jerk' it alive;
  #     echo "Waiting for systemd-timesyncd to be ready... ($i of 5)"
  #     i=6  # if here, then failed; set to 6 and check later;
  # done
fi


# --- kb layout ---
sleep 1; echo "•"
echo ">>> Setting kb layout..."
localectl set-x11-keymap us pc105

echo ">>> Setting vconsole.conf..."
echo 'KEYMAP=us' | tee /etc/vconsole.conf
  # setting this because vultr doesn't have vconsole.conf
   # And when I try to cat it, it errors and breaks the script;

# --- Setup hostname and hosts file ---
# /etc/hostname
sleep 1; echo "•"
echo ">>> Setting /etc/hostname file to $HOSTNAME..."
hostnamectl set-hostname "$HOSTNAME"
echo ">>> Setting /etc/hosts file..."
# echo "$HOSTS" | sudo tee /etc/hosts >/dev/null
echo "$HOSTS" | tee /etc/hosts >/dev/null
  # tee outputs to stout; suppress that;


# --- Vultr: comment out - update_etc_hosts in /etc/cloud/cloud.cfg ---
# /etc/cloud/cloud.cfg
# Comment out:
# - update_etc_hosts
# On vultr, need to comment this out in order to preserve changes to /etc/hosts;
# Linode doesn't need it, but will comment out consistently:
echo ">>> Comment out - update_etc_hosts in /etc/cloud/cloud.cfg"
sed -i 's/ - update_etc_hosts/# - update_etc_hosts/' /etc/cloud/cloud.cfg
  # A danger is that in vult, there are 2 empty spaces;
  # In linode, just 1 empty space; Linode doesn't matter to us, but still...
  # So will just look for the string and not worry about spaces

# This is the message that appears in vultr /etc/hosts:
  # Your system has configured 'manage_etc_hosts' as True.
  # As a result, if you wish for changes to this file to persist
  # then you will need to either
  # a.) make changes to the master file in /etc/cloud/templates/hosts.debian.tmpl
  # b.) change or remove the value of 'manage_etc_hosts' in
  #     /etc/cloud/cloud.cfg or cloud-config from user-data

# --- setup ssh public key ---
sleep 1; echo "•"
echo ">>> Setting up ssh authorized keys..."
sudo -u $NEW_USER mkdir -p "$SSH_DIR"
echo "$SSH_PUB" | sudo -u $NEW_USER tee "$SSH_DIR/authorized_keys" >/dev/null
chmod 600 "$SSH_DIR/authorized_keys"


# --- install git + clone serv_dot ---
sleep 1; echo "•"
echo ">>> Installing git..."
sudo apt install git

if [[ ! -d /home/$NEW_USER/tmp ]]; then
    sudo -u $NEW_USER mkdir /home/$NEW_USER/tmp
fi

sleep 1; echo "•"
if [[ ! -d /home/$NEW_USER/tmp/serv_dot ]]; then
    echo ">>> Cloning serv_dot..."
    sudo -u $NEW_USER git clone --depth 5 https://github.com/hug5/serv_dot.git /home/$NEW_USER/tmp/serv_dot
else
    echo ">>> serv_dot already exists... pulling..."
    cd /home/$NEW_USER/tmp/serv_dot
    sudo -u $NEW_USER git pull --depth 5
fi


# --- Validation ---
sleep 1; echo "•"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>>"
echo ">>> Verification. Check results:"

echo -e "\n•\n\n▪ cat /etc/default/locale"
cat /etc/default/locale

echo -e "\n•\n\n▪ cat /etc/locale.gen | grep 'en_US.UTF-8 UTF-8'"
cat /etc/locale.gen | grep 'en_US.UTF-8 UTF-8'

echo -e "\n•\n\n▪ locale"
echo "Note: This won't show up correctly until reboot."
locale

echo -e "\n•\n\n▪ localectl status"
localectl status

echo -e "\n•\n\n▪ cat /etc/vconsole.conf"
[[ -f /etc/vconsole.conf ]] && cat /etc/vconsole.conf
# cat /etc/vconsole.conf &>/dev/null
  # Not sure why when vconsole.conf doesn't exist, it breaks the damn script!

echo -e "\n•\n\n▪ timedatectl status"
timedatectl status
  # More human readable; more laggy?

echo -e "\n•\n\n▪ timedatectl show"
timedatectl show
  # more machine readable friendly; May be less laggy?

echo -e "\n•\n\n▪ cat /etc/timezone"
cat /etc/timezone

echo -e "\n•\n\n▪ ls -l /etc/localtime"
ls -l /etc/localtime

echo -e "\n•\n\n▪ cat /etc/hostname file"
cat /etc/hostname

echo -e "\n•\n\n▪ cat /etc/hosts file"
cat /etc/hosts

echo -e "\n•\n\n▪ grep "update_etc_hosts" /etc/cloud/cloud.cfg"
grep "update_etc_hosts" /etc/cloud/cloud.cfg;
  # Should be commented out on vultr servers

echo -e "\n•\n\n▪ ls -al $SSH_DIR/authorized_keys"
ls -al $SSH_DIR/authorized_keys

echo -e "\n•\n\n▪ ls -al /home/$NEW_USER/tmp/serv_dot"
ls -al /home/$NEW_USER/tmp/serv_dot


# --- Close ---
echo -e "\n•\n\n🛠️  Setup #1 Complete!"
echo ""

# NTP enable failed; Vultr always fails!
# if [[ $i -eq 6 ]]; then
if [[ ! "$NTP_ENABLED" ]]; then
    echo "Looks like NTP enable failed."
    echo "Try again manually:"
    echo "$ timedatectl set-ntp true"
    echo "And check status:"
    echo "$ timedatectl status"
    echo "$ timedatectl show"
    echo -e "\n- - - - - - - - - - - - - -\n"
fi

echo "What to do next:"
echo -e "\n$ su $NEW_USER"
echo
echo "Install dot files and applications:"
echo "$ cd ~/tmp/serv_dot"
echo "$ . serv_dot.sh"


###############################################

  # --- User Creation ---

  # This had problems with set -eu; when error returned, script halts;
  # UID_VAR=$(id "$NEW_USER" &>/dev/null) || true
    # If user doesn't exist, then send error to /dev/null
    # Don't want bash script to exit because of error;
  # ID_EXIST=$(echo "$UID_VAR" | grep uid)
  # if [[ -z "$ID_EXIST" ]]; then


  # What's getent?
  # getent (short for "get entries") is a Linux/Unix command that
   # fetches entries from system databases like /etc/passwd,
   # /etc/group, or even LDAP/NIS. It’s a portable, standardized
   # way to query user/group info without parsing files directly.
  # Other entries include: ahosts, group, aliases, etc.

  #-----------------------

  # # SSH Key Setup (more secure than passwords):
  # echo ">>> Setting up SSH keys for $NEW_USER:"
  # mkdir -p "/home/$NEW_USER/.ssh"
  # curl -sSL "https://github.com/yourusername.keys" > "/home/$NEW_USER/.ssh/authorized_keys"
  # chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
  # chmod 700 "/home/$NEW_USER/.ssh"
  # chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"


  # # Automated Updates:
  # echo ">>> Configuring automatic updates:"
  # apt install -y unattended-upgrades
  # dpkg-reconfigure -plow unattended-upgrades

  # # Firewall (UFW):
  # echo ">>> Enabling firewall:"
  # ufw allow OpenSSH
  # ufw --force enable

