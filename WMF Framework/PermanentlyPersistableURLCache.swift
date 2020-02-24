import Foundation

public struct Header {
    public static let persistentCacheItemKey = "Persistent-Cache-Item-Key"
    public static let persistentCacheItemVariant = "Persistent-Cache-Item-Variant"
    public static let persistentCacheItemType = "Persistent-Cache-Item-Type"
    public static let persistentCacheETag = "Persistent-Cache-ETag"
    
    public enum ItemType: String {
        case image = "Image"
        case article = "Article"
    }
}

class PermanentlyPersistableURLCache: URLCache {
    private let cacheManagedObjectContext = CacheController.backgroundCacheContext //tonitodo: This is not very flexible
    
    func permanentlyCachedResponse(for request: URLRequest) -> CachedURLResponse? {
        guard let url = request.url,
            let itemKey = request.allHTTPHeaderFields?[Header.persistentCacheItemKey] else {
                return nil
        }
        
        let variant = request.allHTTPHeaderFields?[Header.persistentCacheItemVariant]
        let itemTypeRaw = request.allHTTPHeaderFields?[Header.persistentCacheItemType] ?? Header.ItemType.article.rawValue
        let itemType = Header.ItemType(rawValue: itemTypeRaw) ?? Header.ItemType.article
        
        let cacheKeyGenerator: CacheKeyGenerating.Type
        switch itemType {
        case Header.ItemType.image:
            cacheKeyGenerator = ImageCacheKeyGenerator.self
        case Header.ItemType.article:
            cacheKeyGenerator = ArticleCacheKeyGenerator.self
        }
        
        //2. else try pulling from Persistent Cache
        if let persistedCachedResponse = CacheProviderHelper.persistedCacheResponse(url: url, itemKey: itemKey, variant: variant, cacheKeyGenerator: cacheKeyGenerator) {
            return persistedCachedResponse
            //3. else try pulling a fallback from Persistent Cache
        } else if let moc = cacheManagedObjectContext,
            let fallbackCachedResponse = CacheProviderHelper.fallbackCacheResponse(url: url, itemKey: itemKey, variant: variant, itemType: itemType, cacheKeyGenerator: cacheKeyGenerator, moc: moc) {
            return fallbackCachedResponse
        }
        
        return nil
    }
    
    override func getCachedResponse(for dataTask: URLSessionDataTask, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        super.getCachedResponse(for: dataTask) { (response) in
            if let response = response {
                completionHandler(response)
                return
            }
            guard let request = dataTask.originalRequest else {
                completionHandler(nil)
                return
            }
            completionHandler(self.permanentlyCachedResponse(for: request))
        }
        
    }
    override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        if let response = super.cachedResponse(for: request) {
            return response
        }
        return permanentlyCachedResponse(for: request)
    }
    
    
    override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        super.storeCachedResponse(cachedResponse, for: request)
    }
    
    override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for dataTask: URLSessionDataTask) {
        super.storeCachedResponse(cachedResponse, for: dataTask)
    }
}
