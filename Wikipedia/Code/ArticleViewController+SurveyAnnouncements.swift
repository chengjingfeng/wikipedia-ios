import Foundation

extension ArticleViewController {
    
	func startSurveyAnnouncementTimer(withTimeInterval customTimeInterval: TimeInterval? = nil) {
        
        guard let surveyAnnouncementResult = surveyAnnouncementResult else {
            return
        }
        
        shouldPauseSurveyTimerOnBackground = true

        let timeInterval = customTimeInterval ?? surveyAnnouncementResult.displayDelay
		surveyAnnouncementTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self] (timer) in
            
            guard let self = self else {
                return
            }
            
            self.showSurveyAnnouncementPanel(surveyAnnouncementResult: surveyAnnouncementResult)
            
            self.stopSurveyAnnouncementTimer()
            self.shouldPauseSurveyTimerOnBackground = false
        })
    }
    
    private func showSurveyAnnouncementPanel(surveyAnnouncementResult: SurveyAnnouncementsController.SurveyAnnouncementResult) {
        
        guard state == .loaded else {
            return
        }
        
        wmf_showAnnouncementPanel(announcement: surveyAnnouncementResult.announcement, style: .minimal, primaryButtonTapHandler: { (sender) in
            self.navigate(to: surveyAnnouncementResult.actionURL, useSafari: true)
            // dismiss handler is called
        }, secondaryButtonTapHandler: { (sender) in
            // dismiss handler is called
        }, footerLinkAction: { (url) in
             self.navigate(to: url, useSafari: true)
            // intentionally don't dismiss
        }, traceableDismissHandler: { lastAction in
            switch lastAction {
            case .tappedBackground, .tappedClose, .tappedSecondary:
                SurveyAnnouncementsController.shared.markSurveyAnnouncementAnswer(false, campaignIdentifier: surveyAnnouncementResult.campaignIdentifier)
            case .tappedPrimary:
                SurveyAnnouncementsController.shared.markSurveyAnnouncementAnswer(true, campaignIdentifier: surveyAnnouncementResult.campaignIdentifier)
            case .none:
                assertionFailure("Unexpected lastAction in Panel dismissHandler")
                break
            }
        }, theme: self.theme)
    }
    
    func stopSurveyAnnouncementTimer() {
        surveyAnnouncementTimer?.invalidate()
        surveyAnnouncementTimer = nil
    }

    func pauseSurveyAnnouncementTimer() {
        guard surveyAnnouncementTimer != nil,
        shouldPauseSurveyTimerOnBackground else {
            return
        }

        surveyAnnouncementTimerTimeIntervalRemainingWhenBackgrounded = calculateRemainingSurveyAnnouncementTimerTimeInterval()
        stopSurveyAnnouncementTimer()
    }

	func resumeSurveyAnnouncementTimer() {
		guard surveyAnnouncementTimer == nil,
        shouldResumeSurveyTimerOnForeground else {
			return
		}

		startSurveyAnnouncementTimer(withTimeInterval: surveyAnnouncementTimerTimeIntervalRemainingWhenBackgrounded)
	}

    /// Calculate remaining TimeInterval (if any) until survey timer fire date
    fileprivate func calculateRemainingSurveyAnnouncementTimerTimeInterval() -> TimeInterval? {
        guard let timer = surveyAnnouncementTimer else {
            return nil
        }

        let remainingTime = timer.fireDate.timeIntervalSince(Date())
        return remainingTime < 0 ? nil : remainingTime
    }

}
