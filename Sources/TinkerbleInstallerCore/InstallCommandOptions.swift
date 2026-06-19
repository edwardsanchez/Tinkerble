import Foundation

public struct InstallCommandOptions: Equatable, Sendable {
    public var projectPath: String?
    public var workspacePath: String?
    public var targetNames: [String]
    public var schemeNames: [String]
    public var isDryRun: Bool
    public var shouldShowHelp: Bool
    /// Whether to enable Xcode's `IDESkipMacroFingerprintValidation` default.
    /// `nil` asks interactively, `true`/`false` answer non-interactively.
    public var enableMacroTrust: Bool?

    public init(
        projectPath: String? = nil,
        workspacePath: String? = nil,
        targetNames: [String] = [],
        schemeNames: [String] = [],
        isDryRun: Bool = false,
        shouldShowHelp: Bool = false,
        enableMacroTrust: Bool? = nil
    ) {
        self.projectPath = projectPath
        self.workspacePath = workspacePath
        self.targetNames = targetNames
        self.schemeNames = schemeNames
        self.isDryRun = isDryRun
        self.shouldShowHelp = shouldShowHelp
        self.enableMacroTrust = enableMacroTrust
    }
}

public enum InstallCommandParser {
    public static func parse(_ arguments: [String]) throws -> InstallCommandOptions {
        var options = InstallCommandOptions()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--project":
                options.projectPath = try value(after: argument, in: arguments, advancing: &index)
            case "--workspace":
                options.workspacePath = try value(after: argument, in: arguments, advancing: &index)
            case "--target":
                options.targetNames.append(try value(after: argument, in: arguments, advancing: &index))
            case "--scheme":
                options.schemeNames.append(try value(after: argument, in: arguments, advancing: &index))
            case "--dry-run":
                options.isDryRun = true
            case "--enable-macro-trust":
                options.enableMacroTrust = true
            case "--skip-macro-trust":
                options.enableMacroTrust = false
            case "-h", "--help":
                options.shouldShowHelp = true
            default:
                if argument.hasPrefix("--") {
                    throw TinkerbleInstallError.invalidArguments("Unknown option: \(argument)")
                }

                throw TinkerbleInstallError.invalidArguments("Unexpected argument: \(argument)")
            }

            index += 1
        }

        return options
    }

    private static func value(after option: String, in arguments: [String], advancing index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw TinkerbleInstallError.invalidArguments("Missing value for \(option).")
        }

        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            throw TinkerbleInstallError.invalidArguments("Missing value for \(option).")
        }

        index = valueIndex
        return value
    }
}
