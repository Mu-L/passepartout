// SPDX-FileCopyrightText: 2025 Davide De Rosa
//
// SPDX-License-Identifier: GPL-3.0

import CommonLibrary
import SwiftUI

public struct RefreshInfrastructureButton<Label>: View where Label: View {

    @EnvironmentObject
    private var apiManager: APIManager

    @EnvironmentObject
    private var kvManager: KeyValueManager

    private let module: ProviderModule

    private let label: () -> Label

    @State
    private var elapsed: TimeInterval = .infinity

    public init(module: ProviderModule, label: @escaping () -> Label) {
        self.module = module
        self.label = label
    }

    public var body: some View {
        Button {
            Task {
                try await apiManager.fetchInfrastructure(for: module)
                saveLastUpdate()
            }
        } label: {
            label()
        }
        .disabled(elapsed <= Constants.shared.api.refreshInfrastructureRateLimit)
        .task {
            loadLastUpdate()
        }
        .onChange(of: elapsed) {
            pp_log_g(.app, .info, "Elapsed since last update of \(module.providerId): \($0)")
        }
    }
}

extension RefreshInfrastructureButton where Label == RefreshInfrastructureButtonProgressView {
    public init(module: ProviderModule) {
        self.module = module
        label = {
            RefreshInfrastructureButtonProgressView()
        }
    }
}

public struct RefreshInfrastructureButtonProgressView: View {

    @EnvironmentObject
    private var apiManager: APIManager

    public var body: some View {
#if os(iOS)
        HStack {
            Text(Strings.Views.Providers.refreshInfrastructure)
            if apiManager.isLoading {
                Spacer()
                ProgressView()
            }
        }
#else
        Text(Strings.Views.Providers.refreshInfrastructure)
#endif
    }
}

private extension RefreshInfrastructureButton {
    func loadLastUpdate() {
        guard let map = kvManager.object(forKey: UIPreference.lastInfrastructureRefresh.key) as [String: TimeInterval]? else {
            elapsed = .infinity
            return
        }
        guard let lastUpdate = map[module.providerId.rawValue] else {
            elapsed = .infinity
            return
        }
        elapsed = Date.timeIntervalSinceReferenceDate - lastUpdate
    }

    func saveLastUpdate() {
        var map = kvManager.object(forKey: UIPreference.lastInfrastructureRefresh.key) as [String: TimeInterval]? ?? [:]
        map[module.providerId.rawValue] = Date.timeIntervalSinceReferenceDate
        kvManager.set(map, forKey: UIPreference.lastInfrastructureRefresh.key)
        elapsed = .zero
    }
}
