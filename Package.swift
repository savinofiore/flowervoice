// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FlowerVoice",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio", from: "0.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "FlowerVoice",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]
        ),
    ]
)
