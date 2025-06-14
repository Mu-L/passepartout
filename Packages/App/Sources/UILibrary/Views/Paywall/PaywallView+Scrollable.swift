//
//  PaywallView+Scrollable.swift
//  Passepartout
//
//  Created by Davide De Rosa on 9/10/24.
//  Copyright (c) 2025 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of Passepartout.
//
//  Passepartout is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Passepartout is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Passepartout.  If not, see <http://www.gnu.org/licenses/>.
//

import CommonLibrary
import CommonUtils
import StoreKit
import SwiftUI

struct PaywallScrollableView: View {

    @Binding
    var isPresented: Bool

    @ObservedObject
    var iapManager: IAPManager

    let requiredFeatures: Set<AppFeature>

    @ObservedObject
    var model: PaywallCoordinator.Model

    @ObservedObject
    var errorHandler: ErrorHandler

    let onComplete: (String, InAppPurchaseResult) -> Void

    let onError: (Error) -> Void

    var body: some View {
        Form {
            completeProductsView
                .if(!model.completePurchasable.isEmpty)
            individualProductsView
                .if(!model.individualPurchasable.isEmpty)
            restoreView
            linksView
        }
        .themeForm()
    }
}

private extension PaywallScrollableView {
    var completeProductsView: some View {
        Group {
            ForEach(model.completePurchasable, id: \.productIdentifier) {
                PaywallProductView(
                    iapManager: iapManager,
                    style: .paywall(primary: true),
                    product: $0,
                    withIncludedFeatures: false,
                    requiredFeatures: requiredFeatures,
                    purchasingIdentifier: $model.purchasingIdentifier,
                    onComplete: onComplete,
                    onError: onError
                )
            }
            AllFeaturesView(
                features: [],
                requiredFeatures: requiredFeatures
            )
        }
        .themeSection(
            header: Strings.Views.Paywall.Sections.FullProducts.header,
            footer: [
                Strings.Views.Paywall.Sections.FullProducts.footer,
                Strings.Views.Paywall.Sections.Products.footer
            ].joined(separator: " ")
        )
        .disabled(!iapManager.isEligibleForComplete)
    }

    var individualProductsView: some View {
        ForEach(model.individualPurchasable, id: \.productIdentifier) {
            PaywallProductView(
                iapManager: iapManager,
                style: .paywall(primary: false),
                product: $0,
                withIncludedFeatures: true,
                requiredFeatures: requiredFeatures,
                purchasingIdentifier: $model.purchasingIdentifier,
                onComplete: onComplete,
                onError: onError
            )
        }
        .themeSection(
            header: Strings.Views.Paywall.Sections.Products.header,
            footer: Strings.Views.Paywall.Sections.Products.footer
        )
    }

    var linksView: some View {
        Section {
            Link(Strings.Unlocalized.eula, destination: Constants.shared.websites.eula)
            Link(Strings.Views.Settings.Links.Rows.privacyPolicy, destination: Constants.shared.websites.privacyPolicy)
        }
    }

    var restoreView: some View {
        RestorePurchasesButton(errorHandler: errorHandler)
            .themeContainerWithSingleEntry(
                header: Strings.Views.Paywall.Sections.Restore.header,
                footer: Strings.Views.Paywall.Sections.Restore.footer,
                isAction: true
            )
    }
}

// MARK: - Previews

#Preview {
    let features: Set<AppFeature> = [.appleTV, .dns, .sharing]
    PaywallScrollableView(
        isPresented: .constant(true),
        iapManager: .forPreviews,
        requiredFeatures: features,
        model: .forPreviews(features, including: [.complete]),
        errorHandler: .default(),
        onComplete: { _, _ in },
        onError: { _ in }
    )
    .withMockEnvironment()
}
