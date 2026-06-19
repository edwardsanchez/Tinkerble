import XCTest
@testable import TinkerbleInstallerCore

final class XcodeProjectInstallerTests: XCTestCase {
    func testInstallsPackageProductPlistSettingsAndBuildPhaseForMultipleTargets() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertEqual(try installer.appTargetNames, ["AdminApp", "MainApp"])

        let result = try installer.install(targetNames: ["MainApp", "AdminApp"], dryRun: false)

        XCTAssertFalse(result.isDryRun)
        XCTAssertEqual(result.targetNames, ["MainApp", "AdminApp"])
    }

    func testInstallIsIdempotent() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp", "AdminApp"], dryRun: false)
        let once = try readProject(projectURL)
        let schemeOnce = try readScheme(projectURL, name: "MainApp")
        let tinkerbleSchemeOnce = try readScheme(projectURL, name: "MainApp + Tinkerble")
        _ = try installer.install(targetNames: ["MainApp", "AdminApp"], dryRun: false)
        let twice = try readProject(projectURL)
        let schemeTwice = try readScheme(projectURL, name: "MainApp")
        let tinkerbleSchemeTwice = try readScheme(projectURL, name: "MainApp + Tinkerble")

        XCTAssertEqual(twice, once)
        XCTAssertEqual(schemeTwice, schemeOnce)
        XCTAssertEqual(tinkerbleSchemeTwice, tinkerbleSchemeOnce)
    }

    func testDryRunDoesNotWriteProject() throws {
        let projectURL = try makeFixtureProject()
        let before = try readProject(projectURL)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        let result = try installer.install(targetNames: ["MainApp"], dryRun: true)
        let after = try readProject(projectURL)
        let scheme = try readScheme(projectURL, name: "MainApp")

        XCTAssertTrue(result.isDryRun)
        XCTAssertEqual(after, before)
        XCTAssertEqual(scheme, fixtureScheme)
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectURL.appending(path: "xcshareddata/xcschemes/MainApp + Tinkerble.xcscheme").path))
    }

    func testInstallsIntoProjectWithoutExistingSwiftPackageLists() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithoutPackageLists)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        let result = try installer.install(targetNames: ["MainApp"], dryRun: false)

        XCTAssertFalse(result.isDryRun)
        XCTAssertEqual(result.targetNames, ["MainApp"])
    }

    func testInstallerReusesExistingLocalPackageProduct() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithLocalTinkerblePackage)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let packageReferences = packageReferenceSummary(in: try readProject(projectURL))
        XCTAssertEqual(packageReferences.localNames, ["XCLocalSwiftPackageReference \"..\""])
        XCTAssertEqual(packageReferences.remoteNames, [])
    }

    func testInstallerUsesExistingInfoPlistLocalNetworkEntries() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithInfoPlistFile)
        try writeFixtureInfoPlist(for: projectURL)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let project = try readProject(projectURL)
        XCTAssertEqual(buildSettingValues(named: "INFOPLIST_KEY_NSLocalNetworkUsageDescription", in: project), [])
        XCTAssertEqual(buildSettingValues(named: "INFOPLIST_KEY_NSBonjourServices", in: project), [])
    }

    func testInstallerPreservesExistingInfoPlistUsageDescriptionWhenAddingBonjourService() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithInfoPlistFile)
        try writeFixtureInfoPlist(
            for: projectURL,
            propertyList: [
                "NSLocalNetworkUsageDescription": "Custom app-specific network message."
            ]
        )
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let plist = try readInfoPlist(projectURL, path: "MainApp/Info.plist")
        XCTAssertEqual(plist["NSLocalNetworkUsageDescription"] as? String, "Custom app-specific network message.")
        XCTAssertEqual(plist["NSBonjourServices"] as? [String], [TinkerbleInstallerConstants.bonjourService])
    }

    func testInstallerCreatesExplicitInfoPlistForGeneratedPlistProject() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithGeneratedInfoPlist)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let project = try readProject(projectURL)
        let plist = try readInfoPlist(projectURL, path: "MainApp/Info.plist")

        XCTAssertEqual(buildSettingValues(named: "GENERATE_INFOPLIST_FILE", in: project), ["NO", "NO"])
        XCTAssertEqual(buildSettingValues(named: "INFOPLIST_FILE", in: project), ["MainApp/Info.plist", "MainApp/Info.plist"])
        XCTAssertEqual(plist["NSBonjourServices"] as? [String], [TinkerbleInstallerConstants.bonjourService])
        XCTAssertEqual(plist["NSLocalNetworkUsageDescription"] as? String, TinkerbleInstallerConstants.localNetworkUsageDescription)
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "$(EXECUTABLE_NAME)")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "$(PRODUCT_BUNDLE_IDENTIFIER)")
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "Main App")
        XCTAssertNotNil(plist["UIApplicationSceneManifest"] as? [String: Any])
        XCTAssertNotNil(plist["UILaunchScreen"] as? [String: Any])
    }

    func testInstallerPreservesGeneratedBonjourServicesWhenCreatingExplicitInfoPlist() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithGeneratedBonjourServices)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let plist = try readInfoPlist(projectURL, path: "MainApp/Info.plist")
        XCTAssertEqual(plist["NSBonjourServices"] as? [String], ["_existing._tcp", TinkerbleInstallerConstants.bonjourService])
    }

    func testInstallerFailsWhenConfiguredExplicitInfoPlistCannotBeRead() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithInfoPlistFile)
        let before = try readProject(projectURL)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertThrowsError(try installer.install(targetNames: ["MainApp"], dryRun: false)) { error in
            XCTAssertEqual(
                error as? TinkerbleInstallError,
                .malformedProject("Could not read configured Info.plist at MainApp/Info.plist.")
            )
        }
        XCTAssertEqual(try readProject(projectURL), before)
    }

    func testInstallerExcludesCreatedInfoPlistFromSynchronizedFolderTargetMembership() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithSynchronizedFolder)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let project = try readProject(projectURL)
        let exceptions = fileSystemMembershipExceptions(in: project, targetID: "000000000000000000000030")

        XCTAssertEqual(exceptions, ["Info.plist"])
    }

    func testInstallerCreatesRunSchemeWithoutTargetBuildPhase() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let target = try XCTUnwrap(ProjectText(try readProject(projectURL)).nativeTarget(named: "MainApp"))
        XCTAssertEqual(target.buildPhaseIDs, ["000000000000000000000010"])

        let originalScheme = try SchemeDocument(text: readScheme(projectURL, name: "MainApp"))
        let tinkerbleScheme = try SchemeDocument(text: readScheme(projectURL, name: "MainApp + Tinkerble"))

        XCTAssertFalse(originalScheme.containsElement(named: "ActionContent", attributes: ["title": "Launch Tinkerble Companion"]))
        XCTAssertTrue(
            tinkerbleScheme.containsElement(
                named: "ActionContent",
                attributes: ["title": "Launch Tinkerble Companion"],
                pathSuffix: ["Scheme", "BuildAction", "PreActions", "ExecutionAction", "ActionContent"]
            )
        )
        XCTAssertTrue(tinkerbleScheme.containsElement(named: "BuildableReference", attributes: ["BlueprintIdentifier": "000000000000000000000030"]))
    }

    func testGeneratedRunSchemeLaunchScriptRunsWithSh() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let scheme = try SchemeDocument(text: readScheme(projectURL, name: "MainApp + Tinkerble"))
        let script = try XCTUnwrap(
            scheme.attribute(
                named: "scriptText",
                fromElementNamed: "ActionContent",
                matching: ["title": "Launch Tinkerble Companion"]
            )
        )
        let sourceRoot = projectURL.deletingLastPathComponent().appending(path: "SourceRoot")
        let packageURL = sourceRoot.appending(path: "Tinkerble")
        let scriptURL = packageURL.appending(path: "Scripts/ensure-macos-companion-running.sh")
        let scratchURL = packageURL.appending(path: ".build/tinkerble-companion")
        let argumentsURL = scratchURL.appending(path: "arguments.txt")
        let environmentURL = scratchURL.appending(path: "environment.txt")
        try FileManager.default.createDirectory(
            at: scriptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"""
        #!/bin/sh
        mkdir -p "${TINKERBLE_COMPANION_SCRATCH_PATH}"
        printf "%s" "$*" > "${TINKERBLE_COMPANION_SCRATCH_PATH}/arguments.txt"
        env > "${TINKERBLE_COMPANION_SCRATCH_PATH}/environment.txt"
        """#.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let result = try runShellScript(
            script,
            environment: [
                "CONFIGURATION": "Debug",
                "SRCROOT": sourceRoot.path,
                "SWIFT_EXEC": "swiftc",
                "SWIFT_DEBUG_INFORMATION_FORMAT": "dwarf",
                "SWIFT_DEBUG_INFORMATION_VERSION": "compiler-default"
            ]
        )

        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertEqual(try String(contentsOf: argumentsURL, encoding: .utf8), "--restart")
        let environment = try environmentValues(from: String(contentsOf: environmentURL, encoding: .utf8))
        XCTAssertEqual(environment["TINKERBLE_COMPANION_SCRATCH_PATH"], scratchURL.path)
        XCTAssertNil(environment["SWIFT_EXEC"])
        XCTAssertNil(environment["SWIFT_DEBUG_INFORMATION_FORMAT"])
        XCTAssertNil(environment["SWIFT_DEBUG_INFORMATION_VERSION"])
    }

    func testInstallerMigratesLegacyCompanionBuildPhase() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithLegacyCompanionBuildPhase)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let target = try XCTUnwrap(ProjectText(try readProject(projectURL)).nativeTarget(named: "MainApp"))
        XCTAssertEqual(target.buildPhaseIDs, ["000000000000000000000010"])
    }

    func testInstallerRequiresExplicitSchemeSelectionWhenSharedSchemesAreAmbiguous() throws {
        let projectURL = try makeFixtureProject(includeSharedSchemes: false)
        let schemeDirectory = projectURL.appending(path: "xcshareddata/xcschemes")
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try fixtureScheme.write(to: schemeDirectory.appending(path: "MainApp Debug.xcscheme"), atomically: true, encoding: .utf8)
        try fixtureScheme.write(to: schemeDirectory.appending(path: "MainApp Dev.xcscheme"), atomically: true, encoding: .utf8)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertThrowsError(try installer.install(targetNames: ["MainApp"], dryRun: false)) { error in
            XCTAssertEqual(
                error as? TinkerbleInstallError,
                .schemeSelectionRequired(target: "MainApp", schemes: ["MainApp Debug", "MainApp Dev"])
            )
        }
    }

    func testInstallerUsesExplicitSchemeSelection() throws {
        let projectURL = try makeFixtureProject(includeSharedSchemes: false)
        let schemeDirectory = projectURL.appending(path: "xcshareddata/xcschemes")
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try fixtureScheme.write(to: schemeDirectory.appending(path: "MainApp Debug.xcscheme"), atomically: true, encoding: .utf8)
        try fixtureScheme.write(to: schemeDirectory.appending(path: "MainApp Dev.xcscheme"), atomically: true, encoding: .utf8)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], schemeNames: ["MainApp Dev"], dryRun: false)

        let tinkerbleScheme = try SchemeDocument(text: readScheme(projectURL, name: "MainApp + Tinkerble"))
        XCTAssertTrue(tinkerbleScheme.containsElement(named: "ActionContent", attributes: ["title": "Launch Tinkerble Companion"]))
    }

    func testThrowsForMissingTarget() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertThrowsError(try installer.install(targetNames: ["Missing"], dryRun: false)) { error in
            XCTAssertEqual(error as? TinkerbleInstallError, .targetNotFound("Missing"))
        }
    }

    private func makeFixtureProject(
        projectText: String = fixtureProject,
        includeSharedSchemes: Bool = true
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TinkerbleInstallerTests-\(UUID().uuidString)")
        let projectURL = root.appending(path: "Fixture.xcodeproj")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try projectText.write(to: projectURL.appending(path: "project.pbxproj"), atomically: true, encoding: .utf8)
        if includeSharedSchemes {
            let schemeDirectory = projectURL.appending(path: "xcshareddata/xcschemes")
            try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
            try fixtureScheme.write(
                to: schemeDirectory.appending(path: "MainApp.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
            try releaseFixtureScheme.write(
                to: schemeDirectory.appending(path: "MainApp Release.xcscheme"),
                atomically: true,
                encoding: .utf8
            )
        }
        return projectURL
    }

    private func writeFixtureInfoPlist(
        for projectURL: URL,
        propertyList: [String: Any] = [
            "NSLocalNetworkUsageDescription": TinkerbleInstallerConstants.localNetworkUsageDescription,
            "NSBonjourServices": [TinkerbleInstallerConstants.bonjourService]
        ]
    ) throws {
        let plistURL = projectURL
            .deletingLastPathComponent()
            .appending(path: "MainApp/Info.plist")
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
    }

    private func readProject(_ projectURL: URL) throws -> String {
        try String(contentsOf: projectURL.appending(path: "project.pbxproj"), encoding: .utf8)
    }

    private func readScheme(_ projectURL: URL, name: String) throws -> String {
        try String(
            contentsOf: projectURL.appending(path: "xcshareddata/xcschemes/\(name).xcscheme"),
            encoding: .utf8
        )
    }

    private func readInfoPlist(_ projectURL: URL, path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: projectURL.deletingLastPathComponent().appending(path: path))
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(propertyList as? [String: Any])
    }

    private func runShellScript(
        _ script: String,
        environment additionalEnvironment: [String: String]
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]

        var environment = ProcessInfo.processInfo.environment
        for (key, value) in additionalEnvironment {
            environment[key] = value
        }
        process.environment = environment

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let output = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, output + error)
    }

    private func packageReferenceSummary(in project: String) -> (localNames: [String], remoteNames: [String]) {
        let localNames = packageReferenceNames(in: project, section: "XCLocalSwiftPackageReference")
        let remoteNames = packageReferenceNames(in: project, section: "XCRemoteSwiftPackageReference")
        return (localNames, remoteNames)
    }

    private func packageReferenceNames(in project: String, section: String) -> [String] {
        guard let begin = project.range(of: "/* Begin \(section) section */"),
              let end = project.range(of: "/* End \(section) section */") else {
            return []
        }

        return project[begin.upperBound..<end.lowerBound]
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let commentStart = trimmed.range(of: "/* "),
                      let commentEnd = trimmed.range(of: " */ = {") else {
                    return nil
                }
                return String(trimmed[commentStart.upperBound..<commentEnd.lowerBound])
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func buildSettingValues(named key: String, in project: String) -> [String] {
        project
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let prefix = "\(key) = "
                guard trimmed.hasPrefix(prefix), trimmed.hasSuffix(";") else {
                    return nil
                }

                return String(trimmed.dropFirst(prefix.count).dropLast())
            }
    }

    private func fileSystemMembershipExceptions(in project: String, targetID: String) -> [String] {
        var exceptions: [String] = []
        var currentObjectLines: [String] = []
        var isExceptionObject = false

        for line in project.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("\t\t"), line.contains(" = {") {
                currentObjectLines = [line]
                isExceptionObject = false
                continue
            }

            guard !currentObjectLines.isEmpty else { continue }
            currentObjectLines.append(line)

            if line.contains("isa = PBXFileSystemSynchronizedBuildFileExceptionSet;") {
                isExceptionObject = true
            }

            if line == "\t\t};" {
                defer {
                    currentObjectLines = []
                    isExceptionObject = false
                }

                guard isExceptionObject,
                      currentObjectLines.contains(where: { $0.contains("target = \(targetID)") }) else {
                    continue
                }

                exceptions.append(contentsOf: membershipExceptions(in: currentObjectLines))
            }
        }

        return exceptions.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func membershipExceptions(in objectLines: [String]) -> [String] {
        var values: [String] = []
        var isReadingMembershipExceptions = false

        for line in objectLines {
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t,"))
            if trimmed == "membershipExceptions = (" {
                isReadingMembershipExceptions = true
                continue
            }

            if isReadingMembershipExceptions, trimmed == ");" {
                return values
            }

            if isReadingMembershipExceptions, !trimmed.isEmpty {
                values.append(trimmed.replacing("\"", with: ""))
            }
        }

        return values
    }

    private func environmentValues(from text: String) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: text
                .split(separator: "\n")
                .compactMap { line -> (String, String)? in
                    guard let separator = line.firstIndex(of: "=") else { return nil }
                    let key = String(line[..<separator])
                    let valueStart = line.index(after: separator)
                    return (key, String(line[valueStart...]))
                }
        )
    }

}

private struct SchemeElement {
    let name: String
    let attributes: [String: String]
    let path: [String]
}

private final class SchemeDocument: NSObject, XMLParserDelegate {
    private(set) var elements: [SchemeElement] = []
    private var path: [String] = []
    private var parserError: Error?

    init(text: String) throws {
        super.init()

        let parser = XMLParser(data: Data(text.utf8))
        parser.delegate = self

        if !parser.parse() {
            throw parser.parserError ?? parserError ?? SchemeDocumentError.invalidXML
        }
    }

    func containsElement(
        named name: String,
        attributes requiredAttributes: [String: String] = [:],
        pathSuffix requiredPathSuffix: [String] = []
    ) -> Bool {
        elements.contains { element in
            element.name == name
                && (requiredPathSuffix.isEmpty || element.path.suffix(requiredPathSuffix.count) == requiredPathSuffix)
                && requiredAttributes.allSatisfy { key, value in
                element.attributes[key] == value
            }
        }
    }

    func attribute(
        named attributeName: String,
        fromElementNamed name: String,
        matching requiredAttributes: [String: String] = [:]
    ) -> String? {
        elements.first { element in
            element.name == name && requiredAttributes.allSatisfy { key, value in
                element.attributes[key] == value
            }
        }?.attributes[attributeName]
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        path.append(elementName)
        elements.append(SchemeElement(name: elementName, attributes: attributeDict, path: path))
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        _ = path.popLast()
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = parseError
    }
}

private enum SchemeDocumentError: Error {
    case invalidXML
}

private let fixtureProject = #"""
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		000000000000000000000001 /* MainApp.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MainApp.app; sourceTree = BUILT_PRODUCTS_DIR; };
		000000000000000000000002 /* AdminApp.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AdminApp.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		000000000000000000000010 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		000000000000000000000011 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		000000000000000000000020 = {
			isa = PBXGroup;
			children = (
				000000000000000000000001 /* MainApp.app */,
				000000000000000000000002 /* AdminApp.app */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		000000000000000000000030 /* MainApp */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000000000000000000040 /* Build configuration list for PBXNativeTarget "MainApp" */;
			buildPhases = (
				000000000000000000000010 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = MainApp;
			packageProductDependencies = (
			);
			productName = MainApp;
			productReference = 000000000000000000000001 /* MainApp.app */;
			productType = "com.apple.product-type.application";
		};
		000000000000000000000031 /* AdminApp */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000000000000000000041 /* Build configuration list for PBXNativeTarget "AdminApp" */;
			buildPhases = (
				000000000000000000000011 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = AdminApp;
			packageProductDependencies = (
			);
			productName = AdminApp;
			productReference = 000000000000000000000002 /* AdminApp.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		000000000000000000000050 /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = 000000000000000000000042 /* Build configuration list for PBXProject "Fixture" */;
			compatibilityVersion = "Xcode 16.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 000000000000000000000020;
			packageReferences = (
			);
			productRefGroup = 000000000000000000000020;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				000000000000000000000030 /* MainApp */,
				000000000000000000000031 /* AdminApp */,
			);
		};
/* End PBXProject section */

/* Begin XCBuildConfiguration section */
		000000000000000000000060 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_KEY_CFBundleDisplayName = ExistingName;
				PRODUCT_NAME = MainApp;
			};
			name = Debug;
		};
		000000000000000000000061 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_NAME = MainApp;
			};
			name = Release;
		};
		000000000000000000000062 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_NAME = AdminApp;
			};
			name = Debug;
		};
		000000000000000000000063 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_NAME = AdminApp;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		000000000000000000000040 /* Build configuration list for PBXNativeTarget "MainApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000000000000000000060 /* Debug */,
				000000000000000000000061 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		000000000000000000000041 /* Build configuration list for PBXNativeTarget "AdminApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000000000000000000062 /* Debug */,
				000000000000000000000063 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		000000000000000000000042 /* Build configuration list for PBXProject "Fixture" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 000000000000000000000050 /* Project object */;
}
"""#

private let fixtureProjectWithoutPackageLists = fixtureProject
    .replacing("\t\t\tpackageProductDependencies = (\n\t\t\t);\n", with: "")
    .replacing("\t\t\tpackageReferences = (\n\t\t\t);\n", with: "")

private let fixtureProjectWithLocalTinkerblePackage = fixtureProject
    .replacing(
        "\t\t\tpackageReferences = (\n\t\t\t);",
        with: "\t\t\tpackageReferences = (\n\t\t\t\t000000000000000000000090 /* XCLocalSwiftPackageReference \"..\" */,\n\t\t\t);"
    )
    .replacing(
        "\t\t\tpackageProductDependencies = (\n\t\t\t);",
        with: "\t\t\tpackageProductDependencies = (\n\t\t\t\t000000000000000000000091 /* Tinkerble */,\n\t\t\t);"
    )
    .replacing(
        "\n\t};\n\trootObject",
        with: #"""

/* Begin XCLocalSwiftPackageReference section */
		000000000000000000000090 /* XCLocalSwiftPackageReference ".." */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = ..;
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		000000000000000000000091 /* Tinkerble */ = {
			isa = XCSwiftPackageProductDependency;
			package = 000000000000000000000090 /* XCLocalSwiftPackageReference ".." */;
			productName = Tinkerble;
		};
/* End XCSwiftPackageProductDependency section */

	};
	rootObject
"""#
    )

private let fixtureProjectWithInfoPlistFile = fixtureProject
    .replacing(
        "\t\t\t\tPRODUCT_NAME = MainApp;",
        with: "\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = MainApp/Info.plist;\n\t\t\t\tPRODUCT_NAME = MainApp;"
    )

private let fixtureProjectWithGeneratedInfoPlist = fixtureProject
    .replacing(
        "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = ExistingName;\n",
        with: "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Main App\";\n\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;\n\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;\n"
    )
    .replacing(
        "\t\t\t\tPRODUCT_NAME = MainApp;",
        with: "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n\t\t\t\tPRODUCT_NAME = MainApp;"
    )

private let fixtureProjectWithGeneratedBonjourServices = fixtureProjectWithGeneratedInfoPlist
    .replacing(
        "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Main App\";\n",
        with: "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Main App\";\n\t\t\t\tINFOPLIST_KEY_NSBonjourServices = _existing._tcp;\n"
    )

private let fixtureProjectWithSynchronizedFolder = fixtureProjectWithGeneratedInfoPlist
    .replacing(
        "/* End PBXFileReference section */",
        with: #"""
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		000000000000000000000098 /* MainApp */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = MainApp;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */
"""#
    )
    .replacing(
        "\t\t\tname = MainApp;",
        with: "\t\t\tfileSystemSynchronizedGroups = (\n\t\t\t\t000000000000000000000098 /* MainApp */,\n\t\t\t);\n\t\t\tname = MainApp;"
    )

private let fixtureProjectWithLegacyCompanionBuildPhase = fixtureProject
    .replacing(
        "\t\t\tbuildPhases = (\n\t\t\t\t000000000000000000000010 /* Frameworks */,\n\t\t\t);",
        with: "\t\t\tbuildPhases = (\n\t\t\t\t000000000000000000000099 /* Rebuild Tinkerble Companion */,\n\t\t\t\t000000000000000000000010 /* Frameworks */,\n\t\t\t);"
    )
    .replacing(
        "/* Begin PBXProject section */",
        with: #"""
/* Begin PBXShellScriptBuildPhase section */
		000000000000000000000099 /* Rebuild Tinkerble Companion */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			name = "Rebuild Tinkerble Companion";
			shellPath = /bin/bash;
			shellScript = "set -euo pipefail\n\"${PACKAGE_DIR}/Scripts/ensure-macos-companion-running.sh\" --restart\n";
		};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXProject section */
"""#
    )

private let fixtureScheme = #"""
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "000000000000000000000030"
               BuildableName = "MainApp.app"
               BlueprintName = "MainApp"
               ReferencedContainer = "container:Fixture.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "000000000000000000000030"
            BuildableName = "MainApp.app"
            BlueprintName = "MainApp"
            ReferencedContainer = "container:Fixture.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""#

private let releaseFixtureScheme = #"""
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "000000000000000000000030"
               BuildableName = "MainApp.app"
               BlueprintName = "MainApp"
               ReferencedContainer = "container:Fixture.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "000000000000000000000030"
            BuildableName = "MainApp.app"
            BlueprintName = "MainApp"
            ReferencedContainer = "container:Fixture.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Release">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""#
