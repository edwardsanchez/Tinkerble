import XCTest
@testable import TinkerbleInstallerCore

final class XcodeProjectInstallerTests: XCTestCase {
    func testInstallsPackageProductPlistSettingsAndBuildPhaseForMultipleTargets() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertEqual(try installer.appTargetNames, ["AdminApp", "MainApp"])
        XCTAssertEqual(try installer.debugSchemeNames(targetNames: ["MainApp", "AdminApp"]), ["MainApp"])

        let result = try installer.install(targetNames: ["MainApp", "AdminApp"], schemeNames: ["MainApp"], dryRun: false)

        XCTAssertFalse(result.isDryRun)
        XCTAssertEqual(result.targetNames, ["MainApp", "AdminApp"])
        XCTAssertEqual(result.schemeNames, ["MainApp"])
    }

    func testInstallIsIdempotent() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp", "AdminApp"], schemeNames: ["MainApp"], dryRun: false)
        let once = try readProject(projectURL)
        let schemeOnce = try readScheme(projectURL, name: "MainApp")
        _ = try installer.install(targetNames: ["MainApp", "AdminApp"], schemeNames: ["MainApp"], dryRun: false)
        let twice = try readProject(projectURL)
        let schemeTwice = try readScheme(projectURL, name: "MainApp")

        XCTAssertEqual(twice, once)
        XCTAssertEqual(schemeTwice, schemeOnce)
    }

    func testDryRunDoesNotWriteProject() throws {
        let projectURL = try makeFixtureProject()
        let before = try readProject(projectURL)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        let result = try installer.install(targetNames: ["MainApp"], schemeNames: ["MainApp"], dryRun: true)
        let after = try readProject(projectURL)
        let scheme = try readScheme(projectURL, name: "MainApp")

        XCTAssertTrue(result.isDryRun)
        XCTAssertEqual(after, before)
        XCTAssertEqual(scheme, fixtureScheme)
    }

    func testInstallsIntoProjectWithoutExistingSwiftPackageLists() throws {
        let projectURL = try makeFixtureProject(projectText: fixtureProjectWithoutPackageLists)
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        let result = try installer.install(targetNames: ["MainApp"], schemeNames: [], dryRun: false)

        XCTAssertFalse(result.isDryRun)
        XCTAssertEqual(result.targetNames, ["MainApp"])
    }

    func testCompanionBuildPhaseUsesIsolatedScratchPath() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        _ = try installer.install(targetNames: ["MainApp", "AdminApp"], schemeNames: [], dryRun: false)
        let scripts = try companionBuildPhaseScripts(in: readProject(projectURL))

        XCTAssertEqual(scripts.count, 2)
        for script in scripts {
            XCTAssertTrue(script.contains("DERIVED_DATA_DIR=\"${BUILD_DIR%/Build/*}\""))
            XCTAssertTrue(script.contains("COMPANION_SCRATCH_PATH=\"${DERIVED_DATA_DIR}/TinkerbleCompanionBuild\""))
            XCTAssertTrue(script.contains("COMPANION_SCRATCH_PATH=\"${PACKAGE_DIR}/.build/tinkerble-companion\""))
            XCTAssertTrue(
                script.contains(
                    "TINKERBLE_COMPANION_SCRATCH_PATH=\"${COMPANION_SCRATCH_PATH}\" \"${PACKAGE_DIR}/Scripts/ensure-macos-companion-running.sh\" --restart"
                )
            )
        }
    }

    func testDiscoversAndPatchesUserLocalDebugScheme() throws {
        let projectURL = try makeFixtureProject(includeSharedSchemes: false)
        let userSchemeDirectory = projectURL.appending(path: "xcuserdata/edwardsanchez.xcuserdatad/xcschemes")
        try FileManager.default.createDirectory(at: userSchemeDirectory, withIntermediateDirectories: true)
        try fixtureScheme.write(
            to: userSchemeDirectory.appending(path: "MainApp Dev.xcscheme"),
            atomically: true,
            encoding: .utf8
        )
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertEqual(try installer.debugSchemeNames(targetNames: ["MainApp"]), ["MainApp Dev"])

        let result = try installer.install(targetNames: ["MainApp"], schemeNames: ["MainApp Dev"], dryRun: false)

        XCTAssertEqual(result.schemeNames, ["MainApp Dev"])
    }

    func testThrowsForMissingTarget() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertThrowsError(try installer.install(targetNames: ["Missing"], schemeNames: [], dryRun: false)) { error in
            XCTAssertEqual(error as? TinkerbleInstallError, .targetNotFound("Missing"))
        }
    }

    func testThrowsForReleaseSchemeSelection() throws {
        let projectURL = try makeFixtureProject()
        let installer = try XcodeProjectInstaller(projectURL: projectURL)

        XCTAssertEqual(try installer.debugSchemeNames(targetNames: ["MainApp"]), ["MainApp"])
        XCTAssertThrowsError(try installer.install(targetNames: ["MainApp"], schemeNames: ["MainApp Release"], dryRun: false)) { error in
            XCTAssertEqual(
                error as? TinkerbleInstallError,
                .invalidArguments("Scheme MainApp Release is not a Debug scheme.")
            )
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

    private func companionBuildPhaseScripts(in project: String) throws -> [String] {
        var scripts: [String] = []
        var searchIndex = project.startIndex

        while let nameRange = project[searchIndex...].range(
            of: "name = \"\(TinkerbleInstallerConstants.companionBuildPhaseName)\";"
        ) {
            guard let shellScriptRange = project[nameRange.upperBound...].range(of: "\n\t\t\tshellScript = \"") else {
                throw ProjectDecodeError.missingShellScriptField
            }

            scripts.append(try decodePBXQuotedString(in: project, from: shellScriptRange.upperBound))
            searchIndex = shellScriptRange.upperBound
        }

        return scripts
    }

    private func decodePBXQuotedString(in project: String, from startIndex: String.Index) throws -> String {
        var decoded = ""
        var index = startIndex
        var isEscaped = false

        while index < project.endIndex {
            let character = project[index]
            defer { index = project.index(after: index) }

            if isEscaped {
                switch character {
                case "n":
                    decoded.append("\n")
                case "\"", "\\":
                    decoded.append(character)
                default:
                    decoded.append(character)
                }
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if character == "\"" {
                return decoded
            }

            decoded.append(character)
        }

        throw ProjectDecodeError.unterminatedQuotedString
    }
}

private enum ProjectDecodeError: Error {
    case missingShellScriptField
    case unterminatedQuotedString
}

private extension String {
    func count(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
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
