# Security

Keeper asks for Accessibility access, which is the widest grant on a Mac: it lets an app read the
contents of other apps' windows and press keys in them. That is a lot to hand to a small program
you were sent as a disk image, so this is what Keeper does with it, what was checked, and what is
still true that you might not like.

Reviewed 11 September 2026 against the 1.6 source tree.

## The two properties worth trusting

**Keeper cannot talk to the network.** Not "does not" — cannot. There is no `URLSession`, no
socket, no `Network` framework, and nothing that starts another program (`Process`, `NSTask`,
`system`, `popen`). There are also no third-party packages, so nothing arrives through a
dependency either. `grep -rE "URLSession|NWConnection|socket\(|Process\(|NSTask|system\(|popen"
Sources/` returns nothing, and you can run it yourself.

**Nothing about your browsing is written down.** The only things Keeper saves are the two lists
you built (`blacklistText` and `blockedAppsText`), whatever you had half-typed in the add field
(`draftSite`), the two switches from Settings, and whether the permission alert has been shown. The address of a page it
spotted lives in memory for as long as the window shows "Closed youtube.com in Safari", and goes
when you quit. No page address is written to a file, a log, or the system console.

## What was found and fixed in 1.5

**The developer probe shipped in release builds.** `Keeper --probe` prints the address of every
page open in every browser. It was compiled into the shipped app, and because the Accessibility
grant is keyed to Keeper's code signature, any process on the Mac could have run
`/Applications/Keeper.app/Contents/MacOS/Keeper --probe` and borrowed that grant to dump your open
tabs — without needing any permission of its own. It is now behind `#if DEBUG` and is absent from
release builds; `strings` on the shipped binary finds none of its output.

**The hardened runtime was off.** It is on now (`codesign --options runtime`). For an app that can
read every browser window and synthesise keystrokes, it is worth having the loader refuse
injected libraries.

## The apps list, added in 1.6

Keeper can now take another application off your screen, which is a new power and deserves saying
plainly.

**It hides, it never quits.** The app keeps running and ⌘Tab brings it straight back, so nothing
Keeper does to an app can lose you work. Quitting was considered and rejected for exactly that
reason. Hiding goes through the Accessibility access Keeper already holds — no new permission is
requested, and nothing is installed.

**Three applications can never be blocked**, and this is enforced in the model rather than in the
menu, so an identifier written straight into the preferences file by hand is dropped on the way in
rather than honoured: `com.apple.systempreferences`, because that is where Keeper's own access is
revoked and blocking it would be real lock-in; `com.apple.finder`; and `dev.keeper.Keeper`. There
are tests for all three, including the hand-edited case.

**A session that ends does not unhide anything.** Keeper hid a window; bringing it back is yours
to do. It never unhides an app either, so it cannot be used to reveal something you hid yourself.

**The list is bundle identifiers**, stored in Keeper's preferences next to the site list. Like the
site list it is not encrypted and does not need to be, but a list of apps you are avoiding can be
personal, so it is worth knowing where it lives.

## What was checked and found sound

**The debug trust bypass is not in the shipped app.** `KEEPER_ASSUME_TRUSTED=1` skips the
Accessibility check so the window's states can be looked at during development. It is inside
`#if DEBUG`; `strings .build/release/Keeper | grep KEEPER_ASSUME_TRUSTED` returns nothing.

**The ⌘W keystroke is aimed, not broadcast.** Before pressing anything, Keeper re-reads the
window's address and re-checks it against your list, so a tab you already navigated away from is
left alone. Then it picks one of three routes, in order of how much it can hurt: if the browser
window is focused *and* the browser is the frontmost app, a system-wide ⌘W (which is what a real
keypress is); if only the window is focused, the keystroke is posted to that process alone; if
neither, it presses the tab's own close button through Accessibility and posts no key at all. The
dangerous route is the one that is checked hardest.

**Nothing a web page controls is ever drawn.** The knight's bubble says "Are you trying to enter
youtube.com?" using the *rule you typed*, not the page's title or address. The event line is the
same, plus the browser's name from the OS. So there is no page-controlled string anywhere in
Keeper's interface to spoof with, and no reason to worry about a site with a right-to-left
override in its name.

**The parser cannot be injected into and cannot be made to hang.** It builds no shell command, no
query and no regular expression — it is `lowercased()` and index arithmetic, all linear. It is
tested against empty lines, 200,000-character hosts, 50,000 slashes, control characters,
right-to-left overrides, zero-width joiners, combining marks and emoji: nothing crashes, nothing
takes measurable time, and nothing produces a rule that matches a page it has no business
matching. See `Tests/KeeperTests/BlacklistRobustnessTests.swift`.

**The login item is the system's own.** `SMAppService.mainApp` registers the app with macOS. There
is no helper, no launch agent written by hand, nothing installed outside the bundle, and turning
the switch off unregisters it.

## What is true and you may not like it

**Keeper is not sandboxed, and cannot be.** The Accessibility API is not available to a sandboxed
app. This is the same position every distraction blocker and window manager on the Mac is in.

**It is signed but not notarized.** Notarization needs a Developer ID certificate, which needs
the paid Apple Developer Program. So the first time you open it, macOS says Apple could not verify
it is free of malware and offers to move it to the Trash; since macOS 15 there is no
Control-click bypass, and you clear it once through System Settings → Privacy & Security → Open
Anyway. That warning is the system telling you the truth, and you should read it as such: Apple
has not scanned this build, and no amount of packaging on our side changes that. If you would
rather not take it on faith, build it yourself — `scripts/build-app.sh` — from the same source you
are reading.

To see what you have before you open it:

    codesign -dv --verbose=2 /Applications/Keeper.app
    spctl --assess --verbose /Applications/Keeper.app

**Keeper turns on accessibility support in your browsers.** It sets `AXManualAccessibility` on
Chromium- and Electron-based apps, which is what makes them publish the tree Keeper reads. That
setting stays on for as long as that browser runs, and it costs the browser a little work. Nothing
else about the browser is changed.

**There is a fraction of a millisecond where the keystroke could land elsewhere.** Between
confirming the browser is frontmost and posting ⌘W, you could switch apps, and the keystroke would
go to whatever came forward — closing a window there. The check happens immediately before the
post, so the gap is microseconds, but it is not zero. This is inherent to synthesised keystrokes;
the only complete fix is to never use the system-wide route, which would stop the closing working
in some browsers.

**A site name in a script other than Latin may not match.** If you type a domain in Cyrillic,
Keeper stores it as you typed it, while browsers usually report such addresses in their encoded
`xn--` form, so the rule can sit in the list and never fire. Keeper does not convert between the
two. If you rely on this, add the `xn--` form instead and check it with a real visit.

**Your list is readable by anything running as you.** It is stored in Keeper's preferences, like
every app's settings. It is not encrypted, and it does not need to be — but a list of sites you
are avoiding can be personal, so it is worth knowing where it is.

## Reporting something

If you find something here that is wrong, or something that is not here and should be, open an
issue on the repository. There is no bounty and no security team; it is one app and its author.
