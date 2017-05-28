#!/bin/bash 
#Author: Andrej Mernik, 2015-2017, https://andrej.mernik.eu/
#License: GPLv3

# errors: bash autoinstall.sh >out.txt 2>&1
default_user='htpc'
sources_list='/etc/apt/sources.list'
grub_default='/etc/default/grub'
nfs_exports='/etc/exports'
homedir="/home/$default_user/"
kdm_config='/etc/kde4/kdm/kdmrc'
xbmc_autostart="$homedir.kde/Autostart/xbmc"

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

apt-get update

echo 'Installing packages ...'
# main system
apt-get install -y desktop-base k3b nfs-kernel-server plymouth plymouth-themes pm-utils qbittorrent rsync
# hardware support
apt-get install -y firmware-linux-nonfree firmware-realtek
# owncloud
apt-get install -y owncloud mysql-server phpmyadmin
# xbmc
apt-get install -y xbmc
# localization
apt-get install kde-l10n-sl k3b-i18n

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
if [ "$(/usr/sbin/plymouth-set-default-theme)" == "lines" ]; then
  echo "Boot theme already set to lines!"
elif /usr/sbin/plymouth-set-default-theme --list | grep -q lines; then
  echo "Setting boot theme to lines ..."
  /usr/sbin/plymouth-set-default-theme -R lines
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
if grep -q '#AutoLoginEnable=true' $kdm_config; then
  echo 'Enabling autologin ...'
  sed -i.bak1 's/#AutoLoginEnable=true/AutoLoginEnable=true/' $kdm_config
  sed -i.bak2 "s/#AutoLoginUser=fred/AutoLoginUser=$default_user/" $kdm_config
else
  echo 'KDE autologin already enabled!'  
fi

# autostart XBMC on boot
if [[ -d "$homedir.kde/" ]]; then
  if [[ -L "$xbmc_autostart" ]]; then
      echo 'XMBC already set to autostart!'
  else
    echo 'Enabling XBMC autostart ...'
    ln -s /usr/bin/xbmc $xbmc_autostart
  fi
else
  echo 'Start KDE once and restart this script! XBMC not set to autostart'
fi
