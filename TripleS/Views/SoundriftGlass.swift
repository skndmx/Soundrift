import SwiftUI

enum SoundriftGlass {
    static let cardShape = RoundedRectangle(
        cornerRadius: SoundriftTheme.groupedCornerRadius,
        style: .continuous
    )
    static let heroShape = RoundedRectangle(cornerRadius: 10, style: .continuous)
}

extension View {
    /// Floating Liquid Glass plate for grouped lists and settings cards.
    func soundriftGlassCard() -> some View {
        glassEffect(.regular, in: SoundriftGlass.cardShape)
    }

    /// Glass plate for the currently selected device. Untinted so names stay readable.
    func soundriftHeroGlass() -> some View {
        glassEffect(.regular.interactive(), in: SoundriftGlass.heroShape)
    }
}
