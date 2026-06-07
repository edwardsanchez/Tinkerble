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
        let project = try String(contentsOf: projectURL.appending(path: "project.pbxproj"), encoding: .utf8)
        XCTAssertTrue(project.contains("https://github.com/edwardsanchez/Tinkerble.git"))
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
