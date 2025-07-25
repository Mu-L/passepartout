// SPDX-FileCopyrightText: 2025 Davide De Rosa
//
// SPDX-License-Identifier: GPL-3.0

import CommonLibrary
import CommonUtils
import SwiftUI

// TODO: #878, show CloudKit progress

struct MigrateView: View {
    enum Style {
        case list

        case table
    }

    @EnvironmentObject
    private var migrationManager: MigrationManager

    @EnvironmentObject
    private var iapManager: IAPManager

    @Environment(\.dismiss)
    private var dismiss

    let style: Style

    @ObservedObject
    var profileManager: ProfileManager

    @State
    private var model = Model()

    @State
    private var isEditing = false

    @State
    private var isDeleting = false

    @State
    private var profilesPendingDeletion: [MigratableProfile]?

    @StateObject
    private var errorHandler: ErrorHandler = .default()

    var body: some View {
        debugChanges()
        return MigrateContentView(
            style: style,
            step: model.step,
            profiles: model.visibleProfiles,
            statuses: $model.statuses,
            isEditing: $isEditing,
            onDelete: onDelete,
            performButton: performButton
        )
        .themeProgress(if: !model.step.isReady)
        .themeAnimation(on: model, category: .profiles)
        .themeConfirmation(
            isPresented: $isDeleting,
            title: Strings.Views.Migration.Items.discard,
            message: messageForDeletion,
            isDestructive: true,
            action: confirmPendingDeletion
        )
        .navigationTitle(title)
        .task {
            await fetch()
        }
        .withErrorHandler(errorHandler)
    }
}

private extension MigrateView {
    var title: String {
        Strings.Views.Migration.title
    }

    var messageForDeletion: String? {
        profilesPendingDeletion.map {
            let nameList = $0
                .map(\.name)
                .joined(separator: "\n")

            return Strings.Views.Migration.Alerts.Delete.message(nameList)
        }
    }

    func performButton() -> some View {
        MigrateButton(step: model.step) {
            Task {
                await perform(at: model.step)
            }
        }
    }
}

private extension MigrateView {
    func onDelete(_ profiles: [MigratableProfile]) {
        profilesPendingDeletion = profiles
        isDeleting = true
    }

    func perform(at step: MigrateViewStep) async {
        switch step {
        case .fetched(let profiles):
            await migrate(profiles)

        case .migrated:
            dismiss()

        default:
            assertionFailure("No action allowed at step \(step), why is button enabled?")
        }
    }

    func fetch() async {
        guard model.step == .initial else {
            return
        }
        do {
            model.step = .fetching
            pp_log_g(.App.migration, .notice, "Fetch migratable profiles...")
            let migratable = try await migrationManager.fetchMigratableProfiles()
            let knownIDs = Set(profileManager.previews.map(\.id))
            model.profiles = migratable.filter {
                !knownIDs.contains($0.id)
            }
            model.step = .fetched(model.profiles)
        } catch {
            pp_log_g(.App.migration, .error, "Unable to fetch migratable profiles: \(error)")
            errorHandler.handle(error, title: title) {
                dismiss()
            }
        }
    }

    func migrate(_ allProfiles: [MigratableProfile]) async {
        guard case .fetched = model.step else {
            assertionFailure("Must call fetch() and succeed, why is button enabled?")
            return
        }

        let profiles = allProfiles.filter {
            model.statuses[$0.id] != .excluded
        }
        guard !profiles.isEmpty else {
            assertionFailure("Nothing to migrate, why is button enabled?")
            return
        }

        let previousStep = model.step
        model.step = .migrating
        do {
            pp_log_g(.App.migration, .notice, "Migrate \(profiles.count) profiles...")
            let profiles = try await migrationManager.migratedProfiles(profiles) {
                guard $1 != .done else {
                    return
                }
                model.statuses[$0] = $1
            }
            pp_log_g(.App.migration, .notice, "Mapped \(profiles.count) profiles to the new format, saving...")
            await migrationManager.importProfiles(profiles, into: profileManager) {
                model.statuses[$0] = $1
            }
            let migrated = profiles.filter {
                model.statuses[$0.id] == .done
            }
            pp_log_g(.App.migration, .notice, "Migrated \(migrated.count) profiles")

            if !iapManager.isBeta {
                do {
                    try await migrationManager.deleteMigratableProfiles(withIds: Set(migrated.map(\.id)))
                    pp_log_g(.App.migration, .notice, "Discarded \(migrated.count) migrated profiles from old store")
                } catch {
                    pp_log_g(.App.migration, .error, "Unable to discard migrated profiles: \(error)")
                }
            } else {
                pp_log_g(.App.migration, .notice, "Restricted build, do not discard migrated profiles")
            }

            model.step = .migrated(migrated)
        } catch {
            pp_log_g(.App.migration, .error, "Unable to migrate profiles: \(error)")
            errorHandler.handle(error, title: title)
            model.step = previousStep
        }
    }

    func confirmPendingDeletion() {
        guard let profilesPendingDeletion else {
            isEditing = false
            assertionFailure("No profiles pending deletion?")
            return
        }
        let deletedIds = Set(profilesPendingDeletion.map(\.id))
        Task {
            do {
                try await migrationManager.deleteMigratableProfiles(withIds: deletedIds)
                withAnimation {
                    model.profiles.removeAll {
                        deletedIds.contains($0.id)
                    }
                    model.step = .fetched(model.profiles)
                }
            } catch {
                pp_log_g(.App.migration, .error, "Unable to delete migratable profiles \(deletedIds): \(error)")
            }
            isEditing = false
        }
    }
}
