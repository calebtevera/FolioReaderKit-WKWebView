// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FolioReaderKit",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "FolioReaderKit",
            targets: ["FolioReaderKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.5.0"),
        .package(url: "https://github.com/tadija/AEXML.git", from: "4.6.0"),
        .package(url: "https://github.com/ArtSabintsev/FontBlaster.git", from: "5.0.0"),
        // Temporarily removed heavy dependencies due to disk space constraints
        // You can add back Realm, MenuItemKit, etc. after freeing up disk space
    ],
    targets: [
        .target(
            name: "FolioReaderKit",
            dependencies: [
                "ZipArchive",
                "AEXML",
                "FontBlaster",
            ],
            path: "Source"
        ),
    ]
)
