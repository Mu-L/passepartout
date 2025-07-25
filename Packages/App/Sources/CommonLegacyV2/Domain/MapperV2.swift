// SPDX-FileCopyrightText: 2025 Davide De Rosa
//
// SPDX-License-Identifier: GPL-3.0

import CommonLibrary
import Foundation

struct MapperV2 {
    func toProfileV3(_ v2: ProfileV2, isTV: Bool) throws -> Profile {
        var builder = Profile.Builder(id: v2.id)
        var modules: [Module] = []

        builder.name = v2.header.name
        builder.attributes.lastUpdate = v2.header.lastUpdate
        builder.attributes.isAvailableForTV = isTV

        if let provider = v2.provider {
            if let module = try toProviderModule(provider) {
                modules.append(module)
            }
        } else if let ovpn = v2.host?.ovpnSettings {
            modules.append(try toOpenVPNModule(ovpn))
        } else if let wg = v2.host?.wgSettings {
            modules.append(try toWireGuardModule(wg))
        }

        try toNetworkModules(v2.networkSettings).forEach {
            modules.append($0)
        }

        let onDemand = toOnDemandModule(v2.onDemand)
        modules.append(onDemand.module)

        builder.modules = modules
        builder.activeModulesIds = Set(modules.map(\.id))
        if !onDemand.isEnabled {
            builder.activeModulesIds.remove(onDemand.module.id)
        }

        return try builder.tryBuild()
    }
}

extension MapperV2 {
    func toOnDemandModule(_ v2: ProfileV2.OnDemand) -> (module: OnDemandModule, isEnabled: Bool) {
        var builder = OnDemandModule.Builder()
        switch v2.policy {
        case .any:
            builder.policy = .any
        case .excluding:
            builder.policy = .excluding
        case .including:
            builder.policy = .including
        }
        builder.withSSIDs = v2.withSSIDs
        builder.withOtherNetworks = Set(v2.withOtherNetworks.map {
            switch $0 {
            case .ethernet:
                return .ethernet
            case .mobile:
                return .mobile
            }
        })
        return (builder.tryBuild(), v2.isEnabled)
    }
}

extension MapperV2 {
    func toOpenVPNModule(_ v2: ProfileV2.OpenVPNSettings) throws -> OpenVPNModule {
        var builder = OpenVPNModule.Builder()
        builder.configurationBuilder = v2.configuration.builder()
        builder.credentials = v2.account.map(toOpenVPNCredentials)
        return try builder.tryBuild()
    }

    func toOpenVPNCredentials(_ v2: ProfileV2.Account) -> OpenVPN.Credentials {
        OpenVPN.Credentials.Builder(username: v2.username, password: v2.password)
            .build()
    }

    func toWireGuardModule(_ v2: ProfileV2.WireGuardSettings) throws -> WireGuardModule {
        var builder = WireGuardModule.Builder()
        builder.configurationBuilder = v2.configuration.configuration.builder()
        return try builder.tryBuild()
    }
}

extension MapperV2 {
    func toProviderModule(_ v2: ProfileV2.Provider) throws -> ProviderModule? {
        assert(v2.vpnSettings.count == 1)
        guard let entry = v2.vpnSettings.first else {
            return nil
        }
        assert(entry.key == .openVPN)
        let settings = entry.value

        var builder = ProviderModule.Builder()
        builder.providerId = ProviderID(rawValue: v2.name)
        builder.providerModuleType = .openVPN
        if let credentials = settings.account.map(toOpenVPNCredentials) {
            var options = OpenVPNProviderTemplate.Options()
            options.credentials = credentials
            try? builder.setOptions(options, for: .openVPN)
        }
        return try builder.tryBuild()
    }
}

extension MapperV2 {
    func toNetworkModules(_ v2: ProfileV2.NetworkSettings) throws -> [Module] {
        var modules: [Module] = []
        if v2.dns.choice == .manual, let dnsModule = try toDNSModule(v2.dns) {
            modules.append(dnsModule)
        }
        if v2.proxy.choice == .manual {
            modules.append(try toHTTPProxyModule(v2.proxy))
        }
        if v2.gateway.choice == .manual || v2.mtu.choice == .manual {
            modules.append(try toIPModule(v2.gateway, v2MTU: v2.mtu))
        }
        return modules
    }

    func toDNSModule(_ v2: Network.DNSSettings) throws -> DNSModule? {
        var builder = DNSModule.Builder()
        builder.protocolType = v2.dnsProtocol ?? .cleartext
        builder.servers = v2.dnsServers ?? []
        guard builder.protocolType != .cleartext || !builder.servers.isEmpty else {
            return nil
        }
        builder.domainName = v2.dnsDomain
        builder.searchDomains = v2.dnsSearchDomains
        builder.dohURL = v2.dnsHTTPSURL?.absoluteString ?? ""
        builder.dotHostname = v2.dnsTLSServerName ?? ""
        return try builder.tryBuild()
    }

    func toHTTPProxyModule(_ v2: Network.ProxySettings) throws -> HTTPProxyModule {
        var builder = HTTPProxyModule.Builder()
        builder.address = v2.proxyAddress ?? ""
        builder.port = v2.proxyPort ?? 0
        builder.secureAddress = v2.proxyAddress ?? ""
        builder.securePort = v2.proxyPort ?? 0
        builder.pacURLString = v2.proxyAutoConfigurationURL?.absoluteString ?? ""
        builder.bypassDomains = v2.proxyBypassDomains ?? []
        return try builder.tryBuild()
    }

    func toIPModule(_ v2Gateway: Network.GatewaySettings?, v2MTU: Network.MTUSettings?) throws -> IPModule {
        var builder = IPModule.Builder()

        if let v2Gateway, v2Gateway.choice == .manual {
            let defaultRoute = Route(defaultWithGateway: nil)

            if v2Gateway.isDefaultIPv4 {
                builder.ipv4 = IPSettings(subnet: nil)
                    .including(routes: [defaultRoute])
            } else {
                builder.ipv4 = IPSettings(subnet: nil)
                    .excluding(routes: [defaultRoute])
            }

            if v2Gateway.isDefaultIPv6 {
                builder.ipv6 = IPSettings(subnet: nil)
                    .including(routes: [defaultRoute])
            } else {
                builder.ipv6 = IPSettings(subnet: nil)
                    .excluding(routes: [defaultRoute])
            }
        }
        if let v2MTU, v2MTU.choice == .manual {
            builder.mtu = v2MTU.mtuBytes
        }

        return builder.tryBuild()
    }
}
