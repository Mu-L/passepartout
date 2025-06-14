//
//  Empty.swift
//  Passepartout
//
//  Created by Davide De Rosa on 11/7/24.
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
import SwiftUI
import UIAccessibility

public struct PaywallProductView: View {

    @ObservedObject
    private var iapManager: IAPManager

    private let style: PaywallProductViewStyle

    private let product: InAppProduct

    private let withIncludedFeatures: Bool

    private let requiredFeatures: Set<AppFeature>

    @Binding
    private var purchasingIdentifier: String?

    private let onComplete: (String, InAppPurchaseResult) -> Void

    private let onError: (Error) -> Void

    @State
    private var isPresentingFeatures = false

    public init(
        iapManager: IAPManager,
        style: PaywallProductViewStyle,
        product: InAppProduct,
        withIncludedFeatures: Bool,
        requiredFeatures: Set<AppFeature> = [],
        purchasingIdentifier: Binding<String?>,
        onComplete: @escaping (String, InAppPurchaseResult) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.iapManager = iapManager
        self.style = style
        self.product = product
        self.withIncludedFeatures = withIncludedFeatures
        self.requiredFeatures = requiredFeatures
        _purchasingIdentifier = purchasingIdentifier
        self.onComplete = onComplete
        self.onError = onError
    }

    public var body: some View {
        VStack(alignment: .leading) {
            productView
            if withIncludedFeatures,
               let product = AppProduct(rawValue: product.productIdentifier) {
                DisclosingFeaturesView(
                    product: product,
                    requiredFeatures: requiredFeatures,
                    isDisclosing: $isPresentingFeatures
                )
            }
        }
        .disabled(iapManager.didPurchase(product))
    }
}

private extension PaywallProductView {
    var shouldUseStoreKit: Bool {
#if os(tvOS)
        if case .donation = style {
            return true
        }
#endif
        return false
    }

    @ViewBuilder
    var productView: some View {
        if shouldUseStoreKit {
            StoreKitProductView(
                style: style,
                product: product,
                purchasingIdentifier: $purchasingIdentifier,
                onComplete: onComplete,
                onError: onError
            )
        } else {
            CustomProductView(
                style: style,
                iapManager: iapManager,
                product: product,
                purchasingIdentifier: $purchasingIdentifier,
                onComplete: onComplete,
                onError: onError
            )
        }
    }
}

#Preview {
    List {
        PaywallProductView(
            iapManager: .forPreviews,
            style: .paywall(primary: true),
            product: InAppProduct(
                productIdentifier: AppProduct.Features.appleTV.rawValue,
                localizedTitle: "Foo",
                localizedDescription: "Bar",
                localizedPrice: "$10",
                native: nil
            ),
            withIncludedFeatures: true,
            requiredFeatures: [.appleTV],
            purchasingIdentifier: .constant(nil),
            onComplete: { _, _ in },
            onError: { _ in }
        )
    }
    .withMockEnvironment()
}
