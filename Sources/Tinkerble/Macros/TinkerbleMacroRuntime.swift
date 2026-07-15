public extension Tinkerble {
    /// Publicly reachable runtime symbols used by Tinkerble's attached macro expansions.
    enum MacroRuntime {
        public typealias State<Value: TinkerbleValueConvertible> = TinkerbleState<Value>
        public typealias SourceAnchor = TinkerbleSourceAnchor
    }
}
