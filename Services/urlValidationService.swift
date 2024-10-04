import Foundation

class URLValidationService {
    private let webRiskAPIKey: String
    
    init() {
        guard let apiKey = ProcessInfo.processInfo.environment["GOOGLE_WEB_RISK_API_KEY"] else {
            fatalError("Missing Web Risk API key in environment variables")
        }
        self.webRiskAPIKey = apiKey
    }
    
    func validateURL(_ url: String) async -> (isValid: Bool, isSafe: Bool) {
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return (false, false)
        }
        
        let webRiskURL = "https://webrisk.googleapis.com/v1/uris:search?key=\(webRiskAPIKey)&uri=\(encodedURL)"
        
        guard let url = URL(string: webRiskURL) else {
            return (false, false)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WebRiskResponse.self, from: data)
            let isSafe = response.threat == nil
            return (true, isSafe)
        } catch {
            print("Error validating URL: \(error)")
            return (false, false)
        }
    }
}

struct WebRiskResponse: Codable {
    let threat: Threat?
}

struct Threat: Codable {
    let type: String
}