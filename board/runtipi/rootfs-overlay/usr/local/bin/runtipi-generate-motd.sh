#!/bin/bash
# RuntipiOS MOTD Generator

CONFIG_FILE="/etc/runtipi/config.yml"
MOTD_FILE="/etc/motd"
INSTALL_MARKER="/etc/runtipi/installed"

log() {
    echo "[RuntipiOS MOTD] $1" | tee -a /var/log/runtipi-motd.log
}

log "Waiting for Runtipi installation to complete..."
for i in {1..300}; do
    if [ -f "$INSTALL_MARKER" ]; then
        log "Runtipi installation detected as complete"
        break
    fi
    sleep 1
done

sleep 2

IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

cat > "$MOTD_FILE" << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                    Welcome to RuntipiOS                    ║
║            The Runtipi Embedded Operating System            ║
╚════════════════════════════════════════════════════════════╝

EOF

echo "" >> "$MOTD_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
echo "System Information" >> "$MOTD_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
echo "  Hostname: $HOSTNAME" >> "$MOTD_FILE"
echo "  IP Address: $IP" >> "$MOTD_FILE"
echo "  Uptime: $(uptime -p 2>/dev/null || echo 'N/A')" >> "$MOTD_FILE"
echo "" >> "$MOTD_FILE"

if [ -f "$INSTALL_MARKER" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
    echo "Runtipi is Ready!" >> "$MOTD_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
    echo "  Web Interface:" >> "$MOTD_FILE"
    echo "    → http://$IP" >> "$MOTD_FILE"
    echo "    → http://runtipi.local" >> "$MOTD_FILE"
    echo "" >> "$MOTD_FILE"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
    echo "Runtipi Installation In Progress..." >> "$MOTD_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
    echo "  Runtipi is installing. This may take 2-3 minutes." >> "$MOTD_FILE"
    echo "  Web interface will be available at:" >> "$MOTD_FILE"
    echo "    → http://$IP" >> "$MOTD_FILE"
    echo "    → http://runtipi.local" >> "$MOTD_FILE"
    echo "" >> "$MOTD_FILE"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
echo "Documentation & Support" >> "$MOTD_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$MOTD_FILE"
echo "  Runtipi: https://runtipi.io" >> "$MOTD_FILE"
echo "  RuntipiOS: https://github.com/meienberger/runtipi" >> "$MOTD_FILE"
echo "" >> "$MOTD_FILE"
echo "╚════════════════════════════════════════════════════════════╝" >> "$MOTD_FILE"

log "MOTD generated at $MOTD_FILE"
