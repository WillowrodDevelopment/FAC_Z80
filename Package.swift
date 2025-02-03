// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FAC_Z80",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FAC_Z80",
            targets: ["FAC_Z80"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        //.package(url: "https://github.com/Willowrod/FAC_Common.git", from: "1.0.0")
        .package(path: "../FAC_Common")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "FAC_Z80",
            dependencies: [
               .product(name: "FAC_Common", package: "FAC_Common")
            ]),
        .testTarget(
            name: "FAC_Z80Tests",
            dependencies: ["FAC_Z80"]),
    ]
)
