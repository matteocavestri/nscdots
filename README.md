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

- start an alpine 3.21 extended install
- login as root
- clone the repo: `https://github.com/matteocavestri/nscdots.git`
- run `./scripts/alpine-zfs-prepare.sh`
- enter in chroot
- clone the repo: `https://github.com/matteocavestri/nscdots.git`
- run `./scripts/alpine-zfs-install.sh`
- reboot
- run `./usr/sbin/setup-hardware`
- run `./usr/sbin/setup-desktop-environment`
- run `./usr/bin/install-nscdots`
