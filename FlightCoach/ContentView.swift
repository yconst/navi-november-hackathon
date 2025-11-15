//
//  ContentView.swift
//  FlightCoach
//
//  Created by Ioannis Chatzikonstantinou on 15/11/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: FlightCoachDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(FlightCoachDocument()))
}
