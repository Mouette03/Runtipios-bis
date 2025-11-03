#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse, subprocess, os

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        post_data = urllib.parse.parse_qs(self.rfile.read(length).decode())
        ssid = post_data.get('ssid', [''])[0]
        password = post_data.get('password', [''])[0]
        if ssid and password:
            subprocess.run(['bash', '-c', f"wpa_passphrase '{ssid}' '{password}' >> /etc/wpa_supplicant/wpa_supplicant.conf"])
            subprocess.run(['systemctl', 'stop', 'hostapd', 'dnsmasq'])
            subprocess.run(['systemctl', 'restart', 'networking'])
            subprocess.Popen(['bash', '/opt/runtipi-hotspot/scripts/30-install-runtipi.sh'])
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"<html><body><h2>Wi-Fi configured! Runtipi will start shortly.</h2></body></html>")

if __name__ == '__main__':
    HTTPServer(('0.0.0.0', 8000), Handler).serve_forever()
