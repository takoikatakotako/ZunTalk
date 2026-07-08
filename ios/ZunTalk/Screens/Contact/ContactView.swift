import SwiftUI

struct Contact {
    let id = UUID()
    let name: String
    let imageName: String
}

struct ContactView: View {
    let contacts = [
        Contact(name: "ずんだもん", imageName: "person.circle.fill"),
    ]

    @State private var isNavigatingToChat = false
    @State private var isNavigatingToCall = false
    @State private var isNavigatingToAgent = false
    @State private var isNavigatingToScheduleCall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List(contacts, id: \.id) { contact in
                    HStack(spacing: 16) {
                        Image(.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.name)
                                .font(.headline)
                                .lineLimit(1)
                                .fixedSize()

                            Text("ずんだの妖精")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .fixedSize()
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 8) {
                            Button(action: {
                                isNavigatingToChat = true
                            }) {
                                Image(systemName: "message.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 15))
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }

                            Button(action: {
                                isNavigatingToCall = true
                            }) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 15))
                                    .frame(width: 32, height: 32)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }

                            if FeatureFlags.agentModeEnabled {
                                Button(action: {
                                    isNavigatingToAgent = true
                                }) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 15))
                                        .frame(width: 32, height: 32)
                                        .background(Color.purple)
                                        .clipShape(Circle())
                                }
                            }

                            Button(action: {
                                isNavigatingToScheduleCall = true
                            }) {
                                Image(systemName: "alarm.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 15))
                                    .frame(width: 32, height: 32)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
                .listStyle(.plain)
                .buttonStyle(PlainButtonStyle())

                AdBannerView()
            }
            .background(Color.white)
            .navigationTitle("連絡先")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $isNavigatingToChat) {
                ChatView()
            }
            .navigationDestination(isPresented: $isNavigatingToCall) {
                CallView()
            }
            .navigationDestination(isPresented: $isNavigatingToAgent) {
                AgentView()
            }
            .navigationDestination(isPresented: $isNavigatingToScheduleCall) {
                ScheduleCallView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ConfigView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.blue)
                            .font(Font.system(size: 18).bold())
                    }
                }
            }
        }
    }
}

#Preview {
    ContactView()
}
