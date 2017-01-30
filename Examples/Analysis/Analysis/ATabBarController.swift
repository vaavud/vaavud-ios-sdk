//
//  ATabBarController.swift
//  Analysis
//
//  Created by Andreas Okholm on 05/01/16.
//  Copyright © 2016 Vaavud ApS. All rights reserved.
//

import UIKit

class ATabBarController: UITabBarController {
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return [.Portrait, .PortraitUpsideDown]
    }
}