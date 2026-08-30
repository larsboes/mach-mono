import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "MachSoundKit",
    targets: [
        // Pure, AudioKit-free DSP primitives. Its own module so type names
        // (Oscillator, Reverb, WhiteNoise, …) cannot collide.
        Mach.framework(name: "MachSoundDSP", sources: ["Sources/MachSoundDSP/**"]),
        Mach.framework(
            name: "MachSoundKit",
            sources: ["Sources/MachSoundKit/**"],
            dependencies: [.target(name: "MachSoundDSP")]
        ),
        Mach.unitTests(for: "MachSoundKit", dependencies: [.target(name: "MachSoundDSP")]),
    ]
)
