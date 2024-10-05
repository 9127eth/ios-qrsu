//
//  ContentView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    @State private var url: String = ""
    @State private var showQRCode: Bool = false
    @State private var showShortURL: Bool = false
    @State private var qrCodeImage: UIImage? = nil
    @State private var shortURL: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String? = nil
    @State private var showInvalidExtensionAlert = false
    @State private var isCopied: Bool = false
    
    private let urlService = URLService.shared
    private let urlValidationService = URLValidationService()
    
    private let containerWidth: CGFloat = 300 // Adjust this value as needed
    
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
        .alert("Invalid Domain Extension", isPresented: $showInvalidExtensionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed Anyway") {
                Task {
                    await generateQRCode()
                }
            }
        } message: {
            Text("The domain extension you entered is not recognized. Do you want to proceed anyway?")
        }
    }
    
    func headerView() -> some View {
        VStack {
            Text("The best QR Code &")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Short URL generator ever.")
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
                .placeholder(when: url.isEmpty) {
                    Text("https://example.com").foregroundColor(.gray)
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(url.isEmpty ? Color.clear : Color.black, lineWidth: 2)
                )
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    func actionButtonsView() -> some View {
        HStack(spacing: 10) {
            Button("Get QR Code") {
                Task {
                    await generateQRCode()
                }
            }
            .buttonStyle(BlackButtonStyle())
            .disabled(url.isEmpty || isValidating)
            
            Button("Get Short URL") {
                Task {
                    await generateShortURL()
                }
            }
            .buttonStyle(WhiteButtonStyle())
            .disabled(url.isEmpty || isValidating)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Black button style
    struct BlackButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .fontWeight(.bold)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(configuration.isPressed ? Color.gray : Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
    
    // White button style
    struct WhiteButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .fontWeight(.bold)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(configuration.isPressed ? Color.gray.opacity(0.2) : Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
    
    func qrCodeView() -> some View {
        VStack(spacing: 20) {
            if let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                Text("QR Code")
                    .frame(width: 200, height: 200)
                    .background(Color.gray.opacity(0.2))
            }
            
            VStack(spacing: 15) {
                HStack {
                    Text("Format:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Picker("Format", selection: .constant("png")) {
                        Text("PNG").tag("png")
                        Text("JPEG").tag("jpeg")
                        Text("SVG").tag("svg")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Toggle(isOn: .constant(false)) {
                    Text("Transparent Background")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            Button(action: {
                if let qrImage = qrCodeImage {
                    let activityViewController = UIActivityViewController(activityItems: [qrImage], applicationActivities: nil)
                    UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .frame(width: 150) // Adjust this width to match the "Get QR Code" button
        }
        .frame(width: containerWidth)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    func shortURLView() -> some View {
        VStack(alignment: .leading) {
            Text("Short URL:")
                .font(.headline)
            
            HStack {
                Text(shortURL)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Button(action: {
                    UIPasteboard.general.string = shortURL
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    Text(isCopied ? "Copied!" : "Copy")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(isCopied ? Color.green : Color.black)
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
        .frame(width: containerWidth)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    func generateQRCode() async {
        await validateAndProcess {
            let formattedURL = url.lowercased().hasPrefix("http") ? url : "https://" + url
            qrCodeImage = urlService.generateQRCode(for: formattedURL, size: CGSize(width: 1024, height: 1024))
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
        
        let (isValid, isSafe, hasValidExtension) = await urlValidationService.validateURL(url)
        
        if !isValid {
            validationError = "Invalid URL. Please enter a valid URL."
        } else if !isSafe {
            validationError = "This URL may be unsafe. Please try a different URL."
        } else if !hasValidExtension {
            // Show an alert to the user
            await MainActor.run {
                showInvalidExtensionAlert = true
            }
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
        .foregroundColor(.black)
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

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}