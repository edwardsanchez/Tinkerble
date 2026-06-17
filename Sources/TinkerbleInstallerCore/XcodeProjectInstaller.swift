import Foundation

public final class XcodeProjectInstaller {
    private let projectURL: URL
    private let projectFileURL: URL

    public init(projectURL: URL) throws {
        self.projectURL = projectURL
        self.projectFileURL = projectURL.appending(path: "project.pbxproj")

        guard FileManager.default.fileExists(atPath: projectFileURL.path) else {
            throw TinkerbleInstallError.malformedProject("Missing project.pbxproj at \(projectFileURL.path).")
        }
    }

    public var appTargetNames: [String] {
        get throws {
            let text = try readProject()
            return ProjectText(text).nativeTargets
                .filter { $0.productType == "com.apple.product-type.application" }
                .map(\.name)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
    }

    public func install(targetNames: [String], dryRun: Bool) throws -> TinkerbleInstallResult {
        var text = try readProject()
        var editor = ProjectText(text)
        var changes: [String] = []

        let packageID = try editor.ensureRemotePackageReference(changes: &changes)
        let productID = try editor.ensurePackageProductDependency(packageID: packageID, changes: &changes)
        let buildFileID = try editor.ensureFrameworkBuildFile(productID: productID, changes: &changes)

        for targetName in targetNames {
            try editor.ensureInstall(targetName: targetName, productID: productID, buildFileID: buildFileID, changes: &changes)
        }

        text = editor.text
        if !dryRun {
            try text.write(to: projectFileURL, atomically: true, encoding: .utf8)
        }

        return TinkerbleInstallResult(
            projectPath: projectURL.path,
            targetNames: targetNames,
            changes: changes.isEmpty ? ["Tinkerble already installed."] : changes,
            isDryRun: dryRun
        )
    }

    private func readProject() throws -> String {
        try String(contentsOf: projectFileURL, encoding: .utf8)
    }

}

struct ProjectText {
    var text: String

    var nativeTargets: [NativeTarget] {
        parseNativeTargets()
    }

    init(_ text: String) {
        self.text = text
    }

    mutating func ensureInstall(
        targetName: String,
        productID: String,
        buildFileID: String,
        changes: inout [String]
    ) throws {
        guard let target = nativeTarget(named: targetName) else {
            throw TinkerbleInstallError.targetNotFound(targetName)
        }

        try ensureTargetPackageDependency(targetID: target.id, productID: productID, changes: &changes)
        try ensureFrameworksBuildFile(frameworksPhaseID: target.frameworksPhaseID, buildFileID: buildFileID, changes: &changes)
        try ensureCompanionBuildPhase(targetID: target.id, changes: &changes)
        try ensurePlistBuildSettings(configurationListID: target.buildConfigurationListID, changes: &changes)
    }

    mutating func ensureRemotePackageReference(changes: inout [String]) throws -> String {
        if let existing = objectID(
            section: "XCRemoteSwiftPackageReference",
            containing: "repositoryURL = \"\(TinkerbleInstallerConstants.repositoryURL)\";"
        ) {
            try ensureProjectPackageReference(packageID: existing, changes: &changes)
            return existing
        }

        let packageID = makeID()
        let object = """
\t\t\(packageID) /* XCRemoteSwiftPackageReference "Tinkerble" */ = {
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "\(TinkerbleInstallerConstants.repositoryURL)";
\t\t\trequirement = {
\t\t\t\tbranch = main;
\t\t\t\tkind = branch;
\t\t\t};
\t\t};
"""
        insertObject(object, section: "XCRemoteSwiftPackageReference")
        try ensureProjectPackageReference(packageID: packageID, changes: &changes)
        changes.append("Added Tinkerble package dependency.")
        return packageID
    }

    mutating func ensurePackageProductDependency(packageID: String, changes: inout [String]) throws -> String {
        if let existing = objectID(
            section: "XCSwiftPackageProductDependency",
            containing: "productName = \(TinkerbleInstallerConstants.productName);"
        ) {
            return existing
        }

        let productID = makeID()
        let object = """
\t\t\(productID) /* Tinkerble */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = \(packageID) /* XCRemoteSwiftPackageReference "Tinkerble" */;
\t\t\tproductName = Tinkerble;
\t\t};
"""
        insertObject(object, section: "XCSwiftPackageProductDependency")
        changes.append("Linked Tinkerble package product.")
        return productID
    }

    mutating func ensureFrameworkBuildFile(productID: String, changes: inout [String]) throws -> String {
        if let existing = objectID(
            section: "PBXBuildFile",
            containing: "productRef = \(productID) /* Tinkerble */;"
        ) {
            return existing
        }

        let buildFileID = makeID()
        let object = "\t\t\(buildFileID) /* Tinkerble in Frameworks */ = {isa = PBXBuildFile; productRef = \(productID) /* Tinkerble */; };\n"
        insertObject(object, section: "PBXBuildFile")
        changes.append("Added Tinkerble framework build file.")
        return buildFileID
    }

    private mutating func ensureProjectPackageReference(packageID: String, changes: inout [String]) throws {
        guard let project = projectObject else {
            throw TinkerbleInstallError.malformedProject("Missing PBXProject object.")
        }

        guard !project.block.contains("\(packageID) /* XCRemoteSwiftPackageReference \"Tinkerble\" */") else {
            return
        }

        let updated = try addingListEntry(
            to: project.block,
            listName: "packageReferences",
            entry: "\t\t\t\t\(packageID) /* XCRemoteSwiftPackageReference \"Tinkerble\" */,",
            createBeforeKeys: ["productRefGroup", "projectDirPath", "projectRoot", "targets"]
        )
        replace(project.range, with: updated)
        changes.append("Added Tinkerble to project package references.")
    }

    private mutating func ensureTargetPackageDependency(targetID: String, productID: String, changes: inout [String]) throws {
        guard let target = nativeTarget(id: targetID) else {
            throw TinkerbleInstallError.malformedProject("Missing target \(targetID).")
        }

        guard !target.block.contains("\(productID) /* Tinkerble */") else {
            return
        }

        let updated = try addingListEntry(
            to: target.block,
            listName: "packageProductDependencies",
            entry: "\t\t\t\t\(productID) /* Tinkerble */,",
            createBeforeKeys: ["productName", "productReference", "productType"]
        )
        replace(target.range, with: updated)
        changes.append("Linked Tinkerble product to \(target.name).")
    }

    private mutating func ensureFrameworksBuildFile(frameworksPhaseID: String, buildFileID: String, changes: inout [String]) throws {
        guard let phase = object(id: frameworksPhaseID, section: "PBXFrameworksBuildPhase") else {
            throw TinkerbleInstallError.malformedProject("Missing frameworks build phase \(frameworksPhaseID).")
        }

        guard !phase.block.contains("\(buildFileID) /* Tinkerble in Frameworks */") else {
            return
        }

        let updated = try addingListEntry(
            to: phase.block,
            listName: "files",
            entry: "\t\t\t\t\(buildFileID) /* Tinkerble in Frameworks */,"
        )
        replace(phase.range, with: updated)
        changes.append("Added Tinkerble to the frameworks build phase.")
    }

    private mutating func ensureCompanionBuildPhase(targetID: String, changes: inout [String]) throws {
        guard let target = nativeTarget(id: targetID) else {
            throw TinkerbleInstallError.malformedProject("Missing target \(targetID).")
        }

        if let existingPhaseID = target.buildPhaseIDs.first(where: { phaseID in
            guard let phase = object(id: phaseID, section: "PBXShellScriptBuildPhase") else { return false }
            return phase.block.contains("name = \"\(TinkerbleInstallerConstants.companionBuildPhaseName)\";")
                || phase.block.contains("name = \(TinkerbleInstallerConstants.companionBuildPhaseName.pbxQuoted);")
        }) {
            guard let phase = object(id: existingPhaseID, section: "PBXShellScriptBuildPhase") else {
                throw TinkerbleInstallError.malformedProject("Missing shell script build phase \(existingPhaseID).")
            }

            let updated = phaseBlock(id: existingPhaseID)
            if phase.block != updated {
                replace(phase.range, with: updated)
                changes.append("Updated Tinkerble companion build phase for \(target.name).")
            }
            return
        }

        let phaseID = makeID()
        insertObject(phaseBlock(id: phaseID), section: "PBXShellScriptBuildPhase")

        guard let currentTarget = nativeTarget(id: targetID) else {
            throw TinkerbleInstallError.malformedProject("Missing target \(targetID) after adding phase.")
        }

        let updatedTarget = try addingListEntry(
            to: currentTarget.block,
            listName: "buildPhases",
            entry: "\t\t\t\t\(phaseID) /* \(TinkerbleInstallerConstants.companionBuildPhaseName) */,",
            prepend: true
        )
        replace(currentTarget.range, with: updatedTarget)
        changes.append("Added Tinkerble companion build phase to \(target.name).")
    }

    private mutating func ensurePlistBuildSettings(configurationListID: String, changes: inout [String]) throws {
        guard let configurationList = object(id: configurationListID, section: "XCConfigurationList") else {
            throw TinkerbleInstallError.malformedProject("Missing configuration list \(configurationListID).")
        }

        let configurationIDs = ids(inList: "buildConfigurations", block: configurationList.block)
        for configurationID in configurationIDs {
            guard let configuration = object(id: configurationID, section: "XCBuildConfiguration") else {
                continue
            }

            var updated = configuration.block
            updated = ensureBuildSetting(
                in: updated,
                key: "INFOPLIST_KEY_NSLocalNetworkUsageDescription",
                value: "\"\(TinkerbleInstallerConstants.localNetworkUsageDescription)\""
            )
            updated = ensureBuildSetting(
                in: updated,
                key: "INFOPLIST_KEY_NSBonjourServices",
                value: TinkerbleInstallerConstants.bonjourService
            )
            updated = ensureBuildSetting(in: updated, key: "ENABLE_USER_SCRIPT_SANDBOXING", value: "NO")

            if updated != configuration.block {
                replace(configuration.range, with: updated)
                changes.append("Updated Tinkerble plist/build settings for \(configuration.name).")
            }
        }
    }

    private func phaseBlock(id: String) -> String {
        """
\t\t\(id) /* \(TinkerbleInstallerConstants.companionBuildPhaseName) */ = {
\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\talwaysOutOfDate = 1;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\tinputFileListPaths = (
\t\t\t);
\t\t\tinputPaths = (
\t\t\t);
\t\t\tname = "\(TinkerbleInstallerConstants.companionBuildPhaseName)";
\t\t\toutputFileListPaths = (
\t\t\t);
\t\t\toutputPaths = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\tshellPath = /bin/bash;
\t\t\tshellScript = \(companionBuildPhaseScript.pbxQuoted);
\t\t};
"""
    }

    private var companionBuildPhaseScript: String {
        #"""
set -euo pipefail

CONFIG="${CONFIGURATION:-${BUILD_STYLE:-Debug}}"

if [[ "${CONFIG}" != "Debug" ]]; then
  echo "Skipping Tinkerble companion rebuild for ${CONFIG} build."
  exit 0
fi

CHECKOUT_ROOT="${TINKERBLE_SOURCE_PACKAGES_DIR:-}"
DERIVED_DATA_DIR=""
if [[ -z "${CHECKOUT_ROOT}" && -n "${BUILD_DIR:-}" ]]; then
  DERIVED_DATA_DIR="${BUILD_DIR%/Build/*}"
  CHECKOUT_ROOT="${DERIVED_DATA_DIR}/SourcePackages/checkouts"
fi

PACKAGE_DIR="${TINKERBLE_PACKAGE_DIR:-}"
if [[ -z "${PACKAGE_DIR}" && -n "${CHECKOUT_ROOT}" ]]; then
  for candidate in "${CHECKOUT_ROOT}/Tinkerble" "${CHECKOUT_ROOT}/tinkerble" "${CHECKOUT_ROOT}/Tinker"; do
    if [[ -x "${candidate}/Scripts/ensure-macos-companion-running.sh" ]]; then
      PACKAGE_DIR="${candidate}"
      break
    fi
  done
fi

if [[ -z "${PACKAGE_DIR}" ]]; then
  echo "Unable to locate the Tinkerble package checkout. Set TINKERBLE_PACKAGE_DIR to the package path." >&2
  exit 1
fi

COMPANION_SCRATCH_PATH="${TINKERBLE_COMPANION_SCRATCH_PATH:-}"
if [[ -z "${COMPANION_SCRATCH_PATH}" && -n "${DERIVED_DATA_DIR}" ]]; then
  COMPANION_SCRATCH_PATH="${DERIVED_DATA_DIR}/TinkerbleCompanionBuild"
fi
if [[ -z "${COMPANION_SCRATCH_PATH}" ]]; then
  COMPANION_SCRATCH_PATH="${PACKAGE_DIR}/.build/tinkerble-companion"
fi

TINKERBLE_COMPANION_SCRATCH_PATH="${COMPANION_SCRATCH_PATH}" "${PACKAGE_DIR}/Scripts/ensure-macos-companion-running.sh" --restart
"""#
    }

    private func ensureBuildSetting(in block: String, key: String, value: String) -> String {
        if block.contains("\(key) = ") {
            return block
        }

        guard let settingsRange = block.range(of: "buildSettings = {\n") else {
            return block
        }

        var updated = block
        updated.insert(contentsOf: "\t\t\t\t\(key) = \(value);\n", at: settingsRange.upperBound)
        return updated
    }

    private func addingListEntry(
        to block: String,
        listName: String,
        entry: String,
        prepend: Bool = false,
        createBeforeKeys: [String] = []
    ) throws -> String {
        guard let listRange = block.range(of: "\(listName) = (") else {
            return try addingList(
                named: listName,
                to: block,
                entry: entry,
                beforeKeys: createBeforeKeys
            )
        }

        guard let openLineEnd = block[listRange.upperBound...].firstIndex(of: "\n") else {
            throw TinkerbleInstallError.malformedProject("Malformed \(listName) list.")
        }

        if prepend {
            var updated = block
            updated.insert(contentsOf: "\(entry)\n", at: block.index(after: openLineEnd))
            return updated
        }

        guard let listEnd = block[openLineEnd...].range(of: "\n\t\t\t);") else {
            throw TinkerbleInstallError.malformedProject("Malformed \(listName) list.")
        }

        var updated = block
        updated.insert(contentsOf: "\n\(entry)", at: listEnd.lowerBound)
        return updated
    }

    private func addingList(
        named listName: String,
        to block: String,
        entry: String,
        beforeKeys: [String]
    ) throws -> String {
        guard !beforeKeys.isEmpty else {
            throw TinkerbleInstallError.malformedProject("Missing \(listName) list.")
        }

        let list = "\t\t\t\(listName) = (\n\(entry)\n\t\t\t);\n"

        for key in beforeKeys {
            if let keyRange = block.range(of: "\t\t\t\(key) = ") {
                var updated = block
                updated.insert(contentsOf: list, at: keyRange.lowerBound)
                return updated
            }
        }

        guard let objectEnd = block.range(of: "\n\t\t};", options: .backwards) else {
            throw TinkerbleInstallError.malformedProject("Missing \(listName) list.")
        }

        var updated = block
        updated.insert(contentsOf: list, at: objectEnd.lowerBound)
        return updated
    }

    private var projectObject: ProjectObject? {
        objects(section: "PBXProject").first { $0.block.contains("isa = PBXProject;") }
    }

    func nativeTarget(named name: String) -> NativeTarget? {
        nativeTargets.first { $0.name == name }
    }

    private func nativeTarget(id: String) -> NativeTarget? {
        nativeTargets.first { $0.id == id }
    }

    private func parseNativeTargets() -> [NativeTarget] {
        objects(section: "PBXNativeTarget").compactMap { object in
            guard let name = value(named: "name", in: object.block),
                  let productType = value(named: "productType", in: object.block),
                  let buildConfigurationListID = firstID(after: "buildConfigurationList =", in: object.block),
                  let frameworksPhaseID = phaseID(named: "Frameworks", in: object.block) else {
                return nil
            }

            return NativeTarget(
                id: object.id,
                name: name,
                productType: productType,
                buildConfigurationListID: buildConfigurationListID,
                frameworksPhaseID: frameworksPhaseID,
                buildPhaseIDs: ids(inList: "buildPhases", block: object.block),
                block: object.block,
                range: object.range
            )
        }
    }

    private func object(id: String, section: String) -> ProjectObject? {
        objects(section: section).first { $0.id == id }
    }

    private func objectID(section: String, containing needle: String) -> String? {
        objects(section: section).first { $0.block.contains(needle) }?.id
    }

    private func objects(section: String) -> [ProjectObject] {
        guard let sectionRange = sectionRange(section) else {
            return []
        }

        var result: [ProjectObject] = []
        var searchIndex = sectionRange.lowerBound
        while searchIndex < sectionRange.upperBound {
            guard let objectPrefix = text[searchIndex..<sectionRange.upperBound].range(of: "\n\t\t") else {
                break
            }

            let objectStart = text.index(after: objectPrefix.lowerBound)
            let afterPrefix = text.index(objectStart, offsetBy: 2)
            guard afterPrefix < sectionRange.upperBound else {
                break
            }

            let remaining = text[afterPrefix..<sectionRange.upperBound]
            guard let equalsRange = remaining.range(of: " = ") else {
                searchIndex = afterPrefix
                continue
            }

            let objectID = String(text[afterPrefix..<equalsRange.lowerBound])
                .split(separator: " ")
                .first
                .map(String.init) ?? ""

            guard objectID.count == 24 else {
                searchIndex = equalsRange.upperBound
                continue
            }

            guard let objectEnd = objectEnd(after: equalsRange.upperBound, before: sectionRange.upperBound) else {
                break
            }

            let range = objectStart..<objectEnd
            result.append(ProjectObject(id: objectID, block: String(text[range]), range: range))
            searchIndex = objectEnd
        }

        return result
    }

    private func sectionRange(_ section: String) -> Range<String.Index>? {
        guard let begin = text.range(of: "/* Begin \(section) section */"),
              let end = text.range(of: "/* End \(section) section */") else {
            return nil
        }

        return begin.upperBound..<end.lowerBound
    }

    private func objectEnd(after objectBodyStart: String.Index, before sectionEnd: String.Index) -> String.Index? {
        let remaining = text[objectBodyStart..<sectionEnd]
        if let lineEnd = remaining.firstIndex(of: "\n") {
            let firstLine = text[objectBodyStart..<lineEnd]
            if firstLine.contains("};") {
                return lineEnd
            }
        }

        return remaining.range(of: "\n\t\t};")?.upperBound
    }

    private mutating func insertObject(_ object: String, section: String) {
        let normalizedObject = object.hasSuffix("\n") ? object : "\(object)\n"
        if let endMarker = text.range(of: "/* End \(section) section */") {
            text.insert(contentsOf: normalizedObject, at: endMarker.lowerBound)
            return
        }

        let newSection = "\n/* Begin \(section) section */\n\(normalizedObject)/* End \(section) section */\n"
        let preferredAnchor = "/* Begin XCSwiftPackageProductDependency section */"
        if let anchor = text.range(of: preferredAnchor) {
            text.insert(contentsOf: newSection, at: anchor.lowerBound)
        } else if let objectsEnd = text.range(of: "\n\t};\n\trootObject") {
            text.insert(contentsOf: newSection, at: objectsEnd.lowerBound)
        }
    }

    private mutating func replace(_ range: Range<String.Index>, with replacement: String) {
        text.replaceSubrange(range, with: replacement)
    }

    private func ids(inList listName: String, block: String) -> [String] {
        guard let listRange = block.range(of: "\(listName) = (") else {
            return []
        }

        guard let openLineEnd = block[listRange.upperBound...].firstIndex(of: "\n"),
              let listEnd = block[openLineEnd...].range(of: "\n\t\t\t);") else {
            return []
        }

        return block[openLineEnd..<listEnd.lowerBound]
            .split(separator: "\n")
            .compactMap { line in line.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) }
            .filter { $0.count == 24 }
    }

    private func phaseID(named phaseName: String, in block: String) -> String? {
        ids(inList: "buildPhases", block: block).first { id in
            block.contains("\(id) /* \(phaseName) */")
        }
    }

    private func firstID(after prefix: String, in block: String) -> String? {
        guard let prefixRange = block.range(of: prefix) else {
            return nil
        }

        return block[prefixRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init)
    }

    private func value(named key: String, in block: String) -> String? {
        guard let keyRange = block.range(of: "\(key) = ") else {
            return nil
        }

        let valueStart = keyRange.upperBound
        guard let semicolon = block[valueStart...].firstIndex(of: ";") else {
            return nil
        }

        return String(block[valueStart..<semicolon]).pbxUnquoted
    }

    private func makeID() -> String {
        String(UUID().uuidString.replacing("-", with: "").prefix(24)).uppercased()
    }
}

struct NativeTarget {
    var id: String
    var name: String
    var productType: String
    var buildConfigurationListID: String
    var frameworksPhaseID: String
    var buildPhaseIDs: [String]
    var block: String
    var range: Range<String.Index>
}

struct ProjectObject {
    var id: String
    var block: String
    var range: Range<String.Index>

    var name: String {
        String(
            block
            .split(separator: "\n")
            .first?
            .split(separator: "/*")
            .last?
            .replacing("*/ = {", with: "")
            .trimmingCharacters(in: .whitespaces) ?? id
        )
    }
}

private extension String {
    var pbxQuoted: String {
        let escaped = replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
            .replacing("\n", with: "\\n")
        return "\"\(escaped)\""
    }

    var pbxUnquoted: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\""), value.hasSuffix("\"") {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }

    var xmlEscaped: String {
        replacing("&", with: "&amp;")
            .replacing("\"", with: "&quot;")
            .replacing("'", with: "&apos;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
            .replacing("\n", with: "&#10;")
    }
}
