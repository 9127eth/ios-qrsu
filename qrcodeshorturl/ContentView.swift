//
//  ContentView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var url: String = ""
    @State private var showQRCode: Bool = false
    @State private var showShortURL: Bool = false
    @State private var qrCodeImage: UIImage? = nil
    @State private var shortURL: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String? = nil
    
    private let urlService = URLService.shared
    private let urlValidationService = URLValidationService()
    
    var body: some View {
        VStack(spacing: 20) {
            headerView()
            urlInputView()
            actionButtonsView()
            
            if showQRCode {
                qrCodeView()
            }
            
            if showShortURL {
                shortURLView()
            }
            
            clearButton()
        }
        .padding()
    }
    
    func headerView() -> some View {
        VStack {
            Text("The best QR Code/Short")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("URL generator ever.")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Generate a QR code and a short URL for any website.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .multilineTextAlignment(.center)
    }
    
    func urlInputView() -> some View {
        VStack(alignment: .leading) {
            Text("Enter a URL")
                .font(.headline)
            TextField("https://example.com", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    func actionButtonsView() -> some View {
        HStack {
            Button("Get QR Code") {
                Task {
                    await generateQRCode()
                }
            }
            .disabled(url.isEmpty || isValidating)
            
            Button("Get Short URL") {
                Task {
                    await generateShortURL()
                }
            }
            .disabled(url.isEmpty || isValidating)
        }
    }
    
    func qrCodeView() -> some View {
        VStack {
            if let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            } else {
                Text("QR Code")
                    .frame(width: 200, height: 200)
                    .background(Color.gray.opacity(0.2))
            }
            
            HStack {
                Picker("Format", selection: .constant("png")) {
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpeg")
                    Text("SVG").tag("svg")
                }
                .pickerStyle(MenuPickerStyle())
                
                Toggle("no background", isOn: .constant(false))
            }
            
            Button("Download") {
                // Implement download logic
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    func shortURLView() -> some View {
        VStack(alignment: .leading) {
            Text("Short URL:")
                .font(.headline)
            
            HStack {
                Text(shortURL)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                Button(action: {
                    // Implement copy logic
                }) {
                    Text("Copy")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    // Implement QR code generation for short URL
                }) {
                    Image(systemName: "qrcode")
                        .foregroundColor(.black)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    func generateQRCode() async {
        await validateAndProcess {
            qrCodeImage = urlService.generateQRCode(for: url)
            showQRCode = true
        }
    }
    
    func generateShortURL() async {
        await validateAndProcess { [self] in
            do {
                shortURL = try await urlService.shortenURL(url)
                showShortURL = true
            } catch {
                validationError = "Error shortening URL: \(error.localizedDescription)"
            }
        }
    }
    
    func validateAndProcess(action: @escaping () async -> Void) async {
        isValidating = true
        validationError = nil
        
        let (isValid, isSafe) = await urlValidationService.validateURL(url)
        
        if !isValid {
            validationError = "Invalid URL. Please enter a valid URL."
        } else if !isSafe {
            validationError = "This URL may be unsafe. Please try a different URL."
        } else {
            await action()
        }
        
        isValidating = false
    }
    
    func clearButton() -> some View {
        Button("Clear") {
            url = ""
            showQRCode = false
            showShortURL = false
            qrCodeImage = nil
            shortURL = ""
            validationError = nil
        }
        .foregroundColor(.blue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}