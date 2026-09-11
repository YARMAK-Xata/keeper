# Keeper

A pixel-art knight that closes browser tabs you told it to keep you away from.

1. Click the shield in the menu bar. Add the sites you won't visit this session — type a name,
   paste a page address, or pick one from **Presets** — and the apps you won't open, from
   **Choose**.
2. Press **Start session**. The knight takes his post at the end of the Dock and both lists lock.
3. Open one of those sites in any browser and he runs over, asks "Are you trying to enter
   youtube.com?", and closes the tab. Open one of those apps and he asks the same question and
   hides it.
4. Press **Stop session** when you are done.

No timers, no accounts, no third-party packages. Keeper speaks English, Ukrainian,
Russian, German, French, Italian and Polish, and follows your Mac rather than asking: set the
system to Polish and Keeper is Polish. There is no language setting of its own.

## Where Keeper lives

Three surfaces, one job each.

| Surface | What it is for | How you get there |
|---|---|---|
| **The panel** | The whole task: the state, the list, Start and Stop | Click the menu bar shield |
| **The window** | The same list with room to breathe, and the Accessibility step | "Open Keeper", or the Dock icon |
| **Settings** | Where Keeper appears, and whether it starts at login | "Settings…", or ⌘, |

The panel is the app. Everything you can do, you can do without opening a window: the list, the
one button, and links to the window, Settings and Quit. The window is not a second design — both
surfaces render the same `TaskSection` and the same header, at 420 points and 340, and every
measurement either of them uses comes from `Metrics.swift` — so there is one look and one list,
and closing the window never takes a capability away. Right-clicking the shield gives a
plain menu with the same three links, so a panel that fails to open can never leave Keeper
running with nothing to click.

The shield is a stroked outline rather than the sprite, because every other icon up there is a
thin outline and a filled pixel-art character among them reads as a blob at any size. It is empty
while Keeper waits and filled like smoked glass while a session runs, so you can tell at a glance
whether the knight is on duty. He himself stays in the panel, in the window, and on screen during
a session.

Keeper registers itself as a login item the first time it runs, so it is there the next time you
switch the Mac on — a guard you have to remember to start is one you forget on the day it matters.
It is an ordinary login item: System Settings → General → Login Items lists it, **Open Keeper at
login** in Settings toggles it, and turning it off anywhere sticks, because the registration
happens once on a first run and never argues with you afterwards.

**Show in menu bar** and **Show in Dock** let you decide where Keeper appears. It will not let you
switch off both — whichever is the last one on stays on, so there is always a way back in.

## Sites

Each entry is a host, optionally with a path: `youtube.com`, `reddit.com/r/funny`, or a bare word
like `twitter` that matches any host label. Scheme, `www.`, query and trailing slash are ignored,
and matching covers subdomains.

Pasting a full page address is read as "this whole site", so pasting a video link blocks
`youtube.com` rather than `youtube.com/watch`. Text typed without a scheme is taken literally, so
`reddit.com/r/funny` still means only that corner of Reddit.

## Apps

An app on the list is held by its bundle identifier, so renaming it, running a beta build or
keeping a second copy in another folder does not break the rule. **Choose** lists what is running
right now — the thing annoying you this minute is one click — and nests everything else in your
Applications folders underneath, so nothing needs typing and no file chooser has to take over the
screen.

When the knight catches one he **hides** it: the windows leave the screen and ⌘Tab, the app keeps
running, nothing closes and nothing is lost. Quitting was considered and rejected, because an app
with unsaved work answers ⌘Q with a dialog, which is the opposite of getting out of your way.
Stopping the session does not bring hidden apps back; ⌘Tab does, whenever you want it.

Three apps can never be added, and the menu says why rather than offering a row that does
nothing: **System Settings**, because that is where Keeper's own access is revoked and blocking it
would make Keeper the one thing you cannot switch off; **Finder**, because hiding it takes the
desktop with it; and **Keeper**, because that is the window with Stop session in it.

### Where the knight stands

At the right-hand end of the Dock, on the same ground the Dock sits on, and he moves whenever it
does — resized, or simply widened by an app launching. Keeper reads the Dock's row of icons from
its accessibility tree to find it, because the Dock's own window is a full-screen transparent
overlay whose bounds say nothing about where the icons are. A Dock on the left or right edge, or
hidden, puts him back in the bottom-right corner of the screen.

## How it detects

One mechanism for every browser: the macOS Accessibility API. Once a second Keeper reads the page
address of each visible browser window from its accessibility tree, which works the same way in
Safari, Chrome, Arc, Brave, Edge, Firefox, Zen, Orion and anything else that shows a web page. So
it needs one permission: System Settings → Privacy & Security → Accessibility → Keeper.

To close a tab, Keeper raises the window, re-checks that the page still matches, presses ⌘W,
verifies, and falls back to the tab's close button. A window that refuses gets a three-second
cooldown rather than a retry loop.

Finding a blocked app is far cheaper — a list of running applications rather than an accessibility
tree walk — so it happens on every tick before the browsers are looked at. Hiding goes through the
same Accessibility access, with the same three-second cooldown when an app refuses.

## Security

Accessibility access is the widest grant on a Mac, so `SECURITY.md` sets out what Keeper does with
it: the one network call it makes and what is in it, what it cannot do (start another program),
what it never writes down
(any page you visited), how the ⌘W keystroke is aimed rather than broadcast, and what is true that
you may not like — it is not sandboxed, and it is signed but not notarized. It is worth reading
before you install it, and it is short.

## Build

    scripts/build-app.sh      # → build/Keeper.app
    swift test                # unit tests
    scripts/make-icon.py      # → Assets/AppIcon.icon and Assets/AppIcon.icns

Launch flags: `--start` begins a session immediately with the saved list. A debug build also
honours `--probe` (with `--tree`, `--close`, `--app=Safari`, `--walk`) for checking detection by
hand, `--panel` and `--settings` for looking at those surfaces, and `KEEPER_ASSUME_TRUSTED=1`,
which skips the Accessibility check so the other states can be inspected without the system
prompt. All four are compiled out of release builds.

`scripts/signing-identity.sh` picks the best identity in your keychain — a Developer ID first,
then an Apple Development one, then a local certificate, then ad-hoc — and the app is always built
with the hardened runtime. Only the first of those travels: see *Sending it to someone*. With
ad-hoc signing macOS ties the Accessibility grant to the exact binary, so after a rebuild you may
need to switch Keeper off and on again in the Accessibility list; `scripts/make-signing-cert.sh`
creates a local identity that stops that.

### The design system

`Sources/Keeper/Metrics.swift` holds every spacing, size and type choice, and the two surfaces
read it rather than carrying their own numbers. `DesignSystemTests` reads the view sources and
fails if one writes a measurement down instead of naming one, and `TextFitsTests` measures the
translated strings against the width they have to fit — which is how the panel's width was chosen,
and how an eighth language that overflows it will announce itself.

### The icon

A close crop of the sprite — helmet, eyes, shield, sword — and the whole thing rests on one rule:
**every icon size must be a whole number of screen pixels per sprite pixel.** The 1024 master is
filled edge to edge by a 16 × 16 sprite crop at exactly 64 pixels each, so 512, 256, 128, 64, 32
and 16 all divide cleanly. Nothing is blurred and nothing is composed off-grid.

It ships twice, because macOS 26 and macOS 14–15 want different things. `Assets/AppIcon.icon` is
an Icon Composer bundle — flat layers and a manifest, with no baked shadow, highlight or gradient,
because macOS 26 lights it live and derives the Dark, Clear and Tinted appearances from it;
`build-app.sh` compiles it with `actool` into `Assets.car`. `Assets/AppIcon.icns` is for macOS 14
and 15, which do not mask app icons, so that one draws its own rounded square. Building without
Xcode skips the first and still produces a working app.

## Sending it to someone

    scripts/make-dmg.sh       # → build/Keeper-1.8.dmg

That one file is everything. Opening it shows the knight, the Applications folder, and — drawn
into the window itself by `scripts/make-dmg-background.swift` — the route past Gatekeeper in all
seven languages. A full "Open me first" note in all seven sits beside them.

Keeper is signed but **not notarized**, because notarization needs a Developer ID certificate and
that needs the paid Apple Developer Program. Until then, the first time someone opens it macOS
says Apple could not verify it is free of malware and offers Move to Trash — and since macOS 15
there is no Control-click bypass, so they have to go to System Settings → Privacy & Security and
click Open Anyway. That is why the instruction is on the disk image window rather than only in a
file beside it: a text file next to an app is not where anyone looks.

Nothing but notarization removes that dialog. When you do have a Developer ID,
`scripts/make-dmg.sh` notarizes and staples without being asked, and `scripts/notarize.sh` run on
its own prints exactly what is still missing. No code changes.

## Languages

Strings live in `Sources/Keeper/Resources/<language>.lproj/Localizable.strings`, with plural forms
in the matching `.stringsdict`. Ukrainian, Russian and Polish need one, few and many where English
needs one and other, and the sentence "guarding 1 site and 5 apps" declines on both sides at once.
Seven languages ship: English, Ukrainian, Russian, German, French, Italian and Polish. A new one
is a new `.lproj` folder plus an entry in `CFBundleLocalizations` in `scripts/build-app.sh`, with
no code change — and a section in `docs/Open-me-first.txt`, which a test also insists on.

String Catalogs (`.xcstrings`) are the modern source format but SwiftPM copies them without
compiling, so they never resolve at runtime. These `.strings` and `.stringsdict` files are what a
catalog compiles down to.

Check a language without changing your Mac:

    build/Keeper.app/Contents/MacOS/Keeper -AppleLanguages "(uk)"

`swift test` fails if a key used in code is missing from English, if the languages disagree about
which keys exist, if a Slavic plural is missing a form, if a translation takes different arguments
from the English it replaces, if a two-argument string uses `%@` twice where `%1$@` and `%2$@` are
needed, or if a `.lproj` folder is not listed in `CFBundleLocalizations` and so can never be
chosen. The checks that matter most go through the *built* resource bundle rather than the files
on disk: a folder SwiftPM failed to copy looks perfect on disk and wrong on someone else's Mac.

## Updates

Keeper tells you when a newer release is out. It asks GitHub once a day whether a release newer
than this build has been published, and if so shows one line under the header with a link to it.

**This is on by default**, and it is the only thing in the app that touches the network. It is
switched off in Settings → *Check for updates automatically*, after which Keeper makes no network
request of any kind. It sends nothing about you, and it never downloads or installs anything —
Keeper has no code that could replace itself. `SECURITY.md` states this before anything else and
sets out the request in full, down to what GitHub can infer from it; `NetworkSurfaceTests` fails
the build if a second network call ever appears, if the address changes, or if switching the check
off stops working.

On by default is a real cost and it is paid deliberately: almost nobody opens Settings, so an
opt-in notice reaches almost nobody, and an app that ships fixes its users never hear about is its
own kind of risk. The trade is that every document describing Keeper has to say so plainly, which
is why they all do.


## Limits

- A blacklisted page in a background tab is caught the moment it becomes visible.
- Windows on another Space are left alone until you switch to that Space.
- Pinned tabs that ignore ⌘W and have no close button are reported rather than forced.
- An app with no windows — a menu bar tool — has nothing to hide, and is reported rather than
  pretended about.
- A domain written in a script other than Latin may not match; see `SECURITY.md`.

## Credits

Knight: "Animated Knight Character Pack v3.0" by rgsdev, CC BY-SA 4.0 (see
`Assets/LICENSE-knight.md`). Interface icons are SF Symbols.
