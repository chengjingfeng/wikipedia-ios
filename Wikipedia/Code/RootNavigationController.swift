import UIKit

/// Root view controller for the entire app. Handles splash screen presentation.
@objc(WMFRootNavigationController)
class RootNavigationController: WMFThemeableNavigationController {
    
    @objc var splashScreenViewController: SplashScreenViewController?
    
    @objc func showSplashView() {
        guard splashScreenViewController == nil else {
            return
        }
        let splashVC = SplashScreenViewController()
        // Explicit appearance transitions need to be used here because UINavigationController overrides
        // a lot of behaviors when adding the VC as a child and causes layout issues for our use case.
        splashVC.beginAppearanceTransition(true, animated: false)
        splashVC.apply(theme: theme)
        view.wmf_addSubviewWithConstraintsToEdges(splashVC.view)
        splashVC.endAppearanceTransition()
        splashScreenViewController = splashVC
    }
    
    @objc(hideSplashViewAnimated:)
    func hideSplashView(animated: Bool) {
        guard let splashVC = splashScreenViewController else {
            return
        }
        splashVC.ensureMinimumShowDuration {
            // Explicit appearance transitions need to be used here because UINavigationController overrides
            // a lot of behaviors when adding the VC as a child and causes layout issues for our use case.
            splashVC.beginAppearanceTransition(false, animated: true)
            let duration: TimeInterval = animated ? 0.15 : 0.0
            UIView.animate(withDuration: duration, delay: 0, options: .allowUserInteraction, animations: {
                splashVC.view.alpha = 0.0
            }) { finished in
                splashVC.view.removeFromSuperview()
                splashVC.endAppearanceTransition()
            }
        }
        splashScreenViewController = nil
    }
}
