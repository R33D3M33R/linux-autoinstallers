#!/bin/bash 
#Author: Andrej Mernik, 2015-2017, https://andrej.mernik.eu/
#License: GPLv3

# errors: bash autoinstall.sh >out.txt 2>&1
default_user='htpc'
sources_list='/etc/apt/sources.list'
grub_default='/etc/default/grub'
nfs_exports='/etc/exports'
homedir="/home/$default_user/"
sddm_config='/etc/sddm.conf'
xsession_file='kodi.desktop'

# the script must be run by root
if [[ $(id -u) -ne 0 ]]; then
    echo 'This script must be run as root!'
    exit
fi

# enable the non-free and contrib repositories
if grep -q 'main contrib non-free' $sources_list; then
    echo 'Non-free and contrib repositories already enabled!'
else
  echo 'Enabling non-free and contrib repositories ...'
  sed -i.bak 's/main/main contrib non-free/' $sources_list
fi

# enable backports
if grep -q 'stretch-backports' $sources_list; then
    echo 'Backports already enabled!'
else
  echo 'Enabling backports ...'
  cp $sources_list "sources_list.bak"
  echo 'deb http://ftp.si.debian.org/debian stretch-backports main contrib non-free' >> $sources_list
fi

apt-get update

echo 'Installing packages ...'
# main system
apt-get install -y desktop-base firefox-esr k3b kde-plasma-desktop nfs-kernel-server plymouth plymouth-themes pm-utils qbittorrent rsync
# hardware support
apt-get install -y firmware-linux-nonfree firmware-realtek
# kodi
apt-get install -y kodi
# localization
apt-get install -y kde-l10n-sl k3b-i18n firefox-esr-l10n-sl

# cleanup
apt-get clean

echo 'Additional configuration ...'
# prepare grub for themes
if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"' $grub_default; then
  echo 'Enabling splash ...'
  sed -i.bak 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' $grub_default
  grub_update=1
fi
if grep -q 'GRUB_TIMEOUT=5' $grub_default; then
  echo 'Disabling countdown timer ...'
  sed -i.bak 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' $grub_default
  grub_update=1
fi
# update grub if changes were made
if [[ $grub_update -eq 1 ]]; then
  echo 'Updating grub ...'
  update-grub
fi

# plymouth
if [ "$(/usr/sbin/plymouth-set-default-theme)" == "softwaves" ]; then
  echo "Boot theme already set to softwaves!"
elif /usr/sbin/plymouth-set-default-theme --list | grep -q softwaves; then
  echo "Setting boot theme to softwaves ..."
  /usr/sbin/plymouth-set-default-theme -R softwaves
else
  echo 'Cannot set plymouth theme. Check if desktop-base is installed!'
fi

# nfs-exports
if grep -q "$homedir 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,async)" $nfs_exports; then
  echo 'NFS exports already set!'
else
  echo 'Setting NFS exports ...'
  echo "$homedir 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,async)" >> $nfs_exports
fi

# KDE autologin
if [ -f "$sddm_config" ]; then
    #sddm config exists
    if grep -q "User=$default_user" $sddm_config && grep -q "Session=$xsession_file" $sddm_config; then
        echo 'KDE autologin already enabled!'  
    else
        if [ -f "/usr/share/xsessions/$xsession_file" ]; then
          echo 'Enabling autologin ...'
          sed -i.bak1 "s/User=/User=$default_user/" $sddm_config
          sed -i.bak2 "s/Session=/Session=$xsession_file/" $sddm_config
        fi
else
    #generate sddm config
    echo "[Autologin]\nSession=$xsession_file\nUser=$default_user" > $sddm_config
fi
