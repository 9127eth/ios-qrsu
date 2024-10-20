//
//  readNFCView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/19/24.
//

import SwiftUI
import CoreNFC

struct NFCReadResult {
    let content: String
    let contentType: String
    let tagType: String
    let size: Int
    let capacity: Int
    let isWritable: Bool
}

struct ReadNFCView: View {
    @Binding var nfcReadResult: NFCReadResult?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            if let result = nfcReadResult {
                List {
                    Section(header: Text("Content")) {
                        Text(result.content)
                            .font(.body)
                    }
                    
                    Section(header: Text("Details")) {
                        InfoRow(title: "Content Type", value: result.contentType)
                        InfoRow(title: "Tag Type", value: result.tagType)
                        InfoRow(title: "Data Size", value: "\(result.size) bytes")
                        InfoRow(title: "Tag Capacity", value: "\(result.capacity) bytes")
                        InfoRow(title: "Writable", value: result.isWritable ? "Yes" : "No")
                    }
                }
                .listStyle(GroupedListStyle())
                .navigationTitle("NFC Details")
                .navigationBarItems(trailing: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                })
            } else {
                Text("No NFC data available")
                    .navigationTitle("NFC Read Result")
                    .navigationBarItems(trailing: Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    })
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
