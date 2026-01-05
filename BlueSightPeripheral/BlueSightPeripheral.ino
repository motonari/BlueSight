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
					  3 * sizeof(float) /* valueSize */ ,
					  true /* fixedLength */);

const unsigned long samplingInterval = 10;
unsigned long previousMillis = 0;  // last time inertial measurement was checked, in milliseconds.


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
  BLE.addService(blueSightService); // Add the battery service

  float data[3] = {};
  gyroscopeCharacteristic.writeValue(data, sizeof(data));

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
    }
    // when the central disconnects, turn off the LED:
    digitalWrite(LED_BUILTIN, LOW);
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}

int measurement = 0;
void sendMeasurements() {

  if (IMU.gyroscopeAvailable()) {
    float x, y, z;
    IMU.readGyroscope(x, y, z);

    float data[] = {x, y, z};
    gyroscopeCharacteristic.writeValue(data, sizeof(data));
  }
}
