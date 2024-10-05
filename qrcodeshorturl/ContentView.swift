//
//  ContentView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import SwiftUI
import CoreData
import UIKit
import WebKit
import Photos
import PhotosUI

struct ContentView: View {
    @State private var url: String = ""
    @State private var showQRCode: Bool = false
    @State private var showShortURL: Bool = false
    @State private var qrCodeImage: UIImage? = nil
    @State private var shortURL: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String? = nil
    @State private var showInvalidExtensionAlert = false
    @State private var selectedFormat: String = "png"
    @State private var transparentBackground: Bool = false
    @State private var svgData: String? = nil
    @FocusState private var isInputFocused: Bool // Use @FocusState for input focus

    @State private var keyboardHeight: CGFloat = 0

    private let urlService = URLService.shared
    private let urlValidationService = URLValidationService()

    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Dismiss the keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                // Header View with animation
                if !isInputFocused {
                    headerView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: isInputFocused)
                }

                // Input Field
                urlInputView()
                    .padding(.horizontal)

                // Action Buttons
                actionButtonsView()

                // Validation Error
                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                // QR Code and Short URL Views
                ScrollView {
                    VStack(spacing: 20) {
                        if showQRCode {
                            qrCodeView()
                        }

                        if showShortURL {
                            shortURLView()
                        }

                        // Clear Button (only visible when QR code or short URL is present)
                        if showQRCode || showShortURL {
                            clearButtonView()
                        }
                    }
                    .padding()
                }
            }
            .padding(.top, isInputFocused ? 0 : 60) // Adjust padding based on focus
            .animation(.easeInOut(duration: 0.3), value: isInputFocused)
        }
        .alert("Invalid Domain Extension", isPresented: $showInvalidExtensionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed Anyway") {
                Task {
                    if showQRCode {
                        await generateQRCodeImage(for: url)
                    } else {
                        await generateShortURLString(for: url)
                    }
                }
            }
        } message: {
            Text("The domain extension you entered is not recognized. Do you want to proceed anyway?")
        }
        .ignoresSafeArea(.keyboard) // Ignore the keyboard safe area
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let keyboardRectangle = keyboardFrame.cgRectValue
                keyboardHeight = keyboardRectangle.height
            }
        }
        .padding(.bottom, keyboardHeight) // Add padding to the bottom of the view
    }

    // MARK: - Views

    func headerView() -> some View {
        VStack {
            Text("The best QR Code &")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Short URL generator ever.")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Generate a QR code and a short URL for any website.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    func urlInputView() -> some View {
        VStack(alignment: .leading) {
            Text("Enter a URL")
                .font(.headline)

            TextField("https://example.com", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isInputFocused) // Bind to focus state
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.vertical, 8)
                .padding(.horizontal, 4) // Add horizontal padding inside the border
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(url.isEmpty ? Color.clear : Color.black, lineWidth: 2)
                        .padding(.horizontal, -4) // Adjust the border to account for the padding
                )
        }
        .padding(.horizontal, 20) // Add padding to the entire VStack
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
        .padding(.horizontal)
    }

    // MARK: - QR Code View

    func qrCodeView() -> some View {
        VStack(spacing: 20) {
            if let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            } else {
                Text("QR Code")
                    .frame(width: 200, height: 200)
                    .background(Color.gray.opacity(0.2))
            }

            VStack(spacing: 15) {
                HStack {
                    Text("Format:")
                        .font(.subheadline)
                        .foregroundColor(.black)
                    Picker("Format", selection: $selectedFormat) {
                        Text("PNG").tag("png")
                        Text("JPEG").tag("jpeg")
                        Text("SVG").tag("svg")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedFormat) { newValue in
                        if newValue == "jpeg" {
                            transparentBackground = false
                        }
                        Task {
                            await generateQRCode()
                        }
                    }
                }

                Toggle(isOn: $transparentBackground) {
                    Text("Transparent Background")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(selectedFormat == "jpeg")
                .onChange(of: transparentBackground) { _ in
                    if transparentBackground && selectedFormat == "jpeg" {
                        selectedFormat = "png"
                    }
                    Task {
                        await generateQRCode()
                    }
                }
            }

            Button(action: {
                shareQRCode()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .frame(width: 150)  // Keep the width the same
                .padding(.vertical, 12)  // Keep the height the same
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)  // This will allow the button to be centered
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Short URL View

    func shortURLView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    shareShortURL()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }

    // MARK: - Clear Button View

    func clearButtonView() -> some View {
        Button(action: {
            clearAll()
        }) {
            Text("Clear")
                .foregroundColor(.black)
                .padding(.vertical, 10)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Views and Styles

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

    // MARK: - Functions

    func clearAll() {
        url = ""
        showQRCode = false
        showShortURL = false
        qrCodeImage = nil
        shortURL = ""
        validationError = nil
        // Dismiss the keyboard if it's open
        isInputFocused = false
    }

    func generateQRCode() async {
        isValidating = true
        defer { isValidating = false }

        let urlWithScheme = url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") ? url : "https://" + url

        let (isValid, isSafe, hasValidExtension) = await urlValidationService.validateURL(urlWithScheme)
        if !isValid {
            validationError = "Invalid URL"
            return
        }
        if !isSafe {
            validationError = "URL may not be safe"
            return
        }
        if !hasValidExtension {
            await MainActor.run {
                showInvalidExtensionAlert = true
            }
            return
        }

        await generateQRCodeImage(for: urlWithScheme)
    }

    func generateQRCodeImage(for urlString: String) {
        // Always generate PNG for display
        qrCodeImage = urlService.generateQRCode(for: urlString, size: CGSize(width: 200, height: 200), format: "png", transparent: transparentBackground)

        // Generate SVG data if selected
        if selectedFormat == "svg" {
            svgData = urlService.generateSVGQRCode(for: urlString, size: 200)
        } else {
            svgData = nil
        }

        showQRCode = true
        validationError = nil
    }

    func generateShortURL() async {
        isValidating = true
        defer { isValidating = false }

        let urlWithScheme = url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") ? url : "https://" + url

        let (isValid, isSafe, hasValidExtension) = await urlValidationService.validateURL(urlWithScheme)
        if !isValid {
            validationError = "Invalid URL"
            return
        }
        if !isSafe {
            validationError = "URL may not be safe"
            return
        }
        if !hasValidExtension {
            await MainActor.run {
                showInvalidExtensionAlert = true
            }
            return
        }

        await generateShortURLString(for: urlWithScheme)
    }

    func generateShortURLString(for urlString: String) async {
        do {
            shortURL = try await urlService.shortenURL(urlString)
            showShortURL = true
            validationError = nil
        } catch {
            validationError = "Error shortening URL: \(error.localizedDescription)"
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

    func shareQRCode() {
        guard let qrImage = qrCodeImage else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [qrImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }

    func saveQRCodeToPhotos() {
        guard let qrImage = qrCodeImage else {
            print("No QR code image to save")
            return
        }

        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: qrImage)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("QR code saved to photos")
                            // You can show a success message to the user here
                        } else if let error = error {
                            print("Error saving QR code: \(error.localizedDescription)")
                            // You can show an error message to the user here
                        }
                    }
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    print("Photo library access denied")
                    // You can show an alert to the user here, explaining that they need to grant access in Settings
                }
            case .notDetermined:
                // This case should not be reached as we're inside the callback of requestAuthorization
                break
            @unknown default:
                break
            }
        }
    }

    // Add this function to handle sharing the short URL
    func shareShortURL() {
        let activityViewController = UIActivityViewController(
            activityItems: [shortURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Date formatter (if needed)
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

// Custom Placeholder View Modifier
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

// SVGView (if needed)
struct SVGView: UIViewRepresentable {
    let svgString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let htmlString = """
        <html>
        <body style="margin: 0; padding: 0;">
            \(svgString)
        </body>
        </html>
        """
        uiView.loadHTMLString(htmlString, baseURL: nil)
    }
}