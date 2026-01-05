import CoreBluetooth

protocol MeasurementsObserver {
    func gyroscope(x: CGFloat, y: CGFloat, z: CGFloat)
}

class BlueSightCentral: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var receivedIntegers: [UInt32] = []
    var statusMessage = "Initializing Bluetooth..."

    var measurementsObserver: MeasurementsObserver?

    private var targetServiceUUID = CBUUID(string: "6AFE4D1F-072D-4769-BF7B-EAA5C43B21F6")
    private var targetCharUUID = CBUUID(string: "62C0A592-CA8C-47B0-AB49-081BCB0411AF")
    private var writeCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Scanning for BlueSightIMU..."
            central.scanForPeripherals(withServices: [targetServiceUUID], options: nil)
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
        peripheral.discoverServices([targetServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        statusMessage = "Connected. Discovering characteristics..."
        for service in services {
            peripheral.discoverCharacteristics([targetCharUUID], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == targetCharUUID && characteristic.properties.contains(.notify)
            {
                statusMessage = "Subscribing to BlueSightIMU..."
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }
        guard let observer = self.measurementsObserver else { return }

        let (
            x, y, z
        ) = data.withUnsafeBytes { bytes in
            let x = bytes.load(fromByteOffset: 0, as: Float32.self)
            let y = bytes.load(fromByteOffset: 4, as: Float32.self)
            let z = bytes.load(fromByteOffset: 8, as: Float32.self)
            return (x, y, z)
        }

        observer.gyroscope(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
    }
}
