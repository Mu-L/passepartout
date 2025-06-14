//
//  AppFeature.swift
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

import Foundation

public enum AppFeature: String, CaseIterable {
    case appleTV

    case dns

    case httpProxy

    case onDemand

    case otp

    case providers

    case routing

    case sharing
}

extension AppFeature {
    public static let essentialFeatures: Set<AppFeature> = [
        .dns,
        .httpProxy,
        .onDemand,
        .otp,
        .providers,
        .routing,
        .sharing
    ]

    public var isEssential: Bool {
        Self.essentialFeatures.contains(self)
    }
}

extension AppFeature: Identifiable {
    public var id: String {
        rawValue
    }
}

extension AppFeature: CustomDebugStringConvertible {
    public var debugDescription: String {
        rawValue
    }
}
