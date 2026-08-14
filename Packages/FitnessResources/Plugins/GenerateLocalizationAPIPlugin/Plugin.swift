import PackagePlugin

@main
struct GenerateLocalizationAPIPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let catalog = target.directory.appending([
            "Resources", "Localizable.xcstrings",
        ])
        let nativeOutputDirectory = context.pluginWorkDirectory.appending(
            "NativeSymbols"
        )
        let output = context.pluginWorkDirectory.appending(
            "AppText.generated.swift"
        )
        let nativeOutput = nativeOutputDirectory.appending(
            "GeneratedStringSymbols_Localizable.swift"
        )

        return [
            .buildCommand(
                displayName: "Generate public localization symbols",
                executable: Path("/bin/sh"),
                arguments: [
                    "-c",
                    """
                    set -eu
                    mkdir -p "$2"
                    xcrun xcstringstool generate-symbols "$1" \
                        --output-directory "$2" --language swift
                    perl -pi -e 's/nonisolated extension LocalizedStringResource/public nonisolated extension AppText/' "$3"
                    mv "$3" "$4"
                    """,
                    "GenerateLocalizationAPI",
                    catalog.string,
                    nativeOutputDirectory.string,
                    nativeOutput.string,
                    output.string,
                ],
                inputFiles: [catalog],
                outputFiles: [nativeOutputDirectory, output]
            ),
        ]
    }
}
