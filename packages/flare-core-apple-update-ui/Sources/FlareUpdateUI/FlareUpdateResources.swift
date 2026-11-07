import FlareIMUI
import FlarePlatformUpdate
import SwiftUI

public extension FlarePlatformUpdate.FlareUpdateResourcePack {
    /// The pack as the Kit takes it.
    var kitPack: FlareResourcePack {
        FlareResourcePack(id: id, kind: kind, packVersion: packVersion, contentJson: contentJson)
    }
}

public extension View {
    /// Puts this run's resource packs over the Kit's built-in strings, colours and emoji for this view. The built-in
    /// resources render first and the overlay replaces them when it arrives; when it cannot be read they simply stay,
    /// and the controller's `onError` has the reason.
    ///
    /// Apply it once at the root, inside the `flareStrings` and `flareTheme` it goes over. `locale` is the language
    /// of those strings. `onOverlay` hears of the overlay when it arrives, for what reads no Kit environment: the
    /// app's own strings, copy a session formats.
    @MainActor
    func flareUpdateResources(
        controller: FlareUpdateController,
        locale: String,
        onOverlay: @escaping @MainActor (FlareResourceOverlay) -> Void = { _ in }
    ) -> some View {
        modifier(FlareUpdateResourceBinding(controller: controller, locale: locale, onOverlay: onOverlay))
    }
}

/// The overlay of this run, and what it makes of the resources above. A view's body runs often, and each new value
/// would go down the whole environment, so the results stay until the overlay or the language changes.
@MainActor
final class FlareUpdateResources: ObservableObject {
    @Published private(set) var overlay = FlareResourceOverlay.empty

    private var loaded = false
    private var cachedStrings: (locale: String, result: FlareStrings)?
    private var cachedBrand: (name: String, result: FlareBrandTheme)?

    /// Reads the packs once the engine is up: `update.*` needs `init`, and the first status says it is.
    func load(
        from controller: FlareUpdateController,
        onOverlay: @MainActor (FlareResourceOverlay) -> Void = { _ in }
    ) async {
        guard !loaded else { return }
        for await status in controller.$status.values where status != nil {
            break
        }
        guard !Task.isCancelled else { return }
        let packs = await controller.loadResources()
        guard !Task.isCancelled else { return }
        loaded = true
        // A pack can run to megabytes, and no frame should wait for it.
        let kitPacks = packs.map(\.kitPack)
        let overlay = await Task.detached { FlareResourceOverlay(packs: kitPacks) }.value
        guard !overlay.isEmpty else { return }
        cachedStrings = nil
        cachedBrand = nil
        self.overlay = overlay
        onOverlay(overlay)
        overlay.registerEmoji()
    }

    func strings(over base: FlareStrings, locale: String) -> FlareStrings {
        if let cachedStrings, cachedStrings.locale == locale { return cachedStrings.result }
        let result = overlay.strings(base, locale: locale)
        cachedStrings = (locale, result)
        return result
    }

    /// The Kit's theme, never one built here: themes compare by name, so a copy with new colours would go unnoticed.
    func brand(over base: FlareBrandTheme) -> FlareBrandTheme {
        if let cachedBrand, cachedBrand.name == base.name { return cachedBrand.result }
        let result = overlay.brandTheme(base)
        cachedBrand = (base.name, result)
        return result
    }
}

private struct FlareUpdateResourceBinding: ViewModifier {
    let controller: FlareUpdateController
    let locale: String
    let onOverlay: @MainActor (FlareResourceOverlay) -> Void

    @StateObject private var resources = FlareUpdateResources()
    @Environment(\.flareStrings) private var strings
    @Environment(\.flareBrandTheme) private var brand

    func body(content: Content) -> some View {
        content
            .flareStrings(resources.strings(over: strings, locale: locale))
            .flareTheme(brand: resources.brand(over: brand))
            .task { await resources.load(from: controller, onOverlay: onOverlay) }
    }
}
