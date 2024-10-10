//
//  qrcodeshorturlApp.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import SwiftUI

@main
struct qrcodeshorturlApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isShowingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                
                if isShowingSplash {
                    SplashScreenView()
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isShowingSplash = false
                }
            }
        }
    }
}
