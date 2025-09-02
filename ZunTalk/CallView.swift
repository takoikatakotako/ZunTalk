import SwiftUI

struct CallView: View {
    @StateObject private var viewModel = CallViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.callBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Image(.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 240)
                    .clipShape(Circle())
                
                Text("ずんだもん")
                    .foregroundStyle(Color.white)
                    .font(Font.system(size: 48).bold())
                    .padding(.top, 36)
                
                
                Spacer()
                
                Text(viewModel.text)
                    .foregroundStyle(Color.white)
                    .font(Font.system(size: 24))
                    .padding(.horizontal, 36)
                
                Spacer()
                
                HStack(spacing: 112) {
                    Button(action: {
                        dismiss()
                    }) {
                        ZStack {
                            Color(.red)
                            Text(.init(systemName: "phone.down.fill"))
                                .foregroundStyle(Color.white)
                                .font(Font.system(size: 48).bold())
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    }
                    
                }
            }
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview {
    CallView()
}
