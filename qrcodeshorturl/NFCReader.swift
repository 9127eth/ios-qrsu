//
//  NFCReader.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/19/24.
//

import Foundation
import CoreNFC

class NFCReader: NSObject, NFCNDEFReaderSessionDelegate {
    var completion: (NFCReadResult?) -> Void
    
    init(completion: @escaping (NFCReadResult?) -> Void) {
        self.completion = completion
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.completion(nil)
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first, let record = message.records.first else {
            session.invalidate(errorMessage: "No valid message found")
            return
        }
        
        let content = String(data: record.payload, encoding: .utf8) ?? "Unable to decode content"
        let contentType = String(data: record.type, encoding: .utf8) ?? "Unknown"
        
        DispatchQueue.main.async {
            self.completion(NFCReadResult(
                content: content,
                contentType: contentType,
                tagType: "NDEF",
                size: record.payload.count,
                capacity: 0, // We'll update this in didDetect tags
                isWritable: false // We'll update this in didDetect tags
            ))
        }
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
                
                tag.readNDEF { message, error in
                    if let error = error {
                        session.invalidate(errorMessage: "Read failed: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let message = message, let record = message.records.first else {
                        session.invalidate(errorMessage: "No valid message found")
                        return
                    }
                    
                    let content = String(data: record.payload, encoding: .utf8) ?? "Unable to decode content"
                    let contentType = String(data: record.type, encoding: .utf8) ?? "Unknown"
                    
                    DispatchQueue.main.async {
                        self.completion(NFCReadResult(
                            content: content,
                            contentType: contentType,
                            tagType: "NDEF",
                            size: record.payload.count,
                            capacity: capacity,
                            isWritable: status == .readWrite
                        ))
                    }
                    
                    session.alertMessage = "Tag read successfully!"
                    session.invalidate()
                }
            }
        }
    }
}