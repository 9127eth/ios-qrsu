//
//  SettingsView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 11/5/24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    Toggle(isOn: $isDarkMode) {
                        HStack {
                            Image("DarkMode")
                                .renderingMode(.template)
                            Text("Dark Mode")
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.4.6")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Spacer()
                        TermsAndPrivacyView()
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

