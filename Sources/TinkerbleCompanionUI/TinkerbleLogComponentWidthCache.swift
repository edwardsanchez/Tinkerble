import CoreGraphics

struct TinkerbleLogComponentWidthCache: Equatable {
    private var widths: [String: CGFloat] = [:]

    func width(for key: String) -> CGFloat? {
        widths[key]
    }

    mutating func record(width: CGFloat, for key: String) {
        guard width > (widths[key] ?? 0) else { return }
        widths[key] = width
    }

    static func key(rowID: String, componentID: String) -> String {
        "\(rowID)/\(componentID)"
    }
}
