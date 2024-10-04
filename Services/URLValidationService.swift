import Foundation
import UIKit

class URLValidationService {
    private let webRiskAPIKey: String
    
    init() {
        // Retrieve the API key from the configuration
        webRiskAPIKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_WEB_RISK_API_KEY") as? String ?? ""
    }
    
    func validateURL(_ urlString: String) async -> (isValid: Bool, isSafe: Bool) {
        guard let url = URL(string: urlString) else {
            return (false, false)
        }
        
        // Basic URL validation
        let isValid = UIApplication.shared.canOpenURL(url)
        
        // Check if the URL is safe using Google Web Risk API
        let isSafe = await checkURLSafety(urlString)
        
        return (isValid, isSafe)
    }
    
    private func checkURLSafety(_ urlString: String) async -> Bool {
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://webrisk.googleapis.com/v1/uris:search?key=\(webRiskAPIKey)&uri=\(encodedURL)") else {
            return false
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WebRiskResponse.self, from: data)
            return response.threat.isEmpty
        } catch {
            print("Error checking URL safety: \(error)")
            return false
        }
    }
}

struct WebRiskResponse: Codable {
    let threat: [String]
}
