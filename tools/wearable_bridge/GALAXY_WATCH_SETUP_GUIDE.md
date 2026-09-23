# Galaxy Watch & Wearables Integration Guide

This guide explains how to connect your **Samsung Galaxy Watch (Wear OS)** to Sovereign Soul Engine so your real heart rate (BPM), stress, and somatic telemetry stream to your companions in real time.

---

## Architecture Overview

```
[ Galaxy Watch (Wear OS) ]
      |
      | (Wi-Fi / Local Network HTTP POST)
      v
[ Sovereign Soul Engine ] -> TelemetryController
      |
      v
[ PostgreSQL Somatic State & Theory of Mind ]
      |
      v
[ Companions actively perceive your physical condition ]
```

---

## Step 1: Find Your PC's Local IP Address

1. Open PowerShell on your PC and run:
   ```powershell
   ipconfig
   ```
2. Look for **IPv4 Address** (e.g. `192.168.1.150`).
3. Your Sovereign Soul Engine telemetry endpoint is:
   ```
   http://192.168.1.150:4050/sse/api/telemetry/somatic
   ```

---

## Step 2: Set Up Galaxy Watch (Option A: "HTTP Shortcuts" - Recommended)

The easiest, zero-code way to beam sensor data from Wear OS:

1. On your phone and Galaxy Watch, install **HTTP Shortcuts** (Free on Google Play Store):
   - [HTTP Shortcuts on Google Play](https://play.google.com/store/apps/details?id=ch.rmy.android.http_shortcuts)
2. Open the app on your phone:
   - Create a new shortcut: **"Sync Soul Biometrics"**
   - Method: **POST**
   - URL: `http://<YOUR-PC-IP>:4050/sse/api/telemetry/somatic`
   - Request Body -> JSON:
     ```json
     {
       "heart_rate": 78,
       "stress_level": 25,
       "fatigue_level": 15,
       "motion_state": "resting",
       "ambient_noise_db": 42.0
     }
     ```
3. Enable on Galaxy Watch:
   - The shortcut automatically appears as a tile or button on your Galaxy Watch!
   - Tap it anytime on your wrist to pulse your biometrics to your companions.

---

## Step 3: Set Up Automated Background Sync (Option B: Tasker + AutoWear)

For hands-free continuous streaming every 60 seconds:

1. Install **Tasker** and the **AutoWear** plugin on your phone & watch.
2. In Tasker:
   - Profile: Every 1 minute (or when Heart Rate sensor changes).
   - Action: Read `%heart_rate%` from AutoWear sensor.
   - HTTP Request: POST to `http://<YOUR-PC-IP>:4050/sse/api/telemetry/somatic` with JSON:
     ```json
     {
       "heart_rate": %heart_rate%,
       "motion_state": "%motion_state%"
     }
     ```

---

## Step 4: Instant Testing with Python Bridge / Simulator

If your watch is on the charger or you want to test right now:

1. Run the interactive CLI simulator:
   ```powershell
   python tools/wearable_bridge/galaxy_watch_bridge.py --simulate
   ```
2. Choose from pre-made somatic profiles:
   - `1` = Calm / Resting (BPM: 68, Stress: 15)
   - `2` = High Stress Spike (BPM: 135, Stress: 88)
   - `3` = Intimate / Aroused (BPM: 105, Stress: 45)
   - `4` = Exhausted (BPM: 62, Fatigue: 90)
3. Open `http://localhost:4050/sse/chat` and ask any companion:
   > *"How do I seem right now?"* or *"Report status."*
4. Watch them immediately adjust their tone and protective behavior to match your simulated biometrics!
