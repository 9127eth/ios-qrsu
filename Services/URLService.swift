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
    private let shortURLDomain: String
    
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
    
    func generateQRCode(for url: String, size: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage? {
        guard let data = url.data(using: .utf8) else { return nil }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // Highest error correction
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale the image to the full size
        let fullSizeImage = outputImage.transformed(by: CGAffineTransform(scaleX: size.width / outputImage.extent.width,
                                                                          y: size.height / outputImage.extent.height))
        
        // Create full-size UIImage
        guard let cgImage = context.createCGImage(fullSizeImage, from: fullSizeImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func generateShortCode() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}