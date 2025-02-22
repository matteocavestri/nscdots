# nscdots

## Structure

**BOOTMANAGER**
refind

**BOOTLOADER**
ZFSBootMenu

**FILESYSTEM**
ZFS

**INIT SYSTEM**
OpenRC (AlpineLinux based)
In future:  SystemD (ArchLinux based), Runit (VoidLinux based)

**PACKAGE MANAGER**
apk (AlpineLinux based)
In future: pacman, paru (ArchLinux based), xbps (VoidLinux based)
Added for all:
pipx, cargo, go, npm

**LOGIN MANAGER**
elogind with elogind-polkit

**AUDIO-VIDEO**
pipewire
pipewire-pulse pipewire-alsa pipewire-jack v4l-utils

**GRAPHICS SESSIONS**
wayland
greetd (cage compositor)
Sway, Labwc

**SECURITY**
iptables, ip6tables ufw
apparmor

**CONTAINER**
podman, lxc
distrobox

**VIRTUALISATION**
kvm, qemu

**EMULATION - NOT SO MUCH EMULATION**
waydroid, wine

## Roadmap

[ ] Make installation scripts
[ ] Clean everything
[ ] Make dotfiles
[ ] Documenting
[ ] Make custom tui
[ ] Make custom gui programs
[ ] Make iso
[ ] Custom builds --> Xen

## Workflow

Minimal functional, customizable desktop environment
Use distrobox to install programs.
In future graphical store ...
Multiple desktop themes ...
System settings:

- Sway
- Labwc
- wallpaper
- services
- devices
- ...

## Philosophy

- Everything possible in posix shell
- Minimal system, documentation (man)
- Professional desktop use
- Developer/desktop use

## Install

### Alpine

- start an alpine 3.21 extended live
- login as root
- run `setup-interfaces -r`
- download the script: `wget https://raw.githubusercontent.com/matteocavestri/nscdots/main/scripts/zfs-prepare.sh`
- run `sh zfs-prepare.sh`
- enter in chroot
- download the script: `wget https://raw.githubusercontent.com/matteocavestri/nscdots/main/scripts/zfs-install.sh`
- run `sh zfs-install.sh`
- reboot
- run `setup-interfaces -r`
- run `setup-alpine` and ctrl+x when you have to format a disk (alpine is already installed)
- clone the repo: `https://github.com/matteocavestri/nscdots.git`
- run `zfs snapshot zroot/ROOT/alpine@initial-install`
- run `./usr/sbin/setup-hardware`
- run `./usr/sbin/setup-desktop-environment`
- run `./usr/bin/install-nscdots`

### Void

- start a void linux (zfs) live
- login as root
- `xbps-install -S wget`
- download the script: `wget https://raw.githubusercontent.com/matteocavestri/nscdots/main/scripts/zfs-prepare.sh`
- run `sh zfs-prepare.sh`
- enter in chroot
- download the script: `wget https://raw.githubusercontent.com/matteocavestri/nscdots/main/scripts/zfs-install.sh`
- run `sh zfs-install.sh`
- reboot
- you may need to enable dhcpd

  ```shell
  cp -R /etc/sv/dhcpcd-eth0 /etc/sv/dhcpcd-enp3s0
  sed -i 's/eth0/enp3s0/' /etc/sv/dhcpcd-enp3s0/run
  ln -s /etc/sv/dhcpcd-enp3s0 /var/service/
  ```

- run `zfs snapshot zroot/ROOT/void@initial-install`
- clone the repo: `https://github.com/matteocavestri/nscdots.git`
- run `./usr/sbin/setup-hardware`
