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
    let imageSetURL = repositoryRoot
        .appendingPathComponent("FitnessApp/Assets.xcassets")
        .appendingPathComponent("\(name).imageset")
    let imageURLs = [
        imageSetURL.appendingPathComponent("\(name).png"),
        imageSetURL.appendingPathComponent("\(name)@3x.png"),
        imageSetURL.appendingPathComponent("\(name)@2x.png"),
        imageSetURL.appendingPathComponent("\(name)@1x.png"),
    ]

#if canImport(UIKit)
    guard let image = imageURLs.lazy.compactMap({
        UIImage(contentsOfFile: $0.path)
    }).first else {
        throw AppAssetImageError.missingAsset(name)
    }
    return Image(uiImage: image)
#elseif canImport(AppKit)
    guard let image = imageURLs.lazy.compactMap({ NSImage(contentsOf: $0) }).first else {
        throw AppAssetImageError.missingAsset(name)
    }
    return Image(nsImage: image)
#endif
}
