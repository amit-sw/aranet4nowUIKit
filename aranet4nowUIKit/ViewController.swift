//
//  ViewController.swift
//  aranet4nowUIKit
//
//  Created by Amit Gupta on 11/26/20.
//

import UIKit
import CoreLocation
import CoreBluetooth
import Firebase
import FirebaseUI
import GoogleSignIn



class ViewController: UIViewController {
    
    var locationManager:CLLocationManager!
    var currentLocation:CLLocation?
    
    var centralManager: CBCentralManager!
    var co2Peripheral: CBPeripheral!
    var sleepTime : UInt32 = 60
    
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var mainText: UITextView!
    @IBOutlet weak var lowerLabel: UILabel!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: nil)
        @unknown default:
            print("central.state is unknown: ",central.self)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        //print("Peripheral:",peripheral)
        if((peripheral.name?.starts(with: "Aranet")) == true) {
            print("Found Aranet device")
            co2Peripheral = peripheral
            co2Peripheral.delegate = self
            centralManager.stopScan()
            centralManager.connect(co2Peripheral)
        }
        //print("Finished processing device")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        co2Peripheral.discoverServices([])
        //print("Finished discovery")
    }
    
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            // print("Service: ",service)
            if(service.uuid.uuidString.starts(with: "F0CD1400")) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            //print("Characteristic: ",characteristic)
            
            if characteristic.properties.contains(.read) {
                //print("Char read \(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                //print("Char notify \(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            //print("Unhandled Characteristic UUID: \(characteristic.uuid)")
            guard let characteristicData = characteristic.value else {print("Null characteristic data"); return}
            let byteArray = [UInt8](characteristicData)
            //print(byteArray)
            if(characteristic.uuid.uuidString.starts(with: "F0CD3001")) {
                handleF0CD3001(byteArray: byteArray)
                //peripheral.setNotifyValue(true, for: characteristic)
                let s2 = String(format:"Update in %d secs",sleepTime)
                lowerLabel.text = s2
                DispatchQueue.main.async {
                    self.lowerLabel.text = s2
                }
                print(s2)
                DispatchQueue.main.asyncAfter(deadline: .now()+Double(sleepTime)) {
                    print("On the road again...")
                    self.centralManager.connect(self.co2Peripheral)
                    self.lowerLabel.text = "Fetching..."
                }

            }
            if(characteristic.uuid.uuidString.starts(with: "F0CD1503")) {
                handleF0CD1503(byteArray: byteArray)
                //peripheral.setNotifyValue(true, for: characteristic)
            }
            //print("Finished printing")
        //Unhandled Characteristic UUID: F0CD3001-95DA-4F4B-9AC8-AA55D312AF0C
        // [141, 1, 195, 1, 97, 39, 34, 90, 1, 44, 1, 171, 0]
    }
    
    func baToInt(_ b1:UInt8,_ b2:UInt8) ->Int {
        let i1=Int(b1)
        let i2=Int(b2)
        let i = i1+256*i2
        return i
    }
    
    func getCurrentDateTime() -> String {
        let currentDateTime=Date()
        let formatter=DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        let dateTimeStr=formatter.string(from: currentDateTime)
        return dateTimeStr
    }
    
    func handleF0CD3001(byteArray: [UInt8]) {
        //print("F0CD3001 shows byte array:",byteArray)
        let c = baToInt(byteArray[0],byteArray[1])
        let t1 = baToInt(byteArray[2],byteArray[3])
        let t2 = Float(t1)/20
        let t = (t2*9/5) + 32
        let p = (baToInt(byteArray[4],byteArray[5]) )/10
        let h = baToInt(byteArray[6],0)
        let b = baToInt(byteArray[7],0)
        let i = baToInt(byteArray[9],byteArray[10])
        let a = baToInt(byteArray[11],byteArray[12])
        sleepTime=UInt32(i-a)
        let cdt = getCurrentDateTime()
        print(getCurrentDateTime(),": 3001 Seeing values: ",c,t,p,h,b,i,a, "with t1 & t2 as",t1,t2)
        let s = String(format:"As of \(cdt)\nCO2 %d ppm\n Temp %.1f F\nPressure %d mbar\nHumidity %d%%\nBattery %d%%",c,t,p,h,b)
        mainText.text = s
        //mainText.backgroundColor = .gray
        DispatchQueue.main.async {
            self.mainText.text = s
        }
        let db=Firestore.firestore()
        var dataSet:[String:Any]=[:]
        dataSet["currentDate"] = Date()
        dataSet["recordType"] = "Sensor"
        dataSet["recordSource"] = "Aranet4"
        dataSet["timestamp"] = cdt
        dataSet["CO2"] = c
        dataSet["TempF"] = t
        dataSet["Pressure"] = p
        dataSet["RelativeHumidity"] = h
        dataSet["Battery"] = b
        dataSet["Latitude"] = currentLocation?.coordinate.latitude ?? 0
        dataSet["Longitude"] = currentLocation?.coordinate.longitude ?? 0
        db.collection("CO2TestV01").addDocument(data:dataSet)
        //db.collection("CO2TestV01").addDocument(data: ["currentDate":Date(), "recordType":"Feedback", "timestamp":cdt, "CO2":c, "TempF":t, "Pressure":p, "RelativeHumidity":h,  "Battery":b])


    }
    
    func handleF0CD1503(byteArray: [UInt8]) {
        //print("F0CD1503 shows byte array:",byteArray)
        let c = baToInt(byteArray[0],byteArray[1])
        let t1 = baToInt(byteArray[2],byteArray[3])
        let t2 = Float(t1)/20
        let t = (t2*9/5) + 32
        let p = (baToInt(byteArray[4],byteArray[5]) )/10
        let h = baToInt(byteArray[6],0)
        let b = baToInt(byteArray[7],0)
        //let i = baToInt(byteArray[9],byteArray[10])
        //let a = baToInt(byteArray[11],byteArray[12])
        print(getCurrentDateTime(),": 1503 Seeing values: ",c,t,p,h,b, "with t1 & t2 as",t1,t2)
    }
    
    func updateValues() {
        print("Updating values")
    }
    
    func updateStatus(s:String) {
        print("Setting status s =",s)
    }
    
}

extension ViewController: CLLocationManagerDelegate {
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        determineMyCurrentLocation()
    }
    
    
    func determineMyCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            //locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
        
       // manager.stopUpdatingLocation()
        
        print("user latitude = \(userLocation.coordinate.latitude)")
        print("user longitude = \(userLocation.coordinate.longitude)")
        currentLocation=CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
}

