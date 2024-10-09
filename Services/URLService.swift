//
//  URLService.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import Foundation
import FirebaseFirestore
import CoreImage.CIFilterBuiltins
import UIKit

class URLService {
    static let shared = URLService()
    private let db = Firestore.firestore()
    let shortURLDomain: String
    
    init() {
        self.shortURLDomain = ProcessInfo.processInfo.environment["SHORT_URL_DOMAIN"] ?? "qrsu.io"
    }
    
    func shortenURL(_ longURL: String) async throws -> String {
        let shortCode = generateShortCode()
        let data: [String: Any] = [
            "longURL": longURL,
            "shortCode": shortCode,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("urls").document(shortCode).setData(data)
        return "https://\(shortURLDomain)/\(shortCode)"
    }
    
    func generateQRCode(for url: String, size: CGSize, format: String) -> Any? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        let data = url.data(using: .ascii, allowLossyConversion: false)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: size.width / ciImage.extent.size.width, y: size.height / ciImage.extent.size.height)
        let scaledCIImage = ciImage.transformed(by: transform)
        
        switch format.lowercased() {
        case "png":
            return generatePNGQRCode(from: scaledCIImage, size: size)
        case "jpeg":
            return generateJPEGQRCode(from: scaledCIImage, size: size)
        case "svg":
            return generateSVGQRCode(from: scaledCIImage, size: size)
        default:
            return nil
        }
    }
    
    private func generatePNGQRCode(from ciImage: CIImage, size: CGSize) -> Data? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        let imageData = renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            context.cgContext.interpolationQuality = .none
            context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        
        return imageData
    }
    
    private func generateJPEGQRCode(from ciImage: CIImage, size: CGSize) -> Data? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        let imageData = renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            context.cgContext.interpolationQuality = .none
            context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        
        return imageData
    }
    
    private func generateSVGQRCode(from ciImage: CIImage, size: CGSize) -> String {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return "" }
        
        let width = Int(size.width)
        let height = Int(size.height)
        
        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) \(height)" width="\(width)" height="\(height)">
        <rect width="100%" height="100%" fill="white"/>
        """
        
        for y in 0..<cgImage.height {
            for x in 0..<cgImage.width {
                if let pixel = cgImage.pixel(at: CGPoint(x: x, y: y)), pixel.isBlack {
                    let rectX = x * Int(size.width) / cgImage.width
                    let rectY = y * Int(size.height) / cgImage.height
                    let rectWidth = Int(size.width) / cgImage.width
                    let rectHeight = Int(size.height) / cgImage.height
                    svg += "<rect x='\(rectX)' y='\(rectY)' width='\(rectWidth)' height='\(rectHeight)' fill='black'/>"
                }
            }
        }
        
        svg += "</svg>"
        return svg
    }
    
    private func generateShortCode() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}

extension CGImage {
    func pixel(at point: CGPoint) -> Pixel? {
        guard let pixelData = dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return nil }
        
        let pixelInfo = (Int(point.y) * bytesPerRow) + (Int(point.x) * bitsPerPixel / 8)
        let r = data[pixelInfo]
        let g = data[pixelInfo + 1]
        let b = data[pixelInfo + 2]
        let a = data[pixelInfo + 3]
        
        return Pixel(r: r, g: g, b: b, a: a)
    }
}

struct Pixel {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
    
    var isBlack: Bool {
        return r == 0 && g == 0 && b == 0
    }
}