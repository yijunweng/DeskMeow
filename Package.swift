// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pet-ai",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PetAIDesktop",
            targets: ["PetAIDesktop"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PetAIDesktop",
            path: "Sources/PetAIDesktop"
        )
    ]
)
