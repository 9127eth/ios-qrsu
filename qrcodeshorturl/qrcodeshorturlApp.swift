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
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.5), value: isShowingSplash)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isShowingSplash = false
                    }
                }
            }
        }
    }
}
