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

    func testInstallerCreatesRunSchemeWithoutTargetBuildPhase() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp"], dryRun: false)

        let target = try XCTUnwrap(ProjectText(try readProject(projectURL)).nativeTarget(named: "MainApp"))
        XCTAssertEqual(target.buildPhaseIDs, ["000000000000000000000010"])

        let originalScheme = try SchemeDocument(text: readScheme(projectURL, name: "MainApp"))
        let tinkerbleScheme = try SchemeDocument(text: readScheme(projectURL, name: "MainApp + Tinkerble"))

        XCTAssertFalse(originalScheme.containsElement(named: "ActionContent", attributes: ["title": "Launch Tinkerble Companion"]))
        XCTAssertTrue(tinkerbleScheme.containsElement(named: "ActionContent", attributes: ["title": "Launch Tinkerble Companion"]))
        XCTAssertTrue(tinkerbleScheme.containsElement(named: "BuildableReference", attributes: ["BlueprintIdentifier": "000000000000000000000030"]))
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

    private func readProject(_ projectURL: URL) throws -> String {
        try String(contentsOf: projectURL.appending(path: "project.pbxproj"), encoding: .utf8)
    }

    private func readScheme(_ projectURL: URL, name: String) throws -> String {
        try String(
            contentsOf: projectURL.appending(path: "xcshareddata/xcschemes/\(name).xcscheme"),
            encoding: .utf8
        )
    }

}

private struct SchemeElement {
    let name: String
    let attributes: [String: String]
}

private final class SchemeDocument: NSObject, XMLParserDelegate {
    private(set) var elements: [SchemeElement] = []
    private var parserError: Error?

    init(text: String) throws {
        super.init()

        let parser = XMLParser(data: Data(text.utf8))
        parser.delegate = self

        if !parser.parse() {
            throw parser.parserError ?? parserError ?? SchemeDocumentError.invalidXML
        }
    }

    func containsElement(named name: String, attributes requiredAttributes: [String: String] = [:]) -> Bool {
        elements.contains { element in
            element.name == name && requiredAttributes.allSatisfy { key, value in
                element.attributes[key] == value
            }
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elements.append(SchemeElement(name: elementName, attributes: attributeDict))
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
