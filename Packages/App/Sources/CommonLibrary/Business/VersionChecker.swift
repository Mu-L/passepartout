// SPDX-FileCopyrightText: 2025 Davide De Rosa
//
// SPDX-License-Identifier: GPL-3.0

import Foundation

@MainActor
public final class VersionChecker: ObservableObject {
    public struct Release: Hashable, Sendable {
        public let version: SemanticVersion

        public let url: URL
    }

    private let kvManager: KeyValueManager

    private let strategy: VersionCheckerStrategy

    private let currentVersion: SemanticVersion

    private let downloadURL: URL

    private var isPending = false

    public init(
        kvManager: KeyValueManager,
        strategy: VersionCheckerStrategy,
        currentVersion: String,
        downloadURL: URL
    ) {
        guard let semCurrent = SemanticVersion(currentVersion) else {
            preconditionFailure("Unparsable current version: \(currentVersion)")
        }
        self.kvManager = kvManager
        self.strategy = strategy
        self.currentVersion = semCurrent
        self.downloadURL = downloadURL
    }

    public var latestRelease: Release? {
        guard let latestVersionDescription = kvManager.string(forKey: AppPreference.lastCheckedVersion.key),
              let latestVersion = SemanticVersion(latestVersionDescription) else {
            return nil
        }
        return latestVersion > currentVersion ? Release(version: latestVersion, url: downloadURL) : nil
    }

    public func checkLatestRelease() async {
        guard !isPending else {
            return
        }
        isPending = true
        defer {
            isPending = false
        }
        let now = Date()
        do {
            let lastCheckedInterval = kvManager.double(forKey: AppPreference.lastCheckedVersionDate.key)
            let lastCheckedDate = lastCheckedInterval > 0.0 ? Date(timeIntervalSinceReferenceDate: lastCheckedInterval) : .distantPast

            pp_log_g(.app, .debug, "Version: checking for updates...")
            let fetchedLatestVersion = try await strategy.latestVersion(since: lastCheckedDate)
            kvManager.set(now.timeIntervalSinceReferenceDate, forKey: AppPreference.lastCheckedVersionDate.key)
            kvManager.set(fetchedLatestVersion.description, forKey: AppPreference.lastCheckedVersion.key)
            pp_log_g(.app, .info, "Version: \(fetchedLatestVersion) > \(currentVersion) = \(fetchedLatestVersion > currentVersion)")

            objectWillChange.send()

            if let latestRelease {
                pp_log_g(.app, .info, "Version: new version available at \(latestRelease.url)")
            } else {
                pp_log_g(.app, .debug, "Version: current is latest version")
            }
        } catch AppError.rateLimit {
            pp_log_g(.app, .debug, "Version: rate limit")
        } catch AppError.unexpectedResponse {
            // save the check date regardless because the service call succeeded
            kvManager.set(now.timeIntervalSinceReferenceDate, forKey: AppPreference.lastCheckedVersionDate.key)

            pp_log_g(.app, .error, "Unable to check version: \(AppError.unexpectedResponse)")
        } catch {
            pp_log_g(.app, .error, "Unable to check version: \(error)")
        }
    }
}

extension VersionChecker {
    private final class DummyStrategy: VersionCheckerStrategy {
        func latestVersion(since: Date) async throws -> SemanticVersion {
            SemanticVersion("255.255.255")!
        }
    }

    public convenience init(downloadURL: URL = URL(string: "http://")!) {
        self.init(
            kvManager: KeyValueManager(),
            strategy: DummyStrategy(),
            currentVersion: "0.0.0", // an update is always available
            downloadURL: downloadURL
        )
    }
}
