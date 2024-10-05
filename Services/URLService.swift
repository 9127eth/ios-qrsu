//
//  URLService.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import Foundation
import FirebaseFirestore
import CoreImage.CIFilterBuiltins

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
    
    func generateQRCode(for url: String, size: CGSize, format: String, transparent: Bool) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        let data = url.data(using: .ascii, allowLossyConversion: false)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: size.width / ciImage.extent.size.width, y: size.height / ciImage.extent.size.height)
        let scaledCIImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }
        
        let format = format.lowercased()
        let alphaInfo: CGImageAlphaInfo = transparent ? .premultipliedLast : .noneSkipLast
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let bitmapContext = CGContext(data: nil,
                                            width: Int(size.width),
                                            height: Int(size.height),
                                            bitsPerComponent: 8,
                                            bytesPerRow: 0,
                                            space: colorSpace,
                                            bitmapInfo: alphaInfo.rawValue) else { return nil }
        
        bitmapContext.interpolationQuality = .none
        bitmapContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        guard let outputCGImage = bitmapContext.makeImage() else { return nil }
        
        let outputImage = UIImage(cgImage: outputCGImage)
        
        if format == "svg" {
            // SVG generation is not natively supported in iOS
            // You would need to use a third-party library or implement custom SVG generation
            print("SVG format is not supported in this implementation")
            return outputImage
        }
        
        return outputImage
    }
    
    func generateSVGQRCode(for url: String, size: CGFloat) -> String? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = url.data(using: .ascii, allowLossyConversion: false)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        let svgSize = Int(size)
        let scale = svgSize / Int(ciImage.extent.width)
        
        var svg = """
        <svg width="\(svgSize)" height="\(svgSize)" viewBox="0 0 \(svgSize) \(svgSize)" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="white"/>
        """
        
        for y in 0..<Int(ciImage.extent.height) {
            for x in 0..<Int(ciImage.extent.width) {
                let pixelData = cgImage.dataProvider!.data!
                let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
                let pixelInfo: Int = ((Int(cgImage.width) * y) + x) * 4
                
                if data[pixelInfo] == 0 {
                    let rectX = x * scale
                    let rectY = y * scale
                    svg += "<rect x='\(rectX)' y='\(rectY)' width='\(scale)' height='\(scale)' fill='black'/>"
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