import Foundation
import TinkerbleInstallerCore

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    guard let command = arguments.first else {
        printHelp()
        exit(0)
    }

    switch command {
    case "install":
        let options = try InstallCommandParser.parse(Array(arguments.dropFirst()))
        if options.shouldShowHelp {
            printInstallHelp()
            exit(0)
        }

        _ = try TinkerbleInstallCoordinator().install(options: options)
    case "-h", "--help":
        printHelp()
    default:
        throw TinkerbleInstallError.invalidArguments("Unknown command: \(command)")
    }
} catch let error as TinkerbleInstallError {
    fputs("tinkerble: \(error.description)\n", stderr)
    exit(2)
} catch {
    fputs("tinkerble: \(error.localizedDescription)\n", stderr)
    exit(1)
}

private func printHelp() {
    print(
        """
        Usage: tinkerble <command>

        Commands:
          install    Install Tinkerble into an Xcode app target.
        """
    )
}

private func printInstallHelp() {
    print(
        """
        Usage: tinkerble install [--project PATH] [--workspace PATH] [--target NAME ...] [--dry-run]

        Options:
          --project PATH     Xcode project to edit.
          --workspace PATH   Xcode workspace context. Pass --project for the project to edit.
          --target NAME      App target to install into. Can be repeated.
          --dry-run          Print planned changes without writing project.pbxproj.
        """
    )
}
