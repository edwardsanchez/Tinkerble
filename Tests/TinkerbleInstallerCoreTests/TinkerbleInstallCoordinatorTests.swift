import XCTest
@testable import TinkerbleInstallerCore

final class TinkerbleInstallCoordinatorTests: XCTestCase {
    func testWorkspaceWithOneProjectInstallsSelectedTarget() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TinkerbleCoordinatorTests-\(UUID().uuidString)")
        let projectURL = root.appending(path: "Fixture.xcodeproj")
        let workspaceURL = root.appending(path: "Fixture.xcworkspace")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try coordinatorFixtureProject.write(to: projectURL.appending(path: "project.pbxproj"), atomically: true, encoding: .utf8)
        try workspaceContents.write(to: workspaceURL.appending(path: "contents.xcworkspacedata"), atomically: true, encoding: .utf8)

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { nil },
            standardOutput: { _ in }
        )

        let result = try coordinator.install(
            options: InstallCommandOptions(workspacePath: "Fixture.xcworkspace", targetNames: ["MainApp"])
        )

        XCTAssertEqual(result.targetNames, ["MainApp"])
    }

    func testInstallAcceptsExplicitSchemeSelectionForAmbiguousSchemes() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TinkerbleCoordinatorTests-\(UUID().uuidString)")
        let projectURL = root.appending(path: "Fixture.xcodeproj")
        let schemeDirectory = projectURL.appending(path: "xcshareddata/xcschemes")
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try coordinatorFixtureProject.write(to: projectURL.appending(path: "project.pbxproj"), atomically: true, encoding: .utf8)
        try coordinatorDebugScheme(name: "MainApp Debug").write(
            to: schemeDirectory.appending(path: "MainApp Debug.xcscheme"),
            atomically: true,
            encoding: .utf8
        )
        try coordinatorDebugScheme(name: "MainApp Dev").write(
            to: schemeDirectory.appending(path: "MainApp Dev.xcscheme"),
            atomically: true,
            encoding: .utf8
        )

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { nil },
            standardOutput: { _ in }
        )

        let result = try coordinator.install(
            options: InstallCommandOptions(
                projectPath: "Fixture.xcodeproj",
                targetNames: ["MainApp"],
                schemeNames: ["MainApp Debug"]
            )
        )

        XCTAssertEqual(result.targetNames, ["MainApp"])
    }

    func testEnableMacroTrustFlagRunsTrustCommand() throws {
        let root = try makeProjectFixtureRoot()
        var enableCount = 0

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { nil },
            standardOutput: { _ in },
            enableMacroTrustDefault: { enableCount += 1 }
        )

        _ = try coordinator.install(
            options: InstallCommandOptions(
                projectPath: "Fixture.xcodeproj",
                targetNames: ["MainApp"],
                enableMacroTrust: true
            )
        )

        XCTAssertEqual(enableCount, 1)
    }

    func testSkipMacroTrustFlagLeavesDefaultUnchanged() throws {
        let root = try makeProjectFixtureRoot()
        var enableCount = 0

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { nil },
            standardOutput: { _ in },
            enableMacroTrustDefault: { enableCount += 1 }
        )

        _ = try coordinator.install(
            options: InstallCommandOptions(
                projectPath: "Fixture.xcodeproj",
                targetNames: ["MainApp"],
                enableMacroTrust: false
            )
        )

        XCTAssertEqual(enableCount, 0)
    }

    func testInteractiveMacroTrustPromptEnablesOnYes() throws {
        let root = try makeProjectFixtureRoot()
        var enableCount = 0

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { "y" },
            standardOutput: { _ in },
            enableMacroTrustDefault: { enableCount += 1 }
        )

        _ = try coordinator.install(
            options: InstallCommandOptions(projectPath: "Fixture.xcodeproj", targetNames: ["MainApp"])
        )

        XCTAssertEqual(enableCount, 1)
    }

    func testInteractiveMacroTrustPromptSkipsOnNo() throws {
        let root = try makeProjectFixtureRoot()
        var enableCount = 0

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { "n" },
            standardOutput: { _ in },
            enableMacroTrustDefault: { enableCount += 1 }
        )

        _ = try coordinator.install(
            options: InstallCommandOptions(projectPath: "Fixture.xcodeproj", targetNames: ["MainApp"])
        )

        XCTAssertEqual(enableCount, 0)
    }

    func testNonInteractiveMacroTrustPromptNeverChangesDefault() throws {
        let root = try makeProjectFixtureRoot()
        var enableCount = 0

        let coordinator = TinkerbleInstallCoordinator(
            currentDirectory: root,
            standardInput: { nil },
            standardOutput: { _ in },
            enableMacroTrustDefault: { enableCount += 1 }
        )

        _ = try coordinator.install(
            options: InstallCommandOptions(projectPath: "Fixture.xcodeproj", targetNames: ["MainApp"])
        )

        XCTAssertEqual(enableCount, 0)
    }

    private func makeProjectFixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TinkerbleCoordinatorTests-\(UUID().uuidString)")
        let projectURL = root.appending(path: "Fixture.xcodeproj")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try coordinatorFixtureProject.write(
            to: projectURL.appending(path: "project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }
}

private let workspaceContents = #"""
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:Fixture.xcodeproj">
   </FileRef>
</Workspace>
"""#

private let coordinatorFixtureProject = #"""
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
		100000000000000000000001 /* MainApp.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MainApp.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		100000000000000000000010 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		100000000000000000000020 = {
			isa = PBXGroup;
			children = (
				100000000000000000000001 /* MainApp.app */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		100000000000000000000030 /* MainApp */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 100000000000000000000040 /* Build configuration list for PBXNativeTarget "MainApp" */;
			buildPhases = (
				100000000000000000000010 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = MainApp;
			packageProductDependencies = (
			);
			productName = MainApp;
			productReference = 100000000000000000000001 /* MainApp.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		100000000000000000000050 /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = 100000000000000000000042 /* Build configuration list for PBXProject "Fixture" */;
			mainGroup = 100000000000000000000020;
			packageReferences = (
			);
			productRefGroup = 100000000000000000000020;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				100000000000000000000030 /* MainApp */,
			);
		};
/* End PBXProject section */

/* Begin XCBuildConfiguration section */
		100000000000000000000060 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_NAME = MainApp;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		100000000000000000000040 /* Build configuration list for PBXNativeTarget "MainApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				100000000000000000000060 /* Debug */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		};
		100000000000000000000042 /* Build configuration list for PBXProject "Fixture" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		};
/* End XCConfigurationList section */
	};
	rootObject = 100000000000000000000050 /* Project object */;
}
"""#

private func coordinatorDebugScheme(name: String) -> String {
    #"""
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
               BlueprintIdentifier = "100000000000000000000030"
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
            BlueprintIdentifier = "100000000000000000000030"
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
}
