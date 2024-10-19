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

struct ReadOnlyTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 16)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}

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
    @FocusState private var isInputFocused: Bool
    @GestureState private var dragOffset = CGSize.zero

    @State private var keyboardHeight: CGFloat = 0
    @State private var isGenerating: Bool = false
    @State private var hideHeader: Bool = false
    @State private var pendingAction: (() async -> Void)?

    @State private var copySuccess: Bool = false

    private let urlService = URLService.shared
    private let urlValidationService = URLValidationService()

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    if !hideHeader {
                        headerView()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    urlInputView()
                        .padding(.horizontal)
                    
                    actionButtonsView()
                    
                    if let error = validationError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    if showQRCode {
                        qrCodeView()
                    }
                    
                    if showShortURL {
                        shortURLView()
                    }
                    
                    if showQRCode || showShortURL {
                        clearButtonView()
                    }
                }
                .padding(.top, hideHeader ? 0 : 60)
                .padding(.bottom)
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if value.translation.height > 0 && isInputFocused {
                            state = value.translation
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 50 {
                            isInputFocused = false
                        }
                    }
            )
        }
        .animation(.easeInOut(duration: 0.3), value: hideHeader)
        .onTapGesture {
            isInputFocused = false
        }
        .alert("Invalid Domain Extension", isPresented: $showInvalidExtensionAlert) {
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
            Button("Proceed Anyway") {
                Task {
                    if let action = pendingAction {
                        await action()
                        pendingAction = nil
                    }
                }
            }
        } message: {
            Text("The domain extension you entered is not recognized. Do you want to proceed anyway?")
        }
        NavigationLink("NFC Tools") {
            NFCWriteView(nfcReadResult: .constant(nil))
        }
        .foregroundColor(.blue)
        .padding(.top, 20)
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
                .focused($isInputFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(url.isEmpty ? Color.clear : Color.black, lineWidth: 2)
                        .padding(.horizontal, -4)
                )
                .foregroundColor(.primary)
                .accentColor(.primary)
                .modifier(PlaceholderStyle(showPlaceHolder: url.isEmpty, placeholder: "https://example.com"))
                .onSubmit {
                    Task {
                        hideHeader = true
                        await generateBoth()
                    }
                }
        }
        .padding(.horizontal, 20)
    }

    func actionButtonsView() -> some View {
        HStack(spacing: 10) {
            Button("Get QR Code") {
                Task {
                    hideHeader = true
                    await handleURLValidation { generateQRCode() }
                }
            }
            .buttonStyle(BlackButtonStyle())
            .disabled(url.isEmpty || isValidating)

            Button("Get Short URL") {
                Task {
                    hideHeader = true
                    await handleURLValidation { await generateShortURL() }
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
                .onChange(of: selectedFormat) { oldValue, newValue in
                    Task {
                        generateQRCode()
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
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1)
                )
            }
            .frame(maxWidth: 200) // Limit the width of the button
        }
        .padding()
    }

    // MARK: - Short URL View

    func shortURLView() -> some View {
        VStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Short URL:")
                    .font(.headline)

                HStack {
                    ReadOnlyTextView(text: shortURL)
                        .frame(height: 40)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                    Button(action: {
                        UIPasteboard.general.string = shortURL
                        copySuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copySuccess = false
                        }
                    }) {
                        ZStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.black)
                                .opacity(copySuccess ? 0 : 1)
                            Text("✓")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.green)
                                .opacity(copySuccess ? 1 : 0)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            HStack(spacing: 20) {
                Button(action: {
                    shareShortURL()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(height: 44)

                Button(action: {
                    generateQRCodeForShortURL()
                }) {
                    Image(systemName: "qrcode")
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
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

    // Add this struct at the bottom of your ContentView struct
    struct PlaceholderStyle: ViewModifier {
        var showPlaceHolder: Bool
        var placeholder: String

        func body(content: Content) -> some View {
            ZStack(alignment: .leading) {
                if showPlaceHolder {
                    Text(placeholder)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                }
                content
            }
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
        hideHeader = false  // Show the header again when clearing
        isInputFocused = false
    }

    func handleURLValidation(action: @escaping () async -> Void) async {
        await MainActor.run {
            isValidating = true
            validationError = nil
            isInputFocused = false  // Add this line to dismiss the keyboard
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }

        let urlWithScheme = url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") ? url : "https://" + url

        let (isValid, isSafe, hasValidExtension) = await urlValidationService.validateURL(urlWithScheme)
        
        await MainActor.run {
            if !isValid {
                validationError = "Invalid URL"
                return
            }
            if !isSafe {
                validationError = "URL may not be safe"
                return
            }
            if !hasValidExtension {
                pendingAction = action
                showInvalidExtensionAlert = true
                return
            }
            
            Task {
                await action()
            }
        }
    }

    func generateQRCode() {
        generateQRCodeImage(for: url, format: selectedFormat)
    }

    func generateQRCodeImage(for urlString: String, format: String) {
        if let qrCodeData = urlService.generateQRCode(for: urlString, size: CGSize(width: 200, height: 200), format: format) {
            switch format {
            case "png", "jpeg":
                if let data = qrCodeData as? Data, let image = UIImage(data: data) {
                    qrCodeImage = image
                }
            case "svg":
                if let svgString = qrCodeData as? String {
                    svgData = svgString
                }
            default:
                break
            }
        }

        showQRCode = true
        validationError = nil
        
        if urlString.starts(with: "https://\(urlService.shortURLDomain)") {
            url = urlString
        }
    }

    func generateShortURL() async {
        await generateShortURLString(for: url)
    }

    func generateShortURLString(for urlString: String) async {
        do {
            let (_, isSafe, _) = await urlValidationService.validateURL(urlString)
            shortURL = try await urlService.shortenURL(urlString, isSafe: isSafe)
            showShortURL = true
            validationError = nil
        } catch {
            validationError = "Error shortening URL: \(error.localizedDescription)"
        }
    }

    func shareQRCode() {
        var itemToShare: Any

        switch selectedFormat {
        case "svg":
            if let svgData = svgData {
                itemToShare = svgData
            } else {
                print("No SVG data to share")
                return
            }
        case "jpeg", "png":
            if let qrImage = qrCodeImage, let imageData = selectedFormat == "png" ? qrImage.pngData() : qrImage.jpegData(compressionQuality: 0.8) {
                itemToShare = imageData
            } else {
                print("No QR code image data to share")
                return
            }
        default:
            print("Unsupported format")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [itemToShare],
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

    func generateQRCodeForShortURL() {
        Task {
            generateQRCodeImage(for: shortURL, format: selectedFormat)
            showQRCode = true
        }
    }

    func generateBoth() async {
        await handleURLValidation {
            generateQRCodeImage(for: url, format: selectedFormat)
            await generateShortURLString(for: url)
            
            // Ensure input is not focused
            await MainActor.run {
                isInputFocused = false  // Ensure keyboard is dismissed
            }
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
