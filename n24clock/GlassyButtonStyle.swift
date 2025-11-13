import SwiftUI

struct GlassyButtonModifier: ViewModifier {
    enum Kind {
        case bordered
        case borderedProminent
    }

    let kind: Kind

    func body(content: Content) -> some View {
        switch kind {
        case .bordered:
            bordered(content)
        case .borderedProminent:
            prominent(content)
        }
    }

    @ViewBuilder
    private func bordered(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.bordered)
                .glassEffect(.regular)
        } else {
            content.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func prominent(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.borderedProminent)
                .glassEffect(.regular)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

extension View {
    func glassyButtonStyle(_ kind: GlassyButtonModifier.Kind) -> some View {
        modifier(GlassyButtonModifier(kind: kind))
    }
}
