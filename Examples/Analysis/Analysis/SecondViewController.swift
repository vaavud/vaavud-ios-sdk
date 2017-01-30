//
//  SecondViewController.swift
//  Analysis
//
//  Created by Andreas Okholm on 05/01/16.
//  Copyright © 2016 Vaavud ApS. All rights reserved.
//

import UIKit
import VaavudSDK
import simplePlot

class SecondViewController: UIViewController {

    let sdk = VaavudSDK.shared
    
    @IBOutlet weak var plot: SimplePlot!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var segment: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(animated: Bool) {
        sdk.windSpeedCallback = windSpeed
        plot(segment)
//        plot.clear()
////        plot.addLine([1,2,3,4,2,1,3])
//        
//        sdk.debugVelStore.map { plot.addLine($0.map { CGFloat($0) } ) }
//        plot.display()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func on(sender: UISwitch) {
//        if sender.on {
//            do {
//                try self.sdk.start()
//            } catch {
//                label.text = "didnt start"
//                sender.on = false
//            }
//        } else {
//            self.sdk.stop()
//        }
        
    }
    
    @IBAction func plot(sender: UISegmentedControl) {
//        plot.clear()
//        if sender.selectedSegmentIndex != 0 {
//            plot.addLine(sdk.debugT15.map { CGFloat($0) })
//        }
//        
//        if sender.selectedSegmentIndex != 1 {
//            _ = sdk.debugVelStore.map { plot.addLine($0.map { CGFloat($0) } ) }
//        }
//        
//        plot.display()
    }
    
    func windSpeed(e: WindSpeedEvent) {
        label.text = String(format: "%.1f", e.speed)
    }

}

