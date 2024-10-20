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
    @State private var showWriteOptions = false
    @State private var showClearConfirmation = false
    @State private var isClearing = false
    @State private var showReadNFCSheet = false
    @Binding var nfcReadResult: NFCReadResult?
    @State private var nfcReader: NFCReader?
    @State private var isNFCReady = false
    @State private var contentOffset: CGFloat = 0
    @State private var headerOpacity: Double = 1

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("The greatest NFC tools ever made.")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    .opacity(headerOpacity)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showWriteOptions.toggle()
                        contentOffset = showWriteOptions ? -200 : 0
                        headerOpacity = showWriteOptions ? 0 : 1
                    }
                }) {
                    Text("Write to NFC")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .frame(width: 300, height: 44)
                .opacity(headerOpacity)

                if showWriteOptions {
                    writeOptionsView()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showWriteOptions = false
                            contentOffset = 0
                            headerOpacity = 1
                        }
                    }) {
                        Text("Close")
                            .foregroundColor(.black)
                    }
                    .padding(.top, 10)
                    
                    Divider()
                        .background(Color.gray)
                        .padding(.vertical)
                }

                Button(action: {
                    readNFC()
                }) {
                    Text("Read NFC")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .frame(width: 300, height: 44)

                Button(action: {
                    showClearConfirmation = true
                }) {
                    Text("Clear NFC")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .frame(width: 300, height: 44)
                .disabled(isClearing)
            }
            .padding()
            .offset(y: contentOffset)
        }
        .sheet(isPresented: $showReadNFCSheet, onDismiss: {
            // Clear the nfcReadResult when the sheet is dismissed
            nfcReadResult = nil
        }) {
            ReadNFCView(nfcReadResult: $nfcReadResult)
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
        .alert(isPresented: $showAlert) {
            Alert(title: Text("NFC Write"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("Clear NFC Tag", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Yes, Continue", role: .destructive) {
                clearNFCTag()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action will erase all data on the NFC tag. This process is irreversible. Do you want to continue?")
        }
        .onAppear {
            initializeNFCReader()
        }
    }

    func writeOptionsView() -> some View {
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
        
        nfcWriter = NFCWriter(payload: payload, contentType: selectedType, alertMessage: $alertMessage, showAlert: $showAlert)
        nfcSession = NFCNDEFReaderSession(delegate: nfcWriter!, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to write the data."
        nfcSession?.begin()
    }

    func clearNFCTag() {
        isClearing = true
        
        guard NFCNDEFReaderSession.readingAvailable else {
            alertMessage = "NFC is not available on this device"
            showAlert = true
            isClearing = false
            return
        }
        
        let clearPayload = NFCNDEFPayload(format: .empty, type: Data(), identifier: Data(), payload: Data())
        nfcWriter = NFCWriter(payload: clearPayload, contentType: .text, alertMessage: $alertMessage, showAlert: $showAlert)
        nfcSession = NFCNDEFReaderSession(delegate: nfcWriter!, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to clear its contents."
        nfcSession?.begin()
        
        // Reset isClearing after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isClearing = false
        }
    }

    func readNFC() {
        guard isNFCReady else {
            alertMessage = "NFC is not ready yet. Please try again in a moment."
            showAlert = true
            return
        }
        
        nfcSession = NFCNDEFReaderSession(delegate: nfcReader!, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to read its contents."
        nfcSession?.begin()
    }

    private func initializeNFCReader() {
        guard NFCNDEFReaderSession.readingAvailable else {
            alertMessage = "NFC is not available on this device"
            showAlert = true
            return
        }
        
        nfcReader = NFCReader { result in
            DispatchQueue.main.async {
                self.nfcReadResult = result
                if result != nil {
                    self.showReadNFCSheet = true
                }
            }
        }
        isNFCReady = true
    }
}

struct NFCTypeButton: View {
    let type: NFCContentType
    @Binding var selectedType: NFCContentType
    var label: String?
    
    var body: some View {
        Button(action: { selectedType = type }) {
            Text(label ?? type.rawValue.capitalized)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedType == type ? Color.black : Color.white)
                .foregroundColor(selectedType == type ? Color.white : Color.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
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
            .fontWeight(.bold)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

struct NFCInputField: View {
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .padding(.vertical, 8)
                    .focused($isFocused)
                    .highlightOnFocus(isFocused: isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .padding(.vertical, 8)
                    .focused($isFocused)
                    .highlightOnFocus(isFocused: isFocused)
            }
        }
        .padding(.horizontal)
    }
}

struct HighlightOnFocus: ViewModifier {
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
            )
    }
}

extension View {
    func highlightOnFocus(isFocused: Bool) -> some View {
        self.modifier(HighlightOnFocus(isFocused: isFocused))
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Enter a URL")
                    .font(.headline)
                NFCInputField(placeholder: "Enter a URL", text: $url)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
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
        .padding(.horizontal)
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("EnterText")
                    .font(.headline)
                NFCInputField(placeholder: "Enter Text", text: $text)
            }
            
            Button("Write Text to NFC") {
                let textPayload = NFCNDEFPayload(
                    format: .nfcWellKnown,
                    type: "T".data(using: .utf8)!,
                    identifier: Data(),
                    payload: text.data(using: .utf8)!
                )
                writeAction(textPayload)
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct WifiInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var ssid = ""
    @State private var password = ""
    @State private var isHidden = false
    @State private var encryptionType = "WPA"
    @FocusState private var focusedField: Field?
    
    enum Field {
        case ssid, password
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("SSID")
                    .font(.headline)
                NFCInputField(placeholder: "SSID", text: $ssid)
                    .focused($focusedField, equals: .ssid)
            }
            
            VStack(alignment: .leading) {
                Text("Password")
                    .font(.headline)
                NFCInputField(placeholder: "Password", text: $password, isSecure: true)
                    .focused($focusedField, equals: .password)
            }
            
            VStack(alignment: .leading) {
                Text("Network Settings")
                    .font(.headline)
                
                Toggle("Hidden Network", isOn: $isHidden)
                
                Picker("Encryption", selection: $encryptionType) {
                    Text("WPA").tag("WPA")
                    Text("WEP").tag("WEP")
                    Text("None").tag("None")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Button("Write WiFi to NFC") {
                let wifiConfig = "WIFI:S:\(ssid);T:\(encryptionType);P:\(password);H:\(isHidden ? "true" : "false");;"
                if let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: wifiConfig, locale: .current) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct SMSInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var phoneNumber = ""
    @State private var message = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Phone Number")
                    .font(.headline)
                NFCInputField(placeholder: "Phone Number", text: $phoneNumber, keyboardType: .phonePad)
            }
            
            VStack(alignment: .leading) {
                Text("Message")
                    .font(.headline)
                NFCInputField(placeholder: "Message", text: $message)
            }
            
            Button("Write SMS to NFC") {
                let smsURI = "sms:\(phoneNumber)?body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: smsURI)!) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct EmailInputView: View {
    let writeAction: (NFCNDEFPayload) -> Void
    
    @State private var emailAddress = ""
    @State private var subject = ""
    @State private var messageBody = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Email Address")
                    .font(.headline)
                NFCInputField(placeholder: "Email Address", text: $emailAddress, keyboardType: .emailAddress)
            }
            
            VStack(alignment: .leading) {
                Text("Subject")
                    .font(.headline)
                NFCInputField(placeholder: "Subject", text: $subject)
            }
            
            VStack(alignment: .leading) {
                Text("Message")
                    .font(.headline)
                NFCInputField(placeholder: "Message", text: $messageBody)
            }
            
            Button("Write Email to NFC") {
                let emailURI = "mailto:\(emailAddress)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(messageBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: emailURI)!) {
                    writeAction(payload)
                }
            }
            .nfcWriteButtonStyle()
            .padding(.top, 20)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// Update NFCWriter to accept NFCNDEFPayload instead of String
class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    var payload: NFCNDEFPayload
    @Binding var alertMessage: String
    @Binding var showAlert: Bool
    var contentType: NFCContentType
    
    init(payload: NFCNDEFPayload, contentType: NFCContentType, alertMessage: Binding<String>, showAlert: Binding<Bool>) {
        self.payload = payload
        self.contentType = contentType
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
        // This method is called when tags are read, not when writing
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.invalidate(errorMessage: "Query failed: \(error.localizedDescription)")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")
                case .readWrite:
                    if self.payload.typeNameFormat == .empty {
                        // Clearing the tag
                        tag.writeNDEF(NFCNDEFMessage(records: [])) { error in
                            if let error = error {
                                session.invalidate(errorMessage: "Clear failed: \(error.localizedDescription)")
                            } else {
                                session.alertMessage = "Tag cleared successfully!"
                                session.invalidate()
                            }
                        }
                    } else {
                        // Writing new data to the tag
                        let message: NFCNDEFMessage
                        if self.contentType == .text {
                            let textPayload = self.createProperTextPayload(from: self.payload)
                            message = NFCNDEFMessage(records: [textPayload])
                        } else {
                            message = NFCNDEFMessage(records: [self.payload])
                        }
                        tag.writeNDEF(message) { error in
                            if let error = error {
                                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                            } else {
                                session.alertMessage = "Tag written successfully!"
                                session.invalidate()
                            }
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
    
    private func createProperTextPayload(from payload: NFCNDEFPayload) -> NFCNDEFPayload {
        let languageCode = "en"
        let textContent = String(data: payload.payload, encoding: .utf8) ?? ""
        
        var payloadData = Data([0x02])  // Status byte (UTF-8)
        payloadData += languageCode.data(using: .utf8)!
        payloadData += Data([0x00])  // Null terminator for language code
        payloadData += textContent.data(using: .utf8)!
        
        return NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "T".data(using: .utf8)!,
            identifier: Data(),
            payload: payloadData
        )
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

