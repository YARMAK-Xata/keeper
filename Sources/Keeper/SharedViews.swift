import AppKit
import SwiftUI

/// The pieces the panel and the window both draw. They are shared rather than duplicated so the
/// two surfaces cannot drift apart: one list, one header, one button, rendered at the panel's
/// width and the window's. Every number in this file comes from `Metrics`.

// MARK: - Header

/// The knight, the state, and one line under it. He is the indicator: present in every state,
/// idling, and the only thing in the window that moves.
struct StateHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.Space.gap) {
            KnightBadge()
                .frame(width: KnightSprite.characterTightBox.width * 2,
                       height: KnightSprite.characterTightBox.height * 2)
                .accessibilityLabel("Keeper")
            VStack(alignment: .leading, spacing: Metrics.Space.hair) {
                Text(title).font(Metrics.Typography.title)
                Text(subtitle)
                    .font(Metrics.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A newer release exists. One line under the header, in the reading path — you meet it on the
/// way to the button rather than having to go looking — and absent entirely the rest of the time,
/// so nothing below it moves for a notice that is not there.
///
/// It offers a link, not an installer. Keeper has no code that could replace itself.
struct UpdateLine: View {
    @ObservedObject var checker: UpdateChecker

    var body: some View {
        if let release = checker.available {
            HStack(spacing: Metrics.Row.iconGap) {
                RowIcon(kind: .symbol("arrow.down.circle"))
                Text(L.t("update.available", release.displayVersion))
                    .font(Metrics.Typography.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: Metrics.Space.step)
                Button(L.t("update.action")) { checker.openReleasePage() }
                    .buttonStyle(.link)
                    .font(Metrics.Typography.secondary)
            }
        }
    }
}

/// The window's whole job once Keeper has the access it needs: say where the app is.
///
/// Deliberately not a button. A "show me" control here would be a fourth way to reach a panel
/// that already opens from the shield, the Dock icon and the right-click menu, and it would
/// teach the window as the way in — which is the habit this line exists to break.
struct MenuBarSignpost: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.Row.iconGap) {
            Image(systemName: "menubar.arrow.up.rectangle")
                .foregroundStyle(.secondary)
            Text(L.t("window.menuBarOnly"))
                .font(Metrics.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: Metrics.Group.labelGap) {
            HStack(spacing: Metrics.Space.tight) {
                Text(label)
                if locked {
                    Image(systemName: "lock.fill")
                        .imageScale(.small)
                        .help(L.t("list.locked.help"))
                        .accessibilityLabel(L.t("list.locked.help"))
                }
            }
            .font(Metrics.Typography.secondary)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: Metrics.Group.cornerRadius)
                    .fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: Metrics.Group.cornerRadius)
                    .strokeBorder(Color(nsColor: .separatorColor)))
        }
    }
}

/// The icon slot at the head of every row in either list.
///
/// It exists so the two lists share one text column. An app row has always carried the app's own
/// icon; a site row carried nothing, so inside two identically-drawn boxes the text of one group
/// started twenty-four points further left than the other and the pair read as two unrelated
/// things. A globe for a site and a plus for the add row fill the slot, and the column lines up.
///
/// Symbols come from SF Symbols, the same set the lock and the ⊖ already come from.
struct RowIcon: View {
    enum Kind {
        /// An application's own icon, or a placeholder if it is no longer installed.
        case app(NSImage?)
        /// An SF Symbol, drawn in the secondary colour so it recedes behind the text.
        case symbol(String)
    }

    let kind: Kind

    var body: some View {
        content.frame(width: Metrics.Row.iconSize, height: Metrics.Row.iconSize)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .app(let image):
            if let image {
                Image(nsImage: image).resizable()
            } else {
                // Installed once, gone now. A placeholder keeps the names in one column.
                Image(systemName: "questionmark.app.dashed").foregroundStyle(.secondary)
            }
        case .symbol(let name):
            Image(systemName: name).foregroundStyle(.secondary)
        }
    }
}

extension View {
    /// The padding every row in either list wears, on both surfaces. A row is a row: the density
    /// difference between the window and the panel is in the frame around the lists, never here.
    func listRowInsets() -> some View {
        padding(.horizontal, Metrics.Row.horizontalInset)
            .padding(.vertical, Metrics.Row.verticalInset)
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
            if sites.count > Metrics.Group.maxVisibleRows {
                                ScrollView { rows }.frame(height: Metrics.Group.scrollHeight)
            } else {
                rows
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        if sites.isEmpty {
            // A paragraph rather than a row: it spans the box, so it takes the box's inset and
            // not the text column the rows line up on.
            Text(L.t("list.empty"))
                .font(Metrics.Typography.secondary).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Metrics.Row.horizontalInset)
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
        HStack(spacing: Metrics.Row.iconGap) {
            RowIcon(kind: .symbol("globe"))
            Text(entry)
                .font(Metrics.Typography.body)
                .foregroundStyle(locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if !locked {
                RemoveButton(help: L.t("list.remove.help", entry)) { onRemove(entry) }
            }
        }
        .listRowInsets()
    }

    /// The last row of the group, in the same shape as the ones above it: the plus stands in the
    /// icon slot so the field begins on the text column rather than out on its own.
    private var addRow: some View {
        HStack(spacing: Metrics.Row.iconGap) {
            RowIcon(kind: .symbol("plus"))
            TextField(L.t("list.add.placeholder"), text: $draft)
                .textFieldStyle(.plain)
                .font(Metrics.Typography.body)
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
                // The field beside it is body; a menu one size down on the same line was the
                // most visible mismatch on either surface.
                .font(Metrics.Typography.body)
            }
        }
        .listRowInsets()
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
