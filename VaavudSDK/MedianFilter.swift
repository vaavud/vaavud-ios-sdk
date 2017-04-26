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
    private var directionX = [Double]()
    private var directionY = [Double]()
    private var sortedValues = [Double]()
    private var sortedDirectionX = [Double]()
    private var sortedDirectionY = [Double]()
    private var medianValue : Double = -1.0
    private var directionMedianValue : Int = -1
    
    
    //  let y = sort(x) { $0 > $1 }
    
    required init() {
        // initialize remaining variables
        values.removeAll()
        directionX.removeAll()
        directionY.removeAll()
        sortedValues.removeAll()
        sortedDirectionX.removeAll()
        sortedDirectionY.removeAll()
    }
    
    func addValues(newValue: Double,newDirection:Int) {
        //        Log.d(TAG,"Adding Value "+newValue + this.toString())
        
        values.append(newValue)
        directionX.append((newValue * cos( GLKMathDegreesToRadians(Float(newDirection)) )))
        directionY.append((newValue * sin( GLKMathDegreesToRadians(Float(newDirection)) )))
    }
    
    func evaluateSpeedFilter() -> Double  {
        
        //        Log.d(TAG,"Evaluate Filter "+values.size + this.toString())
        if (values.count > 10){
            sortedValues.append(contentsOf: values)
            sortedValues.sort()
            medianValue = sortedValues[sortedValues.count/2]
            sortedValues.removeAll()
            //            Log.d(TAG,"Median Value:"+ medianValue)
        }
        if (values.count > 20) {
            //            Log.d(TAG,"Values size Before"+ values.size)
            values.remove(at: 0)
            //            Log.d(TAG,"Values size After"+ values.size)
        }
        return medianValue
    }
    
    func evaluateDirectionFilter()-> Int  {
        var medianX:Double = 0.0
        var medianY:Double = 0.0
        var tan:Double = 0.0
        
        if (directionX.count > 5){
            
            sortedDirectionX.append(contentsOf: directionX)
            sortedDirectionY.append(contentsOf: directionY)
            sortedDirectionX.sort()
            sortedDirectionY.sort()
            
            medianX = sortedDirectionX[sortedDirectionX.count/2]
            medianY = sortedDirectionY[sortedDirectionY.count/2]
            tan = medianY/medianX
            //            System.out.println("Sin: "+medianX/values.get(0)+" Cos: "+medianY/values.get(0)+" Tan: "+tan)
            //            var directionTmp =
            //            Log.d(TAG,"Evaluate directionTmp "+directionTmp)
            directionMedianValue = ((360 + Int(GLKMathRadiansToDegrees(atan(Float(tan))))) % 360)
            if (medianX < 0 && medianY > 0 ) {
                directionMedianValue -= 180
                directionMedianValue = ((360 + directionMedianValue) % 360)
            }
            if (medianX < 0 && medianY < 0 ){
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
