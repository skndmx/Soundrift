import SwiftUI

struct ContentCardBackground: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func contentCardBackground(cornerRadius: CGFloat = 10) -> some View {
        modifier(ContentCardBackground(cornerRadius: cornerRadius))
    }
}
