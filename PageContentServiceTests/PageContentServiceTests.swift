import XCTest
@testable import Wikipedia

class PageContentServiceTests: XCTestCase {
    override func setUp() {
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func takeSnapshot(of webView: WKWebView, at offsetY: CGFloat, completion: @escaping () -> Void) {
        let maxOffset = webView.scrollView.contentSize.height - webView.scrollView.bounds.height
        if (offsetY > maxOffset) {
            
        }
        let snapshotConfig = WKSnapshotConfiguration()
        snapshotConfig.afterScreenUpdates = true
        webView.takeSnapshot(with: snapshotConfig, completionHandler: { (image, error) in
            let data = image?.pngData()
            try? data?.write(to: URL(fileURLWithPath: "/Users/wmf/Desktop/out.png"))

        })
    }
    
    
    func takeFullSnapshot(of webView: WKWebView, completion: @escaping () -> Void) {
        
    }

    func testExample() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let exp = XCTestExpectation(description: "Wait for page load")
        let dataStore = MWKDataStore.shared()
        let articleURL = URL(string: "https://en.wikipedia.org/wiki/Dog")!
        guard let articleViewController = ArticleViewController(articleURL: articleURL, dataStore: dataStore, theme: Theme.standard) else {
            XCTFail()
            return
        }
        articleViewController.loadCompletion = {
            takeFullSnapshot(of: articleViewController.webView) {
                exp.fulfill()
            }
        }
        window.rootViewController = articleViewController
        window.makeKeyAndVisible()
        wait(for: [exp], timeout: 100)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
