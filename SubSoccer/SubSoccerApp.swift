//
//  SubSoccerApp.swift
//  SubSoccer
//
//  Created by Cizan Raza on 6/15/25.
//

import SwiftUI
import CoreData

@main
struct SubSoccerApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // Add Rosie FC with 20 players on first launch
                    addSampleDataIfNeeded()
                }
        }
    }
    
    private func addSampleDataIfNeeded() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Team> = Team.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "Rosie FC")
        
        do {
            let existingTeams = try context.fetch(request)
            if existingTeams.isEmpty {
                persistenceController.addRosieFCWithPlayers()
            }
        } catch {
            print("Failed to check for existing Rosie FC: \(error)")
        }
    }
}
