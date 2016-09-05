//
//  StatsViewController.swift
//  Analysis
//
//  Created by Andreas Okholm on 06/01/16.
//  Copyright © 2016 Vaavud ApS. All rights reserved.
//

import UIKit
import VaavudSDK


class StatsViewController: UIViewController {
    let sdk = VaavudSDK.shared
    
//    @IBOutlet weak var plot: SimplePlot!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        cal()
    }
    
    override func viewDidAppear(animated: Bool) {
        cal()
    }
    
    func cal() {
        let n = Float(sdk.debugVelStore.count)
        let completion = Float(sdk.debugVelStore.filter { $0[0] != 0 }.count)/n
        
        label.text = String("Completion \(completion)")
    }
    
    @IBAction func reset(sender: UIButton) {
        sdk.resetWindDirectionCalibration()
        cal()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

