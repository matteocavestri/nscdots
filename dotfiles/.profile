# Load environment variables from /etc/environment
if [ -f /etc/environment ]; then
  while IFS='=' read -r key value; do
    # Trim spaces around the key and value
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    # Remove surrounding double quotes from the value if present
    value=${value#\"}
    value=${value%\"}
    # Export the key-value pair as an environment variable
    export "$key=$value"
  done < <(grep -v '^#' /etc/environment) # Ignore lines starting with #
fi

# Add $HOME/.local/bin to the $PATH
if [ -d "$HOME/.local/bin" ]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# Setup XDG dirs
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export TMPDIR="$XDG_RUNTIME_DIR/tmp"

# Flatpak settings
export XDG_DATA_DIRS=/var/lib/flatpak/exports/share:/usr/share
export XDG_CONFIG_DIRS=/var/lib/flatpak/exports/etc:/etc
export FLATPAK_USER_DIR=$HOME/.local/share/flatpak
export FLATPAK_SYSTEM_DIR=/var/lib/flatpak
export FLATPAK_ENABLE_SOCKETS=pipewire
export PATH="/var/lib/flatpak/exports/bin:$HOME/.local/share/flatpak/exports/bin:$PATH"

# Default programs variables
export EDITOR="nvim"
export TERMINAL="alacritty"
# Use bash as default shell
export SHELL="bash"

# Programming languages
# Golang
export GOPATH="$HOME/.local/share/go"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$PATH"
# Rust
export CARGO_HOME="$HOME/.local/share/cargo"
export PATH="$CARGO_HOME/bin:$PATH"
# Nodejs
export NODE_PATH="$HOME/.local/share/nodejs/lib/node_modules"
export PATH="$HOME/.local/share/nodejs/bin:$PATH"
if [ "$(npm config get prefix)" != "$HOME/.local/share/nodejs" ]; then
  npm config set prefix "$HOME/.local/share/nodejs"
fi
# Python
export PYTHONUSERBASE="$HOME/.local/share/python"
export PATH="$PYTHONUSERBASE/bin:$PATH"
export PIPX_HOME="$HOME/.local/share/pipx"
export PIPX_BIN_DIR="$PIPX_HOME/bin"
export PATH="$PIPX_BIN_DIR:$PATH"
# Lua
LUAROCKS_TREE="$HOME/.local/share/lua"
LUAROCKS_BIN="$LUAROCKS_TREE/bin"
if [ -d "$LUAROCKS_BIN" ]; then
  PATH="$LUAROCKS_BIN:$PATH"
fi

# Cleaning up $HOME dir
export GTK2_RC_FILES="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-2.0/gtkrc-2.0"
export LESSHISTFILE="-"
export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wget/wgetrc"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
export ANDROID_SDK_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/android"
