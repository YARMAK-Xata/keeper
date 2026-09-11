# Security

Keeper asks for Accessibility access, which is the widest grant on a Mac: it lets an app read the
contents of other apps' windows and press keys in them. That is a lot to hand to a small program
you were sent as a disk image, so this is what Keeper does with it, what was checked, and what is
still true that you might not like.

Reviewed 12 September 2026 against the 1.10 source tree.

## The two properties worth trusting

**Keeper contacts GitHub once a day, and you can switch that off.** Until version 1.9 this
section said Keeper *could not* talk to the network at all — no `URLSession` anywhere, and a grep
you could run to prove it. That is no longer true. A security document that quietly keeps a
promise the code has stopped honouring is worse than one that never made it, so here is exactly
what changed, stated before you have to go looking for it.

**It is on when you install Keeper.** Not opt-in. The first time you open Keeper it will, within
a few seconds, make one request to GitHub. If that is not acceptable to you, turn off **Check for
updates automatically** in Settings, and Keeper will make no network request of any kind ever
again. We chose on-by-default knowing what it costs us to say here, because an update notice
nobody is offered is not one — and an app that ships security fixes people never hear about is
its own kind of risk.

**Keeper opens itself at login.** It registers as a login item the first time you run it, because
it guards a session you started and a guard you have to remember to launch is one you forget on
the day it matters. It is an ordinary login item, not a background daemon or a helper that
installs itself somewhere: it shows up in System Settings → General → Login Items alongside
everything else, and in Keeper's own Settings as **Open Keeper at login**. Turning it off in
either place sticks — the registration happens once, on a first run, and never argues with a
decision you have made afterwards.

### The whole of it

There is exactly one network call in the app. It lives in `Sources/Keeper/UpdateChecker.swift`
and it is a single GET to:

    https://api.github.com/repos/YARMAK-Xata/keeper/releases/latest

It asks whether a version newer than yours has been published. It sends no body, no cookies, no
identifier, and nothing about you, your lists, or your browsing. The only thing identifying the
request at all is a `User-Agent` of `Keeper/1.9` — GitHub rejects requests without one — and it
says nothing that distinguishes your copy from anyone else's. The session is ephemeral, so nothing
about the request is written to disk.

What GitHub can therefore see: that some copy of Keeper, of a given version, asked from your IP
address, at most once a day. What GitHub cannot see: who you are, what you block, or what you
browse. That is the honest extent of it, and it is not nothing — an IP address is roughly a
location, and a daily request is roughly "this machine was switched on today". If you would rather
not hand that to GitHub, the switch is in Settings and it is the only thing you have to do.

**It never downloads or installs anything.** It compares a version number and offers a link to the
release page, which opens in your browser. Keeper contains no code that could replace itself, and
a reply pointing anywhere other than `github.com` is discarded rather than opened.

**It still starts no other program** — no `Process`, `NSTask`, `system`, `popen` or
`NSAppleScript` — and there are still no third-party packages, so nothing arrives through a
dependency either.

### Checking this yourself

    grep -rE "URLSession|NWConnection|socket\(|Process\(|NSTask|NSAppleScript" Sources/

Everything it finds is in `UpdateChecker.swift`. `Tests/KeeperTests/NetworkSurfaceTests.swift`
asserts that on every build, along with the address being the one written above and switching the
check off actually sticking — so if this section ever drifts from the code, the build fails.

**Nothing about your browsing is written down.** The only things Keeper saves are the two lists
you built (`blacklistText` and `blockedAppsText`), whatever you had half-typed in the add field
(`draftSite`), the Settings switches, and whether the permission alert has been shown. The address
of a page it spotted lives in memory for as long as the panel shows "Closed youtube.com in
Safari", and goes when you quit. No page address is written to a file, a log, or the system console.

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
Accessibility check so the surfaces' states can be looked at during development. It is inside
`#if DEBUG`; `strings .build/release/Keeper | grep KEEPER_ASSUME_TRUSTED` returns nothing.

**The knight's window takes a click only where he is drawn.** He is carried by a borderless
window that floats above everything on every Space, 360 by 300 points of mostly empty air. It
passes clicks through to whatever is behind it — the Dock included — and stops doing so only
while the pointer is inside the 60 by 78 points he actually occupies, which is re-checked every
frame as he moves. It reads the pointer position and the mouse buttons and nothing else: no event
tap, no monitor on anyone else's input. A carry ends the moment no button is held, with or
without a mouse-up, so a drag interrupted by a Space switch cannot leave a window above
everything swallowing clicks.

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
