import AppKit
import SwiftUI

/// Names and icons for bundle identifiers, and the menu of things you could add.
///
/// Looked up once and remembered: a row is drawn sixty times a second while the knight idles next
/// to it, and asking the file system each time would be silly. An app that is not installed has
/// no icon and falls back to the readable part of its identifier, so its row can still be read
/// and removed rather than being a blank line.
@MainActor
enum AppCatalog {
    private static var descriptions: [String: (name: String, icon: NSImage?)] = [:]
    private static var installedCache: [Entry]?

    struct Entry: Identifiable {
        let bundleID: String
        let name: String
        let icon: NSImage?
        var id: String { bundleID }
    }

    static func describe(_ rule: AppRule) -> (name: String, icon: NSImage?) {
        if let known = descriptions[rule.key] { return known }
        let workspace = NSWorkspace.shared
        var result: (name: String, icon: NSImage?) = (rule.fallbackName, nil)
        if let url = workspace.urlForApplication(withBundleIdentifier: rule.bundleID) {
            result = (FileManager.default.displayName(atPath: url.path), workspace.icon(forFile: url.path))
        }
        descriptions[rule.key] = result
        return result
    }

    /// What is running right now, minus what is already listed and what Keeper refuses. This is
    /// the common case: you add an app at the moment it is annoying you, and at that moment it
    /// is on screen.
    static func running(excluding list: AppList) -> [Entry] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      !list.contains(bundleID), AppList.refusal(for: bundleID) == nil else { return nil }
                return Entry(bundleID: bundleID, name: app.localizedName ?? bundleID, icon: app.icon)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Everything in the two Applications folders, for blocking something before you next open it.
    ///
    /// A nested menu rather than an open panel on purpose: running a file chooser would dismiss
    /// the popover the menu is inside, and you would lose your place to add one app.
    static func installed(excluding list: AppList) -> [Entry] {
        if installedCache == nil {
            let manager = FileManager.default
            var found: [String: Entry] = [:]
            for folder in ["/Applications", "/System/Applications", "/Applications/Utilities"] {
                let contents = (try? manager.contentsOfDirectory(atPath: folder)) ?? []
                for item in contents where item.hasSuffix(".app") {
                    let path = "\(folder)/\(item)"
                    guard let bundle = Bundle(url: URL(fileURLWithPath: path)),
                          let bundleID = bundle.bundleIdentifier, found[bundleID] == nil else { continue }
                    found[bundleID] = Entry(bundleID: bundleID,
                                            name: manager.displayName(atPath: path),
                                            icon: NSWorkspace.shared.icon(forFile: path))
                }
            }
            installedCache = found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return (installedCache ?? []).filter {
            !list.contains($0.bundleID) && AppList.refusal(for: $0.bundleID) == nil
        }
    }
}

/// The apps for this session. The same furniture as the sites list — `ListGroup`, the same rows,
/// the same ⊖ — differing in exactly two earned ways: rows carry the app's own icon, which is
/// what makes the group scannable, and the add row is a menu rather than a text field, because
/// nobody wants to type a bundle identifier.
///
/// While the list is empty the group is just its add row: someone who never blocks an app pays
/// one line rather than an empty box.
struct AppListView: View {
    let apps: AppList
    let locked: Bool
    var onAdd: (String) -> Void
    var onRemove: (String) -> Void

    var body: some View {
        ListGroup(label: L.t("list.apps.label"), locked: locked) {
            if apps.count > Metrics.Group.maxVisibleRows {
                ScrollView { rows }.frame(height: Metrics.Group.scrollHeight)
            } else {
                rows
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(Array(apps.entries.enumerated()), id: \.element) { index, rule in
            if index > 0 { Divider() }
            row(rule)
        }
        if !locked {
            if !apps.isEmpty { Divider() }
            addRow
        }
    }

    private func row(_ rule: AppRule) -> some View {
        let described = AppCatalog.describe(rule)
        return HStack(spacing: Metrics.Row.iconGap) {
            RowIcon(kind: .app(described.icon))
            Text(described.name)
                .font(Metrics.Typography.body)
                .foregroundStyle(locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if !locked {
                RemoveButton(help: L.t("list.remove.help", described.name)) { onRemove(rule.bundleID) }
            }
        }
        .listRowInsets()
    }

    /// The same shape as the rows above it, with the plus in the icon slot — the sites list's add
    /// row is built the same way, which is what keeps one text column down the whole surface.
    private var addRow: some View {
        HStack(spacing: Metrics.Row.iconGap) {
            RowIcon(kind: .symbol("plus"))
            Text(L.t("list.apps.add.placeholder"))
                .font(Metrics.Typography.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Menu(L.t("list.apps.choose")) {
                Section(L.t("list.apps.running")) {
                    ForEach(AppCatalog.running(excluding: apps)) { entry in
                        Button { onAdd(entry.bundleID) } label: { entryLabel(entry) }
                    }
                }
                Menu(L.t("list.apps.chooseOther")) {
                    ForEach(AppCatalog.installed(excluding: apps)) { entry in
                        Button { onAdd(entry.bundleID) } label: { entryLabel(entry) }
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(Metrics.Typography.body)
        }
        .listRowInsets()
    }

    private func entryLabel(_ entry: AppCatalog.Entry) -> some View {
        HStack {
            if let icon = entry.icon {
                Image(nsImage: icon).resizable()
                    .frame(width: Metrics.Row.iconSize, height: Metrics.Row.iconSize)
            }
            Text(entry.name)
        }
    }
}
