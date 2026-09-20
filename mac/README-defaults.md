# macOS preference replication

Captured from a Mac running macOS 27.0 (26A5406e) in 2026-08.

| File | Purpose |
| --- | --- |
| `defaults.sh` | Apply the preferences. Idempotent, called from `setup.sh`. |
| `defaults-dump.sh` | Snapshot the same domains, filtered of per-machine noise. |
| `defaults-snapshot.txt` | Committed reference snapshot to diff a machine against. |

## Usage

```sh
./mac/defaults.sh          # apply, then log out and back in
```

To find drift between this machine and the reference:

```sh
./mac/defaults-dump.sh > /tmp/now.txt && diff -u mac/defaults-snapshot.txt /tmp/now.txt
```

To re-capture after deliberately changing something in System Settings:

```sh
./mac/defaults-dump.sh > mac/defaults-snapshot.txt
```

## What the script contains

`defaults.sh` holds **only settings that differ from stock macOS**. Around 130
of the ~180 keys originally captured turned out to be at their factory value
and were dropped; the trimmed script writes 50.

Two consequences worth understanding:

1. **It converges a fresh Mac, not a drifted one.** Because stock-valued
   settings are omitted, the script will not undo one that has already been
   changed elsewhere. It does not force tap-to-click off, for instance, since
   off is already the factory value -- so a machine where someone enabled it
   stays enabled. Run `defaults-dump.sh` and diff to catch that.
2. **Stock values are not queryable.** They live in each app's compiled-in
   `registerDefaults`, not in any plist on disk (`Dock.app`'s `default.plist`
   is only the default *Dock contents*). So the trim rests on knowledge of
   macOS defaults, not measurement. The entries below are the ones kept
   despite being uncertain -- if any turns out to be stock after all, writing
   it is harmless, just redundant:

   | Setting | Why unsure |
   | --- | --- |
   | `HIToolbox AppleFnUsageType = 0` | Apple documents no value mapping |
   | `dock expose-group-apps = false` | may already be the factory value |
   | `WindowManager HideDesktop = true` | changed meaning across releases |
   | `WindowManager AppWindowGroupingBehavior = 1` | undocumented |
   | `AppleMultitouchMouse MouseButtonMode = OneButton` | conflicting reports on the Magic Mouse default |

Dropped as stock, grouped so you can spot-check: the whole trackpad gesture
set (every gesture on the captured machine is factory -- only the two speeds
survive), the whole `driver.AppleHIDMouse` block, symbolic hotkeys 60/61/79-82
and 98 (stock input-source, Space-switching and Help-menu bindings), the
`screencapture` domain (capture-tool UI state, not preferences), Dock hot
corner and gesture-enabled flags, Stage Manager's off-by-default flags, most
`menuextra.clock` keys, Finder sidebar/group-by/tag-name/`NewWindowTarget`
keys, smart-quote and auto-capitalisation keys, and `screensaver` /
`soundpref` / `systemuiserver` leftovers. `defaults-snapshot.txt` keeps all of
them, so nothing is lost.

Also dropped: `finder ShowMountedServersOnDesktop`, which was doubly inert --
`true` is the factory value *and* the MDM profile forces it to `false`.

## Things worth knowing

**Pointer behaviour is split across three places.** `defaults` only holds the
trackpad side. `com.apple.swipescrolldirection` and `com.apple.mouse.scaling`
are deliberately unset, so the trackpad keeps macOS "natural" scrolling while
LinearMouse (`dot.config/linearmouse/linearmouse.json`) reverses scroll
direction and pins pointer acceleration per mouse. Karabiner
(`dot.config/karabiner/karabiner.json`) maps right shift to escape. Applying
`defaults.sh` without those two configs gives a noticeably different feel.

**Caps Lock -> Control lives in a per-host key**, not the normal global domain:
`defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0`.
There is a second entry for vendor 1452 / product 591, which is the *Karabiner
DriverKit VirtualHIDKeyboard* -- mapped identity so Karabiner's synthetic
output is not remapped a second time. Keep both or the remap misbehaves when
Karabiner is running.

**If you ever customise a trackpad gesture, it must go into three domains
that agree:** `com.apple.AppleMultitouchTrackpad` (built-in),
`com.apple.driver.AppleBluetoothMultitouch.trackpad` (Magic Trackpad), and the
per-host `com.apple.trackpad.*` keys under `-currentHost -g` that the System
Settings pane reads back. Writing only one leaves the UI showing stale values.
Nothing in `defaults.sh` does this today, since all gestures are stock -- but
the two trackpad domains do disagree on `TrackpadThreeFingerVertSwipeGesture`
(2 built-in vs 1 Bluetooth), which is what that kind of partial write looks
like after the fact.

**Keyboard shortcuts are numeric IDs in `com.apple.symbolichotkeys`.** Apple
publishes no mapping, so the values are copied verbatim rather than
reconstructed. What is known: 15-26 are the accessibility zoom / invert-colours
/ contrast hotkeys (all disabled here, freeing Cmd-Opt-8 and Cmd-Opt-+/- for
apps), and 176 is the system Emoji & Symbols hotkey (Ctrl-Cmd-Space), disabled
in favour of an `NSUserKeyEquivalents` menu override on Cmd-Shift-`.`. 60, 61,
79-82 and 98 are stock bindings that happen to be persisted explicitly.

**MDM overrides some of this on work machines.** Anything in
`/Library/Managed Preferences/` wins over the user domain, silently. On the
captured machine that includes `com.apple.finder`, `com.apple.screensaver`,
`com.apple.loginwindow`, `com.apple.systemuiserver` and `com.apple.desktop`.
Concretely, the user domain has `ShowMountedServersOnDesktop = true` while the
profile forces `false`; the user value has no effect. Check with:

```sh
plutil -p "/Library/Managed Preferences/$USER/com.apple.finder.plist"
```

**Needs a logout, not just a `killall`:** input sources (ABC + AquaSKK), the fn
key action (`AppleFnUsageType`), and modifier remapping on already-connected
keyboards. AquaSKK must be installed before the input-source keys mean
anything, and its own dictionaries live in
`~/Library/Application Support/AquaSKK` (not managed here).

## Not captured

Machine-local or account-synced state, left out on purpose:

- Dock contents (`persistent-apps`), window frames, Spaces layout, hot-corner
  assignments other than bottom-right
- Login items (`com.apple.loginwindow` `TALAppsToRelaunchAtLogin`)
- Display arrangement and ColorSync profiles
- Text replacements (`NSUserDictionaryReplacementItems`) -- iCloud-synced
- Per-app notification settings (`com.apple.ncprefs`; opaque blobs)
- Safari settings, which live in its sandbox container rather than the
  `com.apple.Safari` domain
