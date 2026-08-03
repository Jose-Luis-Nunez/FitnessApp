import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum AppAssetImageError: Error, Equatable {
    case missingAsset(String)
}

/// Loads checked-in app artwork for package snapshots without relying on the
/// package test runner's bundle. This keeps snapshots deterministic while the
/// production view continues to resolve the same asset from the app bundle.
public func appAssetImage(named name: String) throws -> Image {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let imageURL = repositoryRoot
        .appendingPathComponent("FitnessApp/Assets.xcassets")
        .appendingPathComponent("\(name).imageset")
        .appendingPathComponent("\(name).png")

#if canImport(UIKit)
    guard let image = UIImage(contentsOfFile: imageURL.path) else {
        throw AppAssetImageError.missingAsset(name)
    }
    return Image(uiImage: image)
#elseif canImport(AppKit)
    guard let image = NSImage(contentsOf: imageURL) else {
        throw AppAssetImageError.missingAsset(name)
    }
    return Image(nsImage: image)
#endif
}
