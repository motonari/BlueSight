import CoreBluetooth

protocol MeasurementsObserver {
    func reportAiming(yaw: CGFloat, pitch: CGFloat)
}

class BlueSightCentral: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var receivedIntegers: [UInt32] = []
    var statusMessage = "Initializing Bluetooth..."

    let measurementsObserver: MeasurementsObserver

    private var serviceUUID = CBUUID(string: "6AFE4D1F-072D-4769-BF7B-EAA5C43B21F6")
    private var aimingCharacteristicUUID = CBUUID(string: "62C0A592-CA8C-47B0-AB49-081BCB0411AF")

    init(observer: MeasurementsObserver) {
        measurementsObserver = observer

        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("Initialized.")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning(central)
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
        statusMessage = "Found BlueSight. Connecting..."
        central.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusMessage = "Connected. Discovering services..."
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        statusMessage = "Disconnected. Scanning for BlueSightIMU..."
        connectedPeripheral?.delegate = nil
        connectedPeripheral = nil
        startScanning(central)
    }

    func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        connectedPeripheral = nil
        startScanning(central)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        statusMessage = "Connected. Discovering characteristics..."
        for service in services {
            peripheral.discoverCharacteristics(
                [aimingCharacteristicUUID],
                for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == aimingCharacteristicUUID && characteristic.properties.contains(.notify)
            {
                statusMessage = "Subscribing to BlueSight..."
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }

        let (
            yaw, pitch
        ) = data.withUnsafeBytes { bytes in
            let yaw = bytes.load(fromByteOffset: 0, as: Float32.self)
            let pitch = bytes.load(fromByteOffset: 4, as: Float32.self)
            return (yaw, pitch)
        }

        measurementsObserver.reportAiming(
            yaw: CGFloat(yaw), pitch: CGFloat(pitch))
    }

    private func startScanning(_ central: CBCentralManager) {
        guard central.state == .poweredOn, !central.isScanning else { return }
        statusMessage = "Scanning for BlueSightIMU..."
        central.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
}
