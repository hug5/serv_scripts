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

NEW_USER=""
HOSTNAME=""

## Choose public ssh key to use:
## Linode
#SSH_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIND3WdyM/uNlOPA3hnGI1NojU0GAhnya5LmEIXsTpkSZ linode"

## Vultr
#SSH_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJvRchOMU0BxUkl3homRaW91rFbM6TAFryqCkqzOk1gD vultr"

## DigitalOcean
#SSH_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCkSINhno1wkFfqjounBUilwg4rhDf2X8DKDix1IRAr digitalocean"


# Heredoc
# /etc/hosts setting:
# EOF without quotes you can use variables, etc;
# pass through sed to remove leading spaces
HOSTS=$(cat << EOF | sed 's/^[[:space:]]*//'

    127.0.0.1         localhost localhost.localdomain
    127.0.1.1         rail rail.paperdrift.com
    172.236.252.18    rail rail.paperdrift.com

    # For IPv6
    2a01:7e03::2000:39ff:fece:cee2  rail rail.paperdrift.com

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
LOCALE="en_US.UTF-8"
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
      echo "Alright... here we go!"
      ;;
esac

# --- apt update & upgrade ---
echo "•"
echo ">>> apt update && update upgrade:"
apt update -y && apt upgrade -y


# --- Root Setup ---
echo "•"
echo ">>> Set root password:"
passwd root
echo ">>> Setting root shell to bash..."
chsh -s /bin/bash root
  # -s : name of shell


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


# --- Locale Language ---
sleep 1; echo "•"



echo ">>> Setting locale to $LOCALE..."
# localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
  # LC_ALL=en_US.UTF-8 --- will error;
  # LC_ALL=en_US.UTF-8 not valid, refusing.
localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en
# localectl set-locale LANG=en_AU.UTF-8 UTF-8 LANGUAGE=en_AU:en
  # If ever get error here, they may need to manually uncomment relevant language in /etc/locale.gen; but so far, it's fine;

# Noticing now that LANG and LANGUAGE aren't set in locale command until it's sourced like this:
# . /etc/default/locale
# Or rebooted;

# Doing this below as I originally did doesn't seem to fix it:

#echo ">>> Doing locale-gen $LOCALE..."
# /usr/sbin/locale-gen
#/usr/sbin/locale-gen en_US.UTF-8
  # generate localisation files;
  # Using full path because when relogin and then try
   # running script again, then can't find locale-gen;
   # but works okay if sudo it;

#echo ">>> Doing update-locale $LOCALE..."
#/usr/sbin/update-locale en_US.UTF-8 LANGUAGE=en_US:en
  # Modify global default locale settings
  # Writes to /etc/default/locale



# --- Timezone ---
sleep 1; echo "•"
echo ">>> Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"
echo "$TIMEZONE" | sudo tee /etc/timezone
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime


# --- Sync NTP clock ---
sleep 1; echo "•"
echo ">>> Set NTP Service..."

# Check that systemd-timesynd is installed
# if systemctl status systemd-timesyncd 2>&1 | grep "could not be found" &>/dev/null; then
if ! systemctl status systemd-timesyncd &>/dev/null; then
    # systemctl status systemd-timesyncd
    # dpkg -l | grep systemd-timesyncd
    # timedatectl timesync-status
    echo ">>> Installing systemd-timesyncd"
    apt install -y systemd-timesyncd
    echo ">>> enabling systemd-timesync"
    systemctl enable --now systemd-timesyncd # enable + start
    # systemctl restart systemd-timesyncd  # Forces D-Bus refresh

    # systemctl status systemd-timesyncd
    # echo ">>> Sleep 4"
    # sleep 4
    # systemctl is-enabled systemd-timesyncd
fi

echo ">>> Synchronize System Clock..."
timedatectl set-ntp true



# --- kb layout ---
sleep 1; echo "•"
echo ">>> Setting kb layout..."
localectl set-x11-keymap us pc105


# --- Setup hostname and hosts file ---
# /etc/hostname
sleep 1; echo "•"
echo ">>> Setting /etc/hostname file to $HOSTNAME..."
hostnamectl set-hostname "$HOSTNAME"
echo ">>> Setting /etc/hosts file..."
echo "$HOSTS" | sudo tee /etc/hosts >/dev/null
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

echo -e "\n•\n\n▪ timedatectl status"
timedatectl status

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
echo "What to do next:"
echo "$ su $NEW_USER"
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

