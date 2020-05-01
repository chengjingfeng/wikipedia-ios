
import Foundation

class ArticleSurveyTimerController {
    
    private var surveyAnnouncementResult: SurveyAnnouncementsController.SurveyAnnouncementResult? {
        guard let articleTitle = articleURL.wmf_title?.denormalizedPageTitle,
            let siteURL = articleURL.wmf_site else {
                return nil
        }

        return SurveyAnnouncementsController.shared.activeSurveyAnnouncementResultForTitle(articleTitle, siteURL: siteURL)
    }
    private let articleURL: URL
    private let surveyController: SurveyAnnouncementsController
    var timerFireBlock: ((SurveyAnnouncementsController.SurveyAnnouncementResult) -> Void)?
    private var surveyAnnouncementTimer: Timer?
    private var surveyAnnouncementTimerTimeIntervalRemainingWhenBackgrounded: TimeInterval?
    private var shouldPauseSurveyTimerOnBackground = false
    private var shouldResumeSurveyTimerOnForeground: Bool { return shouldPauseSurveyTimerOnBackground }
    
    init(articleURL: URL, surveyController: SurveyAnnouncementsController) {
        self.articleURL = articleURL
        self.surveyController = surveyController
    }
    
    func contentDidLoad() {
        startSurveyAnnouncementTimer()
    }
    
    func viewWillAppear(withState state: ArticleViewController.ViewState) {
        //if user pushes on to next screen on stack, then goes back, restart timer from 0 if survey has not been seen yet.
        if state == .loaded {
            //recalculate, if survey was seen already on another page this will flip surveyAnnouncementResult to nil
            if surveyAnnouncementResult != nil {
                shouldPauseSurveyTimerOnBackground = true
                startSurveyAnnouncementTimer()
            }
        }
    }
    
    func viewWillDisappear(withState state: ArticleViewController.ViewState) {
        if state == .loaded && surveyAnnouncementResult != nil {
            //do not listen for background/foreground notifications to pause and resume survey if this article is not on screen anymore
            shouldPauseSurveyTimerOnBackground = false
            stopSurveyAnnouncementTimer()
        }
    }
    
    func willResignActive(withState state: ArticleViewController.ViewState) {
        if state == .loaded,
            shouldPauseSurveyTimerOnBackground {
            pauseSurveyAnnouncementTimer()
        }
    }
    
    func didBecomeActive(withState state: ArticleViewController.ViewState) {
        if state == .loaded,
            shouldResumeSurveyTimerOnForeground {
            resumeSurveyAnnouncementTimer()
        }
    }
    
    private func startSurveyAnnouncementTimer(withTimeInterval customTimeInterval: TimeInterval? = nil) {
        
        guard let surveyAnnouncementResult = surveyAnnouncementResult else {
            return
        }
        
        shouldPauseSurveyTimerOnBackground = true

        let timeInterval = customTimeInterval ?? surveyAnnouncementResult.displayDelay
        surveyAnnouncementTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self] (timer) in
            
            guard let self = self else {
                return
            }
            
            self.timerFireBlock?(surveyAnnouncementResult)

            self.stopSurveyAnnouncementTimer()
            self.shouldPauseSurveyTimerOnBackground = false
        })
    }
    
    private func stopSurveyAnnouncementTimer() {
        surveyAnnouncementTimer?.invalidate()
        surveyAnnouncementTimer = nil
    }

    private func pauseSurveyAnnouncementTimer() {
        guard surveyAnnouncementTimer != nil,
        shouldPauseSurveyTimerOnBackground else {
            return
        }

        surveyAnnouncementTimerTimeIntervalRemainingWhenBackgrounded = calculateRemainingSurveyAnnouncementTimerTimeInterval()
        stopSurveyAnnouncementTimer()
    }

    private func resumeSurveyAnnouncementTimer() {
        guard surveyAnnouncementTimer == nil,
        shouldResumeSurveyTimerOnForeground else {
            return
        }

        startSurveyAnnouncementTimer(withTimeInterval: surveyAnnouncementTimerTimeIntervalRemainingWhenBackgrounded)
    }

    /// Calculate remaining TimeInterval (if any) until survey timer fire date
    private func calculateRemainingSurveyAnnouncementTimerTimeInterval() -> TimeInterval? {
        guard let timer = surveyAnnouncementTimer else {
            return nil
        }

        let remainingTime = timer.fireDate.timeIntervalSince(Date())
        return remainingTime < 0 ? nil : remainingTime
    }
}
