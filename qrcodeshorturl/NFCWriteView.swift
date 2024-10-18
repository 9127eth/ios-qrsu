//
//  NFCWriteView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/17/24.
//

import SwiftUI
import CoreNFC

struct NFCWriteView: View {
    @State private var message: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter message to write", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                writeNFC()
            }) {
                HStack {
                    Image(systemName: "wave.3.right")
                    Text("Write to NFC Tag")
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
            
            NavigationLink("Create QR Code/Short URL") {
                ContentView()
            }
            .foregroundColor(.blue)
        }
        .navigationTitle("Write to NFC")
        .alert(isPresented: $showAlert) {
            Alert(title: Text("NFC Write"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func writeNFC() {
        guard NFCNDEFReaderSession.readingAvailable else {
            alertMessage = "NFC is not available on this device"
            showAlert = true
            return
        }
        
        let session = NFCNDEFReaderSession(delegate: NFCWriter(message: message, alertMessage: $alertMessage, showAlert: $showAlert), queue: nil, invalidateAfterFirstRead: false)
        session.begin()
    }
}

class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    var message: String
    @Binding var alertMessage: String
    @Binding var showAlert: Bool
    
    init(message: String, alertMessage: Binding<String>, showAlert: Binding<Bool>) {
        self.message = message
        self._alertMessage = alertMessage
        self._showAlert = showAlert
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
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
                    let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: self.message, locale: Locale(identifier: "en"))!
                    let message = NFCNDEFMessage(records: [payload])
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
