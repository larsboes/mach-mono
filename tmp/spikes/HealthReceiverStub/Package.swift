// swift-tools-version:5.9
// machHealth H0 — Mac receiver stub. Throwaway-ish: the parsing/stats logic
// graduates into HealthExportKit's receiver later; the HTTP crudeness does not.
import PackageDescription

let package = Package(
    name: "HealthReceiverStub",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "HealthReceiverStub")
    ]
)
