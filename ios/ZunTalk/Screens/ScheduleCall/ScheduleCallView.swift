import SwiftUI

/// ずんだもんからの電話を予約する画面。
struct ScheduleCallView: View {
    @StateObject private var viewModel = ScheduleCallViewModel()

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "時刻",
                    selection: $viewModel.selectedDate,
                    in: viewModel.selectableRange
                )
                .datePickerStyle(.compact)

                Button(action: {
                    Task {
                        await viewModel.scheduleCall()
                    }
                }) {
                    HStack {
                        Spacer()
                        if viewModel.isScheduling {
                            ProgressView()
                        } else {
                            Text("予約する")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isScheduling)
            } header: {
                Text("ずんだもんから電話をかけてもらう")
            } footer: {
                Text("指定した時刻になると、ずんだもんから電話がかかってくるのだ。")
            }

            Section {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.calls.isEmpty {
                    Text("予約はまだないのだ")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.calls) { call in
                        HStack {
                            Image(systemName: "phone.arrow.down.left")
                                .foregroundStyle(.green)
                            Text(formattedDate(call))
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.cancelCall(call)
                                }
                            } label: {
                                Label("キャンセル", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("予約一覧")
            } footer: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("電話の予約")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
    }

    private func formattedDate(_ call: ScheduledCall) -> String {
        guard let date = call.scheduledDate else { return call.scheduledAt }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ScheduleCallView()
    }
}
