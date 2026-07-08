import SwiftUI
import UIKit

/// 設定画面の「カレンダー連携」セクション。
/// EventKit（iOS 標準カレンダー）へのアクセス状態を表示し、許可を促す。
struct CalendarLinkSection: View {
    @StateObject private var access = CalendarAccessManager.shared

    var body: some View {
        Section {
            switch access.status {
            case .authorized:
                HStack {
                    Label("カレンダー", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text("許可済み")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    openSettings()
                } label: {
                    Label("設定アプリで許可を解除", systemImage: "gear")
                }

            case .notDetermined:
                Button {
                    Task { await access.requestAccess() }
                } label: {
                    HStack {
                        Label("カレンダーと連携", systemImage: "calendar.badge.plus")
                        Spacer()
                        if access.isRequesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(access.isRequesting)

            case .denied:
                HStack {
                    Label("カレンダー", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("未許可")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button {
                    openSettings()
                } label: {
                    Label("設定アプリで許可する", systemImage: "gear")
                }
            }
        } header: {
            Text("連携")
        } footer: {
            Text("エージェントが予定を確認するのに使います。iOS 標準カレンダーの予定を端末内で読み取ります。iOS 設定に Google アカウントを追加していれば、Google カレンダーの予定も対象になります。")
        }
        .onAppear {
            access.refresh()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
