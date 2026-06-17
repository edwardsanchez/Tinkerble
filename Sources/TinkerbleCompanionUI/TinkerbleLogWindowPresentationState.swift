public struct TinkerbleLogWindowPresentationState {
    private var didOpenLogsWindow = false

    public init() {}

    public func shouldCloseLogsWindow(logCount: Int) -> Bool {
        logCount == 0
    }

    public mutating func shouldOpenLogsWindow(logCount: Int) -> Bool {
        guard !didOpenLogsWindow, logCount > 0 else {
            return false
        }

        didOpenLogsWindow = true
        return true
    }
}
