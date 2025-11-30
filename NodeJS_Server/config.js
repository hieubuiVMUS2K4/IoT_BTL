// Load environment variables from .env file
require('dotenv').config();

// Environment variables configuration
module.exports = {
  // Server ports
  PORT: process.env.PORT || 3000,
  WS_PORT: process.env.WS_PORT || 3001,
  
  // MQTT Broker configuration
  MQTT_BROKER: process.env.MQTT_BROKER || 'mqtt://10.137.147.176:1883',
  MQTT_PORT: process.env.MQTT_PORT || 1883,
  MQTT_USERNAME: process.env.MQTT_USERNAME || '',
  MQTT_PASSWORD: process.env.MQTT_PASSWORD || '',
  
  // Build full MQTT URL
  getMqttUrl() {
    const protocol = this.MQTT_PORT == 8883 ? 'mqtts://' : 'mqtt://';
    const host = this.MQTT_BROKER.replace(/^mqtt(s)?:\/\//, '');
    
    if (this.MQTT_USERNAME && this.MQTT_PASSWORD) {
      return `${protocol}${this.MQTT_USERNAME}:${this.MQTT_PASSWORD}@${host}:${this.MQTT_PORT}`;
    }
    return `${protocol}${host}:${this.MQTT_PORT}`;
  }
};
