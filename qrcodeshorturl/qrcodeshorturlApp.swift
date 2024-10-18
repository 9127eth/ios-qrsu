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
                MainTabView()
                    .opacity(isShowingSplash ? 0 : 1)
                
                if isShowingSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isShowingSplash)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isShowingSplash = false
                    }
                }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                ContentView()
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            
            NavigationView {
                NFCWriteView()
                    .navigationTitle("NFC Tools")
            }
            .tabItem {
                Label("NFC Tools", systemImage: "wave.3.right")
            }
        }
    }
}
