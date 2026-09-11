enum DeviceType: Hashable, CaseIterable {
    case output
    case input

    var paneTitle: String {
        switch self {
        case .output: "Output"
        case .input: "Input"
        }
    }
}
