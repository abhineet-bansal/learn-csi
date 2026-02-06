//
//  ImageProcessingHelper.swift
//  BGRemover
//
//  Created by Abhineet Bansal on 27/1/2026.
//

import UIKit
import CoreImage

enum ImageProcessingHelper {
    
    /// Convert CVPixelBuffer to UIImage
    static func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation = .up) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    /// Convert UIImage to CVPixelBuffer
    static func uiImageToPixelBuffer(_ image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

        return buffer
    }
    
    /// Apply a mask to an image to remove the background
    static func applyMask(_ mask: UIImage, to original: UIImage) -> UIImage? {
        guard let originalCI = CIImage(image: original),
              let maskCI = CIImage(image: mask) else {
            return nil
        }

        let context = CIContext()

        // Resize mask to match original if needed
        let maskResized: CIImage
        if maskCI.extent.size != originalCI.extent.size {
            let scaleX = originalCI.extent.width / maskCI.extent.width
            let scaleY = originalCI.extent.height / maskCI.extent.height
            maskResized = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        } else {
            maskResized = maskCI
        }

        // Use CIBlendWithMask filter
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            return nil
        }

        filter.setValue(originalCI, forKey: kCIInputImageKey)
        filter.setValue(maskResized, forKey: kCIInputMaskImageKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
    }
    
    /// Extract grayscale pixel values from CGImage
    static func extractGrayscalePixels(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

}
