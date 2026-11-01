import Foundation
import CoreData

/// Core Data-backed persistence (iOS 15+, macOS 12+). Fallback when SwiftData is unavailable.
public final class CoreDataBackend: PersistenceBackend {
    private let container: NSPersistentContainer
    private let queue = DispatchQueue(label: "aperture.coredata", qos: .utility)
    public init(rootURL: URL) {
        let model = CoreDataBackend.makeModel()
        container = NSPersistentContainer(name: "Aperture", managedObjectModel: model)
        let storeURL = rootURL.appendingPathComponent("aperture.sqlite", isDirectory: false)
        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.shouldAddStoreAsynchronously = false
        desc.shouldMigrateStoreAutomatically = true
        desc.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [desc]
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        container.loadPersistentStores { _, _ in }
    }
    public func loadRepos() -> [ApertureRepo] {
        let ctx = container.viewContext
        let req = NSFetchRequest<CDRepo>(entityName: "CDRepo")
        return ((try? ctx.fetch(req)) ?? []).map { $0.toValue() }
    }
    public func saveRepos(_ repos: [ApertureRepo]) {
        queue.async { [container] in
            let ctx = container.newBackgroundContext()
            ctx.perform {
                let existing = (try? ctx.fetch(NSFetchRequest<CDRepo>(entityName: "CDRepo"))) ?? []
                existing.forEach { ctx.delete($0) }
                repos.forEach { r in CDRepo(context: ctx).fill(from: r) }
                try? ctx.save()
            }
        }
    }
    public func loadPackages(repoID: String) -> [AperturePackage] {
        let ctx = container.viewContext
        let req = NSFetchRequest<CDPackage>(entityName: "CDPackage")
        req.predicate = NSPredicate(format: "repoID == %@", repoID)
        req.fetchLimit = 100_000
        return ((try? ctx.fetch(req)) ?? []).map { $0.toValue() }
    }
    public func savePackages(_ packages: [AperturePackage], repoID: String) {
        queue.async { [container] in
            let ctx = container.newBackgroundContext()
            ctx.perform {
                let req = NSFetchRequest<CDPackage>(entityName: "CDPackage")
                req.predicate = NSPredicate(format: "repoID == %@", repoID)
                let existing = (try? ctx.fetch(req)) ?? []
                existing.forEach { ctx.delete($0) }
                packages.forEach { p in CDPackage(context: ctx).fill(from: p) }
                try? ctx.save()
            }
        }
    }
    public func purgePackages(repoID: String) {
        let ctx = container.newBackgroundContext()
        ctx.performAndWait {
            let req = NSFetchRequest<CDPackage>(entityName: "CDPackage")
            req.predicate = NSPredicate(format: "repoID == %@", repoID)
            ((try? ctx.fetch(req)) ?? []).forEach { ctx.delete($0) }
            try? ctx.save()
        }
    }
    public func loadHistory() -> [Transaction] {
        let ctx = container.viewContext
        let req = NSFetchRequest<CDHistoryItem>(entityName: "CDHistoryItem")
        req.fetchLimit = 200
        req.sortDescriptors = [NSSortDescriptor(key: "finishedAt", ascending: false)]
        return ((try? ctx.fetch(req)) ?? []).map { $0.toValue() }
    }
    public func appendHistory(_ txn: Transaction) {
        queue.async { [container] in
            let ctx = container.newBackgroundContext()
            ctx.perform {
                CDHistoryItem(context: ctx).fill(from: txn)
                let req = NSFetchRequest<CDHistoryItem>(entityName: "CDHistoryItem")
                req.sortDescriptors = [NSSortDescriptor(key: "finishedAt", ascending: false)]
                if let all = try? ctx.fetch(req), all.count > 200 { all.dropFirst(200).forEach { ctx.delete($0) } }
                try? ctx.save()
            }
        }
    }
    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let repoEntity = NSEntityDescription()
        repoEntity.name = "CDRepo"; repoEntity.managedObjectClassName = NSStringFromClass(CDRepo.self)
        repoEntity.properties = [attr("id",.stringAttributeType,false),attr("url",.stringAttributeType,false),attr("suite",.stringAttributeType,false),attr("components",.stringAttributeType,false),attr("displayName",.stringAttributeType,false),attr("iconURL",.stringAttributeType,true),attr("isDefault",.booleanAttributeType,false),attr("lastRefresh",.dateAttributeType,true),attr("packageCount",.integer32AttributeType,false)]
        let pkgEntity = NSEntityDescription()
        pkgEntity.name = "CDPackage"; pkgEntity.managedObjectClassName = NSStringFromClass(CDPackage.self)
        pkgEntity.properties = [attr("id",.stringAttributeType,false),attr("package",.stringAttributeType,false),attr("name",.stringAttributeType,false),attr("version",.stringAttributeType,false),attr("architecture",.stringAttributeType,false),attr("section",.stringAttributeType,true),attr("repoID",.stringAttributeType,false),attr("repoURL",.stringAttributeType,false),attr("maintainer",.stringAttributeType,true),attr("author",.stringAttributeType,true),attr("descriptionText",.stringAttributeType,false),attr("homepage",.stringAttributeType,true),attr("depends",.stringAttributeType,false),attr("conflicts",.stringAttributeType,false),attr("provides",.stringAttributeType,false),attr("replaces",.stringAttributeType,false),attr("filename",.stringAttributeType,false),attr("size",.integer64AttributeType,false),attr("md5sum",.stringAttributeType,true),attr("sha256",.stringAttributeType,true),attr("depiction",.stringAttributeType,true),attr("sileoDepiction",.stringAttributeType,true),attr("tags",.stringAttributeType,false),attr("iconURL",.stringAttributeType,true),attr("screenshotURLs",.stringAttributeType,false),attr("changelog",.stringAttributeType,true)]
        let histEntity = NSEntityDescription()
        histEntity.name = "CDHistoryItem"; histEntity.managedObjectClassName = NSStringFromClass(CDHistoryItem.self)
        histEntity.properties = [attr("id",.UUIDAttributeType,false),attr("kind",.stringAttributeType,false),attr("packageID",.stringAttributeType,false),attr("packageName",.stringAttributeType,false),attr("state",.stringAttributeType,false),attr("startedAt",.dateAttributeType,true),attr("finishedAt",.dateAttributeType,true),attr("attempts",.integer32AttributeType,false)]
        model.entities = [repoEntity, pkgEntity, histEntity]
        return model
    }
    private static func attr(_ name: String, _ type: NSAttributeType, _ optional: Bool) -> NSAttributeDescription {
        let a = NSAttributeDescription(); a.name = name; a.attributeType = type; a.isOptional = optional; return a
    }
}
