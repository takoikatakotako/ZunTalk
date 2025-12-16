import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var hasAgreedToTerms = false
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "bubble.left.and.bubble.right",
            title: "ZunTalkへようこそ",
            description: "AIとの会話を楽しみましょう"
        ),
        OnboardingPage(
            image: "person.2",
            title: "連絡先を選択",
            description: "話したい相手を選んで\n会話を始められます"
        ),
        OnboardingPage(
            image: "sparkles",
            title: "さあ、始めよう",
            description: "新しいコミュニケーション体験を\nお楽しみください"
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

            // ボタンエリア
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    // 最後のページ: 利用規約同意チェックボックス
                    Button(action: {
                        hasAgreedToTerms.toggle()
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(hasAgreedToTerms ? .blue : .gray)
                                .font(.title3)

                            TermsAgreementText()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // 始めるボタン
                    Button(action: {
                        onComplete()
                    }) {
                        Text("始める")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasAgreedToTerms ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!hasAgreedToTerms)
                } else {
                    // 途中のページ: 次へボタン
                    Button(action: {
                        withAnimation {
                            currentPage += 1
                        }
                    }) {
                        Text("次へ")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    // スキップボタン
                    Button(action: {
                        withAnimation {
                            currentPage = pages.count - 1
                        }
                    }) {
                        Text("スキップ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.image)
                .font(.system(size: 100))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Terms Agreement Text

struct TermsAgreementText: View {
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                openTermsURL()
            }) {
                Text("利用規約")
                    .underline()
            }

            Text("と")
                .foregroundColor(.primary)

            Button(action: {
                openPrivacyURL()
            }) {
                Text("プライバシーポリシー")
                    .underline()
            }

            Text("に同意する")
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }

    private func openTermsURL() {
        if let url = URL(string: "https://takoikatakotako.github.io/projects/zuntalk/terms.html") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacyURL() {
        if let url = URL(string: "https://takoikatakotako.github.io/projects/zuntalk/privacy.html") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
