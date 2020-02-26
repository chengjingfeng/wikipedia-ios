
import Foundation

enum ArticleCacheDBWriterError: Error {
    case unableToDetermineMobileHtmlDatabaseKey
    case invalidListEndpointType
    case missingListURLInRequest
    case failureFetchingMediaList
    case failureFetchingOfflineResourceList
    case failureFetchOrCreateCacheGroup
    case failureFetchOrCreateMustHaveCacheItem
    case missingExpectedItemsOutOfRequestHeader
}

final class ArticleCacheDBWriter: NSObject, CacheDBWriting {
    
    private let articleFetcher: ArticleFetcher
    private let fetcher: CacheFetching
    private let cacheBackgroundContext: NSManagedObjectContext
    private let imageInfoFetcher: MWKImageInfoFetcher
    private let imageController = ImageController.shared
    
    var groupedTasks: [String : [IdentifiedTask]] = [:]

    init(articleFetcher: ArticleFetcher, cacheBackgroundContext: NSManagedObjectContext, imageInfoFetcher: MWKImageInfoFetcher) {
        
        self.articleFetcher = articleFetcher
        self.fetcher = articleFetcher
        self.cacheBackgroundContext = cacheBackgroundContext
        self.imageInfoFetcher = imageInfoFetcher
   }
    
    func add(urls: [URL], groupKey: String, completion: CacheDBWritingCompletionWithURLRequests) {
        assertionFailure("ArticleCacheDBWriter not setup for batch url inserts.")
    }
    
    //note, this comes in as desktopArticleURL via WMFArticle's key
    func add(url: URL, groupKey: CacheController.GroupKey, completion: @escaping CacheDBWritingCompletionWithURLRequests) {

        var mobileHTMLRequest: URLRequest
        var mobileHTMLOfflineResourcesRequest: URLRequest
        var mobileHTMLMediaListRequest: URLRequest
        do {
            mobileHTMLRequest = try articleFetcher.mobileHTMLRequest(articleURL: url)
            mobileHTMLOfflineResourcesRequest = try articleFetcher.mobileHTMLOfflineResourcesRequest(articleURL: url)
            mobileHTMLMediaListRequest = try articleFetcher.mobileHTMLMediaListRequest(articleURL: url)
        } catch (let error) {
            completion(.failure(error))
            return
        }
        
        var mobileHtmlOfflineResourceURLRequests: [URLRequest] = []
        var mediaListError: Error?
        var mobileHtmlOfflineResourceError: Error?
        
        var imageInfoURLRequests: [URLRequest] = []
        
        let group = DispatchGroup()
        
        group.enter()
        fetchOfflineResourceURLs(request: mobileHTMLOfflineResourcesRequest, groupKey: groupKey) { (result) in
            defer {
                group.leave()
            }
            
            switch result {
            case .success(let urls):
                
                for url in urls {
                    let urlRequest = self.articleFetcher.urlRequest(from: url, forceCache: false)
                    
                    mobileHtmlOfflineResourceURLRequests.append(urlRequest)
                }
                
                
            case .failure(let error):
                mobileHtmlOfflineResourceError = error
            }
        }
        
        group.enter()
        fetchMediaListURLs(request: mobileHTMLMediaListRequest, groupKey: groupKey) { (result) in
            
            defer {
                group.leave()
            }
            
            switch result {
            case .success(let items):
                
                let imageTitles = items.map { $0.imageTitle }
                let imageURLs = items.map { $0.imageURL }
                var imageInfoURLs: [URL] = []
                let dedupedTitles = Set(imageTitles)
                
                //add imageInfoFetcher's urls for deduped titles (for captions/licensing info in gallery)
                for title in dedupedTitles {
                    if let imageInfoURL = self.imageInfoFetcher.galleryInfoURL(forImageTitles: [title], fromSiteURL: url) {
                        imageInfoURLs.append(imageInfoURL)
                    }
                }
                
                for imageInfoURL in imageInfoURLs {
                    let urlRequest = self.imageInfoFetcher.urlRequestFor(from: imageInfoURL, forceCache: false)
                    imageInfoURLRequests.append(urlRequest)
                }
                
                let imageURLsToDownload = imageURLs.filter { (url) -> Bool in
                    
                    let itemKey = self.imageController.cacheKeyForURL(url)
                    let variant = self.imageController.variantForURL(url)
                    
                    return self.shouldDownloadImageVariant(itemKey: itemKey, variant: variant)
                }
                
                //add image urls
                self.imageController.permanentlyCacheInBackground(urls: imageURLsToDownload, groupKey: groupKey, failure: { (error) in
                    //tonitodo: don't think we need this. if not make it optional
                }) {
                    //tonitodo: don't think we need this. if not make it optional
                }
                
            case .failure(let error):
                mediaListError = error
            }
        }
        
        group.notify(queue: DispatchQueue.global(qos: .default)) {
            
            if let mediaListError = mediaListError {
                let result = CacheDBWritingResultWithURLRequests.failure(mediaListError)
                completion(result)
                return
            }
            
            if let mobileHtmlOfflineResourceError = mobileHtmlOfflineResourceError {
                let result = CacheDBWritingResultWithURLRequests.failure(mobileHtmlOfflineResourceError)
                completion(result)
                return
            }
            
            let mustHaveRequests = [[mobileHTMLRequest], [mobileHTMLMediaListRequest], mobileHtmlOfflineResourceURLRequests, imageInfoURLRequests].flatMap { $0 }
            
            self.cacheURLs(groupKey: groupKey, mustHaveURLRequests: mustHaveRequests, niceToHaveURLRequests: []) { (result) in
                switch result {
                case .success:
                    let result = CacheDBWritingResultWithURLRequests.success(mustHaveRequests)
                    completion(result)
                case .failure(let error):
                    let result = CacheDBWritingResultWithURLRequests.failure(error)
                    completion(result)
                }
            }
        }
    }
    
    func allDownloaded(groupKey: String) -> Bool {
        guard let context = CacheController.backgroundCacheContext else {
            return false
        }
        
        return context.performWaitAndReturn {
            guard let group = CacheDBWriterHelper.cacheGroup(with: groupKey, in: context) else {
                return false
            }
            guard let cacheItems = group.cacheItems as? Set<CacheItem> else {
                return false
            }
            for item in cacheItems {
                if !item.isDownloaded && group.mustHaveCacheItems?.contains(item) ?? false {
                    return false
                }
            }
            
            return true
        } ?? false
    }
    
    func shouldDownloadVariant(itemKey: CacheController.ItemKey, variant: String?) -> Bool {
        //maybe tonitodo: if we reach a point where we add all language variation keys to db, we should limit this based on their NSLocale language preferences.
        return true
    }
}

//Migration

extension ArticleCacheDBWriter {
    
    func cacheMobileHtmlFromMigration(desktopArticleURL: URL, success: @escaping (URLRequest) -> Void, failure: @escaping (Error) -> Void) { //articleURL should be desktopURL
        
        guard let groupKey = desktopArticleURL.wmf_databaseKey else {
            failure(ArticleCacheDBWriterError.unableToDetermineMobileHtmlDatabaseKey)
            return
        }
        
        let mobileHTMLRequest: URLRequest
        do {
            
            mobileHTMLRequest = try articleFetcher.mobileHTMLRequest(articleURL: desktopArticleURL)
        } catch (let error) {
            failure(error)
            return
        }
        
        cacheURLs(groupKey: groupKey, mustHaveURLRequests: [mobileHTMLRequest], niceToHaveURLRequests: []) { (result) in
            switch result {
            case .success:
                success(mobileHTMLRequest)
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    func shouldDownloadImageVariant(itemKey: CacheController.ItemKey, variant: String?) -> Bool {
        
        guard let variant = variant else {
            return true
        }
        
        let context = self.cacheBackgroundContext

        var result: Bool = false
        context.performAndWait {

            var allVariantItems = CacheDBWriterHelper.allVariantItems(itemKey: itemKey, in: context)

            allVariantItems.sort { (lhs, rhs) -> Bool in

                guard let lhsVariant = lhs.variant,
                    let lhsSize = Int64(lhsVariant),
                    let rhsVariant = rhs.variant,
                    let rhsSize = Int64(rhsVariant) else {
                        return true
                }

                return lhsSize < rhsSize
            }

            switch (UIScreen.main.scale, allVariantItems.count) {
            case (1.0, _), (_, 1):
                guard let firstVariant = allVariantItems.first?.variant else {
                    result = true
                    return
                }
                result = variant == firstVariant
            case (2.0, _):
                guard let secondVariant = allVariantItems[safeIndex: 1]?.variant else {
                    result = true
                    return
                }
                result = variant == secondVariant
            case (3.0, _):
                guard let lastVariant = allVariantItems.last?.variant else {
                    result = true
                    return
                }
                result = variant == lastVariant
            default:
                result = false
            }
        }

        return result
    }
    
    func migratedCacheItemFile(urlRequest: URLRequest, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        
        guard let url = urlRequest.url,
            let itemKey = urlRequest.allHTTPHeaderFields?[Session.Header.persistentCacheItemKey] else {
                failure(ArticleCacheDBWriterError.missingExpectedItemsOutOfRequestHeader)
                return
        }
        
        let variant = urlRequest.allHTTPHeaderFields?[Session.Header.persistentCacheItemVariant]
        
        cacheBackgroundContext.perform {
            guard let item = CacheDBWriterHelper.fetchOrCreateCacheItem(with: url, itemKey: itemKey, variant: variant, in: self.cacheBackgroundContext) else {
                failure(ArticleCacheDBWriterError.failureFetchOrCreateMustHaveCacheItem)
                return
            }
            item.isDownloaded = true
            CacheDBWriterHelper.save(moc: self.cacheBackgroundContext) { (result) in
                switch result {
                case .success:
                    success()
                case .failure(let error):
                    failure(error)
                }
            }
        }
    }
}

private extension ArticleCacheDBWriter {
    
    func fetchMediaListURLs(request: URLRequest, groupKey: String, completion: @escaping (Result<[ArticleFetcher.MediaListItem], ArticleCacheDBWriterError>) -> Void) {
        
        guard let url = request.url else {
            completion(.failure(.missingListURLInRequest))
            return
        }
        
        let untrackKey = UUID().uuidString
        let task = articleFetcher.fetchMediaListURLs(with: request) { [weak self] (result) in
            
            defer {
                self?.untrackTask(untrackKey: untrackKey, from: groupKey)
            }
            
            switch result {
            case .success(let items):
                completion(.success(items))
            case .failure:
                completion(.failure(.failureFetchingMediaList))
            }
        }
        
        if let task = task {
            trackTask(untrackKey: untrackKey, task: task, to: groupKey)
        }
    }
    
    func fetchOfflineResourceURLs(request: URLRequest, groupKey: String, completion: @escaping (Result<[URL], ArticleCacheDBWriterError>) -> Void) {
        
        guard let url = request.url else {
            completion(.failure(.missingListURLInRequest))
            return
        }
        
        let untrackKey = UUID().uuidString
        let task = articleFetcher.fetchOfflineResourceURLs(with: request) { [weak self] (result) in
            
            defer {
                self?.untrackTask(untrackKey: untrackKey, from: groupKey)
            }
            
            switch result {
            case .success(let urls):
                completion(.success(urls))
            case .failure:
                completion(.failure(.failureFetchingOfflineResourceList))
            }
        }
        
        if let task = task {
            trackTask(untrackKey: untrackKey, task: task, to: groupKey)
        }
    }
    
    func cacheURLs(groupKey: String, mustHaveURLRequests: [URLRequest], niceToHaveURLRequests: [URLRequest], completion: @escaping ((SaveResult) -> Void)) {


        let context = self.cacheBackgroundContext
        context.perform {

            guard let group = CacheDBWriterHelper.fetchOrCreateCacheGroup(with: groupKey, in: context) else {
                completion(.failure(ArticleCacheDBWriterError.failureFetchOrCreateCacheGroup))
                return
            }
            
            for urlRequest in mustHaveURLRequests {
                
                guard let url = urlRequest.url,
                    let itemKey = urlRequest.allHTTPHeaderFields?[Session.Header.persistentCacheItemKey] else {
                        completion(.failure(ImageCacheDBWriterError.missingExpectedItemsOutOfRequestHeader))
                        return
                }
                
                let variant = urlRequest.allHTTPHeaderFields?[Session.Header.persistentCacheItemVariant]
                
                guard let item = CacheDBWriterHelper.fetchOrCreateCacheItem(with: url, itemKey: itemKey, variant: variant, in: context) else {
                    completion(.failure(ArticleCacheDBWriterError.failureFetchOrCreateMustHaveCacheItem))
                    return
                }
                
                group.addToCacheItems(item)
                group.addToMustHaveCacheItems(item)
            }
            
            for urlRequest in niceToHaveURLRequests {
                
                guard let url = urlRequest.url,
                        let itemKey = urlRequest.allHTTPHeaderFields?[Session.Header.persistentCacheItemKey] else {
                        continue
                }
                
                let variant = urlRequest.allHTTPHeaderFields?[Session.Header.persistentCacheItemVariant]
                
                guard let item = CacheDBWriterHelper.fetchOrCreateCacheItem(with: url, itemKey: itemKey, variant: variant, in: context) else {
                    continue
                }
                
                item.variant = variant
                group.addToCacheItems(item)
            }
            
            CacheDBWriterHelper.save(moc: context, completion: completion)
        }
    }
}
