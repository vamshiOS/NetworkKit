// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

typealias Headers = [String: String]

public enum HTTPMethod: String{
    case get = "GET",
         post = "POST",
         put = "PUT",
         delete = "DELETE"
}

public struct EndPoint{
    let path: String
    let httpMethod: HTTPMethod
    let additionalHeaders: Headers?
}

extension EndPoint{
    var headers: Headers{
        var headers =  ["Content-Type": "application/json"]
        additionalHeaders?.forEach { key, value in
            headers[key] = value
        }
        return headers
    }
}

public struct APIConfig{
    
    public let baseUrl: String
    
    public init(baseUrl: String) {
        self.baseUrl = baseUrl
    }
}

public protocol Networking{
    var config: APIConfig { get }
    @available(iOS 13.0.0, *)
    func execute<T: Decodable, B: Encodable>(_ endPoint: EndPoint, body: B?) async throws -> T
}

public enum ApiError: Error{
    case badUrl
    case badServerResponse
    case invalidStatusCode(statusCode: Int)
    case parsing(error: Error)
    case networkError(error: Error)
}

@available(iOS 15.0, *)
public final class NetworkClient: Networking{
    
    public let config: APIConfig
    
    public init(config: APIConfig) {
        self.config = config
    }
    
    private var baseUrl: URL?{
        return URL(string: config.baseUrl)
    }
    
    public  func execute<T: Decodable, B: Encodable>(_ endPoint: EndPoint, body: B? = nil) async throws -> T{
        guard let url = baseUrl?.appendingPathComponent(endPoint.path) else{
            throw ApiError.badUrl
        }
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = endPoint.httpMethod.rawValue
        if let body = body, let httpBody = try? JSONEncoder().encode(body){
            urlRequest.httpBody = httpBody
        }
        urlRequest.allHTTPHeaderFields = endPoint.headers
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpUrlResponse = response as? HTTPURLResponse else{
                throw ApiError.badServerResponse
            }
            if !((200..<300) ~= httpUrlResponse.statusCode){
                throw ApiError.invalidStatusCode(statusCode: httpUrlResponse.statusCode)
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw ApiError.parsing(error: error)
        }
        catch{
            throw ApiError.networkError(error: error)
        }
    }
   
}
