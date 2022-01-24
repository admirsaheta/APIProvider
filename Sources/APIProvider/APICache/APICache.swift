//
//  APICache.swift
//  last.fm
//
//  Created by admin on 23.1.22..
//

import Foundation
import CoreData


public class APICache {
    internal static let shared = APICache()
    
    public enum CacheClearMethod {
        case all
        case expired
    }
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let bundle = Bundle.module
        let modelURL = bundle.url(forResource: "APICache", withExtension: ".momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        
        let container = NSPersistentContainer(name: "APICache", managedObjectModel: model)
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private func clear() async {
        return await backgroundTask { context in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: APIResponse.entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            let deleteResult = try? context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
            }
            print("CACHE CLEARED")
        }
    }
    
    private func clearExpired() async {
        return await backgroundTask { context in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: APIResponse.entityName)
            fetchRequest.predicate = NSPredicate(format: "isExpired == YES")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            let deleteResult = try? context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
                print("DELETED EXPIRED CACHED RESPONES:", objectIDs.count)
            }
        }
    }
    
    public static func clear(_ clearMethod: CacheClearMethod) async {
        switch clearMethod {
        case .all:
            return await APICache.shared.clear()
        case .expired:
            return await APICache.shared.clearExpired()
        }
    }
    
    private func backgroundTask(_ task: @escaping (_ context: NSManagedObjectContext) -> Void) async {
        persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            task(context)
            guard context.hasChanges else { return }
            try! context.save()
        }
        await saveContext()
    }
    
    private func saveContext() async {
        let ctx = persistentContainer.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        }
        catch {
            print("Error saving context: \(error)")
        }
    }
    
    internal func saveResponse(url: URL, data: Data, ttl: TimeInterval) async {
        await backgroundTask { context in
            _ = APIResponse(context: context, url: url, ttl: ttl, data: data)
            print("SAVED TO CACHE FOR URL:", url)
        }
    }
    
    internal func deleteResponse(withURL url: URL) async {
        await backgroundTask { context in
            let fetchRequest: NSFetchRequest<APIResponse> = NSFetchRequest(entityName: APIResponse.entityName)
            fetchRequest.fetchLimit = 1
            guard let fetchResult = try? context.fetch(fetchRequest) else {
                return
            }
            guard let response = fetchResult.first else { return }
            context.delete(response)
        }
    }
    
    internal func getResponse(forURL url: URL) async -> Data? {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<APIResponse> = NSFetchRequest(entityName: APIResponse.entityName)
        fetchRequest.fetchLimit = 1
        guard let fetchResult = try? context.fetch(fetchRequest) else {
            return nil
        }
        guard let response = fetchResult.first else {
            return nil
        }
        if response.isExpired {
            print("CACHE EXPIRED FOR URL:", url)
            await deleteResponse(withURL: url)
            return nil
        }
        print("LOADING FROM CACHE FOR URL:", url)
        return response.data
    }
}
