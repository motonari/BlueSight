/*
  Send Gyroscope sensor feed via BLE.
*/

#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>

// BlueSight Service.
BLEService blueSightService("6AFE4D1F-072D-4769-BF7B-EAA5C43B21F6");

// BLE Gyroscope Characteristic.
//
//
BLECharacteristic gyroscopeCharacteristic("62C0A592-CA8C-47B0-AB49-081BCB0411AF",
					  BLERead | BLENotify /* Permissions */ ,
					  3 * sizeof(float) + 1 * sizeof(unsigned char) /* valueSize */ ,
					  true /* fixedLength */);

BLEByteCharacteristic ackCharacteristic("0126E2AB-136A-4D5F-B964-8839FF2F0CDC", BLEWrite);

unsigned long startTime[256];

const unsigned long samplingInterval = 15;
unsigned long previousMillis = 0;  // last time inertial measurement was checked, in milliseconds.

struct Data {
  float x, y, z;
  uint8_t sequenceNumber;
};

uint8_t sequenceNumber = 0;
unsigned long numberOfLatencyReports = 0;
float averageLatency = 0.0;

void setup() {
  Serial.begin(9600);    // initialize serial communication
  while (!Serial);

  pinMode(LED_BUILTIN, OUTPUT); // initialize the built-in LED pin to indicate when a central is connected

  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");

    while (1);
  }

  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }

  BLE.setLocalName("BlueSightIMU");
  BLE.setAdvertisedService(blueSightService);
  blueSightService.addCharacteristic(gyroscopeCharacteristic);
  blueSightService.addCharacteristic(ackCharacteristic);
  BLE.addService(blueSightService); // Add the battery service

  Data data;
  gyroscopeCharacteristic.writeValue(
    reinterpret_cast<uint8_t *>(&data), sizeof(data));

  BLE.advertise();

  Serial.println("Bluetooth® device active, waiting for connections...");
}

void loop() {
  // wait for a Bluetooth® Low Energy central
  BLEDevice central = BLE.central();

  // if a central is connected to the peripheral:
  if (central) {
    Serial.print("Connected to central: ");
    // print the central's BT address:
    Serial.println(central.address());
    // turn on the LED to indicate the connection:
    digitalWrite(LED_BUILTIN, HIGH);

    while (central.connected()) {
      unsigned long currentMillis = millis();
      if (currentMillis - previousMillis >= samplingInterval) {
        previousMillis = currentMillis;
        sendMeasurements();
      }

      if (ackCharacteristic.written()) {
        uint8_t ackSequenceNumber = ackCharacteristic.value();
        if (startTime[ackSequenceNumber] != -1) {
          unsigned long time = millis();
          unsigned long latency = time - startTime[ackSequenceNumber];
          startTime[ackSequenceNumber] = -1;

          numberOfLatencyReports += 1;
          averageLatency += (static_cast<float>(latency) - averageLatency) / numberOfLatencyReports;

          char text[256];
          sprintf(text, "Millis = %ld, Latency = %ld, seqNum = %d", time, latency, (int)ackSequenceNumber);
//          Serial.println(text);
        }
      }
    }

    // when the central disconnects, turn off the LED:
    digitalWrite(LED_BUILTIN, LOW);
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());

    char text[256];
    sprintf(text, "Average Latncy = %f", averageLatency);
    Serial.println(text);
  }
}


void sendMeasurements() {

  if (IMU.gyroscopeAvailable()) {
    Data data;
    IMU.readGyroscope(data.x, data.y, data.z);
    data.sequenceNumber = sequenceNumber;
    unsigned long time = millis();
    startTime[sequenceNumber] = time;
    
    char text[256];
    sprintf(text, "millis() = %ld, Sending seqNum = %d", time, (int)sequenceNumber);
//    Serial.println(text);

    gyroscopeCharacteristic.writeValue(&data, sizeof(data), false);

    sequenceNumber += 1;
  }
}
