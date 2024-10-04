import Firebase

struct FirebaseConfig {
    static func configure() {
        guard let apiKey = ProcessInfo.processInfo.environment["FIREBASE_API_KEY"],
              let projectID = ProcessInfo.processInfo.environment["FIREBASE_PROJECT_ID"],
              let storageBucket = ProcessInfo.processInfo.environment["FIREBASE_STORAGE_BUCKET"],
              let googleAppID = ProcessInfo.processInfo.environment["FIREBASE_GOOGLE_APP_ID"],
              let gcmSenderID = ProcessInfo.processInfo.environment["FIREBASE_GCM_SENDER_ID"] else {
            fatalError("Missing Firebase configuration in environment variables")
        }
        
        let options = FirebaseOptions(
            googleAppID: googleAppID,
            gcmSenderID: gcmSenderID
        )
        options.apiKey = apiKey
        options.projectID = projectID
        options.storageBucket = storageBucket
        
        FirebaseApp.configure(options: options)
    }
}
//   FirebaseConfig.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/4/24.

