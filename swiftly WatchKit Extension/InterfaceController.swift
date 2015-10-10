//
//  InterfaceController.swift
//  swiftly WatchKit Extension
//
//  Created by Nand Kishore on 10/9/15.
//  Copyright © 2015 Nand Kishore. All rights reserved.
//

import WatchKit
import HealthKit
import Foundation
let healthStore = HKHealthStore()


class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {

    @IBOutlet var heartLabel: WKInterfaceLabel!
    @IBOutlet var collectButton: WKInterfaceButton!
    var collecting = false;
    let healthStore = HKHealthStore()
    var workoutSession:HKWorkoutSession! = nil
    let heartRateUnit = HKUnit(fromString: "count/min")
    var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        initWorkoutSession()
        guard HKHealthStore.isHealthDataAvailable() == true else {
            print("NOOOOO");
            return
        }
        let quantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
        let typesToShare = Set([HKWorkoutType.workoutType()])
        let dataTypes = Set(arrayLiteral:quantityType)
        healthStore.requestAuthorizationToShareTypes(typesToShare,
            readTypes: dataTypes,
            completion: {(succeeded: Bool, error: NSError?) in
                if succeeded && error == nil{
                    print("Successfully received authorization")
                } else {
                        print("Error in authorization \(error)")
                }
        })
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func buttonPressed() {
        collecting = !collecting;
        if(collecting){
            healthStore.startWorkoutSession(workoutSession)
            collectButton.setTitle("Stop Collecting")
        }
        else{
            healthStore.endWorkoutSession(workoutSession)
            collectButton.setTitle("Start Collecting")
        }
        print("Hello " + String(collecting))
    }

    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        dispatch_async(dispatch_get_main_queue()) {
            if(self.collecting){
                print(self.collecting);
                self.startCollecting(date);
            }
            else{
                self.stopCollecting(date);
            }
        }
    }
    
    func startCollecting(date : NSDate) {
        let query = createQuery(date)
        healthStore.executeQuery(query!)
    }
    
    func stopCollecting(date : NSDate) {
        let query = createQuery(date)!
        healthStore.stopQuery(query)
        initWorkoutSession()
        self.heartLabel.setText("Heart Rate: ")
    }
    
    func createQuery(workoutStartDate: NSDate) -> HKQuery? {
        let quantityType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!

        let fn: (HKAnchoredObjectQuery,[HKSample]?,[HKDeletedObject]?,HKQueryAnchor?, NSError?) -> Void = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor!
            self.updateHeartRate(samples)
        }

        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: nil, anchor: anchor, limit: Int(HKObjectQueryNoLimit), resultsHandler: fn)
    
        heartRateQuery.updateHandler = fn
        return heartRateQuery
    }

    func updateHeartRate(samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        guard let sample = heartRateSamples.first else{return}
        let value = sample.quantity.doubleValueForUnit(self.heartRateUnit)
        self.heartLabel.setText("Heart Rate: " + String(UInt16(value)))
    }
    
    func initWorkoutSession(){
        self.workoutSession = HKWorkoutSession(activityType: HKWorkoutActivityType.Running, locationType: HKWorkoutSessionLocationType.Outdoor)
        workoutSession.delegate = self
    }

    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        print("workOutSession Error : \(error.localizedDescription)")
    }
}
