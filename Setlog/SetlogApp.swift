//
//  SetlogApp.swift
//  Setlog
//
//  Created by Gabrisp on 27/4/26.
//

import SwiftUI
import CoreData

@main
struct SetlogApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
