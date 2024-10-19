//
//  NFCWriteView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/17/24.
//

import SwiftUI
import CoreNFC

struct NFCWriteView: View {
    @State private var selectedType: NFCContentType = .link
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var nfcWriter: NFCWriter?
    @State private var nfcSession: NFCNDEFReaderSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Select NFC Content Type")
                    .font(.headline)
                
                NFCTypeButton(type: .link, selectedType: $selectedType, label: "Link")
                    .frame(maxWidth: 300)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    NFCTypeButton(type: .text, selectedType: $selectedType, label: "Plain Text")
                    NFCTypeButton(type: .wifi, selectedType: $selectedType)
                    NFCTypeButton(type: .sms, selectedType: $selectedType, label: "SMS")
                    NFCTypeButton(type: .email, selectedType: $selectedType)
                }
                .frame(maxWidth: 300)
                
                Spacer()
                
                switch selectedType {
                case .link:
                    LinkInputView(writeAction: writeNFC)
                case .text:
                    TextInputView(writeAction: writeNFC)
                case .wifi:
                    WifiInputView(writeAction: writeNFC)
                case .sms:
                    SMSInputView(writeAction: writeNFC)
                case .email:
                    EmailInputView(writeAction: writeNFC)
                }
            }
            .padding()
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
        .navigationTitle("Write to NFC")
        .alert(isPresented: $showAlert) {
            Alert(title: Text("NFC Write"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func writeNFC(payload: NFCNDEFPayload?) {
        guard NFCNDEFReaderSession.readingAvailable else {
            alertMessage = "NFC is not available on this device"
            showAlert = true
            return
        }
        
        guard let payload = payload else {
            alertMessage = "Failed to create NFC payload"
            showAlert = true
            return
        }
        
        nfcWriter = NFCWriter(payload: payload, alertMessage: $alertMessage, showAlert: $showAlert)
        nfcSession = NFCNDEFReaderSession(delegate: nfcWriter!, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to write the data."
        nfcSession?.begin()
    }
}

struct NFCTypeButton: View {
    let type: NFCContentType
    @Binding var selectedType: NFCContentType
    var label: String?
    
    var body: some View {
        Button(action: { selectedType = type }) {
            Text(label ?? type.rawValue.capitalized)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedType == type ? Color.black : Color.white)
                .foregroundColor(selectedType == type ? Color.white : Color.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1)
                )
        }
    }
}

enum NFCContentType: String {
    case link, text, wifi, sms, email
}

// Common button modifier
extension View {
    func nfcWriteButtonStyle() -> some View {
        self.frame(height: 44) // Set a specific height
            .padding(.horizontal)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

struct LinkInputView: View {
    @State private var url = ""
    @State private var isValidating = false
    @State private var validationError: String? = nil
    @State private var showInvalidExtensionAlert = false
    let writeAction: (NFCNDEFPayload) -> Void
    
    private let urlValidationService = URLValidationService()
    
    var body: some View {
        VStack {
            TextField("Enter URL", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Write Link to NFC") {
                Task {
                    await validateAndWriteURL()
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
            .disabled(url.isEmpty || isValidating)
        }
        .padding(.bottom, 20)
        .alert("Invalid Domain Extension", isPresented: $showInvalidExtensionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed Anyway") {
                writeURLToNFC()
            }
        } message: {
            Text("The domain extension you entered is not recognized. Do you want to proceed anyway?")
        }
    }
    
    func validateAndWriteURL() async {
        isValidating = true
        validationError = nil
        
        let urlWithScheme = url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") ? url : "https://" + url
        
        let (isValid, isSafe, hasValidExtension) = await urlValidationService.validateURL(urlWithScheme)
        
        isValidating = false
        
        if !isValid {
            validationError = "Invalid URL"
            return
        }
        if !isSafe {
            validationError = "URL may not be safe"
            return
        }
        if !hasValidExtension {
            showInvalidExtensionAlert = true
            return
        }
        
        writeURLToNFC()
    }
    
    func writeURLToNFC() {
        if let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: url)!) {
            writeAction(payload)
        }
    }
}

struct TextInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var text = ""
    
    var body: some View {
        VStack {
            TextField("Enter text", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Write Text to NFC") {
                if let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: text, locale: .current) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.bottom, 20)
    }
}

struct WifiInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var ssid = ""
    @State private var password = ""
    @State private var isHidden = false
    @State private var encryptionType = "WPA"
    
    var body: some View {
        VStack {
            TextField("SSID", text: $ssid)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Toggle("Hidden Network", isOn: $isHidden)
            Picker("Encryption", selection: $encryptionType) {
                Text("WPA").tag("WPA")
                Text("WEP").tag("WEP")
                Text("None").tag("None")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("Write WiFi to NFC") {
                let wifiConfig = "WIFI:S:\(ssid);T:\(encryptionType);P:\(password);H:\(isHidden ? "true" : "false");;"
                if let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: wifiConfig, locale: .current) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.bottom, 20)
    }
}

struct SMSInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var phoneNumber = ""
    @State private var message = ""
    
    var body: some View {
        VStack {
            TextField("Phone Number", text: $phoneNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.phonePad)
            TextField("Message", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Write SMS to NFC") {
                let smsURI = "sms:\(phoneNumber)?body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: smsURI)!) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.bottom, 20)
    }
}

struct EmailInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var emailAddress = ""
    @State private var subject = ""
    @State private var messageBody = ""
    
    var body: some View {
        VStack {
            TextField("Email Address", text: $emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
            TextField("Subject", text: $subject)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Message", text: $messageBody)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Write Email to NFC") {
                let emailURI = "mailto:\(emailAddress)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(messageBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: emailURI)!) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.bottom, 20)
    }
}

// Update NFCWriter to accept NFCNDEFPayload instead of String
class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    var payload: NFCNDEFPayload
    @Binding var alertMessage: String
    @Binding var showAlert: Bool
    
    init(payload: NFCNDEFPayload, alertMessage: Binding<String>, showAlert: Binding<Bool>) {
        self.payload = payload
        self._alertMessage = alertMessage
        self._showAlert = showAlert
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if let nfcError = error as? NFCReaderError,
               nfcError.code == .readerSessionInvalidationErrorUserCanceled {
                // User canceled the NFC session, no need to show an alert
                return
            }
            self.alertMessage = "Error: \(error.localizedDescription)"
            self.showAlert = true
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used for writing
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Not used for writing
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Query error: \(error!.localizedDescription)")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")
                case .readWrite:
                    let message = NFCNDEFMessage(records: [self.payload])
                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: "Write error: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Successfully wrote message to tag"
                            session.invalidate()
                            DispatchQueue.main.async {
                                self.alertMessage = "Successfully wrote message to tag"
                                self.showAlert = true
                            }
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
#endif
