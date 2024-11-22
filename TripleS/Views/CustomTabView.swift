import SwiftUI

struct CustomTabView: View {
    private let titles: [String]
    private let icons: [String]
    private let tabViews: [AnyView]
    
    @State private var selection = 0
    @State private var indexHovered = -1
    
    init(content: [(title: String, icon: String, view: AnyView)]) {
        self.titles = content.map{ $0.title }
        self.icons = content.map{ $0.icon }
        self.tabViews = content.map{ $0.view }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            Spacer()
            ForEach(0..<titles.count, id: \.self) { index in
                VStack {
                    Image(systemName: self.icons[index])
                        .font(.largeTitle)
                    Text(self.titles[index])
                        .font(.subheadline)
                }
                .frame(width: 150)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(((self.selection == index) || (self.indexHovered == index)) ? 0.2 : 0))
                )
                .foregroundColor(self.selection == index ? Color("SettingsV4") : Color("SettingsV5"))
                .onHover(perform: { hovering in
                    indexHovered = hovering ? index : -1
                })
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selection = index
                    }
                }
            }
            Spacer()
        }
        .background(Color("SettingsV1"))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            
            tabViews[selection]
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("MainBackground"))
        }
    }
} 