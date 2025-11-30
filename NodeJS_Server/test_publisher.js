const mqtt = require('mqtt');

const client = mqtt.connect('mqtt://localhost:1883');

client.on('connect', () => {
  console.log('Test Publisher Connected');
  
  setInterval(() => {
    const data = {
      pir: Math.random() > 0.5,
      led1: false,
      led2: true,
      temperature: 25 + Math.random(),
      humidity: 60 + Math.random(),
      fan: false,
      fanAuto: true,
      door: false,
      autoOpen: false,
      rfid: false,
      distance: 100
    };
    
    console.log('Publishing test data...');
    client.publish('iot/sensors/data', JSON.stringify(data));
  }, 3000);
});
