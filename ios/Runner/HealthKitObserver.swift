import Foundation
import HealthKit
import Flutter

class HealthKitObserver: NSObject {
    private let healthStore = HKHealthStore()
    private var heartRateObserverQuery: HKObserverQuery?
    private var heartRateAnchoredQuery: HKAnchoredObjectQuery?
    private var channel: FlutterMethodChannel?
    
    // Anchor persistence key
    private let heartRateAnchorKey = "HeartRateQueryAnchor"
    
    init(channel: FlutterMethodChannel) {
        super.init()
        self.channel = channel
    }
    
    // MARK: - Anchor Persistence
    private func saveHeartRateAnchor(_ anchor: HKQueryAnchor) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: heartRateAnchorKey)
            print("💾 Saved heart rate query anchor")
        } catch {
            print("❌ Failed to save heart rate anchor: \(error)")
        }
    }
    
    private func loadHeartRateAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: heartRateAnchorKey) else {
            print("📝 No saved heart rate anchor found, starting fresh")
            return nil
        }
        
        do {
            let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
            print("📖 Loaded heart rate query anchor")
            return anchor
        } catch {
            print("❌ Failed to load heart rate anchor: \(error)")
            return nil
        }
    }
    
    // MARK: - HealthKit Setup
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let typesToRead: Set<HKObjectType> = [heartRateType]
    
    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
      DispatchQueue.main.async {
        if let error = error {
          print("HealthKit authorization error: \(error)")
          self?.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
        } else if success {
          print("HealthKit authorization granted")
          self?.channel?.invokeMethod("onAuthorizationGranted", arguments: nil)
        } else {
          print("HealthKit authorization denied")
          self?.channel?.invokeMethod("onAuthorizationDenied", arguments: nil)
        }
      }
    }
    }
    
    // MARK: - Observer Query
    func startHeartRateObserver() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available")
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Enable background delivery for heart rate
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to enable background delivery: \(error)")
                    self?.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                } else {
                    print("✅ Background delivery enabled for heart rate")
                }
            }
        }
        
        // Create observer query
        heartRateObserverQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            print("🔔 HealthKit Observer: New data notification received!")
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Observer query error: \(error)")
                    self?.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                    completionHandler()
                    return
                }
                
                print("📊 HealthKit Observer: Running anchored query for new data...")
                // Use anchored query to fetch only new data
                self?.fetchNewHeartRateDataWithAnchor()
                completionHandler()
            }
        }
        
        // Execute the observer query
        if let query = heartRateObserverQuery {
            healthStore.execute(query)
            print("✅ Heart rate observer started and executing")
            DispatchQueue.main.async {
                self.channel?.invokeMethod("onObserverStarted", arguments: nil)
            }
            
            // Add a fallback timer to check for new data every 30 seconds
            // This helps when the observer doesn't trigger automatically
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                print("🔄 Fallback: Checking for new heart rate data...")
                self.fetchLatestHeartRateData()
            }
        }
    }
    
    func stopHeartRateObserver() {
        if let query = heartRateObserverQuery {
            healthStore.stop(query)
            heartRateObserverQuery = nil
        }
        
        if let anchoredQuery = heartRateAnchoredQuery {
            healthStore.stop(anchoredQuery)
            heartRateAnchoredQuery = nil
        }
        
        print("Heart rate observer and anchored query stopped")
        DispatchQueue.main.async {
            self.channel?.invokeMethod("onObserverStopped", arguments: nil)
        }
    }
    
    // MARK: - Data Fetching
    private func fetchNewHeartRateDataWithAnchor() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Load the saved anchor, or start fresh
        let anchor = loadHeartRateAnchor()
        
        print("🔍 Running anchored query for heart rate data (anchor: \(anchor != nil ? "loaded" : "fresh"))")
        
        // Create anchored object query
        heartRateAnchoredQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching heart rate data with anchor: \(error)")
                    self?.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    print("📝 No new heart rate samples found")
                    return
                }
                
                // Save the new anchor for next time
                if let newAnchor = newAnchor {
                    self?.saveHeartRateAnchor(newAnchor)
                }
                
                // Convert samples to dictionary format for Flutter and sort by date (newest first)
                let heartRateData = samples
                    .sorted { $0.endDate > $1.endDate } // Sort by date, newest first
                    .map { sample in
                        return [
                            "value": sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                            "dateTime": ISO8601DateFormatter().string(from: sample.endDate),
                            "unit": "BPM"
                        ]
                    }
                
                print("💓 HealthKit Observer: Found \(samples.count) NEW heart rate readings (anchored query)")
                for (index, sample) in samples.enumerated() {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    let date = ISO8601DateFormatter().string(from: sample.endDate)
                    print("   Reading \(index + 1): \(Int(value)) BPM at \(date)")
                }
                
                // Send data to Flutter
                print("📱 HealthKit Observer: Sending NEW data to Flutter: \(heartRateData)")
                self?.channel?.invokeMethod("onHeartRateData", arguments: heartRateData)
                print("📱 HealthKit Observer: NEW data sent to Flutter successfully")
            }
        }
        
        if let query = heartRateAnchoredQuery {
            healthStore.execute(query)
        }
    }
    
    // Fallback method for manual refresh (still uses time-based query)
    private func fetchLatestHeartRateData() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Get data from the last 10 minutes to catch recent readings
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-600) // 10 minutes ago
        
        print("🔍 Fetching heart rate data from \(startDate) to \(endDate) (fallback method)")
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 10, // Get last 10 readings
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching heart rate data: \(error)")
                    self?.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    print("No heart rate samples found")
                    return
                }
                
                // Convert samples to dictionary format for Flutter and sort by date (newest first)
                let heartRateData = samples
                    .sorted { $0.endDate > $1.endDate } // Sort by date, newest first
                    .map { sample in
                        return [
                            "value": sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                            "dateTime": ISO8601DateFormatter().string(from: sample.endDate),
                            "unit": "BPM"
                        ]
                    }
                
                print("💓 HealthKit Observer: Found \(samples.count) heart rate readings (fallback)")
                for (index, sample) in samples.enumerated() {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    let date = ISO8601DateFormatter().string(from: sample.endDate)
                    print("   Reading \(index + 1): \(Int(value)) BPM at \(date)")
                }
                
                // Send data to Flutter
                print("📱 HealthKit Observer: Sending data to Flutter: \(heartRateData)")
                self?.channel?.invokeMethod("onHeartRateData", arguments: heartRateData)
                print("📱 HealthKit Observer: Data sent to Flutter successfully")
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Manual Data Fetching
    func fetchHeartRateDataNow() {
        print("🔄 Manual fetch triggered")
        fetchLatestHeartRateData()
    }
    
    
    // MARK: - Cleanup
    deinit {
        stopHeartRateObserver()
    }
}
