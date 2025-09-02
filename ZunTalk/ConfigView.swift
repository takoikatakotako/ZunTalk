import SwiftUI

struct ConfigView: View {
    var body: some View {
        ZStack {
            Color(.callBackground)
                .ignoresSafeArea()
            
            VStack {
                Text("設定")
                    .foregroundStyle(Color.white)
                    .font(Font.system(size: 32).bold())
                    .padding(.top, 24)
                
                Spacer()
                
                Text("設定画面を実装中...")
                    .foregroundStyle(Color.white)
                    .font(Font.system(size: 18))
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ConfigView()
}