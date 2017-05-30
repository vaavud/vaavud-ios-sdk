//
//  MedianFilter.swift
//  Sailor
//
//  Created by Juan Muñoz on 26/04/2017.
//  Copyright © 2017 Facebook. All rights reserved.
//

import Foundation
import GLKit

class MedianFilter {
    
    private var values = [Double]()
    private var directionX = [Float]()
    private var directionY = [Float]()
    private var sortedValues = [Double]()
    private var sortedDirectionX = [Float]()
    private var sortedDirectionY = [Float]()
    private var medianValue : Double = 0
    private var directionMedianValue : Int = -1
    
    
    //  let y = sort(x) { $0 > $1 }
    
    init() {
        // initialize remaining variables
        values.removeAll()
        directionX.removeAll()
        directionY.removeAll()
        sortedValues.removeAll()
        sortedDirectionX.removeAll()
        sortedDirectionY.removeAll()
    }
    
    func addValues(newValue: Double,newDirection:Int) {
        values.append(newValue)
        directionX.append((Float(newValue) * cos( GLKMathDegreesToRadians(Float(newDirection)) )))
        directionY.append((Float(newValue) * sin( GLKMathDegreesToRadians(Float(newDirection)) )))
    }
    
    func evaluateSpeedFilter() -> Double  {
        
        if (values.count > 10){
            sortedValues.append(contentsOf: values)
            sortedValues.sort()
            medianValue = sortedValues[sortedValues.count/2]
            sortedValues.removeAll()
        }
        if (values.count > 20) {
            values.remove(at: 0)
        }
        return medianValue
    }
    
    func evaluateDirectionFilter()-> Int  {
        var medianX:Float = 0.0
        var medianY:Float = 0.0
        var tan:Float = 0.0
        
        if (directionX.count > 5){
            
            sortedDirectionX.append(contentsOf: directionX)
            sortedDirectionY.append(contentsOf: directionY)
            sortedDirectionX.sort()
            sortedDirectionY.sort()
            
            medianX = sortedDirectionX[sortedDirectionX.count/2]
            medianY = sortedDirectionY[sortedDirectionY.count/2]
            tan = medianY/medianX
            
            directionMedianValue = ((360 + Int(GLKMathRadiansToDegrees(atan(Float(tan))))) % 360)
            if medianX < 0 && medianY > 0  {
                directionMedianValue -= 180
                directionMedianValue = ((360 + directionMedianValue) % 360)
            }
            if medianX < 0 && medianY < 0 {
                directionMedianValue += 180
                directionMedianValue = ((360 + directionMedianValue) % 360)
            }
            
            
            sortedDirectionX.removeAll()
            sortedDirectionY.removeAll()
            //            Log.d(TAG,"Median Value:"+ medianValue)
        }
        if (directionX.count > 10) {
            //            Log.d(TAG,"Values size Before"+ values.size)
            directionX.remove(at: 0)
            directionY.remove(at: 0)
            //            Log.d(TAG,"Values size After"+ values.size)
        }
        return directionMedianValue
    }
    
    func clear() {
        values.removeAll()
        directionX.removeAll()
        directionY.removeAll()
        sortedValues.removeAll()
        sortedDirectionX.removeAll()
        sortedDirectionY.removeAll()
    }
    
    deinit {
        clear()
    }
}
