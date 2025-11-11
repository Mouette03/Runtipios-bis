# ~/.bashrc for RuntipiOS user

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Aliases
alias ll='ls -lah'
alias update='sudo apt update && sudo apt upgrade -y'
alias runtipi-status='systemctl status runtipi-install'
alias runtipi-logs='journalctl -u runtipi-install -f'
alias runtipi-install-log='tail -f /tmp/runtipi-install.log'
alias runtipi-start='cd ~/runtipi && sudo ./runtipi-cli start'
alias runtipi-stop='cd ~/runtipi && sudo ./runtipi-cli stop'
alias runtipi-restart='cd ~/runtipi && sudo ./runtipi-cli restart'

# Welcome message on first login
if [ ! -f ~/.runtipi_welcome_shown ]; then
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║              Welcome to RuntipiOS - First Login!              ║
╚═══════════════════════════════════════════════════════════════╝

Runtipi will install automatically when internet is available.

Check installation status:
  systemctl status runtipi-install
  journalctl -u runtipi-install -f
  tail -f /tmp/runtipi-install.log  (detailed installation log)

After installation:
  Access at: http://runtipios.local OR http://YOUR_IP

Useful commands:
  runtipi-status        - Check installation status
  runtipi-logs          - View systemd logs
  runtipi-install-log   - View detailed installation log
  runtipi-start         - Start Runtipi
  runtipi-stop          - Stop Runtipi
  runtipi-restart       - Restart Runtipi

Network info:
EOF
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1 | xargs -I {} echo "  IP Address: {}"
    echo ""
    touch ~/.runtipi_welcome_shown
fi

# Prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
