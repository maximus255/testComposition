//
//  CustomComposition.swift
//  TestSegmentation
//
//  Created by admin on 17.04.2023.
//

import Foundation
import AVFoundation
import UIKit
import VideoToolbox
let kHeight = 2897
let kWidth = 2000
let kWholeDuration: Double = 10
func makeComposition() throws -> (composition: AVComposition, videoComposition: AVVideoComposition, audioMix: AVMutableAudioMix){
    //let renderSize = CGSize(width: 1080, height: 1920)
    let renderSize = CGSize(width: kWidth, height: kHeight)

    let composition = AVMutableComposition()
    composition.naturalSize = renderSize

    let videoComposition = AVMutableVideoComposition()
    
    videoComposition.customVideoCompositorClass = customCompositor.self
    videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
    videoComposition.renderSize = renderSize

    let audioMix = AVMutableAudioMix()
    var audioMixParam = [AVMutableAudioMixInputParameters]()

    var layerInstructions = [CustomRuntimeVideoCompositionLayerInstruction]()

    let backgroundUrl = Bundle.main.url(forResource: "dummy_video60", withExtension:"mp4")
    let backgroundAsset = AVURLAsset(url: backgroundUrl!)

    guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { fatalError() }
    guard let backgroundAssetTrack = backgroundAsset.tracks(withMediaType: .video).first else { fatalError() }


    let targetDuration = CMTime(seconds: kWholeDuration, preferredTimescale: 600) // Для тестирования.

    let loopInfoList = getVideoLoopInfo(totalDuration: targetDuration, videoDuration: backgroundAsset.duration)
    for loopInfo in loopInfoList {
        try? compositionTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: loopInfo.duration),
            of: backgroundAssetTrack,
            at: loopInfo.at
        )
    }
    
    let backgroundLayerInstruction = CustomRuntimeVideoCompositionLayerInstruction(assetTrack: backgroundAssetTrack)
    layerInstructions.append(backgroundLayerInstruction)
    
    ///[ADD AUDIO
    do {
        let bundlePath = Bundle.main.path(forResource: "music", ofType: "aac")
        let url: URL = URL(fileURLWithPath: bundlePath!)
        let asset = AVURLAsset(url: url)
        var assetDuration = asset.duration
        assetDuration = min(assetDuration, targetDuration)
        if let assetTrack = asset.tracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            
            let audioParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: assetTrack)
            audioParam.trackID = audioTrack.trackID
            audioParam.setVolume(Float(1), at: CMTime.zero)
            let timeRangeA = CMTimeRange(start: .zero, duration: assetDuration)
            try audioTrack.insertTimeRange(timeRangeA, of: assetTrack, at: .zero)
            
            audioMixParam.append(audioParam)
        }
    } catch {
        print("Failed to add audio track!. Error: <\(error.localizedDescription)>")
    }
    ///]
    
    audioMix.inputParameters = audioMixParam
    let compositionInstruction = AVMutableVideoCompositionInstruction()
    compositionInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: targetDuration)
    compositionInstruction.layerInstructions = layerInstructions
    videoComposition.instructions = [compositionInstruction]

    return (composition, videoComposition, audioMix)
}
func getVideoLoopInfo(totalDuration: CMTime, videoDuration: CMTime) -> [(at: CMTime, duration: CMTime)] {
    var result = [(at: CMTime, duration: CMTime)]()
    var start: CMTime = .zero
    
    repeat {
        let info = (
            at: start,
            duration: min(CMTimeSubtract(totalDuration, start), videoDuration)
        )
        result.append(info)
        start = CMTimeAdd(start, info.duration)
    } while start < totalDuration
    
    return result
}

class customCompositor: NSObject , AVVideoCompositing{
    
    private var renderContext : AVVideoCompositionRenderContext?
    
    var img0,img1,img2,img3,img4,img5,img6,img7: CVPixelBuffer!
    var img0_msk,img1_msk,img2_msk,img3_msk,img4_msk,img5_msk,img5_1_msk,img6_msk,img7_msk: CVPixelBuffer!
    
    var contour3_1: CGPath? = nil; var contour3_2: CGPath? = nil; var contour3_3: CGPath? = nil
    var size3: CGSize = .zero
    var contour3_1_b = false; var contour3_2_b = false; var contour3_3_b = false;
    
    let seqmentation = performSeqmentation()
    
    override init() {
        
        print("Init inner assets")
                
        super.init()
        
        (self.img0, _) = loadAsset("img0", type: "jpeg", make_mask: false )
        (self.img1, self.img1_msk) = loadAsset("img1", type: "jpeg")
        (self.img2, self.img2_msk) = loadAsset("img2", type: "jpeg")
        (self.img3, self.img3_msk) = loadAsset("img3", type: "jpeg")
        (self.img4, self.img4_msk) = loadAsset("img4", type: "jpeg")
        (self.img5, self.img5_msk) = loadAsset("img5", type: "jpeg")
        (self.img6, self.img6_msk) = loadAsset("img6", type: "jpeg")
        (self.img7, self.img7_msk) = loadAsset("img7", type: "jpeg")
        
        
        
        let (img3_1, _) = loadAsset("newPixelBuffer02", type: "png", make_mask: false )
        let (img3_2, _) = loadAsset("newPixelBuffer04", type: "png", make_mask: false )
        let (img3_3, _) = loadAsset("newPixelBuffer05", type: "png", make_mask: false )
        
        if let img03 = UIImage(pixelBuffer: img3_1) {
            self.contour3_1 = detectVisionContours(from: img03)
        }
        if let img03 = UIImage(pixelBuffer: img3_2) {
            self.contour3_2 = detectVisionContours(from: img03)
        }
        if let img03 = UIImage(pixelBuffer: img3_3) {
            self.contour3_3 = detectVisionContours(from: img03)
            self.size3 = img03.size
        }
        
        let bundlePath = Bundle.main.path(forResource: "img5", ofType: "jpeg")
        let url = URL(fileURLWithPath: bundlePath!)
        img5_1_msk = seqmentation.processURL(url: url, net: 0)
        img5_1_msk = makeCVBufferSameSize(src: img5_1_msk, exm: img5, level: 1)
        
    }
    func loadAsset(_ name: String, type: String, make_mask: Bool = true  ) -> (CVPixelBuffer, CVPixelBuffer?){
        let bundlePath = Bundle.main.path(forResource: name, ofType: type)
        let image = UIImage(contentsOfFile: bundlePath!)
        let size = image?.size
        guard let buffer = image?.buffer(with: size!) else {
            fatalError()
        }
        var img_msk: CVPixelBuffer? = nil
        if make_mask {
            let url = URL(fileURLWithPath: bundlePath!)
            if let msk = seqmentation.processURL(url: url) {
                img_msk = makeCVBufferSameSize(src: msk, exm: buffer, level: 1)
            }
        }
        return (buffer, img_msk )
    }
    
    var sourcePixelBufferAttributes: [String : Any]?{
        get {
            return ["\(kCVPixelBufferPixelFormatTypeKey)": kCVPixelFormatType_32BGRA]
        }
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any]{
        get {
            return ["\(kCVPixelBufferPixelFormatTypeKey)": kCVPixelFormatType_32BGRA]
        }
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext){
        renderContext = newRenderContext
    }
    
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        
        let destinationFrame = request.renderContext.newPixelBuffer()
        if(request.sourceTrackIDs.count == 1){
            
            //let instruction = request.videoCompositionInstruction
            
                let time = request.compositionTime.seconds
                //print("time is \(time)")
                //let startTime = Date().timeIntervalSince1970
            
                //img0
                if (time <= 2){
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img0,
                           offset: CGPoint(x: kWidth/2 , y: kHeight - 2937/2 ),
                           rotate: 0,scale: 1, maskBuffer: nil, maskInvert: true)
                }
                if (time >= 1.5)&&(time < 2){
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img1,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2915/2 ),
                               rotate: 0,scale: 1, maskBuffer: img1_msk, maskInvert: true)
                }
            
                //img1
                if (time >= 1) && (time < 2){
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img1,
                               offset: CGPoint(x: kWidth/2 + 50 , y: kHeight - 2915/2 - 150 ),
                               rotate: .pi/15 ,scale: 1, maskBuffer: img1_msk, maskInvert: false)
                }
                if (time >= 2)&&(time < 3) {
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img1,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2915/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
            //img2
                if (time > 2.25)&&(time < 3 ){
                    var Mul: Float = 1; var Bias: Float = 0
                    if (time > 2.5){
                        let t = min(1,Float(time-2.5)/0.5)
                        Mul = 1 - t/2
                        Bias = t
                    }
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img2,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2933/2 ),
                               rotate: 0,scale: 1, maskBuffer: img2_msk, maskInvert: false, maskMul: Mul, maskBias: Bias)
                }
                if (time >= 3)&&(time < 4) {
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img2,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2933/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
                //img3
                if (time > 3) && (time < 4) {
                    
                    let t = min(1,Float(time-3))
                    
                    if !contour3_1_b , t > 0.25, let contour3_1 = contour3_1 {
                        contour3_1_b = true
                        let img = renderPath(path: contour3_1, size: size3, lineWidth: 50, color: .white)
                        if let contourBuffer = img.buffer(with: size3) {
                            bufferOver(lowerBuffer : img3_msk, upperBuffer : contourBuffer,
                                       offset: CGPoint(x: kWidth/2 , y: 2915/2  ),
                                       rotate: 0,scale: 1.1, maskBuffer: nil, maskInvert: false)
                        }
                    }
                    
                    if !contour3_2_b , t > 0.5, let contour3_2 = contour3_2 {
                        contour3_2_b = true
                        let img = renderPath(path: contour3_2, size: size3, lineWidth: 75, color: .white)
                        if let contourBuffer = img.buffer(with: size3) {
                            bufferOver(lowerBuffer : img3_msk, upperBuffer : contourBuffer,
                                       offset: CGPoint(x: kWidth/2 , y: 2915/2  ),
                                       rotate: 0,scale: 1.05, maskBuffer: nil, maskInvert: false)
                        }
                    }
                    
                    if !contour3_3_b , t > 0.75, let contour3_3 = contour3_3 {
                        contour3_3_b = true
                        let img = renderPath(path: contour3_3, size: size3, lineWidth: 100, color: .white)
                        if let contourBuffer = img.buffer(with: size3) {
                            bufferOver(lowerBuffer : img3_msk, upperBuffer : contourBuffer,
                                       offset: CGPoint(x: kWidth/2 , y: 2915/2  ),
                                       rotate: 0,scale: 1.1, maskBuffer: nil, maskInvert: false)
                        }
                    }
                    
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img2,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2933/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                    
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img3,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2915/2 ),
                               rotate: 0,scale: 1, maskBuffer: img3_msk, maskInvert: false)
                }
                if (time >= 4)&&(time<5) {
                    
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img3,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2915/2 ),
                               rotate: 0, scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
                //img4
                if (time > 4) && (time < 5) {
                    let scale = (time < 4.33) ? 1.25 : 1
                    let rotate = CGFloat.pi / 20
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img4,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2904/2 ),
                               rotate: rotate,scale: scale, maskBuffer: img4_msk, maskInvert: true)
                    if time > 4.66 {
                        bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img4,
                                   offset: CGPoint(x: kWidth/2 , y: kHeight - 2904/2 ),
                                   rotate: 0,scale: 1, maskBuffer: img4_msk, maskInvert: false)
                    }
                }
                if (time >= 5)&&(time<6) {
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img4,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2904/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
                
                //img5
                if (time > 5) && (time < 6) {
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img5,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2921/2 ),
                               rotate: 0,scale: 1, maskBuffer:
                                (time < 5.5) ? img5_msk : img5_1_msk, maskInvert: false)
                }
                if (time >= 6)&&(time<=6.5)  {
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img5,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2921/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
                ///img6
                if (time > 6.1) && (time < 7) {
                    if (time > 6.5){
                        bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img6,
                                   offset: CGPoint(x: kWidth/2 , y: kHeight - 2923/2 ),
                                   rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                    }
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img6,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2922/2 ),
                               rotate: 0,scale: 1.1, maskBuffer:
                                 img6_msk , maskInvert: false)
                }
                if (time >= 7 )&&(time<8.5) {
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img6,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2923/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
                //img7
                if (time>=7.5)&&(time<8.5){
                    let t: CGFloat = min(1.5,CGFloat(time)-7.5)
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img7,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2897/2 ),
                               rotate: 0,scale: 1.25 - 0.25*t, maskBuffer: img7_msk, maskInvert: true)
                }
                if (time >= 8.5){
                    bufferOver(lowerBuffer : destinationFrame!, upperBuffer : img7,
                               offset: CGPoint(x: kWidth/2 , y: kHeight - 2897/2 ),
                               rotate: 0,scale: 1, maskBuffer: nil, maskInvert: false)
                }
                
            
                //let rndTime = Date().timeIntervalSince1970 - startTime
                //print("Render time = \(rndTime)")
                
                request.finish(withComposedVideoFrame: destinationFrame!)
            
        }else {
            print("tracks count = \(request.sourceTrackIDs.count)")
        }
    }
}
func mixPixel(lb: UnsafeMutablePointer<UInt8>, ub: UnsafeMutablePointer<UInt8>, tt: Int, tt1: Int, mb: UnsafeMutablePointer<UInt8>?, ttm: Int, maskInvert: Bool, maskMul: Float, maskBias: Float) {
    
    var aI = ub[tt1+3]
    if let mb = mb {
        let m = (maskInvert) ? 255 - mb[ttm] : mb[ttm]
        //aI = UInt8( Int(aI) * Int(m) / 255 )
        var mF: Float = Float(m) * maskMul / 255 + maskBias;
        if mF < 0 {mF = 0}; if mF > 1 {mF = 1}
        aI = UInt8(Float(aI)*mF)
    }
    if aI == 255 {
        lb[tt] = ub[tt1]; lb[tt+1] = ub[tt1+1]; lb[tt+2] = ub[tt1+2]; lb[tt+3] = 255
    }else {
        let al = Float(aI)/255
        let al1 = 1.0 - al
        lb[tt] = UInt8(Float(ub[tt1]) * al + Float(lb[tt]) * al1) ;
        lb[tt+1] = UInt8(Float(ub[tt1+1]) * al + Float(lb[tt+1]) * al1) ;
        lb[tt+2] = UInt8(Float(ub[tt1+2]) * al + Float(lb[tt+2]) * al1) ;
        lb[tt+3] = max(lb[tt+3],ub[tt1+3])
    }
}
func bufferOver(lowerBuffer : CVPixelBuffer, upperBuffer : CVPixelBuffer, offset: CGPoint, rotate: CGFloat, scale: CGFloat,
                maskBuffer: CVPixelBuffer? = nil, maskInvert: Bool = false, maskMul: Float = 1.0, maskBias: Float = 0.0
) {
    CVPixelBufferLockBaseAddress(lowerBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferLockBaseAddress(upperBuffer, CVPixelBufferLockFlags(rawValue: 1))
    if maskBuffer != nil {
        CVPixelBufferLockBaseAddress(maskBuffer!, CVPixelBufferLockFlags(rawValue: 2))
    }
    
    let lWidth = CVPixelBufferGetWidth(lowerBuffer)
    let lHeight = CVPixelBufferGetHeight(lowerBuffer)
    let lRowbytes = CVPixelBufferGetBytesPerRow(lowerBuffer)
    //let lPlanes = CVPixelBufferGetPlaneCount(lowerBuffer)
    let lBaseAddress = CVPixelBufferGetBaseAddress(lowerBuffer)
    let lb = lBaseAddress!.assumingMemoryBound(to: UInt8.self)
    
    let uWidth = CVPixelBufferGetWidth(upperBuffer)
    let uHeight = CVPixelBufferGetHeight(upperBuffer)
    let uRowbytes = CVPixelBufferGetBytesPerRow(upperBuffer)
    //let uPlanes = CVPixelBufferGetPlaneCount(upperBuffer)
    let uBaseAddress = CVPixelBufferGetBaseAddress(upperBuffer)
    let ub = uBaseAddress!.assumingMemoryBound(to: UInt8.self)
        
    var mWidth: Int = 0; var mHeight: Int = 0; var mRowbytes: Int = 0;
    var mb: UnsafeMutablePointer<UInt8>? = nil
    if maskBuffer != nil {
            mWidth = CVPixelBufferGetWidth(maskBuffer!)
            mHeight = CVPixelBufferGetHeight(maskBuffer!)
            mRowbytes = CVPixelBufferGetBytesPerRow(maskBuffer!)
            //print("mRowbytes = \(mRowbytes)")
            if mWidth == uWidth && mHeight == mHeight {
                let mBaseAddress = CVPixelBufferGetBaseAddress(maskBuffer!)
                mb = mBaseAddress!.assumingMemoryBound(to: UInt8.self)
        }else {
            print("WARNING! mWidth != uWidth or mHeight != mHeight")
        }
    }
    var ttm: Int = 0
    
    if rotate == 0 {
        let uW = CGFloat(uWidth) * scale; let uH = CGFloat(uHeight) * scale
        let uW2 = uW/2; let uH2 = uH/2
        let j0 =  offset.y - uH2; let i0 =  offset.x - uW2
        let j1 =  offset.y + uH2; let i1 =  offset.x + uW2
        var I0 = (i0 < 0) ? Int(i0 - 0.5) : Int(i0 + 0.5); I0 = max(0, min(lWidth, I0))
        var J0 = (j0 < 0) ? Int(j0 - 0.5) : Int(j0 + 0.5); J0 = max(0, min(lHeight, J0))
        var I1 = (i1 < 0) ? Int(i1 - 0.5) : Int(i1 + 0.5); I1 = max(0, min(lWidth, I1))
        var J1 = (j1 < 0) ? Int(j1 - 0.5) : Int(j1 + 0.5); J1 = max(0, min(lHeight, J1))
        
        for j in J0..<J1 {
            let jjl = j * lRowbytes;
            let j1 = (CGFloat(j) - offset.y + uH2)/scale //u_c_y;
            let J1 = Int(j1 + 0.5)
            if (J1<0) || (J1>=uHeight){
                continue }
            let JJ1 = J1 * uRowbytes
            for i in I0..<I1 {
                let i1 = (CGFloat(i) - offset.x + uW2 )/scale //u_c_x;
                let I1 = Int(i1 + 0.5)
                if (I1<0) || (I1>=uWidth){
                    continue }
                
                let tt = jjl + i*4//lPlanes
                let tt1 = JJ1 + I1*4//uPlanes
                
                if mb != nil {
                    ttm = J1 * mRowbytes + I1*4
                }
                
                mixPixel(lb: lb, ub: ub, tt: tt, tt1: tt1, mb: mb, ttm:ttm, maskInvert: maskInvert, maskMul: maskMul, maskBias: maskBias)
                
            }
        }//for j
    }//rotate = 0
    else {
        let uW = CGFloat(uWidth) * scale; let uH = CGFloat(uHeight) * scale
        let uW2 = uW/2; let uH2 = uH/2
        //calc corners
        var c_a = cos(rotate); var s_a = sin(rotate)
        let (x00,y00,x11,y11) = calcBorders(w2: uW2, h2: uH2, c_a: c_a, s_a: s_a)
        
        let j0 =  offset.y + y00; let i0 =  offset.x + x00
        let j1 =  offset.y + y11; let i1 =  offset.x + x11
        var I0 = (i0 < 0) ? Int(i0 - 0.5) : Int(i0 + 0.5); I0 = max(0, min(lWidth, I0))
        var J0 = (j0 < 0) ? Int(j0 - 0.5) : Int(j0 + 0.5); J0 = max(0, min(lHeight, J0))
        var I1 = (i1 < 0) ? Int(i1 - 0.5) : Int(i1 + 0.5); I1 = max(0, min(lWidth, I1))
        var J1 = (j1 < 0) ? Int(j1 - 0.5) : Int(j1 + 0.5); J1 = max(0, min(lHeight, J1))
        
        c_a = cos(-rotate); s_a = sin(-rotate)
        for j in J0..<J1 {
            let jjl = j * lRowbytes;
            let j2 = (CGFloat(j) - offset.y)
            for i in I0..<I1 {
                let i2 = (CGFloat(i) - offset.x)
                let i3 = i2*c_a - j2*s_a
                let j3 = i2*s_a + j2*c_a
                let i1 = (i3 + uW2)/scale
                let j1 = (j3 + uH2)/scale
                let I1 = Int(i1 + 0.5)
                let J1 = Int(j1 + 0.5)
                if (I1>=0) && (J1>=0) && (I1<uWidth) && (J1<uHeight) {
                    let tt = jjl + i*4//lPlanes
                    let tt1 = J1 * uRowbytes + I1*4//uPlanes
                    if mb != nil {
                        ttm = J1 * mRowbytes + I1*4
                    }
                    
                    mixPixel(lb: lb, ub: ub, tt: tt, tt1: tt1, mb: mb, ttm: ttm, maskInvert: maskInvert,maskMul: maskMul, maskBias: maskBias)
                    
                }//I1 >=0
            }//for i
        }//j
        
    }//else rotate = 0
    if maskBuffer != nil {
        CVPixelBufferUnlockBaseAddress(maskBuffer!, CVPixelBufferLockFlags(rawValue: 2))
    }
    CVPixelBufferUnlockBaseAddress(upperBuffer, CVPixelBufferLockFlags(rawValue: 1))
    CVPixelBufferUnlockBaseAddress(lowerBuffer, CVPixelBufferLockFlags(rawValue: 0))
}
func calcBorders(w2: CGFloat, h2: CGFloat, c_a: CGFloat,s_a: CGFloat) -> (CGFloat, CGFloat, CGFloat, CGFloat){
    let x00 = -w2*c_a + h2*s_a
    let y00 = -w2*s_a - h2*c_a
    
    let x10 =  w2*c_a + h2*s_a
    let y10 =  w2*s_a - h2*c_a
    
    let x01 = -w2*c_a - h2*s_a
    let y01 = -w2*s_a + h2*c_a
    
    let x11 = w2*c_a - h2*s_a
    let y11 = w2*s_a + h2*c_a
    
    return (min(x00,min(x10,min(x01,x11))),
            min(y00,min(y10,min(y01,y11))),
            max(x00,max(x10,max(x01,x11))),
            max(y00,max(y10,max(y01,y11)))
    )
    
}
func fillBufferColor(destinationFrame: CVPixelBuffer?, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 ){
    if let destination = destinationFrame {
        CVPixelBufferLockBaseAddress(destination, CVPixelBufferLockFlags(rawValue: 0))
        
        let  destHeight = CVPixelBufferGetHeight(destination)
        let rowbytes = CVPixelBufferGetBytesPerRow(destination)
        let baseAddress = CVPixelBufferGetBaseAddress(destination)
        let b = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        let end: Int = destHeight * rowbytes
        for tt in stride(from: Int(0), to: end, by: Int(4)){
            b[tt] = red;  b[tt+1] = green;   b[tt+2] = blue;   b[tt+3] = alpha
        }
        CVPixelBufferUnlockBaseAddress(destination, CVPixelBufferLockFlags(rawValue: 0))
    }
}
func testBufferProcess( destinationFrame: CVPixelBuffer?, time: Double) {
    if let destination = destinationFrame {
        CVPixelBufferLockBaseAddress(destination, CVPixelBufferLockFlags(rawValue: 0))
        
        let destWidth = CVPixelBufferGetWidth(destination)
        let  destHeight = CVPixelBufferGetHeight(destination)
        let rowbytes = CVPixelBufferGetBytesPerRow(destination)
        let baseAddress = CVPixelBufferGetBaseAddress(destination)
        let b = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        for j in 0..<destHeight {
            let jj = j * rowbytes
            let J: Int = ((j+Int(time*50)) / 40) % 2
            for i in 0..<destWidth {
                var I: Int = ((i+Int(time*50)) / 40) % 2
                if J == 1 {
                    I = 1 - I
                }
                let color:UInt8 = (I==1) ? 255 : 0
                let tt = i*4 + jj
                b[tt] = 255
                b[tt+1] = color
                b[tt+2] = 0
                b[tt+3] = 255
            }
        }//j
        
        CVPixelBufferUnlockBaseAddress(destination, CVPixelBufferLockFlags(rawValue: 0))
    }
}
class CustomOverlayInstruction: NSObject ,  AVVideoCompositionInstructionProtocol{
    
        //the 5 variables below are required to implement the class
    var timeRange: CMTimeRange
        //describes the duration that the given intructions are used
    var enablePostProcessing: Bool = true
        // this is if you are also working with Core Animation as well
    var containsTweening: Bool = false
        // to learn more about this i reccomend just looking it up but for now
        //you can make it false
    var requiredSourceTrackIDs: [NSValue]?
        //if there are any specific id you are requiring for your asset tracks
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
        // if a trackId is in the passthroughTrackId then the for duration that it is available,
        //the compositor wont be run
    
    init(timerange:CMTimeRange , rotateSecondAsset: Bool){
        self.timeRange = timerange
    }
    
}
final class CustomRuntimeVideoCompositionLayerInstruction: AVMutableVideoCompositionLayerInstruction /*, NSCopying*/ {
    convenience init(_ with: CustomRuntimeVideoCompositionLayerInstruction){
        self.init()
        self.trackID = with.trackID
    }
    override func copy(with zone: NSZone? = nil) -> Any {
        return type(of: self).init(self)
    }
}

func makeCVBufferSameSize(src: CVPixelBuffer, exm: CVPixelBuffer, level: Float) -> CVPixelBuffer? {
    let dstWidth = CVPixelBufferGetWidth(exm)
    let dstHeight = CVPixelBufferGetHeight(exm)
    return resizePixelBufferMy(src, width: dstWidth, height: dstHeight, level: level)
}


func export(asset: AVAsset, outputUrl: URL, videoComposition: AVVideoComposition, audioMix: AVMutableAudioMix) {
    
    let presets = AVAssetExportSession.exportPresets(compatibleWith: asset)
    presets.forEach { pres in
        AVAssetExportSession.determineCompatibility(ofExportPreset: pres, with: asset, outputFileType: .mov) { res in
            if res {
                print("Compatible preset: <\(pres)>")
            }
        }
    }
    print("Compatible presets: <\(presets)>")
    
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else {
   //guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
    //guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
        print("Couldn't create AVAssetExportSession.")
        return
    }
    exportSession.audioMix = audioMix
    exportSession.outputURL = outputUrl
    exportSession.videoComposition = videoComposition
    exportSession.outputFileType = .mov
    exportSession.shouldOptimizeForNetworkUse = true
    
    exportSession.exportAsynchronously {
        switch exportSession.status {
            case .cancelled:
                print("CANCELED")
            case .exporting:
                print("EXPORTING")
            case .completed:
                print("COMPLETED")
                print("outputUrl = \(outputUrl)")
                
                //save in library
               /* UISaveVideoAtPathToSavedPhotosAlbum(
                    outputUrl.path,
                    nil,
                    nil,//#selector(self.alert(_:didFinishSavingWithError:contextInfo:)),
                    nil)
                */
            case .failed:
                print("ERROR", String(describing: exportSession.error?.localizedDescription))
                print("ERROR", String(describing: exportSession.error))
                print("Failed to export. Reason: \(exportSession.error as NSError? ?? NSError())")
                
            case .unknown:
                print("UNKNOWN")
            case .waiting:
                print("WAITING")
            @unknown default:
                break
        }
    }
}
