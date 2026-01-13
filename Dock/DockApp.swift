//
//  DockApp.swift
//  Dock
//
//  Created by Zachary Coriarty on 1/13/26.
//

import SwiftUI
import CoreData

@main
struct DockApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
