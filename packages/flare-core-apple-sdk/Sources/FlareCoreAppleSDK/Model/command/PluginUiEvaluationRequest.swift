import Foundation

/// GENERATED. Do not edit by hand.
/// 
public struct PluginUiEvaluationRequest: Sendable {
    /// wire: `payload`. Typed UI evaluation envelope defined by the shared UI protocol. presentPluginMessage, invokePluginAction and pluginDetail accept an optional messageId (server id or clientMsgId) of the message the card belongs to: the card resolves over the shared and local state layers stored on that message, and invoke stores a successful operation's data.sharedState and data.messageState on it. invokePluginAction also takes formValues and selection; pluginDetail also takes cursor and previous for the next page of a paged detail, and refresh with previous to re-read a shown sheet keeping the pages it had loaded. pluginPage takes {pluginId, page, platform, conversationId?, locale?, arguments?, filters?, cursor?, previous?, refresh?}; conversationId is host route context outside the business arguments and source DTO. Page results and page navigation host results retain this reserved top-level conversationId. invokePluginAction takes page {pluginId, page}, the same top-level conversationId, data and row {key, input} instead of message for a page action. Plugin data, arguments, filters and row input never select the invocation conversation; Core revalidates current membership. pluginFileUpload carries {page:{pluginId,page},inputId,platform,locale?,conversationId?,arguments?,data?,formValues?,fileName,contentType,bytes:[0..255],commandId}; one completed private file reference {fileId} is returned. File inputs declare exact accept MIME types, maxBytes<=5242880 and same-plugin upload prepare/complete/purpose. showWhen:{field,anyOf:[strings]} reads an earlier unconditional Select in the same collected action scope. Hidden inputs are not required or forwarded, conditional inputs do not fall back to defaults on submission, and hosts invalidate every dependent value/upload on any controller value change.
    public let payload: [String: AnySendable]

    public init(payload: [String: AnySendable] = [:]) {
        self.payload = payload
    }
}
