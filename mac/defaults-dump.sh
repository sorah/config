#!/usr/bin/env zsh
#
# Snapshot the preference domains that mac/defaults.sh cares about, so a new
# machine (or a drifted old one) can be diffed against a known-good capture:
#
#   ./mac/defaults-dump.sh > /tmp/this-machine.txt
#   diff -u mac/defaults-snapshot.txt /tmp/this-machine.txt
#
# One line per key, sorted, with per-machine state (window frames, recents,
# analytics stamps, Dock contents, Spaces UUIDs, iCloud-synced text
# replacements, Finder per-folder view settings) dropped.

exec python3 - <<'PY'
import plistlib, subprocess, sys

DOMAINS = [
    "com.apple.dock",
    "com.apple.finder",
    "com.apple.HIToolbox",
    "com.apple.inputsources",
    "com.apple.keyboard.preferences",
    "com.apple.symbolichotkeys",
    "com.apple.universalaccess",
    "com.apple.AppleMultitouchTrackpad",
    "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    "com.apple.AppleMultitouchMouse",
    "com.apple.driver.AppleBluetoothMultitouch.mouse",
    "com.apple.driver.AppleHIDMouse",
    "com.apple.WindowManager",
    "com.apple.menuextra.clock",
    "com.apple.screencapture",
    "com.apple.screensaver",
    "com.apple.systemuiserver",
    "com.apple.Spotlight",
    "com.apple.soundpref",
]

# Substrings; a key containing any of these is per-machine noise.
NOISE = (
    "NSWindow Frame", "NSSplitView", "last-analytics-stamp", "lastShowIndicatorTime",
    "LastHeartbeat", "mod-count", "LastPeriodicAnalytics", "SULastCheckTime",
    "AppleInputSourceUpdateTime", "AppleInputSourceHistory", "persistent-apps",
    "persistent-others", "recent-apps", "GoToField", "FXRecentFolders",
    "RecentMoveAndCopyDestinations", "SearchRecents", "SGTRecentFileSearches",
    "ViewSettings", "ViewSetting", "StandardViewOptions", "FK_",
    "ProgressWindowLocation", "last-selection", "FXDesktopVolumePositions",
    "NSToolbar Configuration", "_FXInputMethodLocation",
    "NSUserDictionaryReplacementItems", "NSLinguisticDataAssets", "AKLast",
    "History", "keyboardAccessCommandMap", "trash-full", "com.apple.gms",
    "SyncExtensions", "NSSpellChecker", "PreferencesWindow",
    "TagsCloudSerialNumber", "DataSeparatedDisplayNameCache", "ColorSync",
    "CommonPanels", "SpacesDisplayConfiguration", "Configuration",
    "TALAppsToRelaunchAtLogin", "bootUUID", "UpgradedTo", "UpgradeLevel",
    "UpgradedToTen", "TransitionComplete", "SchemaVersion", "CleanExit",
    "missionControlTooltipCount", "HasDisplayed", "hasMigrated", "HasAttempted",
    "SUHasLaunchedBefore", "SUUpdateGroupIdentifier",
    # live input-source state (changes as you switch sources)
    "AppleCurrentKeyboardLayoutInputSourceID", "AppleSavedCurrentInputSource",
    "AppleSelectedInputSources",
    # Spotlight UI/usage state
    "engagement", "lastVisibleScreenRect", "lastWindowPosition", "queryViewOptions",
    "showed", "startTime", "windowHeight", "FTEReset", "ModelName",
    "PreferencesVersion", "SSActionKeyboardAliasStoreVersion", "collectedBundleID",
    # menu bar item ordering depends on the display, not on preference
    "NSStatusItem Preferred Position",
    # misc transient
    "LastTrashState", "FXLastSearchScope", "FXDetachedDesktopProviderID",
    "FXDetachedDocumentsProviderID", "FXICloudLoggedIn", "SidebarWidth",
    "closeViewZoomFactorBeforeTermination", "closeViewZoomDisplayID",
)

def flat(prefix, v, out):
    if isinstance(v, dict):
        for k in sorted(v, key=str):
            flat(f"{prefix}.{k}", v[k], out)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            flat(f"{prefix}[{i}]", x, out)
    else:
        if isinstance(v, bytes):
            v = f"<{len(v)} bytes>"
        out.append(f"{prefix} = {v!r}")

def dump(label, argv):
    r = subprocess.run(argv, capture_output=True)
    if r.returncode != 0 or not r.stdout.strip():
        return
    try:
        d = plistlib.loads(r.stdout)
    except Exception as e:
        print(f"### {label}: unreadable ({e})")
        return
    d = {k: v for k, v in d.items() if not any(n in k for n in NOISE)}
    if not d:
        return
    out = []
    for k in sorted(d, key=str):
        flat(k, d[k], out)
    print(f"### {label}")
    print("\n".join(out))

ver = subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip()
build = subprocess.run(["sw_vers", "-buildVersion"], capture_output=True, text=True).stdout.strip()
print(f"### macOS {ver} ({build})")

dump("NSGlobalDomain", ["defaults", "export", "-g", "-"])
dump("NSGlobalDomain (currentHost)", ["defaults", "-currentHost", "export", "-g", "-"])
for dom in DOMAINS:
    dump(dom, ["defaults", "export", dom, "-"])
    dump(f"{dom} (currentHost)", ["defaults", "-currentHost", "export", dom, "-"])

import os, glob
print("### MDM-managed domains (these override everything above)")
seen = set()
for p in glob.glob("/Library/Managed Preferences/*.plist") + \
         glob.glob(f"/Library/Managed Preferences/{os.environ.get('USER','')}/*.plist"):
    seen.add(os.path.basename(p)[:-6])
for n in sorted(seen):
    print(n)
PY
