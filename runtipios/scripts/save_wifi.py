#!/usr/bin/env python3
"""
Runtipi WiFi Configuration Web Server
Handles WiFi credentials submission from the captive portal
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse
import subprocess
import os
import sys
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/runtipi-wifi.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class WifiConfigHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info("%s - %s" % (self.address_string(), format % args))
    
    def do_POST(self):
        try:
            # Read POST data
            length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(length).decode('utf-8')
            params = urllib.parse.parse_qs(post_data)
            
            ssid = params.get('ssid', [''])[0].strip()
            password = params.get('password', [''])[0].strip()
            
            logger.info(f"Received WiFi configuration request for SSID: {ssid}")
            
            if not ssid:
                self.send_error(400, "SSID is required")
                return
            
            if not password:
                self.send_error(400, "Password is required")
                return
            
            # Configure wpa_supplicant
            logger.info("Configuring wpa_supplicant...")
            wpa_conf = f'/etc/wpa_supplicant/wpa_supplicant.conf'
            
            # Generate WPA configuration
            result = subprocess.run(
                ['wpa_passphrase', ssid, password],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Backup existing config
            if os.path.exists(wpa_conf):
                subprocess.run(['cp', wpa_conf, f'{wpa_conf}.backup'], check=False)
            
            # Write new configuration
            with open(wpa_conf, 'a') as f:
                f.write('\n' + result.stdout)
            
            logger.info("✓ WiFi configuration saved")
            
            # Send success response before shutting down services
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            response = """
            <html>
            <head>
                <meta charset="utf-8">
                <title>Configuration réussie</title>
                <style>
                    body { font-family: Arial; text-align: center; padding: 50px; background: #f0f0f0; }
                    .success { background: white; padding: 30px; border-radius: 10px; display: inline-block; }
                    h1 { color: #28a745; }
                </style>
            </head>
            <body>
                <div class="success">
                    <h1>✓ Wi-Fi configuré !</h1>
                    <p>Runtipi va démarrer dans quelques instants...</p>
                    <p>Vous pouvez fermer cette fenêtre.</p>
                </div>
            </body>
            </html>
            """
            self.wfile.write(response.encode('utf-8'))
            
            # Stop hotspot services
            logger.info("Stopping hotspot services...")
            subprocess.run(['systemctl', 'stop', 'runtipi-hotspot.service'], check=False)
            subprocess.run(['systemctl', 'stop', 'hostapd'], check=False)
            subprocess.run(['systemctl', 'stop', 'dnsmasq'], check=False)
            
            # Restart networking to apply WiFi config
            logger.info("Restarting networking...")
            subprocess.run(['systemctl', 'restart', 'dhcpcd'], check=False)
            
            # Start Runtipi installation in background
            logger.info("Starting Runtipi installation...")
            subprocess.Popen(
                ['bash', '/opt/runtipi-hotspot/scripts/30-install-runtipi.sh'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            
            # Shutdown this server
            logger.info("Shutting down configuration server...")
            subprocess.Popen(['pkill', '-f', 'save_wifi.py'])
            
        except Exception as e:
            logger.error(f"Error processing WiFi configuration: {e}", exc_info=True)
            self.send_error(500, f"Configuration error: {str(e)}")

def run_server(port=8000):
    """Start the WiFi configuration web server"""
    try:
        server = HTTPServer(('0.0.0.0', port), WifiConfigHandler)
        logger.info(f"✓ WiFi configuration server started on port {port}")
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    run_server()
