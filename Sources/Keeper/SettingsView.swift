import AppKit
import SwiftUI

/// Where Keeper lives and when it starts. These three switches used to sit under the primary
/// button in the window, competing with the one action that mattered; here they are the content.
struct SettingsView: View {
    @ObservedObject var session: SessionController

    @State private var presence = Presence()
    @State private var openAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle(L.t("checkbox.menuBar"), isOn: Binding(
                    get: { presence.menuBar },
                    set: { apply(presence.setting(menuBar: $0)) }
                ))
                Toggle(L.t("checkbox.dock"), isOn: Binding(
                    get: { presence.dock },
                    set: { apply(presence.setting(dock: $0)) }
                ))
            } footer: {
                Text(L.t("settings.presence.help"))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle(L.t("checkbox.openAtLogin"), isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        // If the system refuses, put the switch back rather than lying about it.
                        if !LoginItem.setEnabled(on) { openAtLogin = LoginItem.isEnabled }
                    }
            }

            Section {
                Text(L.t("about.credit"))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { presence = Presence() }
    }

    /// A refused change — the one that would hide Keeper everywhere — comes back unchanged, so
    /// the switch springs back on its own without a dialog explaining why.
    private func apply(_ new: Presence) {
        guard new != presence else { return }
        presence = new
        new.save()
        session.refreshPresence()
    }
}
