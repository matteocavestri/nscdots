#!/bin/sh

#############################
## INPUT SECTION
#############################
collect_user_inputs() {
  clear

  echo "INFO: Please set the root password:"
  passwd

  echo "Enter your timezone (e.g., Europe/Rome) [UTC]:"
  read -r TIMEZONE
  TIMEZONE="${TIMEZONE:-UTC}"

  echo "Enter your keymap (e.g., us) [us]:"
  read -r KEYMAP
  KEYMAP="${KEYMAP:-us}"

  echo "Enter your encoding (e.g., en_US.UTF-8) [en_US.UTF-8]:"
  read -r ENCODING
  ENCODING="${ENCODING:-en_US.UTF-8}"

  echo "Enter your Workstation Hostname:"
  read -r HOSTNAME
  HOSTNAME="${HOSTNAME:-voidworkstation}"

  # Ask for CPU type
  echo "Select microcode (intel/amd): "
  read -r CPU_CHOICE

  echo "Enter GPU vendors (intel, amd, nvidia; separate by space for multiple): "
  read -r GPU_CHOICE

  for VENDOR in $GPU_CHOICE; do
    case $VENDOR in
    intel)
      echo "Is your Intel GPU pre Coffe Lake or post Coffe Lake? (pre/post): "
      read -r INTEL_CHOICE
      ;;
    nvidia)
      echo "Enter your NVIDIA GPU series (800+/600-700/400-500):"
      read -r NVIDIA_SERIES
      ;;
    esac
  done

  echo "Select your preferred primary GPU from the following (choose dedicated if available):"
  for VENDOR in $GPU_CHOICE; do
    echo "- $VENDOR"
  done

  echo "Enter your choice: "
  read -r PRIMARY_GPU

  echo "INFO: Detecting partitions..."
  lsblk
  echo "Enter the boot partitions separated by space (e.g., /dev/sda1 /dev/sdb1):"
  read -r BOOT_PARTITIONS
  if [ -z "$BOOT_PARTITIONS" ]; then
    echo "ERROR: No boot partitions provided. Exiting."
    exit 1
  fi

  BOOT_PART_COUNT=$(echo "$BOOT_PARTITIONS" | wc -w)

  echo "Enter the username for the administrator account:"
  read -r ADMIN_USER
  if [ -z "$ADMIN_USER" ]; then
    echo "ERROR: No username provided. Exiting."
    exit 1
  fi

  USERNAME="$ADMIN_USER"
}

##################################
## CPU MICROCODE
##################################
install_cpu_microcode() {
  log "INFO" "Installing CPU microcode..."
  xbps-install -S void-repo-nonfree
  case $CPU_CHOICE in
  intel)
    xbps-install -Sy intel-ucode
    ;;
  amd)
    xbps-install -Sy linux-firmware-amd
    ;;
  *)
    log "ERROR" "Invalid CPU type: $CPU_CHOICE"
    exit 1
    ;;
  esac
  log "INFO" "CPU microcode installed for $CPU_CHOICE."
}

##################################
## CPU MICROCODE
##################################
install_gpu_drivers() {
  log "INFO" "Installing GPU drivers for $GPU_CHOICE..."
  for VENDOR in $GPU_CHOICE; do
    case $VENDOR in
    # case $GPU_CHOICE in
    amd)
      xbps-install -Sy linux-firmware-amd \
        mesa-dri vulkan-loader mesa-vulkan-radeon mesa-opencl mesa-vaapi mesa-vdpau
      ;;
    intel)
      xbps-install -Sy linux-firmware-intel \
        mesa-dri mesa-vulkan-intel mesa-opencl mesa-vaapi mesa-vdpau libva-glx
      if [ "$INTEL_GPU_TYPE" = "pre" ]; then
        xbps-install -Sy libva-intel-driver
      else
        xbps-install -Sy intel-media-driver
      fi

      ;;
    nvidia)
      case $NVIDIA_SERIES in
      800+)
        xbps-install -Sy nvidia
        ;;
      600-700)
        xbps-install -Sy nvidia470
        ;;
      400-500)
        xbps-install -Sy nvidia390
        ;;
      *)
        log "ERROR" "Invalid NVIDIA series: $NVIDIA_SERIES"
        exit 1
        ;;
      esac
      ;;
    *)
      log "ERROR" "Invalid GPU vendor: $GPU_CHOICE"
      exit 1
      ;;
    esac
  done
  log "INFO" "GPU drivers installed and environment variables configured."

  configure_primary_gpu
}

##################################
## SYSTEM CONFIGURATION
##################################
configure_system_settings() {
  echo "INFO: Configuring essential system settings..."
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

  cat <<EOF >>/etc/rc.conf
KEYMAP="$KEYMAP"
HARDWARECLOCK="UTC"
EOF

  echo "HOSTNAME=$HOSTNAME" >>/etc/hostname
  log "INFO" "Hostname set to: $HOSTNAME"

  cat <<EOF >>/etc/default/libc-locales
$ENCODING UTF-8
EOF
  echo "LANG=$ENCODING" >/etc/locale.conf

  xbps-reconfigure -f glibc-locales
}

##################################
## SERVICE CONFIG
##################################
service_config() {
  # Setup logging system
  xbps-install -Sy socklog-void
  ln -s /etc/sv/socklog-unix /var/service
  ln -s /etc/sv/nanoklogd /var/service
  usermod -aG socklog "$USERNAME"

  # Setup Cron
  xbps-install -Sy cronie
  ln -s /etc/sv/cronie /var/service

  # Setup NTP
  xbps-install -Sy ntpd-rs
  ln -s /etc/sv/ntpd-rs /var/service

  # Power and session management
  xbps-install -Sy dbus dbus-elogind
  ln -s /etc/sv/dbus /var/service
  xbps-install -Sy elogind polkit-elogind

  # Network management
  xbps-install -Sy NetworkManager python3-dbus

  # Setup xdg desktop portal
  xbps-install -Sy xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde

  # Setup pipewire, gstreamer and v4l
  xbps-install -Sy \
    pipewire wireplumber alsa-pipewire libjack-pipewire gstreamer1-pipewire v4l-utils

  # Wireplumber init
  mkdir -p /etc/pipewire/pipewire.conf.d
  ln -s /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/

  # Setup pipewire-pulse
  ln -s /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/

  # Setup pipewire alsa
  mkdir -p /etc/alsa/conf.d
  ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d
  ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d

  # Setup pipewire jack
  echo "/usr/lib/pipewire-0.3/jack" >/etc/ld.so.conf.d/pipewire-jack.conf
  ldconfig

  # Setup Printer
  xbps-install -Sy cups cups-filters
  ln -s /etc/sv/cupsd /var/service

  # Install apparmor
  xbps-install -Sy apparmor

  # Better fonts
  ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
  xbps-reconfigure -f fontconfig

  # Performance and scaling
  xbps-install irqbalance
  ln -s /etc/sv/irqbalance /var/service/

  # Better memory
  xbps-install earlyoom
  ln -sfv /etc/sv/earlyoom /var/service/
  cat <<EOF >>/etc/default/earlyoom
EARLYOOM_ARGS=" -m 96,92 -s 99,99 -r 5 -n --avoid '(^|/)(runit|Xwayland|sshd|labwc|sway)$'"
EOF
}

##################################
## DESKTOP CONFIG
##################################
desktop_setup() {
  # Install utilities
  xbps-install -Sy \
    clang go rust nodejs python3 lua bash bash-completion \
    cmake make \
    python3-pipx cargo yarn luarocks \
    git neovim tmux htop nvtop \
    lazygit ripgrep fd fzf curl wget starship \
    p7zip unzip xz tar rsync

  # # Wayland
  # xbps-install -Sy \
  #   sway labwc \
  #   swww sway-audio-idle-inhibit swayidle swaylock Waybar \
  #   polkit-kde-agent wl-clipboard cliphist libnotify libinput \
  #   wlsunset fuzzel alacritty network-manager-applet \
  #   grim slurp noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji nerd-fonts \
  #   qt5-wayland qt6-wayland ffmpeg
  # fc-cache -fv
  #
  # # Desktop tools
  # xbps-install -Sy \
  #   qt5ct qt6ct \
  #   dolphin dolphin-plugins ark mpv pavucontrol-qt qpwgraph \
  #   kwallet kwallet-pam kwalletmanager \
  #   okular libreoffice ffmpegthumbs xdg-user-dirs kcalc \
  #   firefox breeze breeze-cursors breeze-icons breeze-gtk \
  #   fuse ntfs-3g smbnetfs nfs-utils virt-manager

  # Setup graphics servers
  xbps-install -Sy \
    mlocate ca-certificates xtools \
    xorg-minimal wl-clipboard libinput libnotify cliphist \
    wayland wayland-protocols wayland-utils xorg-server-xwayland \
    xorg-fonts noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji nerd-fonts \
    qt5-wayland qt6-wayland
  fc-cache -fv

  # Install Desktop Environment and tools
  xbps-install -Sy \
    kde-plasma kde-baseapps \
    ffmpeg breeze breeze-cursors breeze-icons breeze-gtk \
    kdegraphics-thumbnailers ffmpegthumbs ffmpeg \
    qpwgraph libreoffice firefox virt-manager \
    dolphin-plugins xdg-user-dirs okular ark \
    fuse ntfs-3g smbnetfs nfs-utils

  # Setup session start
  echo "exec startplasma-x11" >.xinitrc

  # Setup wine
  xbps-install -Sy \
    wine wine-gecko wine-mono

  su "$USERNAME" -c "xdg-user-dirs-update"

  # xbps-install -Sy \
  #   greetd gtkgreet cage
  # if [ -f /etc/greetd/config.toml ]; then
  #   sed -i 's|command = ".*"|command = "cage -s -mextend -- gtkgreet"|' /etc/greetd/config.toml
  # fi
  # echo "dbus-run-session -- labwc
  #   dbus-run-session -- sway" >>/etc/greetd/environments
  # ln -s /etc/sv/greetd /var/service
}

##################################
## VIRTUALISATION CONFIG
##################################
virtualisation_setup() {
  xbps-install -Sy libvirt qemu qemu-firmware qemu-img spice \
    qemu-system-aarch64 qemu-system-amd64 qemu-system-arm qemu-system-riscv32 qemu-system-riscv64 \
    qemu-user \
    qemu-user-aarch64 qemu-user-amd64 qemu-user-arm
  ln -s /etc/sv/libvirtd /var/service
  ln -s /etc/sv/virtlockd /var/service
  ln -s /etc/sv/virtlogd /var/service
  usermod -aG libvirt "$USERNAME"

  # LXC Install
  xbps-install -Sy lxc
  cat <<EOF >>/etc/subuid
root:1000000:65536
$USERNAME:2000000:65536
EOF
  cat <<EOF >>/etc/subgid
root:1000000:65536
$USERNAME:2000000:65536
EOF
  cat <<EOF >>/etc/lxc/default.conf
lxc.idmap = u 0 1000000 65536
lxc.idmap = g 0 1000000 65536
EOF
  su "$USERNAME" -c "mkdir -p /home/$USERNAME/.config/lxc"
  su "$USERNAME" -c "cat <<EOF >>/home/$USERNAME/.config/lxc/default.conf
lxc.idmap = u 0 2000000 65536
lxc.idmap = g 0 2000000 65536
EOF"
  cat <<EOF >>/etc/lxc/lxc-usernet
$USERNAME veth lxcbr0 40
EOF

  # Install podman and distrobox
  xbps-install -Sy podman fuse-overlayfs
  curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh
  cat <<EOF >>/etc/rc.conf
CGROUP_MODE=unified
EOF
  cat <<EOF >>/etc/containers/storage.conf
[storage]
runroot="/var/lib/containers/"
graphroot="/var/lib/containers/storage"
driver="zfs"
EOF

  mkdir -p /home/"$USERNAME"/.config/containers
  cat <<EOF >>/home/"$USERNAME"/.config/containers/storage.conf
[storage]
runroot="/home/$USERNAME/.local/share/containers/"
graphroot="/home/$USERNAME/.local/share/containers/storage"
driver="overlay"
EOF
  chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.config/containers
  chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.config/containers/*

}
##################################
## INITRAMFS CONFIG
##################################
configure_initramfs() {
  echo "INFO: Configuring initramfs for ZFS..."
  cat <<EOF >/etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
install_items+=" /etc/zfs/zroot.key "
EOF
  xbps-install -Sy zfs
  zfs set org.zfsbootmenu:commandline="quiet loglevel=0 apparmor=1 security=apparmor" zroot/ROOT
  zfs set org.zfsbootmenu:keysource="zroot/ROOT/${ID}" zroot
}

##################################
## BOOTLOADER SECTION
##################################
configure_bootloader() {
  echo "INFO: Configuring EFI bootloader..."

  if [ "$BOOT_PART_COUNT" -eq 1 ]; then
    BOOT_DEVICE="$BOOT_PARTITIONS"
    mkfs.vfat -F32 "$BOOT_DEVICE"
    cat <<EOF >>/etc/fstab
$(blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2) /boot/efi vfat defaults 0 0
EOF
    mkdir -p /boot/efi
    mount /boot/efi
  else
    echo "INFO: Creating RAID 1 for boot partitions..."
    mdadm --create --verbose --level 1 --metadata 1.0 \
      --homehost any --raid-devices "$BOOT_PART_COUNT" /dev/md/esp \
      $BOOT_PARTITIONS
    mdadm --assemble --scan
    mdadm --detail --scan >>/etc/mdadm.conf

    mkfs.vfat -F32 /dev/md/esp
    cat <<EOF >>/etc/fstab
/dev/md/esp /boot/efi vfat defaults 0 0
EOF
    mkdir -p /boot/efi
    mount /boot/efi
  fi

  xbps-install -Sy zfsbootmenu gummiboot-efistub curl
  mkdir -p /boot/efi/EFI/BOOT

  rm /etc/zfsbootmenu/config.yaml
  cat <<EOF >>/etc/zfsbootmenu/config.yaml
Global:
  ManageImages: true
  BootMountPoint: /boot/efi
Components:
  Enabled: false
EFI:
  ImageDir: /boot/efi/EFI/zbm
  Versions: false
  Enabled: true
Kernel:
  CommandLine: quiet loglevel=0
EOF
  generate-zbm

  curl -o /boot/efi/EFI/BOOT/BOOTX64.EFI -LJ https://get.zfsbootmenu.org/efi/recovery

  xbps-install -Sy refind
  refind-install
  rm /boot/refind_linux.conf

  cat <<EOF >>/boot/efi/EFI/BOOT/refind_linux.conf
"Boot default"  "quiet loglevel=0 zbm.skip apparmor=1 security=apparmor"
"Boot to menu"  "quiet loglevel=0 zbm.show apparmor=1 security=apparmor"
EOF
}

##################################
## ADMIN USER
##################################
create_admin_user() {
  echo "INFO: Creating administrator account..."
  useradd -m -G wheel "$ADMIN_USER"
  echo "Set password for $ADMIN_USER:"
  passwd "$ADMIN_USER"

  log "INFO" "Enabling sudo for the wheel group..."
  if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    log "INFO" "Sudo enabled for the wheel group."
  else
    log "INFO" "Sudo is already enabled for the wheel group."
  fi

  mkdir /etc/sv/runsvdir-$USERNAME
  cat <<EOF | tee "/etc/sv/runsvdir-$USERNAME/run" >/dev/null
#!/bin/sh

export USER="$USERNAME"
export HOME="/home/$USERNAME"

groups="\$(id -Gn "$USERNAME" | tr ' ' ':')"
svdir="\$HOME/.service"

exec chpst -u "\$USER:\$groups" runsvdir "\$svdir"
EOF

  chmod +x "/etc/sv/runsvdir-$USERNAME"
  ln -s /etc/sv/runsvdir-"$USERNAME" /var/service
}

##################################
## PRIMARY GPU DEFINITION
##################################
configure_primary_gpu() {
  log "INFO" "Configuring primary GPU..."
  case $PRIMARY_GPU in
  nvidia)
    log "INFO" "Primary GPU set to: NVIDIA"
    ;;
  amd)
    echo "LIBVA_DRIVER_NAME=radeonsi" >>/etc/environment
    echo "VDPAU_DRIVER=radeonsi" >>/etc/environment
    echo "RUSTICL_ENABLE=radeonsi" >>/etc/environment
    log "INFO" "Primary GPU set to: AMD"
    ;;
  intel)
    if [ "$INTEL_CHOICE" = "post" ]; then
      echo "LIBVA_DRIVER_NAME=iHD" >>/etc/environment
    else
      echo "LIBVA_DRIVER_NAME=i965" >>/etc/environment
    fi
    echo "VDPAU_DRIVER=va_gl" >>/etc/environment
    echo "RUSTICL_ENABLE=iris" >>/etc/environment
    log "INFO" "Primary GPU set to: Intel"
    ;;
  *)
    log "ERROR" "Invalid choice for primary GPU: $PRIMARY_GPU"
    return
    ;;
  esac
}

# Main execution block
collect_user_inputs
install_cpu_microcode
install_gpu_drivers
configure_system_settings
service_config
desktop_setup
virtualisation_setup
configure_initramfs
configure_bootloader
create_admin_user
rm /var/service/dhcpcd-enp3s0
ln -s /etc/sv/NetworkManager /var/service

# Final instructions
echo "INFO: In-chroot setup completed successfully for Void Linux."
echo "Before rebooting, exit the chroot and run the following commands:"
echo "  umount -n -R /mnt"
echo "  zpool export zroot"
echo "Then, reboot the system."
