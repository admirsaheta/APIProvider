//
//  APIResponse.swift
//  last.fm
//
//  Created by admin on 23.1.22..
//

import CoreData

class APIResponse: NSManagedObject {
    static let entityName = "APIResponse"
    @NSManaged public var url: URL
    @NSManaged public var data: Data
    @NSManaged public var created: Date
    @NSManaged public var ttl: TimeInterval
    @NSManaged public var isExpired: Bool
    
    convenience init(context: NSManagedObjectContext, url: URL, ttl: TimeInterval, data: Data) {
        let entityDescription: NSEntityDescription = .entity(forEntityName: APIResponse.entityName, in: context)!
        self.init(entity: entityDescription, insertInto: context)
        self.url = url
        self.data = data
        self.ttl = ttl
        self.isExpired = false
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.created = Date()
        self.isExpired = false
    }
    
    override func awakeFromFetch() {
        self.isExpired = (Date().timeIntervalSince1970 - created.timeIntervalSince1970) > ttl
    }

}
