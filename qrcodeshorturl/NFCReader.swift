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
                        let typeString = String(data: record.type, encoding: .utf8) ?? ""
                        if typeString == "T" {
                            let payload = record.payload
                            let statusByte = payload[0]
                            let languageCodeLength = Int(statusByte & 0x3F)
                            let languageCode = String(data: payload.subdata(in: 1..<(1 + languageCodeLength)), encoding: .utf8) ?? ""
                            let textContent = String(data: payload.subdata(in: (1 + languageCodeLength)..<payload.count), encoding: .utf8) ?? ""
                            content = (languageCode != "en") ? "\(languageCode):\(textContent)" : textContent
                        } else {
                            content = String(data: record.payload, encoding: .utf8) ?? "Unable to decode content"
                        }
                    case .absoluteURI, .media, .nfcExternal, .empty, .unknown:
                        content = String(data: record.payload, encoding: .utf8) ?? "Unable to decode content"
                    @unknown default:
                        content = "Unsupported record type"
                    }

                    let contentType = String(data: record.type, encoding: .utf8) ?? "Unknown"

                    let result = NFCReadResult(
                        content: content,
                        contentType: contentType,
                        tagType: "NDEF",
                        size: record.payload.count,
                        capacity: capacity,
                        isWritable: status == .readWrite
                    )

                    DispatchQueue.main.async {
                        self.completion(result)
                    }

                    session.alertMessage = "Tag read successfully!"
                    session.invalidate()
                }
            }
        }
    }
}
