
import Foundation

public class ImageCacheHeaderProvider: CacheHeaderProviding {
    
    private let cacheKeyGenerator: CacheKeyGenerating.Type = ImageCacheKeyGenerator.self
    
    public init() {
        
    }
    
    public func requestHeader(urlRequest: URLRequest) -> [String: String] {
        var header: [String: String] = [:]
        
        guard let url = urlRequest.url,
            let itemKey = cacheKeyGenerator.itemKeyForURL(url) else {
            return header
        }
        
        header[Header.persistentCacheItemKey] = itemKey
        
        if let variant = cacheKeyGenerator.variantForURL(url) {
            header[Header.persistentCacheItemVariant] = variant
        }
        
        header[Header.persistentCacheItemType] = Header.ItemType.image.rawValue
        
        return header
    }
}
