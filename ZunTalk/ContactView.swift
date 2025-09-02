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
    
    @State private var isNavigatingToText = false
    @State private var isNavigatingToCall = false
    
    var body: some View {
        NavigationView {
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
                        
                        Text("ずんだの妖精")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            isNavigatingToText = true
                        }) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .frame(width: 36, height: 36)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            isNavigatingToCall = true
                        }) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .frame(width: 36, height: 36)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.vertical, 4)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            .listStyle(.plain)
            .buttonStyle(PlainButtonStyle())
            .background(Color.white)
            .navigationTitle("連絡先")
            .navigationBarTitleDisplayMode(.large)
            .background {
                NavigationLink(destination: Text("XXXX"), isActive: $isNavigatingToText) {
                    EmptyView()
                }
                NavigationLink(destination: CallView(), isActive: $isNavigatingToCall) {
                    EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ConfigView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.black)
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
