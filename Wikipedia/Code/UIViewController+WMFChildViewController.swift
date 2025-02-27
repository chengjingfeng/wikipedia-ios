import Foundation
import WMF

extension UIViewController {
    /// Embeds a view controller's view in a container view ensuring the VC's view is constrained to the edges of the given view
    ///
    /// - Parameters:
    ///   - childController: Controller whose view will be embedded in containerView
    ///   - containerView: View to which childController's view will be added as a subview
    @objc public func wmf_add(childController: UIViewController, andConstrainToEdgesOfContainerView containerView: UIView, belowSubview: UIView? = nil) {
        addChild(childController)
        containerView.wmf_addSubview(childController.view, withConstraintsToEdgesWithInsets: .zero, priority: .required, belowSubview: belowSubview)
        childController.didMove(toParent: self)
    }


    /// Embeds a view controller's view in a container view ensuring the container view expands vertically as needed to encompass any AutoLayout changes to the embedded view which affect its height.
    ///
    /// - Parameters:
    ///   - childController: Controller whose view will be embedded in containerView
    ///   - containerView: View to which childController's view will be added as a subview
    @objc public func wmf_addHeightDetermining(childController: UIViewController?, andConstrainToEdgesOfContainerView containerView: UIView, belowSubview: UIView? = nil) {
        guard let childController = childController else {
            return
        }
        addChild(childController)
        containerView.wmf_addHeightDeterminingSubviewWithConstraintsToEdges(childController.view, belowSubview: belowSubview)
        childController.didMove(toParent: self)
    }
}
