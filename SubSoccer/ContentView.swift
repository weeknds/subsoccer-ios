//
//  ContentView.swift
//  SubSoccer
//
//  Created by Cizan Raza on 6/15/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
