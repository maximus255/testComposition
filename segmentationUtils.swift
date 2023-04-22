//
//  segmentationUtils.swift
//  TestSegmentation
//
//  Created by admin on 17.04.2023.
//

import Foundation
import UIKit
import CoreML
import Vision

class performSeqmentation {
    var kUseRVM = 2
    var request2: VNCoreMLRequest?
    var visionModel2: VNCoreMLModel?
    var request0: VNCoreMLRequest?
    var visionModel0: VNCoreMLModel?
    var resultBuffer: CVPixelBuffer? = nil
    
    lazy var model: segmentation_8bit  = {
        do {
            return try segmentation_8bit(configuration: MLModelConfiguration())
        }catch {
            fatalError("Failed to load ML model.")
        }
    }()
    
    lazy var model_rvm_1080_s04: model_rvm_1080_04  = {
        do {
            return try model_rvm_1080_04(configuration: MLModelConfiguration())
        }catch {
            fatalError("Failed to load RVM model.")
        }
    }()
    
    init (){
        if let visionModel = try? VNCoreMLModel(for: model.model ) {
            self.visionModel0 = visionModel
            request0 = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request0?.imageCropAndScaleOption = .scaleFill //.centerCrop
        } else {
            fatalError()
        }
        
        if let visionModel = try? VNCoreMLModel(for: model_rvm_1080_s04.model ) {
            self.visionModel2 = visionModel
            request2 = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request2?.imageCropAndScaleOption = .scaleFill //.centerCrop
        } else {
            fatalError()
        }
    }
    
    func processURL(url: URL, net: Int = 2) ->CVPixelBuffer? {
        predict(with: url, net: net)
        print("after call predict")
        return resultBuffer
    }
    
    func predict(with url: URL, net: Int) {
        kUseRVM = net
        guard let request = (net == 2) ? request2 : request0  else { fatalError() }
        let handler = VNImageRequestHandler(url: url, options: [:])
        try? handler.perform([request])
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        print("visionRequestDidComplete>>>>")
        resultBuffer = nil
        if kUseRVM > 0 {
            if let observations = request.results
                , let pha = observations[3] as? VNPixelBufferObservation {
                
                resultBuffer = pha.pixelBuffer
                
            }
        }
        else {
            if let observations = request.results as? [VNPixelBufferObservation] {
                resultBuffer = observations.first?.pixelBuffer
            }
        }
    }
}

func detectVisionContours(from sourceImage: UIImage) -> CGPath? {
    let inputImage = CIImage.init(cgImage: sourceImage.cgImage!)
    let contourRequest = VNDetectContoursRequest()
    contourRequest.revision = VNDetectContourRequestRevision1
    contourRequest.contrastAdjustment = 1.0
    contourRequest.maximumImageDimension = 512
    let requestHandler = VNImageRequestHandler(ciImage: inputImage, options: [:])
    try! requestHandler.perform([contourRequest])
    if let contoursObservation = contourRequest.results?.first {
        let path = contoursObservation.normalizedPath
        let size = sourceImage.size
        let scW: CGFloat = (size.width ) / path.boundingBox.width
        let scH: CGFloat = (size.height) / path.boundingBox.height
        var transform = CGAffineTransform.identity
            .scaledBy(x: scW, y: -scH)
            .translatedBy(x: 0.0, y: -path.boundingBox.height)
        return path.copy(using: &transform)
    }
    return nil
}

func renderPath(path: CGPath, size: CGSize, lineWidth: CGFloat, color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    let renderedImage = renderer.image { (context) in
        let renderingContext = context.cgContext
        renderingContext.setLineWidth(lineWidth)
        renderingContext.setStrokeColor(color.cgColor)
        renderingContext.addPath(path)
        renderingContext.strokePath()
    }
    return renderedImage
}
