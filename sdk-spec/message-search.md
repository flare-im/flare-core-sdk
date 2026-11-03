# Search across platforms

All public search methods accepting `MessageSearchQuery` preserve every supplied
field, including the conversation-scoped method. The Rust binding dispatcher owns
this behavior for Web, Android, Apple and Flutter; adapters must not filter an
already-limited result set in UI code.

See the authoritative [message-search contract](../../flare-core-sdk-engine/bindings/contract/message-search.md).
Applications may use `searchMessagesByQuery` for new advanced search flows. Existing
calls to `searchMessages` and `searchMessagesInConversation` use the same complete
query contract after rebuilding the native/WASM library. No platform wrapper
signature change is required for this repair.
