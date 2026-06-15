@attached(member, names: arbitrary)
public macro TinkerbleObservable() = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableMacro"
)

@attached(peer)
public macro TinkerbleObservableState(
    name: String,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleObservableState<Value: TinkerbleValueConvertible>(
    name: String,
    screen: String? = nil,
    category: String? = nil,
    control: TinkerbleControl<Value>
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleObservableState(
    category: String,
    name: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleObservableState<Value: TinkerbleValueConvertible>(
    category: String,
    name: String,
    screen: String? = nil,
    control: TinkerbleControl<Value>
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleObservableState(
    _ category: String,
    name: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleObservableState<Value: TinkerbleValueConvertible>(
    _ category: String,
    name: String,
    screen: String? = nil,
    control: TinkerbleControl<Value>
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleAction(
    name: String? = nil,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleActionMacro"
)

@attached(peer)
public macro TinkerbleAction(
    _ name: String,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleActionMacro"
)

@attached(peer)
public macro TinkerbleAction(
    category: String,
    name: String? = nil,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleActionMacro"
)

@attached(member, names: arbitrary)
public macro TinkerbleActions() = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleActionsMacro"
)
