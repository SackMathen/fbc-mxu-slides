import Foundation
#if canImport(dnssd)
import dnssd
#endif

public final class BonjourAdvertiser: @unchecked Sendable {
    public static let serviceType = "_mxu-slides._tcp"

    #if canImport(dnssd)
    private let queue = DispatchQueue(label: "localapi.bonjour")
    private var serviceRef: DNSServiceRef?
    #endif

    public init() {}

    deinit {
        stop()
    }

    #if canImport(dnssd)
    public func start(name: String, port: UInt16) {
        stop()
        var ref: DNSServiceRef?
        let error = DNSServiceRegister(
            &ref, 0, 0,
            name, Self.serviceType, nil, nil,
            port.bigEndian, 0, nil, nil, nil
        )
        guard error == kDNSServiceErr_NoError, let ref else { return }
        DNSServiceSetDispatchQueue(ref, queue)
        serviceRef = ref
    }

    public func stop() {
        if let ref = serviceRef {
            DNSServiceRefDeallocate(ref)
            serviceRef = nil
        }
    }
    #else
    // TODO(windows): advertise over mDNS with the Win32 DnsServiceRegister API
    // (windns.h, Windows 10 1809+). Until then the Local API is reachable by
    // address and port but is not discoverable.
    public func start(name: String, port: UInt16) {}

    public func stop() {}
    #endif
}
