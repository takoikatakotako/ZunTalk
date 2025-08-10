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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.callBackground)
                    .ignoresSafeArea()
                
                VStack {
                    Text("連絡先")
                        .foregroundStyle(Color.white)
                        .font(Font.system(size: 32).bold())
                        .padding(.top, 24)
                    
                    List(contacts, id: \.id) { contact in
                        ContactRowView(contact: contact)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
}

struct ContactRowView: View {
    let contact: Contact
    @State private var isNavigatingToCall = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: contact.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .foregroundStyle(Color.white)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
            
            Text(contact.name)
                .foregroundStyle(Color.white)
                .font(Font.system(size: 20).bold())
            
            Spacer()
            
            ZStack {
                NavigationLink(
                    destination: CallView(),
                    isActive: $isNavigatingToCall
                ) {
                    EmptyView()
                }
                .opacity(0)
                
                Button(action: {
                    isNavigatingToCall = true
                }) {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(Color.white)
                        .font(Font.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    ContactView()
}
