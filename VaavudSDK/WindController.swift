//
//  WindController.swift
//  Pods
//
//  Created by Andreas Okholm on 24/06/15.
//
//

import Foundation
import AVFoundation
import UIKit
import MediaPlayer
import CoreLocation

class WindController: NSObject, LocationListener {
    weak var listener: WindListener?
    private var listeners: [WindListener] { return [listener].reduce([WindListener]()) { if let l = $1 { return $0 + [l] } else { return $0 } } }

    private var audioEngine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    
    private let outputBuffer : AVAudioPCMBuffer
    
    private var heading: Float? // Floats are thread safe
    
    // fixme: there is a memory management bug / leak for these input/output formats. fix later.
    private let inputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.PCMFormatInt16, sampleRate: 44100.0, channels: 1, interleaved: false)
    private let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
    
    private var data = [Int16](count: 16537, repeatedValue: 0)
    
    private let zeroEventThreshold = 1.5 // seconds
    
    private var sampleTimeLast = AVAudioFramePosition(0)
    private var sampleTimeStart = AVAudioFramePosition(-1)
    private var startTime : NSDate!
    private var audioSampleProcessor = AudioSampleProcessor()
    private var tickTimeProcessor = TickTimeProcessor()
    private var rotationProcessor = RotationProcessor(flipped: false) // not going to be used
    private var vol = Volume()
    
    private var observers = [NSObjectProtocol]()
    private var lastWindSpeedEvent: WindSpeedEvent?
    private var debugStartTime = NSDate()
    
    override init() {
        // initialize remaining variables
        outputBuffer = WindController.createBuffer(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        super.init()
    }

    func addListener(listener: WindListener) {
        self.listener = listener
    }
    
    private func reset() {
        heading = nil
        sampleTimeLast = AVAudioFramePosition(0)
        sampleTimeStart = AVAudioFramePosition(-1)
        audioSampleProcessor = AudioSampleProcessor()
        tickTimeProcessor = TickTimeProcessor()
        vol = Volume()
        observers = [NSObjectProtocol]()
        lastWindSpeedEvent = nil
    }
    
    private func resetAudio() {
        audioEngine = AVAudioEngine()
        player = AVAudioPlayerNode()
    }
    
    private func createEngineAttachNodesConnect() throws {
        audioEngine.attachNode(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: outputBuffer.format)
        
        guard let inputNode = audioEngine.inputNode else {
            throw VaavudAudioError.AudioInputUnavailable
        }
        
        inputNode.installTapOnBus(0, bufferSize: 16537, format: inputFormat) {
            [weak self] (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) in
            if let strongSelf = self {
                strongSelf.inputHandler(buffer, time: time)
            }
        }
    }

    func start(flipped: Bool) throws {
        audioEngine.mainMixerNode.outputVolume = volumeSetting(vol.volume)
        setVolumeToMax()
        rotationProcessor = RotationProcessor(flipped: flipped)

        do {
            try checkEngineAlreadyRunning()
            try initAVAudioSession()
            try checkCurrentRoute()
            try createEngineAttachNodesConnect()
            try startEngine()
        }
        catch {
            stop()
            throw error
        }
        
        setupObservers()
        startOutput()
    }
    
    func stop() {
        _ = observers.map(NSNotificationCenter.defaultCenter().removeObserver) // fixme: check
        vol.save()
        rotationProcessor.save()
        audioEngine.pause() // The other options (stop/reset) does occasionally cause a BAD_ACCESS CAStreamBasicDescription
        reset()
        resetAudio()
    }
    
    func resetCalibration() {
        rotationProcessor.resetCalibration()
    }
    
    private func startOutput() {
        player.play()
        player.scheduleBuffer(outputBuffer, atTime: nil, options: .Loops, completionHandler: nil)
    }
    
    private func inputHandler(buffer: AVAudioPCMBuffer!, time: AVAudioTime!) {
        let sampleTimeBufferStart = time.sampleTime - Int64(buffer.frameLength)
        updateTime(sampleTimeBufferStart, bufferLength: buffer.frameLength)
        copyData(buffer)
        
        let ticks = audioSampleProcessor.processSamples(data, sampleTime: sampleTimeBufferStart)
        let (rotations, detectionErrors) = tickTimeProcessor.processTicks(ticks, heading: heading)
        let directions = rotationProcessor.processRotations(rotations)
        
        // find the correct audio volume
        let noise = noiseEstimator(data)
        let resp = AudioResponse(diff20: noise.diff20, rotations: rotations.count, detectionErrors: detectionErrors, sN: noise.sN)
        audioEngine.mainMixerNode.outputVolume = vol.newVolume(resp)
        
        dispatch_async(dispatch_get_main_queue()) {
            let windSpeedEvents = rotations.map {
                (rotation: Rotation) -> WindSpeedEvent in
                let measurementTime = self.sampleTimeToUnixTime(rotation.sampleTime)
                let windspeed = WindController.rotationFrequencyToWindspeed(44100/Double(rotation.timeOneRotaion))
                return WindSpeedEvent(time: measurementTime, speed: windspeed)
            }
            
            let windSpeedEventsWithZeros = self.addZeroSpeedEvents(windSpeedEvents, endTime: self.sampleTimeToUnixTime(time.sampleTime))
            _ = windSpeedEventsWithZeros.map { event in self.listeners.map { listener in listener.newWindSpeed(event) } }
            
            for direction in directions {
                let measurementTime = self.sampleTimeToUnixTime(direction.sampleTime)
                let event = WindDirectionEvent(time: measurementTime, direction: Double(direction.globalDirection))
                _ = self.listeners.map { $0.newWindDirection(event) }
            }
            
            let dirAvgs = self.rotationProcessor.debugLastDirectionAverage.map { CGFloat($0) }
            let dirAvgsCorrected = zip(self.rotationProcessor.debugLastDirectionAverage, self.rotationProcessor.t15).map { CGFloat($0 - $1) }
            let correctionCoeffs = self.rotationProcessor.t15.map { CGFloat($0) }
            let localAngle: [CGFloat] = self.rotationProcessor.fitcurveForAngle(-self.rotationProcessor.debugLastLocalAngle).map { CGFloat($0) }
            
            let plotData = [dirAvgs, dirAvgsCorrected, correctionCoeffs, localAngle]
            
            _ = self.listeners.map { $0.debugPlot(plotData) }
        }
    }
    
    private func setVolumeToMax() {
        for view in MPVolumeView().subviews where view.description.rangeOfString("MPVolumeSlider") != nil {
            let mpVolumeSilder = (view as! UISlider)
            mpVolumeSilder.value = 1
        }
    }
    
    private func updateTime(sampleTime: AVAudioFramePosition, bufferLength: AVAudioFrameCount) {
        if sampleTimeStart == -1 {
            sampleTimeStart = sampleTime
            startTime = NSDate()
        }
        else if sampleTimeLast + AVAudioFramePosition(bufferLength) != sampleTime {
            print("Oops. Samples Lost at time: \(sampleTime)")
        }
        sampleTimeLast = sampleTime
    }
    
    private func copyData(buffer: AVAudioPCMBuffer) {
        let channel = buffer.int16ChannelData[0]
        for i in 0..<Int(buffer.frameLength) {
            data[i] = channel[i]
        }
    }
    
    private class func createBuffer(outputFormat: AVAudioFormat) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(PCMFormat: outputFormat, frameCapacity: 99)
        buffer.frameLength = 99 // Should divisible by 3
        
        let leftChannel = buffer.floatChannelData[0]
        let rightChannel = buffer.floatChannelData[1]
        
        for i in 0..<Int(buffer.frameLength) {
            leftChannel[i] = sinf(Float(i)*2*Float(M_PI)/3) // One 3rd of the sample frequency
            rightChannel[i] = -sinf(Float(i)*2*Float(M_PI)/3)
        }
        return buffer
    }
    
    private func sampleTimeToUnixTime(sampleTime: Int64) -> NSDate {
        return startTime.dateByAddingTimeInterval(Double(sampleTime - sampleTimeStart)/44100)
    }
    
    private func addZeroSpeedEvents(speedEvents: [WindSpeedEvent], endTime: NSDate) -> [WindSpeedEvent] {
        var newEvents = [WindSpeedEvent]()
        
        if lastWindSpeedEvent == nil, let event = speedEvents.first {
            lastWindSpeedEvent = event
        }
        
        if let lastEvent = lastWindSpeedEvent {
            var lEvent = lastEvent
            for event in speedEvents {
                if lEvent.speed != 0 && event.time.timeIntervalSinceDate(lEvent.time) > zeroEventThreshold {
                    newEvents.append(WindSpeedEvent(time: lEvent.time.dateByAddingTimeInterval(zeroEventThreshold), speed: 0))
                }
                newEvents.append(event)
                lEvent = event
            }
            
            if lEvent.speed != 0 && endTime.timeIntervalSinceDate(lEvent.time) > zeroEventThreshold {
                newEvents.append(WindSpeedEvent(time: lEvent.time.dateByAddingTimeInterval(zeroEventThreshold), speed: 0))
            }
            
            if let newLastEvent = newEvents.last {
                lastWindSpeedEvent = newLastEvent
            }
        }
        
        return newEvents
    }
    
    private func noiseEstimator(samples: [Int16]) -> (diff20: Int, sN: Double) {
        let skipSamples = 10000
        let nSamples = 100
        
        var diffValues = [Int]()

        for _ in 0..<nSamples {
            let index = Int(arc4random_uniform(UInt32(samples.count - skipSamples - 3))) + skipSamples
            var diff = 0
            
            for j in 0..<3 {
                diff = diff + abs(samples[index + j] - samples[index + j + 1])
            }
            
            diffValues.append(diff)
        }

        diffValues.sortInPlace(<)
        
        let preSN = Double(diffValues[79])/Double(diffValues[39])
        let sN = preSN == Double.infinity ? 0 : preSN
        
        return (diffValues[19], sN)
    }
    
    private func checkEngineAlreadyRunning() throws {
        guard audioEngine.running == false else {
            throw VaavudAudioError.MultipleStart
        }
    }

    private func initAVAudioSession() throws {
        // For complete details regarding the use of AVAudioSession see the AVAudioSession Programming Guide
        // https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html
        
        // Configure the audio session
        let sessionInstance = AVAudioSession.sharedInstance()
        do { try sessionInstance.setCategory(AVAudioSessionCategoryPlayAndRecord) }
        catch let error as NSError { throw VaavudAudioError.AudioSessionCategory(error) }
        
        let hsSampleRate = 44100.0
        do { try sessionInstance.setPreferredSampleRate(hsSampleRate) }
        catch let error as NSError { throw VaavudAudioError.AudioSessionSampleRate(error) }
        
        let ioBufferDuration = 0.0029
        do { try sessionInstance.setPreferredIOBufferDuration(ioBufferDuration) }
        catch let error as NSError { throw VaavudAudioError.AudioSessionBufferDuration(error) }
    }
    
    private func checkCurrentRoute() throws {
        // Configure the audio session
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        
        guard currentRoute.inputs.first?.portType == AVAudioSessionPortHeadsetMic &&
            currentRoute.outputs.first?.portType == AVAudioSessionPortHeadphones else {
                throw VaavudAudioError.Unplugged
        }
    }

    private func startEngine() throws {
        // start the engine and play
        
        /*  startAndReturnError: calls prepare if it has not already been called since stop.
        
        Starts the audio hardware via the AVAudioInputNode and/or AVAudioOutputNode instances in
        the engine. Audio begins flowing through the engine.
        
        Reasons for potential failure include:
        
        1. There is problem in the structure of the graph. Input can't be routed to output or to a
        recording tap through converter type nodes.
        2. An AVAudioSession error.
        3. The driver failed to start the hardware. */
        
        do { try audioEngine.start() }
        catch let error as NSError { throw VaavudAudioError.AudioEngine(error) }
    }

    private func setupObservers() {
        let nc = NSNotificationCenter.defaultCenter()
        let mainQueue = NSOperationQueue.mainQueue()
        let sessionInstance = AVAudioSession.sharedInstance()

        let interuptionObserver = nc.addObserverForName(AVAudioSessionInterruptionNotification, object:sessionInstance, queue:mainQueue) {
            [unowned self] notification in
            if let info = notification.userInfo {
                var intValue: UInt = 0
                (info[AVAudioSessionInterruptionTypeKey] as! NSValue).getValue(&intValue)
                if let type = AVAudioSessionInterruptionType(rawValue: intValue) where type == .Began {
                    self.stop()
                    let error = ErrorEvent(eventType: .AudioInterruption(type))
                    _ = self.listeners.map { $0.newError(error) }
                }
            }
        }
        
        observers.append(interuptionObserver)
        
        let routeObserver = nc.addObserverForName(AVAudioSessionRouteChangeNotification, object:sessionInstance, queue:mainQueue) {
            [unowned self] notification in
            if let info = notification.userInfo {
                var intValue: UInt = 0
                (info[AVAudioSessionRouteChangeReasonKey] as! NSValue).getValue(&intValue)
                
                if let reason = AVAudioSessionRouteChangeReason(rawValue: intValue) {
                    let error = ErrorEvent(eventType: .AudioRouteChange(reason))
                    _ = self.listeners.map { $0.newError(error) }
                    self.stop()
                }
            }
        }
        observers.append(routeObserver)
    
        let mediaObserver = nc.addObserverForName(AVAudioSessionMediaServicesWereResetNotification, object: sessionInstance, queue: mainQueue) {
            [unowned self] notification in
            // If we've received this notification, the media server has been reset
            // Re-wire all the connections and start the engine
            print("Media services have been reset!")
            print("Re-wiring connections and starting once again")
            
            self.resetAudio()
            
            do {
                try self.createEngineAttachNodesConnect()
                try self.startEngine()
            }
            catch let audioError as VaavudAudioError {
                let error = ErrorEvent(eventType: .AudioReconfigurationFailure(audioError))
                _ = self.listeners.map { $0.newError(error) }

                return
            }
            catch { }

            self.startOutput()
        }
        
        observers.append(mediaObserver)
    }
    
    // MARK: Location listener
    
    func newHeading(event: HeadingEvent) {
        heading = Float(event.heading)
    }
    
    func newLocation(event: LocationEvent) {
        
    }
    
    func newVelocity(event: VelocityEvent) {
        
    }
    
    // Fixme: send wind heading error
    func newError(error: ErrorEvent) {
        if case .LocationManagerFailure(let locationError) = error.type {
            _ = listeners.map { $0.newError(ErrorEvent(eventType: .HeadingUnavailable(locationError))) }
        }
    }
    
    private static func rotationFrequencyToWindspeed(freq: Double) -> Double {
        return freq > 0.0 ? freq*0.325 + 0.2 : 0.0
    }
    
    deinit {
        stop() // Remove observers if accedentially deinitialized before calling stop
        print("DEINIT WindController")
    }
}