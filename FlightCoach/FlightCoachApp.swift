//
//  FlightCoachApp.swift
//  FlightCoach
//
//  Created by Ioannis Chatzikonstantinou on 15/11/25.
//

import SwiftUI

@main
struct FlightCoachApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: FlightCoachDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
