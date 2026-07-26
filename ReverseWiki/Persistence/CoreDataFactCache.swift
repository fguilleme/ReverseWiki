import CoreData
import CoreLocation
import CryptoKit

protocol FactCaching {
    func fact(
        for coordinate: CLLocationCoordinate2D?,
        imageData: Data,
        cacheIdentifier: String
    ) async throws -> PlaceFact?
    func save(
        _ fact: PlaceFact,
        for coordinate: CLLocationCoordinate2D?,
        imageData: Data,
        cacheIdentifier: String
    ) async throws
    func history() async throws -> [HistoryEntry]
    func deleteHistoryEntries(ids: [String]) async throws
    func clear() async throws
}

final class CoreDataFactCache: FactCaching {
    private enum Field {
        static let entity = "CachedPlaceFact"
        static let coordinateKey = "coordinateKey"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let payload = "payload"
        static let imageData = "imageData"
        static let updatedAt = "updatedAt"
        static let modelIdentifier = "modelIdentifier"
    }

    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ReverseWiki", managedObjectModel: Self.makeModel())
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.forEach {
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data failed: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func fact(
        for coordinate: CLLocationCoordinate2D?,
        imageData: Data,
        cacheIdentifier: String
    ) async throws -> PlaceFact? {
        let key = Self.coordinateKey(
            for: coordinate,
            imageData: imageData,
            cacheIdentifier: cacheIdentifier
        )
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: Field.entity)
            request.predicate = NSPredicate(format: "%K == %@", Field.coordinateKey, key)
            request.fetchLimit = 1
            guard let data = try context.fetch(request).first?.value(forKey: Field.payload) as? Data else {
                return nil
            }
            return try JSONDecoder().decode(PlaceFact.self, from: data)
        }
    }

    func save(
        _ fact: PlaceFact,
        for coordinate: CLLocationCoordinate2D?,
        imageData: Data,
        cacheIdentifier: String
    ) async throws {
        let key = Self.coordinateKey(
            for: coordinate,
            imageData: imageData,
            cacheIdentifier: cacheIdentifier
        )
        let payload = try JSONEncoder().encode(fact)
        let context = container.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: Field.entity)
            request.predicate = NSPredicate(format: "%K == %@", Field.coordinateKey, key)
            request.fetchLimit = 1
            let object = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: Field.entity, into: context)
            object.setValue(key, forKey: Field.coordinateKey)
            let storedCoordinate = fact.identifiedCoordinate ?? coordinate
            object.setValue(storedCoordinate?.latitude ?? 0, forKey: Field.latitude)
            object.setValue(storedCoordinate?.longitude ?? 0, forKey: Field.longitude)
            object.setValue(payload, forKey: Field.payload)
            object.setValue(imageData, forKey: Field.imageData)
            object.setValue(Date(), forKey: Field.updatedAt)
            object.setValue(cacheIdentifier, forKey: Field.modelIdentifier)
            try context.save()
        }
    }

    func history() async throws -> [HistoryEntry] {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: Field.entity)
            request.sortDescriptors = [
                NSSortDescriptor(key: Field.updatedAt, ascending: false)
            ]
            return try context.fetch(request).compactMap { object in
                guard let id = object.value(forKey: Field.coordinateKey) as? String,
                      let payload = object.value(forKey: Field.payload) as? Data,
                      let imageData = object.value(forKey: Field.imageData) as? Data,
                      let date = object.value(forKey: Field.updatedAt) as? Date,
                      let fact = try? JSONDecoder().decode(PlaceFact.self, from: payload) else {
                    return nil
                }
                let latitude = object.value(forKey: Field.latitude) as? Double ?? 0
                let longitude = object.value(forKey: Field.longitude) as? Double ?? 0
                let coordinate: CLLocationCoordinate2D? = (latitude == 0 && longitude == 0)
                    ? nil
                    : CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                return HistoryEntry(
                    id: id,
                    imageData: imageData,
                    date: date,
                    fact: fact,
                    coordinate: coordinate,
                    modelIdentifier: object.value(forKey: Field.modelIdentifier) as? String
                )
            }
        }
    }

    func deleteHistoryEntries(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        let context = container.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: Field.entity)
            request.predicate = NSPredicate(format: "%K IN %@", Field.coordinateKey, ids)
            try context.fetch(request).forEach(context.delete)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    func clear() async throws {
        let context = container.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: Field.entity)
            try context.fetch(request).forEach(context.delete)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    static func coordinateKey(
        for coordinate: CLLocationCoordinate2D?,
        imageData: Data,
        cacheIdentifier: String = "legacy"
    ) -> String {
        let digest = SHA256.hash(data: imageData)
        let imageFingerprint = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        let locationComponent = coordinate.map {
            String(format: "%.4f,%.4f", $0.latitude, $0.longitude)
        } ?? "no-gps"
        let modelDigest = SHA256.hash(data: Data(cacheIdentifier.utf8))
        let modelFingerprint = modelDigest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "vision-v5:"
            + modelFingerprint
            + ":"
            + locationComponent
            + ":"
            + imageFingerprint
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = Field.entity
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let coordinateKey = attribute(Field.coordinateKey, .stringAttributeType)
        entity.properties = [
            coordinateKey,
            attribute(Field.latitude, .doubleAttributeType),
            attribute(Field.longitude, .doubleAttributeType),
            attribute(Field.payload, .binaryDataAttributeType),
            attribute(Field.imageData, .binaryDataAttributeType, optional: true),
            attribute(Field.updatedAt, .dateAttributeType),
            attribute(Field.modelIdentifier, .stringAttributeType, optional: true)
        ]
        entity.uniquenessConstraints = [[Field.coordinateKey]]
        entity.indexes = [NSFetchIndexDescription(
            name: "coordinateKeyIndex",
            elements: [NSFetchIndexElementDescription(property: coordinateKey, collationType: .binary)]
        )]
        model.entities = [entity]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
