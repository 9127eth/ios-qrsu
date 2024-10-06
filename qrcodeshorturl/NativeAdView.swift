//
//  NativeAdView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/6/24.
//

import SwiftUI
import GoogleMobileAds

struct NativeAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADNativeAdView {
        guard let nativeAdView = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first as? GADNativeAdView else {
            fatalError("Unable to load NativeAdView from nib file.")
        }
        
        let rootViewController = UIApplication.shared.windows.first?.rootViewController
        let adLoader = GADAdLoader(adUnitID: adUnitID, rootViewController: rootViewController,
                                   adTypes: [.native], options: nil)
        adLoader.delegate = context.coordinator
        adLoader.load(GADRequest())
        
        return nativeAdView
    }

    func updateUIView(_ nativeAdView: GADNativeAdView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GADNativeAdLoaderDelegate {
        var parent: NativeAdView

        init(_ parent: NativeAdView) {
            self.parent = parent
        }

        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            guard let nativeAdView = parent.makeUIView(context: .init()) as? GADNativeAdView else { return }

            (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
            nativeAdView.headlineView?.isHidden = nativeAd.headline == nil

            (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
            nativeAdView.bodyView?.isHidden = nativeAd.body == nil

            (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

            nativeAdView.nativeAd = nativeAd
        }
    }
}

