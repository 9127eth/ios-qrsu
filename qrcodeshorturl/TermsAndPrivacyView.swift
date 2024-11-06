//
//  TermsAndPrivacyView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 11/5/24.
//
import SwiftUI
import SafariServices

struct TermsAndPrivacyView: View {
    @State private var showSafariSheet = false
    @State private var selectedURL: URL?
    
    private let termsURL = URL(string: "https://www.qrcodeshorturl.com/terms-of-service")!
    private let privacyURL = URL(string: "https://www.qrcodeshorturl.com/privacy-policy")!
    
    var body: some View {
        HStack(spacing: 4) {
            Button("Terms") {
                selectedURL = termsURL
                showSafariSheet = true
            }
            Text("•")
            Button("Privacy") {
                selectedURL = privacyURL
                showSafariSheet = true
            }
        }
        .font(.footnote)
        .foregroundColor(.gray)
        .sheet(isPresented: $showSafariSheet) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }
}

// Safari View wrapper using UIKit's SFSafariViewController
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

