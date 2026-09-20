#!/usr/bin/env zsh
#
# macOS UI preferences, captured from sorah's Mac on macOS 27.0 (2026-08).
# Idempotent: safe to re-run.
#
# This holds only settings that DIFFER from stock macOS. Anything already at
# its factory value is left out -- see mac/README-defaults.md for the full list
# of what was dropped and why, and note the consequence: this script converges
# a freshly provisioned Mac, but will not undo a stock-valued setting that some
# other machine has already had changed (e.g. it does not force tap-to-click
# off, because off is already the factory value).
#
# mac/defaults-snapshot.txt remains the lossless record of every value.
#
# Some of this is overridden by MDM on managed machines; see the README.

set -x

# `defaults` cannot type numbers inside the old-style inline plist syntax --
# `{enabled = 0;}` stores the string "0", not the integer 0 -- so anything
# nested is written as XML instead. Same for reals: `-float` truncates to
# single precision, `<real>` does not.

# shk <id> <0|1> [param ...]  -- write one com.apple.symbolichotkeys entry
shk() {
  local id=$1 flag=false value=""
  [[ $2 == 1 ]] && flag=true
  shift 2
  if (( $# )); then
    local params=""
    for p in "$@"; do params+="<integer>${p}</integer>"; done
    value="<key>value</key><dict><key>parameters</key><array>${params}</array>"
    value+="<key>type</key><string>standard</string></dict>"
  fi
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
    "<dict><key>enabled</key><${flag}/>${value}</dict>"
}

# modmap <vendor-product-key> <src> <dst>  -- one modifier-key remapping
modmap() {
  defaults -currentHost write -g "com.apple.keyboard.modifiermapping.$1" \
    "<array><dict><key>HIDKeyboardModifierMappingSrc</key><integer>$2</integer>\
<key>HIDKeyboardModifierMappingDst</key><integer>$3</integer></dict></array>"
}

##### Locale / language ########################################################

defaults write -g AppleLanguages -array 'en-GB' 'ja-GB'
defaults write -g AppleLocale -string 'en_GB'
# Stock for en_GB, but not for a US-provisioned machine, so set explicitly
defaults write -g AppleMeasurementUnits -string Centimeters
defaults write -g AppleMetricUnits -bool true

##### Keyboard #################################################################

# Fast key repeat: 375ms delay, 30ms interval (stock is 68 / 6)
defaults write -g InitialKeyRepeat -float 25
defaults write -g KeyRepeat -float 2

# F1/F2 etc. behave as standard function keys
defaults write -g com.apple.keyboard.fnState -bool true

# Full Keyboard Access: Tab moves between all controls, not just text boxes
defaults write -g AppleKeyboardUIMode -int 3

# fn key action. Value copied verbatim; the UI offers Do Nothing / Change Input
# Source / Show Emoji & Symbols / Start Dictation and Apple documents no
# mapping, so which one 0 means is unconfirmed.  [logout]
defaults write com.apple.HIToolbox AppleFnUsageType -int 0

# Modifier keys: Caps Lock -> Control (0x700000039 -> 0x7000000E4) for every
# keyboard, EXCEPT vendor 1452 / product 591, which is the Karabiner DriverKit
# VirtualHIDKeyboard -- exempted so Karabiner output is not remapped twice.
modmap 0-0-0        30064771129 30064771300   # caps lock -> control
modmap 1452-591-0   30064771129 30064771129   # Karabiner virtual kbd: leave alone

defaults write com.apple.keyboard.preferences IsMixmojiSuggestionsEnabled -bool false

# Input sources: ABC layout + AquaSKK (Japanese). AquaSKK must be installed
# first, and HIToolbox is only re-read at login.  [logout]
defaults write com.apple.HIToolbox AppleEnabledInputSources '<array>
  <dict><key>InputSourceKind</key><string>Keyboard Layout</string>
        <key>KeyboardLayout ID</key><integer>252</integer>
        <key>KeyboardLayout Name</key><string>ABC</string></dict>
  <dict><key>Bundle ID</key><string>com.apple.CharacterPaletteIM</string>
        <key>InputSourceKind</key><string>Non Keyboard Input Method</string></dict>
  <dict><key>Bundle ID</key><string>com.apple.PressAndHold</string>
        <key>InputSourceKind</key><string>Non Keyboard Input Method</string></dict>
</array>'
defaults write com.apple.inputsources AppleEnabledThirdPartyInputSources -array \
  '{"Bundle ID" = "jp.sourceforge.inputmethod.aquaskk"; InputSourceKind = "Keyboard Input Method";}' \
  '{"Bundle ID" = "jp.sourceforge.inputmethod.aquaskk"; "Input Mode" = "com.apple.inputmethod.Japanese"; InputSourceKind = "Input Mode";}'

##### Keyboard shortcuts #######################################################

# Accessibility zoom / invert-colours / contrast hotkeys (IDs 15-26): all off,
# so Cmd-Opt-8 and Cmd-Opt-+/- stay available to apps.
for id in 15 16 17 18 19 20 21 22 23 24 25 26; do
  shk $id 0
done
defaults write com.apple.universalaccess closeViewHotkeysEnabled -bool false

# Unidentified system hotkey, disabled. 65535/65535/0 is how macOS records
# a shortcut with no key assigned, so it is kept verbatim.
shk 164 0 65535 65535 0

# System "Show Emoji & Symbols" (Ctrl-Cmd-Space) off, replaced by the
# Cmd-Shift-. menu equivalent below -- which frees Ctrl-Cmd-Space entirely.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 176 \
  '<dict><key>enabled</key><false/>
   <key>value</key><dict><key>type</key><string>SAE1.0</string></dict></dict>'
defaults write -g NSUserKeyEquivalents -dict-add 'Emoji & Symbols' -string '@$.'
defaults write com.apple.universalaccess 'com.apple.custommenu.apps' -array NSGlobalDomain

##### Trackpad #################################################################
#
# Every gesture on this machine is at its factory setting, so only the speeds
# are here. If a gesture ever does get customised, remember it has to be
# written to three domains that agree: com.apple.AppleMultitouchTrackpad
# (built-in), com.apple.driver.AppleBluetoothMultitouch.trackpad (Magic
# Trackpad), and the per-host com.apple.trackpad.* keys under `-currentHost -g`
# that the System Settings pane reads back.

defaults write -g com.apple.trackpad.scaling -float 2.0          # tracking speed
defaults write -g com.apple.trackpad.scrolling '<real>0.1838</real>'  # scroll speed

# Spring-loaded folder delay (stock sits mid-slider)
defaults write -g com.apple.springing.delay '<real>0.7575731128454208</real>'

# No two-finger swipe-to-navigate-back in apps
defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false

##### Mouse ####################################################################
#
# com.apple.swipescrolldirection and com.apple.mouse.scaling are deliberately
# left UNSET: the trackpad keeps macOS "natural" scrolling, while per-mouse
# scroll direction, pointer speed and acceleration are handled by LinearMouse
# (mac/dot.config/linearmouse/linearmouse.json), which reverses scrolling for
# the Logitech mice only. Setting swipescrolldirection here would fight it.
# com.apple.driver.AppleHIDMouse is likewise untouched -- all stock, and
# LinearMouse governs those mice anyway.

# Magic Mouse: single button (no right-click), no one-finger smart zoom
for dom in com.apple.AppleMultitouchMouse com.apple.driver.AppleBluetoothMultitouch.mouse; do
  defaults write $dom MouseButtonMode -string OneButton
  defaults write $dom MouseOneFingerDoubleTapGesture -int 0
  defaults write $dom UserPreferences -bool true   # marks the set as user-customised
done

##### Dock / Mission Control ###################################################

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock tilesize -float 39
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock mru-spaces -bool false        # don't reorder Spaces by use
defaults write com.apple.dock expose-group-apps -bool false # Mission Control: don't group by app
defaults write com.apple.dock workspaces-auto-swoosh -bool true

##### Windows ##################################################################

defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
defaults write com.apple.WindowManager HideDesktop -bool true
defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1
defaults write -g AppleShowScrollBars -string Always

##### Finder ###################################################################

defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv   # list view
# Open/Save dialogs default to list view
defaults write -g NSNavPanelFileListModeForOpenMode2 -int 2
defaults write -g NSNavPanelFileListModeForSaveMode2 -int 2
defaults write -g NSNavPanelFileLastListModeForOpenModeKey -int 2
defaults write -g NSNavPanelFileLastListModeForSaveModeKey -int 2

##### Menu bar #################################################################

defaults write com.apple.menuextra.clock ShowAMPM -bool true   # 12-hour, vs 24h for en_GB
defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true

##### Misc #####################################################################

defaults write -g com.apple.sound.beep.sound -string /System/Library/Sounds/Sosumi.aiff
defaults write -g shouldShowRSVPDataDetectors -bool false

##### Apply ####################################################################

set +x
for app in Dock Finder SystemUIServer ControlCenter; do
  killall "$app" 2>/dev/null || true
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

cat <<'EOF'

Done. A logout/login is needed for: input sources (AquaSKK/ABC), fn key action,
and modifier-key remapping on already-connected keyboards.
EOF
