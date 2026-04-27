import CoreData

struct PersistenceController {

    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext
        do {
            try ctx.save()
        } catch {
            fatalError("Preview store save failed: \(error)")
        }
        return result
    }()

    let container: NSPersistentContainer

    // TODO: To enable CloudKit sync, replace NSPersistentContainer with
    //       NSPersistentCloudKitContainer(name: "Setlog") and add
    //       storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(...)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Setlog")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
