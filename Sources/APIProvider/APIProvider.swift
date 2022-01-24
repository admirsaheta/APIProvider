//
//  APIProvider.swift
//  last.fm
//
//  Created by admin on 21.1.22..
//

import Foundation

open class APIProvider {
    private let cache = APICache.shared
    public let apiURL: URL
    public let configuration: URLSessionConfiguration
    public let session: URLSession
    private let decoder = JSONDecoder()
    typealias FetchCompletion<T> = (_ result: Result<T, FetchError>) -> Void

    public enum FetchMethod {
        case get(_ query: [String : Any]? = nil)
        case post(_ query: [String : Any]? = nil)
        
        var string: String {
            switch self {
            case .get(_):
                return "GET"
            case .post(_):
                return "POST"
            }
        }
        
        var query: [String : Any]? {
            switch self {
            case .get(let query), .post(let query):
                return query
            }
        }
    }
    
    public enum FetchError: Error {
        case statusCode(Int)
        case emptyData
        case dataTaskError(Error)
        case decodingError(DecodingError)
        case unexpected(Error)
    }
    
    public enum CacheMethod {
        case none
        case persistent(TimeInterval)
    }
    
    public init(apiURL: URL, urlSessionConfiguration: URLSessionConfiguration?) {
        self.apiURL = apiURL
        self.configuration = urlSessionConfiguration ?? .default
        self.session = URLSession(
            configuration: self.configuration,
            delegate: nil,
            delegateQueue: OperationQueue.main
        )
    }

    
    private func dataTask(withRequest request: URLRequest, statusCodeRange: Range<Int> = 200..<300) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    return continuation.resume(throwing: FetchError.unexpected(error))
                }
                guard let data = data else {
                    return continuation.resume(throwing: FetchError.emptyData)
                }
                if let httpResponse = response as? HTTPURLResponse {
                    guard statusCodeRange.contains(httpResponse.statusCode) else {
                        return continuation.resume(throwing: FetchError.statusCode(httpResponse.statusCode))
                    }
                }
                continuation.resume(returning: data)
            }
            .resume()
        }
    }
    
    
    
    /// TEST
    /// - Returns: Test
    public func fetch<T: Decodable>(endpoint: String? = nil, method: FetchMethod = .get(), statusCodeRange: Range<Int> = 200..<300, decode: T.Type, cacheMethod: CacheMethod = .none) async throws -> T {
        let url = endpoint == nil ? apiURL : apiURL.appendingPathComponent(endpoint!)
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var request = URLRequest(url: url)
        request.httpMethod = method.string
        
        if let query = method.query {
            urlComponents?.queryItems = query.map({ item in
                return URLQueryItem(name: item.key, value: item.value as? String)
            })
            request.url = urlComponents!.url!
        }
        
        if case .persistent(_) = cacheMethod,
           let data = await cache.getResponse(forURL: request.url!)
        {
            do {
                let decoded = try self.decoder.decode(T.self, from: data)
                return decoded
            }
            catch {
                //continue
            }
        }
        
        let data = try await dataTask(withRequest: request, statusCodeRange: statusCodeRange)
        do {
            if case .persistent(let cacheInterval) = cacheMethod {
                await cache.saveResponse(url: request.url!, data: data, ttl: cacheInterval)
            }
            let decoded = try self.decoder.decode(T.self, from: data)
            return decoded
        }
        catch let error as DecodingError {
            throw FetchError.decodingError(error)
        }
        catch {
            throw error
        }
    }

}
