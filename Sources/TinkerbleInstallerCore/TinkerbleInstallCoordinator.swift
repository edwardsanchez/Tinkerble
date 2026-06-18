import Foundation

public struct TinkerbleInstallCoordinator {
    private let fileManager: FileManager
    private let currentDirectory: URL
    private let standardInput: () -> String?
    private let standardOutput: (String) -> Void

    public init(
        fileManager: FileManager = .default,
        currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        standardInput: @escaping () -> String? = { readLine() },
        standardOutput: @escaping (String) -> Void = { print($0) }
    ) {
        self.fileManager = fileManager
        self.currentDirectory = currentDirectory
        self.standardInput = standardInput
        self.standardOutput = standardOutput
    }

    public func install(options: InstallCommandOptions) throws -> TinkerbleInstallResult {
        let projectURL = try selectedProjectURL(options: options)
        let project = try XcodeProjectInstaller(projectURL: projectURL)
        let appTargets = try project.appTargetNames
        guard !appTargets.isEmpty else {
            throw TinkerbleInstallError.noTargetsFound
        }

        let selectedTargets: [String]
        if options.targetNames.isEmpty {
            selectedTargets = try promptForTargets(appTargets)
        } else {
            selectedTargets = options.targetNames
        }

        let result = try project.install(
            targetNames: selectedTargets,
            schemeNames: options.schemeNames,
            dryRun: options.isDryRun
        )
        if options.isDryRun {
            standardOutput("Dry run: no files changed.")
        }
        result.changes.forEach(standardOutput)
        return result
    }

    private func selectedProjectURL(options: InstallCommandOptions) throws -> URL {
        if let projectPath = options.projectPath {
            return resolvedURL(projectPath)
        }

        if let workspacePath = options.workspacePath {
            let workspaceURL = resolvedURL(workspacePath)
            let projects = try projects(inWorkspace: workspaceURL)
            if projects.count == 1 {
                return projects[0]
            }

            if projects.isEmpty {
                throw TinkerbleInstallError.unsupportedWorkspace(workspacePath)
            }

            throw TinkerbleInstallError.multipleProjectsFound(projects.map(\.lastPathComponent).sorted())
        }

        let projects = try discoveredProjects()
        if projects.isEmpty {
            throw TinkerbleInstallError.noProjectFound
        }

        if projects.count == 1 {
            return projects[0]
        }

        throw TinkerbleInstallError.multipleProjectsFound(projects.map(\.lastPathComponent).sorted())
    }

    private func projects(inWorkspace workspaceURL: URL) throws -> [URL] {
        let contentsURL = workspaceURL
            .appending(path: "contents.xcworkspacedata")
        let fallbackContentsURL = workspaceURL
            .appending(path: "xcshareddata")
            .appending(path: "contents.xcworkspacedata")
        let resolvedContentsURL = fileManager.fileExists(atPath: contentsURL.path) ? contentsURL : fallbackContentsURL
        let contents = try String(contentsOf: resolvedContentsURL, encoding: .utf8)
        let workspaceDirectory = workspaceURL.deletingLastPathComponent()
        var projects: [URL] = []

        for line in contents.split(separator: "\n") {
            guard line.contains("location") && line.contains(".xcodeproj") else {
                continue
            }

            guard let location = line.locationAttribute else {
                continue
            }

            let path = location
                .replacing("group:", with: "")
                .replacing("self:", with: "")
                .replacing("container:", with: "")
            let projectURL = URL(fileURLWithPath: path, relativeTo: workspaceDirectory).standardizedFileURL
            if !projects.contains(projectURL) {
                projects.append(projectURL)
            }
        }

        return projects.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func discoveredProjects() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: currentDirectory,
            includingPropertiesForKeys: nil
        )

        return contents
            .filter { $0.pathExtension == "xcodeproj" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func resolvedURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        return currentDirectory.appending(path: path).standardizedFileURL
    }

    private func promptForTargets(_ targets: [String]) throws -> [String] {
        if targets.count == 1 {
            return targets
        }

        standardOutput("Select Tinkerble targets:")
        for (offset, target) in targets.enumerated() {
            standardOutput("\(offset + 1). \(target)")
        }
        standardOutput("Enter target numbers, for example 1,3-4:")

        guard let answer = standardInput(), !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TinkerbleInstallError.nonInteractiveSelectionRequired(targets)
        }

        return try MultiSelectionParser.parse(answer, choices: targets)
    }

}

private extension String.SubSequence {
    var locationAttribute: String? {
        guard let keyRange = range(of: "location = \"") else {
            return nil
        }

        let valueStart = keyRange.upperBound
        guard let valueEnd = self[valueStart...].firstIndex(of: "\"") else {
            return nil
        }

        return String(self[valueStart..<valueEnd])
    }
}

public enum MultiSelectionParser {
    public static func parse(_ input: String, choices: [String]) throws -> [String] {
        let parts = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var selectedIndexes: [Int] = []

        for part in parts {
            if part.contains("-") {
                let bounds = part.split(separator: "-", omittingEmptySubsequences: false)
                guard bounds.count == 2,
                      let start = Int(bounds[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let end = Int(bounds[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                      start <= end else {
                    throw TinkerbleInstallError.invalidArguments("Invalid target selection: \(part)")
                }

                selectedIndexes.append(contentsOf: start...end)
            } else if let index = Int(part) {
                selectedIndexes.append(index)
            } else {
                throw TinkerbleInstallError.invalidArguments("Invalid target selection: \(part)")
            }
        }

        var selected: [String] = []
        for index in selectedIndexes {
            guard choices.indices.contains(index - 1) else {
                throw TinkerbleInstallError.invalidArguments("Target selection out of range: \(index)")
            }

            let choice = choices[index - 1]
            if !selected.contains(choice) {
                selected.append(choice)
            }
        }

        guard !selected.isEmpty else {
            throw TinkerbleInstallError.invalidArguments("Select at least one target.")
        }

        return selected
    }
}
