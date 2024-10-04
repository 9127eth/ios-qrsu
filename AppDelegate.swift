//
//  AppDelegate.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.
//

import UIKit
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        loadEnvironmentVariables()
        FirebaseApp.configure()
        return true
    }
    
    private func loadEnvironmentVariables() {
        guard let path = Bundle.main.path(forResource: "config", ofType: "xcconfig") else {
            print("Unable to find config.xcconfig file")
            return
        }
        
        do {
            let config = try String(contentsOfFile: path, encoding: .utf8)
            let lines = config.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    setenv(key, value, 1)
                }
            }
        } catch {
            print("Error loading config file: \(error)")
        }
    }
}

