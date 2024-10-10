//
//  SplashScreenView.swift
//  qrcodeshorturl
//
//  Created by Richard Waithe on 10/10/24.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            Image("splashscreenimage")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}