# Deploy to Render.com - Quick Start

## Prerequisites
- GitHub account
- Render.com account (free)
- HiveMQ Cloud account (free)

## Step 1: Push to GitHub
```bash
cd c:\Users\hieuu\Downloads\IoT_BTL\IoT_BTL
git add .
git commit -m "Prepare for cloud deployment"
git push origin master
```

## Step 2: Setup HiveMQ Cloud
1. Go to https://console.hivemq.cloud/
2. Create new cluster
3. Save credentials:
   - Host: `xxxxxx.s1.eu.hivemq.cloud`
   - Port: `8883`
   - Username: `your-username`
   - Password: `your-password`

## Step 3: Deploy to Render
1. Go to https://dashboard.render.com
2. Click "New +" → "Web Service"
3. Connect your GitHub repo
4. Fill in:
   - **Name**: `iot-mqtt-bridge`
   - **Root Directory**: `NodeJS_Server`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node server_mqtt.js`
   - **Instance Type**: Free

5. Add Environment Variables:
   ```
   MQTT_BROKER=your-hivemq-host.hivemq.cloud
   MQTT_PORT=8883
   MQTT_USERNAME=your-username
   MQTT_PASSWORD=your-password
   PORT=10000
   ```

6. Click "Create Web Service"

## Step 4: Get Your URLs
After deployment completes:
- API URL: `https://iot-mqtt-bridge.onrender.com`
- WebSocket: `wss://iot-mqtt-bridge.onrender.com`

## Step 5: Update Flutter App
Edit `lib/services/iot_service.dart`:
```dart
IoTService({
  this.baseUrl = 'https://iot-mqtt-bridge.onrender.com',
  this.wsUrl = 'wss://iot-mqtt-bridge.onrender.com',
});
```

## Step 6: Update ESP8266
Edit `ESP8266_Master.ino`:
```cpp
const char* mqtt_server = "your-cluster.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "your-username";
const char* mqtt_pass = "your-password";
```

## Test
1. Upload ESP8266 firmware
2. Run Flutter app on 4G/5G (not WiFi)
3. Try controlling devices

Done! 🎉
