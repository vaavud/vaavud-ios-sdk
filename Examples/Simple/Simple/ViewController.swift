//
//  ViewController.swift
//  Simple
//
//  Created by Andreas Okholm on 13/09/15.
//  Copyright (c) 2015 Vaavud ApS. All rights reserved.
//

import UIKit
import VaavudSDK

class ViewController: UIViewController {

    let sdk = VaavudSDK.shared
    
    @IBOutlet weak var labelWindSpeed: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        sdk.windSpeedCallback = windspeed
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func windspeed(event: WindSpeedEvent) {
        labelWindSpeed.text = String(format: "%0.1f", event.speed)
    }
    @IBAction func measure(sender: UISwitch) {
        if sender.on {
            
            do {
                try sdk.start()
            }
            catch {
                sender.on = false
                createAlert("Start failed")
            }
            
        }
        else {
            sdk.stop()
            labelWindSpeed.text = "-"
        }
    }
    
    func createAlert(message: String) {
        let alert = UIAlertController(title: "Sleipnir not available!", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return [.Portrait, .PortraitUpsideDown]
    }
}

