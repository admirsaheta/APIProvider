//
//  APIURL.swift
//  last.fm
//
//  Created by admin on 21.1.22..
//

import Foundation

public class APIUrl {
    let fileURL: URL
    
    public enum Configuration: String {
        case production
        case development
    }
    
    private let configuration : Configuration = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    public subscript (key: String) -> URL {
        return value(forKey: key)
    }
    
    private func value(forKey key: String) -> URL {
        let rootDict = NSDictionary(contentsOf: fileURL)!
        let envDict = rootDict[configuration.rawValue] as! [String : String]
        let url = URL(string: envDict[key]!)!
        return url
    }
}
