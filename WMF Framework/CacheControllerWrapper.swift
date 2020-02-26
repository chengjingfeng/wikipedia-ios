
import Foundation

//DEBT: Wrapper class for accessing CacheControllers from MWKDataStore. Remove once MWKDataStore is no longer Objective-C and reference ArticleCacheController directly.

@objc(WMFCacheControllerType)
enum CacheControllerType: Int {
    case article
}

@objc(WMFCacheControllerWrapper)
public final class CacheControllerWrapper: NSObject {
    
    public private(set) var cacheController: CacheController? = nil
    
    @objc override init() {
        assertionFailure("Must init from init(type) or init(articleCacheWithImageCacheControllerWrapper)")
        self.cacheController = nil
        super.init()
    }
    
    @objc init?(type: CacheControllerType) {

        let articleFetcher = ArticleFetcher()
        let imageInfoFetcher = MWKImageInfoFetcher()
        
        guard let cacheBackgroundContext = CacheController.backgroundCacheContext,
            let cacheFileWriter = CacheFileWriter(fetcher: articleFetcher, cacheBackgroundContext: cacheBackgroundContext, cacheKeyGenerator: ArticleCacheKeyGenerator.self) else {
            return nil
        }
        
        let articleDBWriter = ArticleCacheDBWriter(articleFetcher: articleFetcher, cacheBackgroundContext: cacheBackgroundContext, imageInfoFetcher: imageInfoFetcher)
        
        self.cacheController = ArticleCacheController(dbWriter: articleDBWriter, fileWriter: cacheFileWriter)
    }
}
