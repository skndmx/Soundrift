import SwiftUI

struct ContentCardBackground: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func contentCardBackground(cornerRadius: CGFloat = 10) -> some View {
        modifier(ContentCardBackground(cornerRadius: cornerRadius))
    }
}
