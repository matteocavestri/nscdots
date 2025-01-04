# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# profile
if [ -f ~/.profile ]; then
  # shellcheck source=/dev/null
  . "$HOME/.profile"
fi

eval "$(starship init bash)"

export HISTCONTROL=ignorespace:ignoredups:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
shopt -s histappend
# Check window size after each command
shopt -s checkwinsize

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    # shellcheck source=/dev/null
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    # shellcheck source=/dev/null
    . /etc/bash_completion
  fi
fi

# Alias definition
if [ -f ~/.config/aliasrc ]; then
  # shellcheck source=/dev/null
  . "$HOME/.config/aliasrc"
fi

# fzf history
bind '"\C-r": "\C-x1\e^\er"'
bind -x '"\C-x1": __fzf_history'

__fzf_history() {
  # Capture the selected command from history using fzf
  local selected_cmd
  selected_cmd=$(history | fzf --tac --tiebreak=index | perl -ne 'm/^\s*([0-9]+)\s*(.*)/ and print "$2"')

  # Check if the selected command is different from the last history entry and the last executed command
  if [[ -n $selected_cmd && $selected_cmd != "$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')" ]]; then
    __ehc "$selected_cmd"
  fi
}

__ehc() {
  if [[ -n $1 ]]; then
    bind '"\er": redraw-current-line'
    READLINE_LINE=${READLINE_LINE:+${READLINE_LINE:0:READLINE_POINT}}${1}${READLINE_LINE:+${READLINE_LINE:READLINE_POINT}}
    READLINE_POINT=$((READLINE_POINT + ${#1}))
  else
    bind '"\er":'
  fi
}

# Function to not log a command in history.
hidden() {
  HISTFILE=/dev/null
  bash -ic "$*"
  history -d "$(history 1)"
}

# `tm` will allow you to select your tmux session via fzf.
tmswitch() {
  [[ -n "$TMUX" ]] && change="switch-client" || change="attach-session"
  if [ "$1" ]; then
    tmux "$change" -t "$1" 2>/dev/null || (tmux new-session -d -s "$1" && tmux "$change" -t "$1")
    return
  fi
  session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0) && tmux i"$change" -t "$session" || echo "No sessions found."
}
