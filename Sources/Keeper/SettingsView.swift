import AppKit
import SwiftUI

/// Where Keeper lives and when it starts. These three switches used to sit under the primary
/// button in the window, competing with the one action that mattered; here they are the content.
struct SettingsView: View {
    @ObservedObject var session: SessionController

    @ObservedObject private var updates = UpdateChecker.shared

    @State private var presence = Presence()
    @State private var openAtLogin = LoginItem.isEnabled
    @AppStorage(UpdateChecker.enabledKey) private var checkForUpdates = true

    var body: some View {
        Form {
            Section {
                Toggle(L.t("checkbox.dock"), isOn: Binding(
                    get: { presence.dock },
                    set: { apply(Presence(dock: $0)) }
                ))
            } footer: {
                Text(L.t("settings.presence.help"))
                    .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle(L.t("checkbox.openAtLogin"), isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        // If the system refuses, put the switch back rather than lying about it.
                        if !LoginItem.setEnabled(on) { openAtLogin = LoginItem.isEnabled }
                    }
            }

            // The only place Keeper's one network request can be turned off. It is on by
            // default, so this switch is the thing every document about Keeper points at.
            Section {
                Toggle(L.t("checkbox.checkForUpdates"), isOn: $checkForUpdates)
                HStack(spacing: Metrics.Space.step) {
                    Button(L.t("update.checkNow")) { updates.checkNow() }
                        .disabled(!checkForUpdates || updates.status == .checking)
                    switch updates.status {
                    case .checking:
                        ProgressView().controlSize(.small)
                    case .upToDate:
                        Text(L.t("update.upToDate"))
                            .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    case .failed:
                        Text(L.t("update.failed"))
                            .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    case .idle:
                        if let release = updates.available {
                            Button(L.t("update.available", release.displayVersion)) {
                                updates.openReleasePage()
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            } footer: {
                Text(L.t("settings.updates.help"))
                    .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Text(L.t("about.credit"))
                    .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        // The same width as the window, so the two never read as different-sized apps.
        .frame(width: Metrics.Surface.window.width)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { presence = Presence() }
    }

    private func apply(_ new: Presence) {
        guard new != presence else { return }
        presence = new
        new.save()
        session.refreshPresence()
    }
}
