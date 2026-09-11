import AppKit
import SwiftUI

/// The pieces the panel and the window both draw. They are shared rather than duplicated so the
/// two surfaces cannot drift apart: one list, one header, one button, rendered at 300 pt in the
/// menu bar panel and at 420 pt in the window.

// MARK: - Header

/// The knight, the state, and one line under it. He is the indicator: present in every state,
/// idling, and the only thing in the window that moves.
struct StateHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            KnightBadge()
                .frame(width: KnightSprite.characterTightBox.width * 2,
                       height: KnightSprite.characterTightBox.height * 2)
                .accessibilityLabel("Keeper")
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - The list chrome both lists wear

/// The label, the lock, and the rounded container a list sits in. Extracted so the sites list and
/// the apps list cannot drift apart: they are two sets of rows inside one piece of furniture.
struct ListGroup<Content: View>: View {
    let label: String
    var locked = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(label)
                if locked {
                    Image(systemName: "lock.fill")
                        .imageScale(.small)
                        .help(L.t("list.locked.help"))
                        .accessibilityLabel(L.t("list.locked.help"))
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
        }
    }
}

/// The ⊖ at the trailing edge of every removable row.
struct RemoveButton: View {
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - The sites

/// The sites for this session: grouped rows, a remove control per row, an add row with the
/// presets behind a menu.
///
/// The presets used to be a row of chips that wrapped onto a second line the moment one was
/// used, which moved the button underneath them. A menu is a fixed size, so nothing reflows.
struct SiteListView: View {
    let sites: SiteList
    let locked: Bool
    @Binding var draft: String
    var onAdd: (String) -> Void
    var onRemove: (String) -> Void

    var body: some View {
        ListGroup(label: L.t("list.label"), locked: locked) {
            if sites.count > 8 {
                // Past eight sites the list would push the button off a short screen.
                ScrollView { rows }.frame(height: 240)
            } else {
                rows
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        if sites.isEmpty {
            Text(L.t("list.empty"))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
        }
        ForEach(Array(sites.entries.enumerated()), id: \.element) { index, entry in
            if index > 0 { Divider() }
            row(entry)
        }
        if !locked {
            if !sites.isEmpty { Divider() }
            addRow
        }
    }

    private func row(_ entry: String) -> some View {
        HStack(spacing: 8) {
            Text(entry)
                .foregroundStyle(locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if !locked {
                RemoveButton(help: L.t("list.remove.help", entry)) { onRemove(entry) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var addRow: some View {
        HStack(spacing: 6) {
            TextField(L.t("list.add.placeholder"), text: $draft)
                .textFieldStyle(.plain)
                .onSubmit {
                    onAdd(draft)
                    draft = ""
                }
            if !sites.unusedPresets.isEmpty {
                Menu(L.t("quickAdd.menu")) {
                    ForEach(sites.unusedPresets, id: \.rule) { preset in
                        Button(preset.label) { onAdd(preset.rule) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .font(.callout)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - The one action

/// The single coloured control on each surface: blue to begin, red to end.
struct PrimaryButton: View {
    let label: String
    var tint: Color = .accentColor
    var isDefault = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            Text(label).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tint)
        .disabled(!enabled)

        if isDefault { button.keyboardShortcut(.defaultAction) } else { button }
    }
}

// MARK: - Editing the list

/// The list lives in one place — the saved text — and both surfaces read and write it there, so
/// a site added in the panel is already in the window and the other way round.
enum SiteStore {
    static func add(_ raw: String, to text: inout String) {
        var sites = SiteList(text: text)
        guard sites.add(raw) else { return }
        text = sites.text
    }

    static func remove(_ entry: String, from text: inout String) {
        var sites = SiteList(text: text)
        sites.remove(entry)
        text = sites.text
    }
}

/// The same, for applications.
enum AppStore {
    @discardableResult
    static func add(_ bundleID: String, to text: inout String) -> Bool {
        var apps = AppList(text: text)
        guard apps.add(bundleID) else { return false }
        text = apps.text
        return true
    }

    static func remove(_ bundleID: String, from text: inout String) {
        var apps = AppList(text: text)
        apps.remove(bundleID)
        text = apps.text
    }
}
