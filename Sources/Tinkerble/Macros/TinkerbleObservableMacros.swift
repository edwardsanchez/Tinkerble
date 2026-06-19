@attached(member, names: arbitrary)
public macro TinkerbleObservable() = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableMacro"
)

@attached(peer)
public macro TinkerbleObservableState(
    _ name: String,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@attached(peer)
public macro TinkerbleObservableState<Value: TinkerbleValueConvertible>(
    _ name: String,
    screen: String? = nil,
    category: String? = nil,
    control: TinkerbleControl<Value>
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleObservableState(\"Name\", screen: ..., category: ...) instead.")
@attached(peer)
public macro TinkerbleObservableState(
    name: String,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleObservableState(\"Name\", screen: ..., category: ..., control: ...) instead.")
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

@available(*, deprecated, message: "Use @TinkerbleObservableState(\"Name\", category: \"Category\") instead.")
@attached(peer)
public macro TinkerbleObservableState(
    category: String,
    name: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleObservableState(\"Name\", category: \"Category\", control: ...) instead.")
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

@available(*, deprecated, message: "Use @TinkerbleObservableState(\"Name\", category: \"Category\"). The unlabeled argument is now the tweak name.")
@attached(peer)
public macro TinkerbleObservableState(
    _ category: String,
    name: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleObservableStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleObservableState(\"Name\", category: \"Category\", control: ...). The unlabeled argument is now the tweak name.")
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
public macro TinkerbleAction() = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleActionMacro"
)

@attached(peer)
public macro TinkerbleAction(
    category: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleActionMacro"
)

@available(*, deprecated, message: "Use @TinkerbleAction(\"Name\", screen: ..., category: ...) instead.")
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

@available(*, deprecated, message: "Use @TinkerbleAction(\"Name\", category: \"Category\") instead.")
@attached(peer)
public macro TinkerbleAction(
    category: String,
    name: String?,
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
