//
//  CVPixelBufferUtils.swift
//  TestSegmentation
//
//  Created by admin on 17.04.2023.
//

import Foundation
import CoreVideo
import UIKit
import Accelerate
import CoreImage

func buffer(from image: CIImage) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    
    guard (status == kCVReturnSuccess) else {
        return nil
    }
    
    return pixelBuffer
}
public func resizePixelBufferMy(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int, level: Float) -> CVPixelBuffer? {
    
    var newPixelBuffer: CVPixelBuffer? = nil
    
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_32BGRA , attrs, &newPixelBuffer)
    if status != kCVReturnSuccess {
        return nil
    }
    
    if let newPixelBuffer = newPixelBuffer {
    
        CVPixelBufferLockBaseAddress(newPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 1))
        
        let srcW = CVPixelBufferGetWidth(pixelBuffer)
        let srcH = CVPixelBufferGetHeight(pixelBuffer)
        let srcRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let srcPlanes = Int(srcRowBytes/srcW)
        let srcData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let dstData = CVPixelBufferGetBaseAddress(newPixelBuffer)
        let dstRowBytes = CVPixelBufferGetBytesPerRow(newPixelBuffer)
        //print("srcType = \(srcType)") // 'L008'
        
        let b1 = srcData!.assumingMemoryBound(to: UInt8.self)
        let b = dstData!.assumingMemoryBound(to: UInt8.self)
        
        let scaleX = Float(srcW)/Float(width);
        let scaleY = Float(srcH)/Float(height);
        
        for j in 0..<height {
            var J = Int(Float(j)*scaleY); if (J >= srcH) { J = srcH - 1 }
            let JJ = J * srcRowBytes; let jj = j * dstRowBytes
            for i in 0..<width {
                var I = Int(Float(i)*scaleX); if (I >= srcW) { I = srcW - 1 }
                let tt = i*4 + jj
                let tt1 = I*srcPlanes + JJ
                var cf = Float(b1[tt1])*level; if cf>255 {cf = 255}
                let c = UInt8(cf)
                
                b[tt] = c;
                b[tt+1] = c;
                b[tt+2] = c;
                b[tt+3] = c;
            }//for i
        }//for j
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 1))
        CVPixelBufferUnlockBaseAddress(newPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }//if newPixelBuffer
    return newPixelBuffer
}

extension CVPixelBuffer {
    public static func Create(cgImage image: CGImage) -> CVPixelBuffer? {
        let size = CGSize(width: image.width, height: image.height)
        let frameSize = size
        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        if status != kCVReturnSuccess {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

extension FileManager {
    static func removeFileIfExists(_ fileURL: URL) {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        }
}
