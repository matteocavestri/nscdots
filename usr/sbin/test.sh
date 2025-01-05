#!/bin/sh

###########################################################
# Script Name: setup-hardware
# Description: This script installs CPU microcode and GPU drivers,
#              configures multi-GPU setups, and updates environment variables.
# Usage:       Run the script and follow the prompts.
# Author:      Matteo Cavestri
# Version:     1.0
# Date:        2025-01-02
###########################################################

usage() {
  cat <<EOF
Usage: setup-hardware

Follow the prompts to install CPU microcode and GPU drivers, and configure your hardware.
EOF
}

log() {
  level="$1"
  message="$2"
  printf '[%s] %s\n' "$level" "$message"
}

prompt_system() {
  echo "Select your system type (void/alpine):"
  read -r SYSTEM_TYPE
  case $SYSTEM_TYPE in
  void | alpine)
    log "INFO" "Selected system: $SYSTEM_TYPE"
    ;;
  *)
    log "ERROR" "Invalid system type. Please choose 'void' or 'alpine'."
    exit 1
    ;;
  esac
}

#
## PROMPT USER
#
prompt_user_alpine() {
  echo "Enter the username for configuration: "
  read -r USERNAME

  echo "Select microcode (intel, amd): "
  read -r MICROCODE_CHOICE

  echo "Enter GPU vendors (intel, amd, nvidia; separate by space for multiple): "
  read -r GPU_CHOICE

  for VENDOR in $GPU_CHOICE; do
    case $VENDOR in
    intel)
      echo "Is your Intel GPU pre-Broadwell or post-Broadwell? (pre/post): "
      read -r INTEL_CHOICE
      ;;
    amd)
      echo "Is your AMD GPU pre-Vega or post-Vega? (pre/post): "
      read -r AMD_CHOICE
      ;;
    esac
  done

  echo "Select your preferred primary GPU from the following (choose dedicated if available):"
  for VENDOR in $GPU_CHOICE; do
    echo "- $VENDOR"
  done

  echo "Enter your choice: "
  read -r PRIMARY_GPU

  echo "You have chosen the following configuration:"
  echo "User: $USERNAME"
  echo "CPU Microcode: $MICROCODE_CHOICE"
  echo "GPU Vendors: $GPU_CHOICE"
  [ -n "$INTEL_CHOICE" ] && echo "Intel GPU: $INTEL_CHOICE"
  [ -n "$AMD_CHOICE" ] && echo "AMD GPU: $AMD_CHOICE"
  echo "Primary GPU: $PRIMARY_GPU"

  echo "Do you want to proceed with this configuration? (yes/no): "
  read -r CONFIRMATION
  if [ "$CONFIRMATION" != "yes" ]; then
    log "INFO" "Setup aborted by user."
    exit 0
  fi
}

prompt_user_void() {
  echo "Welcome to the Void Linux setup script."

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

  # Ask for system locale
  echo "Enter your preferred locale (e.g., en_US.UTF-8):"
  read -r LANG_CHOICE

  # Ask for username
  echo "Enter the username to create:"
  read -r USERNAME

  echo "Enter the password for user $USERNAME:"
  stty -echo # Disable echo
  read -r USER_PASSWORD
  stty echo # Re-enable echo
  echo      # Move to a new line for clean output
  # Ask for hostname
  echo "Enter the hostname for this system:"
  read -r HOSTNAME

  # Confirm the configuration
  echo "You have chosen:"
  echo "CPU: $CPU_CHOICE"
  echo "GPU: $GPU_CHOICE"
  [ "$GPU_CHOICE" = "intel" ] && echo "Intel GPU type: $INTEL_GPU_TYPE"
  [ "$GPU_CHOICE" = "nvidia" ] && echo "NVIDIA series: $NVIDIA_SERIES"
  echo "Primary GPU: $PRIMARY_GPU"
  echo "Locale: $LANG_CHOICE"
  echo "Username: $USERNAME"
  echo "Hostname: $HOSTNAME"
  echo "Do you confirm? (yes/no):"
  read -r CONFIRMATION
  if [ "$CONFIRMATION" != "yes" ]; then
    log "INFO" "Setup aborted by user."
    exit 0
  fi
}

#
## CPU MICROCODE
install_cpu_microcode_alpine() {
  log "INFO" "Installing CPU microcode..."
  case $MICROCODE_CHOICE in
  intel)
    apk add intel-ucode
    ;;
  amd)
    apk add amd-ucode
    ;;
  *)
    log "ERROR" "Unknown microcode choice: $MICROCODE_CHOICE"
    return
    ;;
  esac
  log "INFO" "CPU microcode installed."
}

install_microcode_void() {
  log "INFO" "Installing CPU microcode..."
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

#
## GPU DRIVERS
#
install_gpu_drivers_alpine() {
  log "INFO" "Installing GPU drivers..."
  for VENDOR in $GPU_CHOICE; do
    case $VENDOR in
    intel)
      if [ "$INTEL_CHOICE" = "post" ]; then
        apk add intel-media-driver
      elif [ "$INTEL_CHOICE" = "pre" ]; then
        apk add libva-intel-driver
      else
        log "ERROR" "Invalid choice for Intel GPU."
        return
      fi

      apk add \
        linux-firmware-i915 \
        mesa-dri-gallium \
        mesa-va-gallium mesa-vdpau-gallium libva-glx \
        mesa-egl mesa-gbm mesa-gl mesa-gles \
        mesa-rusticl opencl-headers opencl-icd-loader \
        mesa-vulkan-intel
      ;;
    amd)
      if [ "$AMD_CHOICE" = "post" ]; then
        apk add linux-firmware-amdgpu
      else
        apk add linux-firmware-radeon
      fi

      apk add \
        mesa-dri-gallium \
        mesa-va-gallium mesa-vdpau-gallium \
        mesa-egl mesa-gbm mesa-gl mesa-gles \
        mesa-rusticl opencl-headers opencl-icd-loader \
        mesa-vulkan-ati

      if [ "$AMD_CHOICE" = "pre" ]; then
        echo radeon >>/etc/modules
      else
        echo amdgpu >>/etc/modules
      fi

      apk add mkinitfs
      mkinitfs
      ;;
    nvidia)
      apk add \
        mesa-dri-gallium \
        mesa-va-gallium mesa-vdpau-gallium \
        mesa-egl mesa-gbm mesa-gl mesa-gles \
        mesa-rusticl opencl-headers opencl-icd-loader
      ;;
    *)
      log "ERROR" "Unknown vendor: $VENDOR"
      ;;
    esac
  done

  configure_primary_gpu
}

install_gpu_drivers_void() {
  log "INFO" "Installing GPU drivers for $GPU_CHOICE..."
  case $GPU_CHOICE in
  amd)
    xbps-install -Sy linux-firmware-amd mesa-dri vulkan-loader mesa-vulkan-radeon mesa-opencl mesa-vaapi mesa-vdpau
    echo "RUSTICL_ENABLE=radeonsi" >>/etc/environment
    echo "LIBVA_DRIVER_NAME=radeonsi" >>/etc/environment
    echo "VDPAU_DRIVER=radeonsi" >>/etc/environment
    ;;
  intel)
    xbps-install -Sy linux-firmware-intel mesa-dri mesa-vulkan-intel mesa-opencl mesa-vaapi mesa-vdpau libva-glx
    if [ "$INTEL_GPU_TYPE" = "upto" ]; then
      xbps-install -Sy libva-intel-driver
      echo "LIBVA_DRIVER_NAME=i965" >>/etc/environment
    else
      xbps-install -Sy intel-media-driver
      echo "LIBVA_DRIVER_NAME=iHD" >>/etc/environment
    fi
    echo "VDPAU_DRIVER=va_gl" >>/etc/environment
    echo "RUSTICL_ENABLE=iris" >>/etc/environment
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
  log "INFO" "GPU drivers installed and environment variables configured."
}

configure_void() {
  log "INFO" "Setting system locale..."
  echo "LANG=$LANG_CHOICE" >/etc/locale.conf
  log "INFO" "Locale configured: $LANG_CHOICE"
  log "INFO" "Creating user $USERNAME..."
  useradd -m -G wheel "$USERNAME"
  echo "$USERNAME:$USER_PASSWORD" | chpasswd
  chsh -s /bin/bash "$USERNAME"
  log "INFO" "User $USERNAME created and configured."
  log "INFO" "Setting system hostname..."
  echo "HOSTNAME=$HOSTNAME" >>/etc/rc.conf
  log "INFO" "Hostname set to: $HOSTNAME"
  log "INFO" "Enabling sudo for the wheel group..."
  if ! grep -q "^%wheel ALL=(ALL) ALL" /etc/sudoers; then
    sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
    log "INFO" "Sudo enabled for the wheel group."
  else
    log "INFO" "Sudo is already enabled for the wheel group."
  fi
}

configure_primary_gpu_alpine() {
  log "INFO" "Configuring primary GPU..."
  case $PRIMARY_GPU in
  nvidia)
    echo "MESA_LOADER_DRIVER_OVERRIDE=nouveau" >>/etc/environment
    echo "LIBVA_DRIVER_NAME=nouveau" >>/etc/environment
    echo "VDPAU_DRIVER=nouveau" >>/etc/environment
    echo "RUSTICL_ENABLE=nouveau" >>/etc/environment
    log "INFO" "Primary GPU set to: NVIDIA"
    ;;
  amd)
    # echo "MESA_LOADER_DRIVER_OVERRIDE=radeonsi" >>/etc/environment
    echo "LIBVA_DRIVER_NAME=radeonsi" >>/etc/environment
    echo "VDPAU_DRIVER=radeonsi" >>/etc/environment
    echo "RUSTICL_ENABLE=radeonsi" >>/etc/environment
    log "INFO" "Primary GPU set to: AMD"
    ;;
  intel)
    # echo "MESA_LOADER_DRIVER_OVERRIDE=i965" >>/etc/environment
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

clean_variables() {
  unset USERNAME
  unset MICROCODE_CHOICE
  unset GPU_CHOICE
  unset INTEL_CHOICE
  unset AMD_CHOICE
  unset PRIMARY_GPU
}

main() {
  prompt_system

  if [ "$SYSTEM_TYPE" = "void" ]; then
    prompt_user_void
    install_cpu_microcode_void
    install_gpu_drivers_void
    # se
  elif [ "$SYSTEM_TYPE" = "alpine" ]; then
    prompt_user_alpine
    install_cpu_microcode_alpine
    install_gpu_drivers_alpine
  fi

  clean_variables
}

main "$@"
