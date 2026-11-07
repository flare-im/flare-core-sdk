import FlareIMUI
import FlarePlatformUpdate
import Foundation
import SwiftUI

public extension FlarePlatformUpdate.FlareUpdateStatus {
    /// The Kit's form for `prompt`; nil when nothing interrupts the user, which is all a badge does.
    var kitPromptForm: FlareIMUI.FlareUpdatePromptForm? {
        switch prompt {
        case .sheet: return .sheet
        case .modal: return .modal
        case .fullscreen: return .fullscreen
        case .none, .badge: return nil
        }
    }

    /// The version the prompt names: the running one when the server refused this build before any
    /// release arrived.
    var kitVersion: String { release?.version ?? current.version ?? "" }

    /// Forced, which the state says on its own before a release arrives.
    var kitMandatory: Bool { state == .required || release?.mandatory == true }

    var kitProgress: FlareIMUI.FlareUpdateProgress? {
        progress.map { FlareIMUI.FlareUpdateProgress(received: $0.received, total: $0.total) }
    }

    var kitFallbackTarget: FlareIMUI.FlareUpdateFallbackTarget {
        switch fallbackTarget {
        case .website: return .website
        case .store: return .store
        }
    }
}

public extension View {
    /// The update prompt over this view, in either sign-in state: on screen for as long as `status.prompt`
    /// is a form, and told to the engine once it is. Put it where the Kit's theme and strings reach it.
    func flareUpdatePrompt(controller: FlareUpdateController) -> some View {
        modifier(FlareUpdatePromptBinding(controller: controller))
    }
}

private struct FlareUpdatePromptBinding: ViewModifier {
    /// Outlasts a sheet's way out, the second the Kit gives one to report it. Opened again sooner, the layer
    /// would take that exit for the reader leaving and ask for `onLater` once more.
    private static let sheetExitNanoseconds: UInt64 = 1_100_000_000

    @ObservedObject var controller: FlareUpdateController
    /// The last status on screen: the layer keeps showing it on its way out.
    @State private var lastShown: FlareUpdateStatus?
    /// Holds the layer closed for a moment, so that it opens again.
    @State private var reopening = false

    private var shown: FlareUpdateStatus? {
        guard let status = controller.status, status.kitPromptForm != nil else { return nil }
        return status
    }

    /// What makes a prompt a new one for the engine: its form and the release it is about.
    private var promptKey: String? {
        shown.map { "\($0.prompt.rawValue)-\($0.release?.build ?? 0)" }
    }

    func body(content: Content) -> some View {
        content
            // `status.prompt` opens and closes it: the Kit's own dismissals all go through `onLater`.
            .flareUpdatePrompt(isPresented: Binding(get: { shown != nil && !reopening }, set: { _ in }),
                               prompt: prompt(for: shown ?? lastShown))
            .onChange(of: shown) { status in
                if let status { lastShown = status }
            }
            .task(id: promptKey) {
                if promptKey != nil { await controller.markPrompted() }
            }
    }

    /// `onLater`. A swipe has taken the system sheet away before this runs, so when `update.defer` fails the
    /// engine still wants the prompt while nothing shows it, and a binding that stayed true opens nothing: it has
    /// to go false and back. A sheet the reader left up with the button closes and returns the same way, now
    /// with the error on it.
    @MainActor
    private static func later(_ controller: FlareUpdateController, reopening: Binding<Bool>) async {
        await controller.later()
        guard controller.status?.kitPromptForm == .sheet else { return }
        reopening.wrappedValue = true
        try? await Task.sleep(nanoseconds: sheetExitNanoseconds)
        reopening.wrappedValue = false
    }

    private func prompt(for status: FlareUpdateStatus?) -> UpdatePromptView {
        let controller = self.controller
        let reopening = $reopening
        return UpdatePromptView(
            form: status?.kitPromptForm ?? .sheet,
            version: status?.kitVersion ?? "",
            notes: status?.release?.notes ?? [],
            reason: status?.blockReason,
            sizeBytes: status?.release?.sizeBytes,
            mandatory: status?.kitMandatory ?? false,
            state: status?.state.rawValue,
            progress: status?.kitProgress,
            errorCode: status?.error?.code,
            retryable: status?.error?.retryable ?? true,
            fallbackTarget: status?.kitFallbackTarget ?? .website,
            canContinueReadOnly: status?.canContinueReadOnly ?? false,
            onUpdate: { Task { await controller.update() } },
            onLater: { Task { await Self.later(controller, reopening: reopening) } },
            onSkip: { Task { await controller.skip() } },
            onRetry: { Task { await controller.update() } },
            // The Kit draws the fallback only when it has a handler, and there is nowhere to go without a link.
            onFallback: status?.error?.fallbackUrl == nil ? nil : { Task { await controller.openFallback() } },
            onContinueReadOnly: { Task { await controller.continueReadOnly() } }
        )
    }
}

/// The version block of the about page. The bundle's version shows until the first status is read.
public struct FlareUpdateVersionPanel: View {
    @ObservedObject private var controller: FlareUpdateController

    public init(controller: FlareUpdateController) {
        self.controller = controller
    }

    private var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    public var body: some View {
        let controller = self.controller
        let status = controller.status
        VersionPanelView(
            version: status?.current.version ?? installedVersion,
            build: status?.current.build,
            channel: status?.current.channel,
            updateState: status?.state.rawValue,
            onCheck: { Task { await controller.check() } },
            onUpdate: { Task { await controller.update() } }
        )
    }
}
