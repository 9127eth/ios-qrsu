import Foundation
import CoreNFC

class NFCReader: NSObject, NFCNDEFReaderSessionDelegate {
    var completion: (NFCReadResult?) -> Void

    init(completion: @escaping (NFCReadResult?) -> Void) {
        self.completion = completion
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Handle only actual errors
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled,
                 .readerSessionInvalidationErrorFirstNDEFTagRead:
                // These are expected invalidations; do nothing
                break
            default:
                // An actual error occurred; clear the data
                DispatchQueue.main.async {
                    self.completion(nil)
                }
            }
        } else {
            // An unknown error occurred; clear the data
            DispatchQueue.main.async {
                self.completion(nil)
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used in this implementation
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

                    let content: String
                    switch record.typeNameFormat {
                    case .nfcWellKnown:
                        content = String(data: record.payload.advanced(by: 3), encoding: .utf8) ?? "Unable to decode content"
                    case .absoluteURI:
                        content = String(data: record.payload, encoding: .utf8) ?? "Unable to decode content"
                    default:
                        content = "Unsupported type"
                    }

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