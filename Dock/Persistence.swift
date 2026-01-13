//
//  Persistence.swift
//  Dock
//
//  Core Data + CloudKit persistence controller
//

import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()
    
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let property = PropertyEntity(context: viewContext)
        property.id = UUID()
        property.createdAt = Date()
        property.updatedAt = Date()
        property.address = "123 Investment Lane"
        property.city = "Austin"
        property.state = "TX"
        property.zipCode = "78701"
        property.askingPrice = 450000
        property.bedrooms = 3
        property.bathrooms = 2
        property.squareFeet = 1800
        property.lotSize = 6500
        property.yearBuilt = 1985
        property.propertyType = "Single Family"
        property.unitCount = 1
        property.taxAssessedValue = 380000
        property.annualTaxes = 8500
        property.estimatedRentPerUnit = 2400
        property.estimatedTotalRent = 2400
        property.vacancyRate = 0.05
        property.managementFeePercent = 0.08
        property.repairsPerUnit = 1200
        property.insuranceAnnual = 2400
        property.interestRate = 0.07
        property.ltv = 0.75
        property.loanTermYears = 30
        property.targetCapRate = 0.06
        property.targetCashOnCash = 0.08
        property.targetDSCR = 1.25
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Dock")
        
        // Configure for CloudKit sync
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Enable CloudKit sync only for non-memory stores
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.dock.app"
            )
        }
        
        // Enable remote change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Query generations for efficient diffing
        try? container.viewContext.setQueryGenerationFrom(.current)
    }
    
    // MARK: - Save Context
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Delete All
    
    func deleteAll<T: NSManagedObject>(of type: T.Type) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try container.viewContext.execute(deleteRequest)
            save()
        } catch {
            print("Error deleting all \(type): \(error)")
        }
    }
}
