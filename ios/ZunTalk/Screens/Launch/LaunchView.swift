import SwiftUI

struct LaunchView: View {
    @StateObject private var viewModel = LaunchViewModel()
    @State private var hasCompletedOnboarding = UserDefaultsRepository().hasCompletedOnboarding

    var body: some View {
        Group {
            switch viewModel.appStatus {
            case .loading:
                LoadingView()
            case .ready:
                if hasCompletedOnboarding {
                    ContactView()
                } else {
                    OnboardingView {
                        var repository = UserDefaultsRepository()
                        repository.hasCompletedOnboarding = true
                        hasCompletedOnboarding = true
                    }
                }
            case .maintenance:
                MaintenanceView()
            case .updateRequired(let currentVersion, let minimumVersion):
                UpdateRequiredView(
                    currentVersion: currentVersion,
                    minimumVersion: minimumVersion,
                    onUpdateTapped: {
                        viewModel.openAppStore()
                    }
                )
            case .error(let message):
                ErrorView(message: message) {
                    Task {
                        await viewModel.checkAppStatus()
                    }
                }
            }
        }
        .task {
            await viewModel.checkAppStatus()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Maintenance View

struct MaintenanceView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("メンテナンス中")
                .font(.title)
                .fontWeight(.bold)

            Text("現在メンテナンスを行っています。\nしばらくお待ちください。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Update Required View

struct UpdateRequiredView: View {
    let currentVersion: String
    let minimumVersion: String
    let onUpdateTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.app")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("アップデートが必要です")
                .font(.title)
                .fontWeight(.bold)

            Text("新しいバージョンがリリースされています。\nApp Storeからアップデートしてください。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("現在のバージョン: \(currentVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("必要なバージョン: \(minimumVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onUpdateTapped) {
                Text("App Storeを開く")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("エラーが発生しました")
                .font(.title)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Text("再試行")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LaunchView()
}
