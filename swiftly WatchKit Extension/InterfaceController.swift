//
//  InterfaceController.swift
//  swiftly WatchKit Extension
//
//  Created by Nand Kishore on 10/9/15.
//  Copyright © 2015 Nand Kishore. All rights reserved.
//

import WatchKit
import SwiftyJSON
import HealthKit
import Foundation
let healthStore = HKHealthStore()

class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {

    @IBOutlet var picker: WKInterfacePicker!
    
    var itemList: [String] = ["Avishek Dutta", "Nand Kishore", "Sarthak Sahu", "Sid Murching"]
    
    @IBOutlet var heartLabel: WKInterfaceLabel!
    @IBOutlet var collectButton: WKInterfaceButton!

    var collecting = false;
    var authorized = false;
    var username = "";
    let healthStore = HKHealthStore()
    var workoutSession:HKWorkoutSession!
    var runId = -1
    var userId = -1

    // DataQueries for the measurements we're taking
    var dataQueries:[DataQuery]!

    var heartDataQuery = DataQuery(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!, anchor: HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor)), updateFn: nil, samples: [], unit:HKUnit(fromString: "count/min"))

    /*var stepDataQuery = DataQuery(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!, anchor: HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor)), updateFn: nil, samples: [], unit:HKUnit.countUnit())*/

    var distanceDataQuery = DataQuery(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!, anchor: HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor)), updateFn: nil, samples: [], unit:HKUnit.meterUnit())

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        self.userId = context as! Int
        if self.userId < 0 {
            print("ERROR: userId not received")
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        // Healthstore Authorization
        if(authorized){
            return
        }
        guard HKHealthStore.isHealthDataAvailable() == true else {
            return
        }
        dataQueries = [heartDataQuery, distanceDataQuery]
        var quantityTypes:[HKQuantityType] = []
        for dataQuery in dataQueries{
            quantityTypes.append(dataQuery.type)
        }
        let typesToShare = Set([HKWorkoutType.workoutType()])
        let dataTypes = Set(quantityTypes)
        healthStore.requestAuthorizationToShareTypes(typesToShare,
            readTypes: dataTypes,
            completion: {(succeeded: Bool, error: NSError?) in
                if succeeded && error == nil{
                    print("Successfully received authorization")
                } else {
                    print("Error in authorization \(error)")
                    return
                }
        })
        authorized = true;

        // Initialize DataQueries
        initQueries()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func initQueries(){
        let updateHeartFn: (HKAnchoredObjectQuery,[HKSample]?,[HKDeletedObject]?,HKQueryAnchor?, NSError?) -> Void = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            if let e = error{
                print("error in heart rate \(e)")
                return
            }
            self.updateHeartRate(samples)
            self.heartDataQuery.anchor = newAnchor!
            self.heartDataQuery.samples.appendContentsOf(samples!)
            let code = self.send(self.heartDataQuery)
            if code==0 {
                self.heartDataQuery.clearSamples()
            }
        }
        self.heartDataQuery.updateFn = updateHeartFn
        let updateFn: (HKAnchoredObjectQuery,[HKSample]?,[HKDeletedObject]?,HKQueryAnchor?, NSError?) -> Void = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            if let e = error{
                print("error in heart rate \(e)")
                return
            }
            for dataQuery in self.dataQueries{
                if dataQuery.type == query.sampleType{
                    dataQuery.anchor = newAnchor!
                    dataQuery.samples.appendContentsOf(samples!)
                    let code = self.send(dataQuery)
                    if code==0 {
                        dataQuery.clearSamples()
                    }
                }
            }
        }
        //self.stepDataQuery.updateFn = updateFn
        self.distanceDataQuery.updateFn = updateFn
        self.resetQueries()
    }

    func resetQueries(){
        for dataQuery in dataQueries{
            dataQuery.resetQuery()
        }
    }

    // Send Request to Server for a new Run id
    func getRunId(){
        let id = "{userId: " + String(userId) + "}"
        let session = NSURLSession.sharedSession()
        let url = NSURL(string: "http://ec2-54-193-10-55.us-west-1.compute.amazonaws.com/swiftly/runs")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.HTTPBody = id.dataUsingEncoding(NSUTF8StringEncoding)

        let task = session.dataTaskWithRequest(request){
            (data, response, error) in
            if((error) != nil){
                print("Error in networking \(error)")
            }
            else{
                let json = JSON(data: data!)
                self.runId = json["id"].int!
                print("Recieved New RunId!")
            }
        }
        task.resume()
    }

    @IBAction func buttonPressed() {
        getRunId();
        collecting = !collecting;
        if(collecting){
            initWorkoutSession()
            healthStore.startWorkoutSession(workoutSession)
            collectButton.setTitle("Stop Collecting")
        }
        else{
            healthStore.endWorkoutSession(workoutSession)
            collectButton.setTitle("Start Collecting")
        }
    }

    func initWorkoutSession(){
        self.workoutSession = HKWorkoutSession(activityType: HKWorkoutActivityType.Running, locationType: HKWorkoutSessionLocationType.Outdoor)
        workoutSession.delegate = self
    }

    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        dispatch_async(dispatch_get_main_queue()) {
            if(self.collecting){
                self.startCollecting(date);
            }
            else{
                print(self.collecting)
                self.stopCollecting(date);
            }
        }
    }

    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        print("workOutSession Error : \(error.localizedDescription)")
    }

    func startCollecting(date : NSDate) {
        for dataQuery in dataQueries{
            healthStore.executeQuery(dataQuery.query)
        }
    }

    func stopCollecting(date : NSDate) {
        print("Stopping")
        for dataQuery in dataQueries{
            healthStore.stopQuery(dataQuery.query)
            dataQuery.resetQuery()
        }
        self.heartLabel.setText("Heart Rate: ")
    }

    func send(dataQuery:DataQuery) -> Int{
        if(runId == -1){
            print("Error runId not set")
            return -1;
        }
        let json = dataQuery.getJsonString(self.runId);
        print(json)
        let data = json.dataUsingEncoding(NSUTF8StringEncoding)
        let session = NSURLSession.sharedSession()
        let url = NSURL(string: "http://ec2-54-193-10-55.us-west-1.compute.amazonaws.com/swiftly/measurements")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "PUT"
        request.HTTPBody = data
        let task = session.dataTaskWithRequest(request){
            (data, response, error) in
            if((error) != nil){
                print("Error in networking \(error)")
            }
            else{
                print("Sent!")
            }
        }
        task.resume()
        return 0;
    }

    // Update heart rate on display
    func updateHeartRate(samples: [HKSample]?) {
        if(!collecting){
            return;
        }
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        guard let sample = heartRateSamples.first else{return}
        let value = sample.quantity.doubleValueForUnit(HKUnit(fromString: "count/min"))
        self.heartLabel.setText("Heart Rate: " + String(UInt16(value)))
    }
}
