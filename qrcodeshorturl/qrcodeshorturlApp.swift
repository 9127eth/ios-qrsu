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
    @AppStorage("isDarkMode") private var isDarkMode = false
    
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
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

struct MainTabView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var nfcReadResult: NFCReadResult?

    var body: some View {
        TabView {
            NavigationView {
                ContentView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("qrsu", systemImage: "qrcode")
            }
            
            NavigationView {
                NFCWriteView(nfcReadResult: $nfcReadResult)
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image("nfc")
                    .renderingMode(.template)
                Text("nfc tools")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image("Settings")
                    .renderingMode(.template)
                Text("settings")
            }
        }
        .accentColor(isDarkMode ? .white : .black)
    }
}
