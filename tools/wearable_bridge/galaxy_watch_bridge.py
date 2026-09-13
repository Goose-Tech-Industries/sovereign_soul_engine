"""
Sovereign Soul Engine - Galaxy Watch & Smart Wearables Telemetry Bridge
Acts as a local network hub to receive biometrics from Galaxy Watch (Wear OS)
and forward them into the Phoenix Sovereign Soul Engine API.

Features:
- Webhook receiver for Tasker / AutoWear / Wear OS HTTP Shortcuts
- Direct forwarder to http://127.0.0.1:4050/sse/api/telemetry/somatic
- Interactive CLI Simulator for instant testing without putting on the watch
"""

import argparse
import http.server
import json
import socket
import socketserver
import time
import urllib.request

SSE_ENDPOINT = "http://127.0.0.1:4050/sse/api/telemetry/somatic"

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't need to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def send_telemetry_to_sse(data):
    """Forwards parsed somatic telemetry payload to Phoenix Sovereign Soul Engine"""
    payload = {
        "heart_rate": int(data.get("heart_rate", data.get("bpm", 72))),
        "stress_level": int(data.get("stress_level", data.get("stress", 20))),
        "fatigue_level": int(data.get("fatigue_level", data.get("fatigue", 15))),
        "motion_state": str(data.get("motion_state", data.get("motion", "resting"))),
        "ambient_noise_db": float(data.get("ambient_noise_db", data.get("noise_db", 42.0))),
        "steps_count": int(data.get("steps_count", data.get("steps", 0))),
        "sleep_hours": float(data.get("sleep_hours", 7.5))
    }
    
    req = urllib.request.Request(
        SSE_ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            print(f"[+] Synced to SSE: BPM={payload['heart_rate']} | Stress={payload['stress_level']}/100 | Motion={payload['motion_state']}")
            return result
    except Exception as e:
        print(f"[-] Error syncing to SSE ({SSE_ENDPOINT}): {e}")
        return None

class WatchWebhookHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        try:
            data = json.loads(body.decode('utf-8'))
            print(f"\n[Watch Ingestion] Received from Galaxy Watch ({self.client_address[0]}):")
            print(json.dumps(data, indent=2))
            
            res = send_telemetry_to_sse(data)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "received", "sse_sync": res is not None}).encode('utf-8'))
        except Exception as e:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({
            "service": "Galaxy Watch Somatic Hub",
            "status": "online",
            "target": SSE_ENDPOINT
        }).encode('utf-8'))

def run_server(port=8089):
    ip = get_local_ip()
    print("=" * 60)
    print(" GALAXY WATCH SOMATIC TELEMETRY BRIDGE")
    print("=" * 60)
    print(f"[*] Local Bridge IP: http://{ip}:{port}/")
    print(f"[*] On your Galaxy Watch, send HTTP POST to:")
    print(f"    http://{ip}:{port}/")
    print(f"[*] Forwarding to Phoenix Sovereign Soul Engine at:")
    print(f"    {SSE_ENDPOINT}")
    print("=" * 60)
    
    with socketserver.TCPServer(("", port), WatchWebhookHandler) as httpd:
        print(f"[*] Listening for watch telemetry on port {port}... (Ctrl+C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nBridge stopped.")

def run_simulation():
    print("=" * 60)
    print(" INTERACTIVE SOMATIC SIMULATOR")
    print("=" * 60)
    print("1. Resting / Calm (BPM: 68, Stress: 15, Resting)")
    print("2. Tactical Stress Spike (BPM: 135, Stress: 88, Pacing)")
    print("3. Intimate / Aroused (BPM: 105, Stress: 45, Arousal: 80, Still)")
    print("4. Exhausted / Recovery (BPM: 62, Fatigue: 90, Stress: 25)")
    print("5. Custom values")
    print("=" * 60)
    
    while True:
        choice = input("\nSelect profile (1-5, or 'q' to quit): ").strip()
        if choice == 'q':
            break
        elif choice == '1':
            send_telemetry_to_sse({"bpm": 68, "stress": 15, "fatigue": 10, "motion": "resting"})
        elif choice == '2':
            send_telemetry_to_sse({"bpm": 135, "stress": 88, "fatigue": 40, "motion": "pacing", "noise_db": 75.0})
        elif choice == '3':
            send_telemetry_to_sse({"bpm": 105, "stress": 45, "fatigue": 15, "motion": "still"})
        elif choice == '4':
            send_telemetry_to_sse({"bpm": 62, "stress": 25, "fatigue": 90, "motion": "lying down"})
        elif choice == '5':
            bpm = int(input("Heart Rate BPM: ") or 72)
            stress = int(input("Stress Level (0-100): ") or 20)
            fatigue = int(input("Fatigue (0-100): ") or 15)
            motion = input("Motion State (resting/walking/pacing): ") or "resting"
            send_telemetry_to_sse({"bpm": bpm, "stress": stress, "fatigue": fatigue, "motion": motion})

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Galaxy Watch Telemetry Bridge")
    parser.add_argument("--simulate", action="store_true", help="Run interactive simulator")
    parser.add_argument("--port", type=int, default=8089, help="Port to listen for watch webhooks")
    args = parser.parse_args()
    
    if args.simulate:
        run_simulation()
    else:
        run_server(args.port)
