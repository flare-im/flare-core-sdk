import Foundation

/// GENERATED. Do not edit by hand.
/// One side of an access point switch.
public struct AccessEndpoint: Codable, Sendable {
    /// wire: `ap`. Access point id.
    public let ap: String
    /// wire: `protocol`. Transport: quic or ws.
    public let `protocol`: String

    public init(ap: String = "", `protocol`: String = "") {
        self.ap = ap
        self.`protocol` = `protocol`
    }
}
