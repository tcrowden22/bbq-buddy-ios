import Foundation
import CoreBluetooth
import Combine

class ThermometerManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var latestTemperature: Double? = nil
    @Published var isConnected: Bool = false
    @Published var discoveredDevices: [CBPeripheral] = []

    var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var temperatureCharacteristic: CBCharacteristic?

    // Replace with your probe's advertised name or UUID
    private let targetDeviceName = "BBQ Probe"
    // Replace with your probe's GATT characteristic UUID for temperature
    // Using a valid placeholder UUID format - replace with actual device UUID
    private let temperatureCharacteristicUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.contains(targetDeviceName) {
            centralManager.stopScan()
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([temperatureCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == temperatureCharacteristicUUID {
                temperatureCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == temperatureCharacteristicUUID, let value = characteristic.value {
            // Parse temperature from value (depends on device spec, here assuming a float in Celsius)
            let temp = value.withUnsafeBytes { $0.load(as: Float.self) }
            latestTemperature = Double(temp)
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            isConnected = false
        }
    }
} 