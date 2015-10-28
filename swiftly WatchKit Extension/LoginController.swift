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


class LoginController: WKInterfaceController {
    
    @IBOutlet var picker: WKInterfacePicker!
    
    var itemList: [String] = ["Avishek Dutta", "Nand Kishore", "Sarthak Sahu", "Sid Murching"]
    
    var username = "";
    var userId = -1
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }
    
    func setUpPicker() {
        username = itemList[0]
        let pickerItems: [WKPickerItem] = itemList.map {
            let pickerItem = WKPickerItem()
            pickerItem.title = $0
            return pickerItem
        }
        picker.setItems(pickerItems)
    }
    
    func getLoginId(){
        let session = NSURLSession.sharedSession()
        let url = NSURL(string: "http://ec2-54-193-10-55.us-west-1.compute.amazonaws.com/swiftly/users")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        let task = session.dataTaskWithRequest(request){
            (data, response, error) in
            if((error) != nil){
                print("Error in networking \(error)")
            }
            else{
                let json = JSON(data: data!)
                self.userId = json["id"].int!
                print("Recieved New UserId!")
            }
        }
        task.resume()
    }
    
    @IBAction func pickerChanged(value: Int) {
        username = itemList[value]
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        setUpPicker()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    override func contextForSegueWithIdentifier(segueIdentifier: String) -> AnyObject? {
        // Return data to be accessed in ResultsController
        print("hello: " + username)
        getLoginId()
        sleep(1)
        return self.userId
    }
}
