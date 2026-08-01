// swift-tools-version:5.9
// THROWAWAY SPIKE — machSound M0 audio-stack evaluation. Not part of the Bazel graph.
// Two executables answering one question: AudioKit (MIT) or hand-rolled AVAudioSourceNode?
import PackageDescription

let package = Package(
    name: "AudioEngineSpike",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
        .package(url: "https://github.com/AudioKit/SoundpipeAudioKit", from: "5.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "AudioKitSpike",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "SoundpipeAudioKit", package: "SoundpipeAudioKit"),
            ]
        ),
        .executableTarget(name: "HandRolledSpike"),
    ]
)
