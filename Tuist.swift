import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: .all,
        swiftVersion: "5.0",
        generationOptions: .options(
            // Bazel enforced the AudioKit-free default with a graph query. The
            // replacement is `task verify:no-audiokit`, which inspects the linked
            // binary of the built app instead of the build graph.
            enforceExplicitDependencies: true
        )
    )
)
