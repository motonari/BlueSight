import CoreBluetooth

protocol MeasurementsObserver {
    func reportGyroscopeMeasurements(x: CGFloat, y: CGFloat, z: CGFloat)
}

class BlueSightCentral: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var receivedIntegers: [UInt32] = []
    var statusMessage = "Initializing Bluetooth..."

    let measurementsObserver: MeasurementsObserver

    private var serviceUUID = CBUUID(string: "6AFE4D1F-072D-4769-BF7B-EAA5C43B21F6")
    private var measurementCharacteristicUUID = CBUUID(string: "62C0A592-CA8C-47B0-AB49-081BCB0411AF")
    private var ackCharacteristicUUID = CBUUID(string: "0126E2AB-136A-4D5F-B964-8839FF2F0CDC")

    var ackCharacteristic: CBCharacteristic?
    
    init(observer: MeasurementsObserver) {
        measurementsObserver = observer

        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Scanning for BlueSightIMU..."
            central.scanForPeripherals(withServices: [serviceUUID], options: nil)
        case .poweredOff:
            statusMessage = "Bluetooth is off."
        default:
            statusMessage = "Bluetooth state: \(central.state.rawValue)"
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        if peripheral.name == "Arduino" {
            statusMessage = "Found BlueSightIMU. Connecting..."
            central.stopScan()
            connectedPeripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusMessage = "Connected. Discovering services..."
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        statusMessage = "Connected. Discovering characteristics..."
        for service in services {
            peripheral.discoverCharacteristics(
                [measurementCharacteristicUUID, ackCharacteristicUUID],
                for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == measurementCharacteristicUUID && characteristic.properties.contains(.notify)
            {
                statusMessage = "Subscribing to BlueSightIMU..."
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            if characteristic.uuid == ackCharacteristicUUID {
                ackCharacteristic = characteristic
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }

        let (
            x, y, z, time
        ) = data.withUnsafeBytes { bytes in
            let x = bytes.load(fromByteOffset: 0, as: Float32.self)
            let y = bytes.load(fromByteOffset: 4, as: Float32.self)
            let z = bytes.load(fromByteOffset: 8, as: Float32.self)
            let time = bytes.load(fromByteOffset: 12, as: UInt8.self)
            return (x, y, z, time)
        }

        measurementsObserver.reportGyroscopeMeasurements(
            x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
        
        if let ackCharacteristic {
            let data = Data(bytes: [time])
//            peripheral.writeValue(data, for: ackCharacteristic, type: .withoutResponse);
        }
    }
}
