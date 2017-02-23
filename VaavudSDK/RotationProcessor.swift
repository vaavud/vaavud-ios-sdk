//
//  RotationProcessor.swift
//  Pods
//
//  Created by Andreas Okholm on 03/08/15.
//
//

import Foundation
import Accelerate

// MARK: Rotation Processor
public struct Direction {
    public let sampleTime: Int64
    public let globalDirection: Float
    public let heading: Float
}

public struct RotationProcessor {
    public var t15: [Float]
    let ea15: [Float]
    
    let sleipnirFlipped: Bool
    
    let rotationNMax: Int
    let anglesN: Int
    let length: Int
    var d: [Float]
    var t: [Float]
    var b: [Float]
    var c: [Float]
    var f: [Float]
    var ea: [Float]
    var h: [Float]
    var wd: [Float]
    var a: [Float]
    var v360: [Float]
    
    let indicesTeeth: [vDSP_Length]
    let indicesWD: [vDSP_Length]
    
    struct RotationGroup {
        var rots = [Rotation]()
        var totalTime: Int = 0
    }
    
    var directionRotations = RotationGroup()
    var calibrationRotations = RotationGroup()
    
    struct Scheduler {
        var time: Int64 = 0
        let delta: Int64
    }
    
    var calibrationScheduler = Scheduler(time: 0, delta: 2*44100)
    var relVelsStore = [[Float]](repeating: [Float](repeating: 0, count: TPR), count: 360)
    
    var debugLastDirectionAverage = [Float](repeating: 0, count: TPR)
    var debugLastLocalAngle: Float = 0
    
    struct FitAngleCapsule {
        let revN: Int
        let relVels: [[Float]]
        let headings: [Float]
        let tCor: [Float]
        let merge: Bool
    }
    
    public init(flipped: Bool) {
        t15 = [Float](repeating: 0, count: TPR)
        ea15 = [0,23.5,47.0,70.5,94.0,117.5,141.0,164.5,188.0,211.5,235.0,258.5,282.0,305.5,332.75]
        sleipnirFlipped = flipped
        
        rotationNMax = 150
        anglesN = 20
        length = anglesN * TPR * rotationNMax
        
        d = [Float](repeating: 0, count: length)
        t = [Float](repeating: 0, count: length)
        b = [Float](repeating: 0, count: length)
        c = [Float](repeating: 0, count: length)
        f = [Float](repeating: 0, count: length)
        ea = [Float](repeating: 0, count: length)
        h = [Float](repeating: 0, count: length)
        wd = [Float](repeating: 0, count: length)
        a = [Float](repeating: 0, count: length)
        v360 = [Float](repeating: 360, count: length)

        indicesTeeth = getIndicesTeeth(length: length)
        indicesWD = getIndicesWD(anglesN: anglesN, length: length)
        
        if let relVelData = UserDefaults.standard.object(forKey: "vaavud_relVelsStore") as? NSData,
            let relVelsStore = NSKeyedUnarchiver.unarchiveObject(with: relVelData as Data) as? [[Float]] {
                self.relVelsStore = relVelsStore
//                print("Calibration store loaded, completion: \(calibrationCompletionPercentage(relVelsStore))")
        }
        
        if let t15Data = UserDefaults.standard.object(forKey: "vaavud_t15") as? NSData,
            let t15 = NSKeyedUnarchiver.unarchiveObject(with: t15Data as Data) as? [Float] {
                self.t15 = t15
//                print("Calibration coefficients loaded: \(self.t15)")
        }
    }
    
    public mutating func processRotations(rotations: [Rotation]) -> [Direction] {
        func steadyRotation(rotation: Rotation) -> Bool {
            return rotation.relRotaionTime > -0.03 && rotation.relRotaionTime < 0.03
        }
        
        func validForCoempensation(rotation: Rotation) -> Bool {
            return steadyRotation(rotation: rotation) && (rotation.timeOneRotaion > 700 && rotation.timeOneRotaion < 3600)
        }
        
        func validForDirection(rotation: Rotation) -> Bool {
            return steadyRotation(rotation: rotation) && (rotation.heading != nil)
        }
        
        func timeForCalibration( schedular: inout Scheduler, time: Int64) -> Bool {
            if time > schedular.time {
                schedular.time += time
                if time < schedular.time {
                    schedular.time = time + schedular.delta
                }
            
                return true
            }
            
            return false
        }
        
        let groupCalibration = groupRotations(group: &calibrationRotations, rotations: rotations.filter (validForCoempensation))
        let groupDirection = groupRotations(group: &directionRotations, rotations: rotations.filter(validForDirection))
        
        // Update correction coefficients
        let relVelsMean = groupCalibration.map { self.averageVectors(vectors: $0.map { $0.relVelocities }) }
        
        insertIntoStore(relVels: relVelsMean, relVelsStore: &relVelsStore)
        
        if let rotation = rotations.first, timeForCalibration(schedular: &calibrationScheduler, time: rotation.sampleTime) {
            let angles = Array(0..<360).filter({ self.relVelsStore[$0][0] != 0 }).map { Float($0) }
            if angleDifferenceMax(angles: angles) > 60 {
                t15 = estimateCoefficients(relVels: relVelsStore.filter { $0[0] != 0 }, windD: angles) // Only use data in the store with values
            }
        }
        
        if let group = groupDirection.last {
            debugLastDirectionAverage = averageVectors(vectors: group.map { $0.relVelocities })
        }
        
        // Calculate winddirections
        return groupDirection.map {
            rotations in
            let dir = self.fitAngle( relVels: rotations.map { $0.relVelocities }, headings: rotations.map { $0.heading! })
            // Debug
            debugLastLocalAngle = (dir - rotations.last!.heading! + 360).truncatingRemainder(dividingBy: 360)
            //print("H: \(rotations.last!.heading!), L: \(self.debugLastLocalAngle), G: \(dir)")
            return Direction(sampleTime: rotations.last!.sampleTime, globalDirection: dir, heading: rotations.last!.heading!) // There will always be at least one rotations in a group
        }
    }
    
    func groupRotations( group: inout RotationGroup, rotations: [Rotation]) -> [[Rotation]] {
        var groups = [[Rotation]]()
        
        for rotation in rotations {
            group.rots.append(rotation)
            group.totalTime += rotation.timeOneRotaion
            
            if group.totalTime > 44100 || group.rots.count == rotationNMax {
                groups.append(group.rots)
                group = RotationGroup()
            }
        }
        return groups
    }
    
    func averageVectors(vectors: [[Float]]) -> [Float] {
        var b = [Float](repeating: 0, count: vectors[0].count)
        for vector in vectors {
            b = zip(vector, b).map(+)
        }
        return b.map { $0/Float(vectors.count) }
    }
    
    mutating func fitAngle(relVels: [[Float]], headings: [Float]) -> Float {
        let fc = FitAngleCapsule(revN: relVels.count, relVels: relVels, headings: headings, tCor: t15, merge: true)
        return fitAngles(range: 360, centers: [Float](repeating: 0, count: relVels.count), c: fc).last!
    }
    
    mutating func fitAngles(relVels: [[Float]]) -> [Float] {
        let fc = FitAngleCapsule(revN: relVels.count, relVels: relVels, headings: [Float](repeating: 0, count: relVels.count), tCor: t15, merge: false)
        return fitAngles(range: 360, centers: [Float](repeating: 0, count: relVels.count), c: fc)
    }
    
    mutating func fitAngles(range: Int, centers: [Float], c: FitAngleCapsule) -> [Float] {
        let stride = range/anglesN
        let angless = centers.map { getAngles(N: self.anglesN, stride: stride, center: $0) }
        let rmsAngleRotation = rmsForAngleForRotation(relVels: c.relVels, headings: c.headings, tCor: c.tCor, angless: angless)
        
        let angle: [Float]
        
        if c.merge {
            // Sum every angle (1 x rotationsN) (rotationsN x anglesN)
            let sumVector = [Float](repeating: 1/Float(c.revN), count: c.revN)
            var rmsAngle = [Float](repeating: 0, count: anglesN)
            vDSP_mmul(sumVector, 1, rmsAngleRotation, 1, &rmsAngle, 1, vDSP_Length(1), vDSP_Length(anglesN),vDSP_Length(c.revN))
            angle = [Float](repeating: angless[0][minIndex(data: rmsAngle, advanceBy: anglesN).first!], count: c.revN)
        }
        else {
            angle = zip(angless, minIndex(data: rmsAngleRotation, advanceBy: anglesN)).map { $0[$1] }
        }
        
        if stride > 1 {
            let newStride = stride/anglesN + 1
            let newRange = newStride*anglesN
            return fitAngles(range: newRange, centers: angle, c: c)
        }
        
        return angle
    }
    
    func minIndex(data: [Float], advanceBy: Int) -> [Int] {
        var indexes = [Int](repeating: 0, count: data.count/advanceBy)
        
        var minValue = [Float](repeating: 0, count: 1)
        var minIndex = [vDSP_Length](repeating: 0, count: 1)
        
        for i in 0..<indexes.count {
            vDSP_minvi(UnsafePointer(data).advanced(by: i*advanceBy), 1, &minValue, &minIndex, vDSP_Length(advanceBy))
            indexes[i] = Int(minIndex[0])
        }
        return indexes
    }
    
    mutating func rmsForAngleForRotation(relVels: [[Float]], headings: [Float], tCor: [Float], angless: [[Float]]) -> [Float] {
        
        // d = data
        // f = fitcurve: lookup table (input is Di = f(Li), Li = -L + eai, => f(-G+h+aei)) and G = wd
        // t = teeth corection
        // e = error
        
        // d = f + t + e
        // e^2 = (d-t-f)^2
        // b = d-t
        // c = b-f
        // e^2 = c^2
        
        let rotaN = relVels.count
        let anglesN = angless[0].count
        let length = anglesN*TPR*rotaN
        let lengthDSP = vDSP_Length(length)
        
        for (i, relVel) in relVels.enumerated() {
            // populate data array
            vDSP_vgathr(relVel, indicesTeeth, 1, UnsafeMutablePointer(mutating: d).advanced(by: i*anglesN * TPR), 1, vDSP_Length(anglesN * TPR))
            // load h into h ... not verefied to be working yet! (relVels x angles)
            vDSP_vfill([headings[i]], UnsafeMutablePointer(mutating: h).advanced(by: i*anglesN*TPR), 1, vDSP_Length(anglesN * TPR))
            
            // load wind direction
            vDSP_vgathr(angless[i], indicesWD, 1, UnsafeMutablePointer(mutating: wd).advanced(by: i*anglesN * TPR), 1, vDSP_Length(anglesN * TPR)) // was lengthDSP
        }

        vDSP_vgathr(tCor, indicesTeeth, 1, &t, 1, lengthDSP)
        
        let ea15mightBeFlipped = sleipnirFlipped ? ea15.map {$0+180} : ea15
        
        vDSP_vgathr(ea15mightBeFlipped, indicesTeeth, 1, &ea, 1, lengthDSP)
        
        // find angle for f
        vDSP_vsub(wd, 1, v360, 1, &a, 1, lengthDSP)
        vDSP_vadd(h, 1, a, 1, &a, 1, lengthDSP)
        vDSP_vadd(ea, 1, a, 1, &a, 1, lengthDSP)
        vvfmodf(&a, a, v360, [Int32(length)])
        vDSP_vindex(fitcurve, a, 1, &f, 1, lengthDSP)
        
        // subtract correction t
        vDSP_vsub(t, 1, d, 1, &b, 1, lengthDSP)
        
        // subtract f from b
        vDSP_vsub(f, 1, b, 1, &c, 1, lengthDSP)
        
        //// error (c^2)
        vDSP_vmul(c, 1, c, 1, &c, 1, lengthDSP)
        
        // sum every single rotation (anglesN*rotationsN x TPR) * (TPR x 1)
        let sumVector = [Float](repeating: 1, count: TPR)
        var rmsAngleRotation = [Float](repeating: 0, count: anglesN*rotaN)
        vDSP_mmul(c, 1, sumVector, 1, &rmsAngleRotation, 1, vDSP_Length(anglesN*rotaN), vDSP_Length(1),vDSP_Length(TPR))
        return rmsAngleRotation
    }
    
    mutating func estimateCoefficients(relVels: [[Float]], windD: [Float]) -> [Float] {
        // d = data
        // f = fitcurce
        // t = teeth corection
        // e = error
        
        // d = f + t + e
        // e^2 = (d-f-t)^2
        // find where e2 is smallest -> different with respect to t and equal 0
        // d-f = g
        // (g-t)^2 (d/dt) = 0
        // -2(g-t) = 0
        // t = g = d-f
        
        let length = TPR * relVels.count
        let lengthDSP = vDSP_Length(length)
        
        // load data into d
        for (i, relvel) in relVels.enumerated() {
            memcpy(UnsafeMutablePointer<Float>(mutating: d).advanced(by:i*TPR), relvel, MemoryLayout<Float>.size*TPR)
        }
        
        // load wind direction(angles) into wd
        for i in 0..<TPR {
            vDSP_mmov(windD, UnsafeMutablePointer<Float>(mutating: wd).advanced(by:i), vDSP_Length(1), vDSP_Length(relVels.count), vDSP_Length(1), vDSP_Length(TPR))
        }
        // estimate angles to find f
        // load encoder angles
        vDSP_vgathr(ea15, indicesTeeth, 1, &ea, 1, lengthDSP)
        vDSP_vadd(v360, 1, ea, 1, &a, 1, lengthDSP)
        vDSP_vsub(wd, 1, a, 1, &a, 1, lengthDSP)
        vvfmodf(&a, a, v360, [Int32(length)])
        vDSP_vindex(fitcurve, a, 1, &f, 1, lengthDSP)
        
        // sum d and f per teeth basis
        let sumVector = [Float](repeating: 1/Float(relVels.count), count: relVels.count)
        var dSum = [Float](repeating: 0, count: TPR)
        var fSum = [Float](repeating: 0, count: TPR)
        vDSP_mmul(sumVector, 1, d, 1, &dSum, 1, vDSP_Length(1), vDSP_Length(TPR),vDSP_Length(relVels.count))
        vDSP_mmul(sumVector, 1, f, 1, &fSum, 1, vDSP_Length(1), vDSP_Length(TPR),vDSP_Length(relVels.count))

        return zip(dSum, fSum).map(-)
    }
    
    func angleDifferenceMax(angles: [Float]) -> Float {
        func dist(a: Float, b: Float) -> Float {
            return min(abs(a - b), min(abs(a + 360 - b), abs(a - 360 - b)))
        }
        
        let deltas = (0..<angles.count).map {
            i in dist(a: angles[i], b: angles[(i + 1) % angles.count])
        }
        
        return deltas.reduce(0, +)/2
    }
    
    mutating func insertIntoStore(relVels: [[Float]], relVelsStore: inout [[Float]]) {
        if relVels.count > 0 {
            var angles = fitAngles(relVels: relVels)
            
            for i in 0..<angles.count {
                relVelsStore[Int(angles[i])] = relVels[i]
            }
        }
    }
    
    func fitcurveForAngle(angle: Float) -> [Float] {
        return ea15.map { fitcurve[Int(mod(angle:angle + $0))] }
    }
    
    func save() {
        let userDefaults = UserDefaults.standard
        let t15Store = NSKeyedArchiver.archivedData(withRootObject: t15)
        UserDefaults.standard.set(t15Store, forKey: "vaavud_t15")
        
        let relVelStoreData = NSKeyedArchiver.archivedData(withRootObject: relVelsStore)
        UserDefaults.standard.set(relVelStoreData, forKey: "vaavud_relVelsStore")
        userDefaults.synchronize()
        
//        print("Calibration completion: \(calibrationCompletionPercentage(relVelsStore))")
    }
    
    mutating func resetCalibration() {
        relVelsStore = [[Float]](repeating: [Float](repeating: 0, count: TPR), count: 360)
        t15 = [Float](repeating: 0, count: TPR)
        save()
    }
}

public let fitcurvePercent: [Float] = [1.93055056304272,1.92754159835895,1.92282438491601,1.91642240663535,1.90836180821769,1.89867136590046,1.88738243346175,1.87452883370120,1.86014676759279,1.84427478518094,1.82695377850290,1.80822697586826,1.78813992874676,1.76674047747091,1.74407866757061,1.72020656030400,1.69517800715690,1.66904843699963,1.64187464950645,1.61371462647876,1.58462740924956,1.55467305246007,1.52391260026944,1.49240801962532,1.46022202221808,1.42741784194637,1.39405900931661,1.36020913199620,1.32593169153717,1.29128981914961,1.25634600129292,1.22116175831135,1.18579734303049,1.15031150113437,1.11476127584804,1.07920182312177,1.04368623722990,1.00826539680125,0.972987817770956,0.937899532389511,0.903043996582429,0.868462039649354,0.834191843341422,0.800268955749256,0.766726343538812,0.733594507605786,0.700901592353379,0.668673415622578,0.636933467547068,0.605702923030820,0.575000695079098,0.544843511789263,0.515245997694165,0.486220761974393,0.457778504155552,0.429928136760471,0.402676934592876,0.376030705291920,0.349993988555626,0.324570272343151,0.299762224554410,0.275571929569200,0.252001097395764,0.229051207572156,0.206723638918024,0.185019804046930,0.163941295536526,0.143490058746097,0.123668551764306,0.104479853075893,0.0859277278556616,0.0680166393704737,0.0507517558714560,0.0341389996545297,0.0181851042532520,0.00289764968455452,-0.0117149087765697,-0.0256432058939759,-0.0388769297985376,-0.0514047989025574,-0.0632145881998666,-0.0742932098523405,-0.0846268105605133,-0.0942008705954160,-0.103000306115350,-0.111009589516615,-0.118212913029394,-0.124594370818823,-0.130138144991804,-0.134828678151935,-0.138650863623146,-0.141589940836392,-0.143631982613669,-0.144763880519847,-0.144973663286989,-0.144250763791977,-0.142586242357516,-0.139972901415060,-0.136405374393993,-0.131880243512971,-0.126396155480609,-0.119953903391895,-0.112556485929105,-0.104209142607944,-0.0949193873907413,-0.0846970613071941,-0.0735543869171775,-0.0615060081531991,-0.0485690247473594,-0.0347630384066071,-0.0201102291169421,-0.00463544268113327,0.0116337222903312,0.0286668458970663,0.0464306654552773,0.0648890733800766,0.0840031184656525,0.103731019912623,0.124028212339776,0.144847424043910,0.166138809986866,0.187850105743243,0.209926771139125,0.232312099871980,0.254947302034379,0.277771580177066,0.300722214300621,0.323734675998779,0.346742778934413,0.369678866423019,0.392474005660318,0.415058168415599,0.437360424725763,0.459309184877691,0.480832480534593,0.501858298006565,0.522314926262134,0.542131291505136,0.561237285624209,0.579564080503314,0.597044401632675,0.613612772959745,0.629205754062743,0.643762145476949,0.657223114636108,0.669532313041451,0.680636049606467,0.690483471159853,0.699026703209735,0.706220954402490,0.712024568042803,0.716399053179197,0.719309119720656,0.720722727690873,0.720611146548223,0.718949016219273,0.715714393715594,0.710888767907992,0.704457075805069,0.696407729977473,0.686732645873142,0.675427261400450,0.662490538243213,0.647924923861272,0.631736296292326,0.613933903685354,0.594530298066370,0.573541258916757,0.550985712714184,0.526885650621979,0.501266033241476,0.474154669767433,0.445582087732282,0.415581407568944,0.384188230396930,0.351440532507190,0.317378563602313,0.282044739176431,0.245483514902245,0.207741270922022,0.168866239711485,0.128908451253386,0.0879196798867660,0.0459533973687714,0.00306473704801602,-0.0406895385539698,-0.0852510874443092,-0.130560085653262,-0.176555352635537,-0.223174483926726,-0.270354003694408,-0.318029564779040,-0.366136150084997,-0.414608230085121,-0.463379905156156,-0.512385053863697,-0.561557494697062,-0.610831175836623,-0.660140375852816,-0.709419902462159,-0.758605275138057,-0.807632877266797,-0.856440096451739,-0.904965450293262,-0.953148676657088,-1.00093081662756,-1.04825431459765,-1.09506313749468,-1.14130292468632,-1.18692112548173,-1.23186707424668,-1.27609204040434,-1.31954926810789,-1.36219398618314,-1.40398339226546,-1.44487663036859,-1.48483477692865,-1.52382083785846,-1.56179973308302,-1.59873829611478,-1.63460528731700,-1.66937141578467,-1.70300935345337,-1.73549372023954,-1.76680103882706,-1.79690964091476,-1.82579956937042,-1.85345251794598,-1.87985178650518,-1.90498224798798,-1.92883034611430,-1.95138411094696,-1.97263317597833,-1.99256875417214,-2.01118351063343,-2.02847142222021,-2.04442770651076,-2.05904876934359,-2.07233212953319,-2.08427634067406,-2.09488092934612,-2.10414633918689,-2.11207385653047,-2.11866550063715,-2.12392392855818,-2.12785235294625,-2.13045446941802,-2.13173440166218,-2.13169662774024,-2.13034586385060,-2.12768694358104,-2.12372472526967,-2.11846404796602,-2.11190978398746,-2.10406693046473,-2.09494070314769,-2.08453657856423,-2.07286020228535,-2.05991724573168,-2.04571329439890,-2.03025381011404,-2.01354409660671,-1.99558925551097,-1.97639417257405,-1.95596358148356,-1.93430215219623,-1.91141456498716,-1.88730558353145,-1.86198014106267,-1.83544343461144,-1.80770102675171,-1.77875894897603,-1.74862377338231,-1.71730261999106,-1.68480317756577,-1.65113374186939,-1.61630326967538,-1.58032147957387,-1.54319899451728,-1.50494750075179,-1.46557986180280,-1.42511011063198,-1.38355342912957,-1.34092621637585,-1.29724617853082,-1.25253238496823,-1.20680533995027,-1.16008712948684,-1.11240159666417,-1.06377448238627,-1.01423346987064,-0.963808178076644,-0.912530147553338,-0.860432823915887,-0.807551534849895,-0.753923437647436,-0.699587397418073,-0.644583841616784,-0.588954623685606,-0.532742913754490,-0.475993148906732,-0.418751007243797,-0.361063391962615,-0.302978414524606,-0.244545320336948,-0.185814388853583,-0.126836850407010,-0.0676648561212342,-0.00835148845376236,0.0510492170666441,0.110482255689112,0.169891654855290,0.229220498160153,0.288410989747835,0.347404532745552,0.406141804216642,0.464562841859978,0.522607165069588,0.580213909827325,0.637321971379807,0.693870171239719,0.749797447763799,0.805043053132515,0.859546740347051,0.913248923637761,0.966090812760156,1.01801450649125,1.06896306768950,1.11888059184822,1.16771228860579,1.21540460253994,1.26190534933332,1.30716384843168,1.35113103633228,1.39375955096661,1.43500380728303,1.47482010511715,1.51316681498404,1.55000456748550,1.58529639518708,1.61900783540342,1.65110697646223,1.68156447603108,1.71035356279630,1.73745001850842,1.76283212588682,1.78648061977600,1.80837868058991,1.82851194497160,1.84686852509262,1.86343902222370,1.87821647622575,1.89119628770111,1.90237616864563,1.91175616824101,1.91933872768542,1.92512873506254,1.92913358874019,1.93136328313521,1.93183048501708]

// fixme: why public?
public let fitcurve = fitcurvePercent.map { $0/100 }

public func getIndicesTeeth(length: Int) -> [vDSP_Length] {
    return (0..<length).map { vDSP_Length($0 % TPR + 1) }
}

public func getIndicesWD(anglesN: Int, length: Int) -> [vDSP_Length] {
    return (0..<length).map { vDSP_Length(($0/TPR) % anglesN + 1) }
}


public func mod(angle: Float) -> Float {
    return (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    //  return ((i % n) + n) % n
    //    return ((angle % 360) + 360) % 360
}

public func mod(angle: Double) -> Double {
    return (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
//    return ((angle % 360) + 360) % 360
}

public func getAngles(N: Int, stride: Int, center: Float) -> [Float] {
    let range = N*stride
    let offset = range/2
    let start = (center - Float(offset) + 360).truncatingRemainder(dividingBy: 360)
    return (0..<N).map { (Float($0)*Float(stride) + start).truncatingRemainder(dividingBy: 360) }
}

public func calibrationCompletionPercentage(relValss: [[Float]]) -> Float {
    let n = Float(relValss.count)
    
    let v1 = relValss.reduce(Float()) { $1[0] != 0 ? $0 + 1 : $0 }/n
    let v0 = Float(relValss.filter { $0[0] != 0 }.count)/n
    
    if v1 != v0 {
        fatalError("Reduce failed")
    }
    
    return relValss.reduce(Float()) { $1[0] != 0 ? $0 + 1 : $0 }/n
}

