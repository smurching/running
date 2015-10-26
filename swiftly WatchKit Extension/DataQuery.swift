//
//  DataQuery.swift
//  swiftly
//
//  Created by Nand Kishore on 10/22/15.
//  Copyright © 2015 Nand Kishore. All rights reserved.
//

import WatchKit
import HealthKit
import Foundation

class DataQuery{
    var type:HKQuantityType
    var anchor:HKQueryAnchor
    var query:HKAnchoredObjectQuery!
    var samples:[HKSample]
    var updateFn:((HKAnchoredObjectQuery,[HKSample]?,[HKDeletedObject]?,HKQueryAnchor?, NSError?) -> Void)!
    var unit:HKUnit
    
    init(type:HKQuantityType, anchor:HKQueryAnchor, updateFn:((HKAnchoredObjectQuery,[HKSample]?,[HKDeletedObject]?,HKQueryAnchor?, NSError?) -> Void)?, samples:[HKSample], unit:HKUnit){
        self.type = type
        self.anchor = anchor
        self.samples = samples
        self.unit = unit
        if let updateHandler = updateFn {
            self.updateFn = updateHandler
        }
        else{
            self.updateFn = {(qy, samples, deleteObjects, newAnchor, error) -> Void in
                self.updateSamples(anchor, samples: samples!)
            }
        }
        self.query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor, limit: Int(HKObjectQueryNoLimit), resultsHandler: self.updateFn)
    }
    
    func resetQuery(){
        self.query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor, limit: Int(HKObjectQueryNoLimit), resultsHandler: updateFn)
        self.query.updateHandler = updateFn
    }
    
    func updateSamples(anchor:HKQueryAnchor, samples:[HKSample]){
        self.anchor = anchor
        self.samples.appendContentsOf(samples)
    }
    
    func getJsonString(runId:Int) -> NSString{
        var st = "["
        let samples = self.samples as! [HKQuantitySample]
        for sample in samples{
            st += "{" +
                    "\"type\":\"" + String(type) + "\"\n" +
                    "\"value\":" + String(sample.quantity.doubleValueForUnit(unit)) + "\n" +
                    "\"start\":\"" + String(sample.startDate) + "\"\n" +
                    "\"end\":\"" + String(sample.endDate) + "\"\n" +
                    "\"runId\":" + String(runId) + "},\n"
        }
        st += "]"
        return st
    }
    
    func clearSamples(){
        self.samples = []
    }
}