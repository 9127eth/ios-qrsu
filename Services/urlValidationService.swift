import Foundation
import DomainParser

class URLValidationService {
    private let webRiskAPIKey: String
    private let domainParser: DomainParser

    init() {
        guard let apiKey = ProcessInfo.processInfo.environment["GOOGLE_WEB_RISK_API_KEY"] else {
            fatalError("Missing Web Risk API key in environment variables")
        }
        self.webRiskAPIKey = apiKey
        self.domainParser = try! DomainParser()
    }
    
    func validateURL(_ url: String) async -> (isValid: Bool, isSafe: Bool, hasValidExtension: Bool) {
        // Prepend "https://" if the URL doesn't start with a scheme
        let urlWithScheme = url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") ? url : "https://" + url
        
        // Check if the URL is valid
        guard let url = URL(string: urlWithScheme),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host,
              !host.isEmpty else {
            return (false, false, false)
        }
        
        let hasValidExtension = isValidDomainExtension(urlWithScheme)

        // If the URL is valid, check its safety
        let (_, isSafe) = await checkURLSafety(urlWithScheme)

        return (true, isSafe, hasValidExtension)
    }
    
    private func checkURLSafety(_ url: String) async -> (isValid: Bool, isSafe: Bool) {
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return (true, false)
        }
        
        let threatTypes = ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"].joined(separator: "&threatTypes=")
        let webRiskURL = "https://webrisk.googleapis.com/v1/uris:search?key=\(webRiskAPIKey)&uri=\(encodedURL)&threatTypes=\(threatTypes)"
        
        guard let url = URL(string: webRiskURL) else {
            return (true, false)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WebRiskResponse.self, from: data)
            if let error = response.error {
                print("Web Risk API Error: \(error.message)")
                return (true, false) // Assume unsafe if there's an API error
            }
            let isSafe = response.threat == nil
            return (true, isSafe)
        } catch {
            print("Error validating URL safety: \(error)")
            return (true, false) // Assume unsafe if there's an error
        }
    }
    
    func isValidDomainExtension(_ url: String) -> Bool {
        guard let host = URL(string: url)?.host else {
            return false
        }

        let parsed = domainParser.parse(host: host)
        if let publicSuffix = parsed?.publicSuffix {
            return !publicSuffix.isEmpty
        }
        return false
    }
}

struct WebRiskResponse: Codable {
    let threat: Threat?
    let error: WebRiskError?
}

struct Threat: Codable {
    let type: String
}

struct WebRiskError: Codable {
    let code: Int
    let message: String
    let status: String
}
