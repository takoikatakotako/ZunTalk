import FirebaseAnalytics

enum AnalyticsManager {
    static func logOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }

    static func logChatStarted() {
        Analytics.logEvent("chat_started", parameters: nil)
    }

    static func logMessageSent(messageCount: Int) {
        Analytics.logEvent("message_sent", parameters: [
            "message_count": messageCount
        ])
    }
}
