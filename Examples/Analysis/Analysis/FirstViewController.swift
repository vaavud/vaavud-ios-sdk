//
//  FirstViewController.swift
//  Analysis
//
//  Created by Andreas Okholm on 05/01/16.
//  Copyright © 2016 Vaavud ApS. All rights reserved.
//

import UIKit
import VaavudSDK
import simplePlot


class FirstViewController: UIViewController {
    
    let sdk = VaavudSDK.shared
    
    @IBOutlet weak var plot: SimplePlot!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(animated: Bool) {
        sdk.windSpeedCallback = windSpeed
        sdk.debugPlotCallback = debug
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func on(sender: UISwitch) {
        if sender.on {
            do {
                try self.sdk.start()
            } catch {
                label.text = "didn't start"
                sender.on = false
            }
        } else {
            self.sdk.stop()
        }
        
    }
    
    func windSpeed(e: WindSpeedEvent) {
        label.text = String(format: "%.1f", e.speed)
    }
    
    func debug(pss: [[CGPoint]]) {
        plot.clear()
        plot.addLines(pss)
        plot.display()
    }
}

