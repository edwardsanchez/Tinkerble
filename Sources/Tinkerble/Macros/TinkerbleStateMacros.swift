@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState(
    _ name: String,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState<Control: TinkerbleControlExpression>(
    _ name: String,
    screen: String? = nil,
    category: String? = nil,
    control: Control
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleState(\"Name\", screen: ..., category: ...) instead.")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState(
    name: String,
    screen: String? = nil,
    category: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleState(\"Name\", screen: ..., category: ..., control: ...) instead.")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState<Control: TinkerbleControlExpression>(
    name: String,
    screen: String? = nil,
    category: String? = nil,
    control: Control
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleState(\"Name\", category: \"Category\") instead.")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState(
    category: String,
    name: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleState(\"Name\", category: \"Category\", control: ...) instead.")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState<Control: TinkerbleControlExpression>(
    category: String,
    name: String,
    screen: String? = nil,
    control: Control
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleState(\"Name\", category: \"Category\"). The unlabeled argument is now the tweak name.")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState(
    _ category: String,
    name: String,
    screen: String? = nil
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@available(*, deprecated, message: "Use @TinkerbleState(\"Name\", category: \"Category\", control: ...). The unlabeled argument is now the tweak name.")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`))
public macro TinkerbleState<Control: TinkerbleControlExpression>(
    _ category: String,
    name: String,
    screen: String? = nil,
    control: Control
) = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateMacro"
)

@attached(accessor, names: named(get), named(set))
public macro _TinkerbleStateBacking() = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateBackingMacro"
)

@attached(accessor, names: named(get))
public macro _TinkerbleStateProjected() = #externalMacro(
    module: "TinkerbleMacros",
    type: "TinkerbleStateProjectedMacro"
)
