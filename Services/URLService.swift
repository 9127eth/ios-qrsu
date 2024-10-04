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
    
    func generateQRCode(for url: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(url.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return nil
    }
    
    private func generateShortCode() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}