--[[
  Locale.lua
  Every piece of text the add-on shows. Where the game already has a
  translated string (slot names, Accept, Cancel, ...) we use the game's own
  global so it shows in the player's language. Detection never relies on
  these strings; it uses the game's strings and flags (see Tooltip.lua).

  To translate, copy this file, check GetLocale(), and override entries.
]]

local _, FWR = ...

local L = setmetatable({}, {
  -- A missing entry shows its key instead of erroring.
  __index = function(_, key) return key end,
})
FWR.L = L

local function G(name, fallback)
  local value = _G[name]
  if type(value) == "string" and value ~= "" then return value end
  return fallback
end

-- Slot names (game strings where they exist)
L.SLOT_MAINHAND = G("INVTYPE_WEAPONMAINHAND", "Main Hand")
L.SLOT_OFFHAND = G("INVTYPE_WEAPONOFFHAND", "Off Hand")
L.SLOT_RANGED = G("INVTYPE_RANGED", "Ranged")
L.SLOT_AMMO = G("INVTYPE_AMMO", "Ammo")

-- Slot states
L.STATE_ITEM = "Item"
L.STATE_EMPTY = "Empty"
L.STATE_SKIP = "Leave alone"
L.STATE_ITEM_DESC = "Swapping equips this item."
L.STATE_EMPTY_DESC = "Empty on purpose. Swapping unequips whatever is there."
L.STATE_SKIP_DESC = "The swap never touches this slot."

-- Generic buttons
L.ACCEPT = G("ACCEPT", "Accept")
L.CANCEL = G("CANCEL", "Cancel")
L.SAVE = G("SAVE", "Save")
L.DELETE = G("DELETE", "Delete")
L.OKAY = G("OKAY", "Okay")
L.CLOSE = G("CLOSE", "Close")
L.DISCARD = "Don't Save"
L.RENAME = "Rename"
L.SAVE_AS_NEW = "Save as New"
L.EDIT = G("EDIT", "Edit")
L.EQUIP = "Equip"
L.UP = "Up"
L.DOWN = "Down"
L.ADD_SET = "Add Set"
L.SETTINGS = G("SETTINGS", "Settings")

-- Window
L.TAB_EDIT = "Edit Set"
L.TAB_SETS = "Sets"
L.EXPERIMENTAL = "Experimental"
L.LOCK_WINDOW = "Lock window"
L.UNLOCK_WINDOW = "Unlock window"
L.LOCKED_HINT = "The window is locked. It can't be moved or resized."
L.UNLOCKED_HINT = "Drag the title to move. Drag the bottom-right corner to resize."
L.HEADER_WEARING = "Wearing: %s"
L.HEADER_NOT_WEARING = "Not wearing any saved set"
L.HEADER_NO_SETS = "No sets yet"
L.QUEUED = "Queued"
L.QUEUED_TIP_TITLE = "Waiting to run"
L.QUEUED_TIP_SWAP = "%s will run when %s."
L.QUEUED_TIP_BINDINGS = "Key binding changes go live when combat ends."
L.QUEUED_TIP_CANCEL = "Right-click to cancel the queued swap."
L.WHEN_COMBAT = "combat ends"
L.WHEN_DEAD = "you are alive again"
L.WHEN_CASTING = "your cast finishes"
L.QUEUE_CANCELLED = "Queued swap cancelled."
L.TOGGLE_NAME = "Equipment Toggle"

-- Edit Set tab
L.SET_LABEL = "Set:"
L.NAME_LABEL = "Name:"
L.KEY_LABEL = "Key:"
L.NO_SETS_HINT = "You have no weapon sets yet. Add one to get started."
L.SELECT_SET = "Select a set"
L.UNSAVED_MARK = "(unsaved)"
L.HINT_ALL_SKIP = "Every slot is Leave alone, so this set would do nothing."
L.HINT_UNSAVED = "You have unsaved item changes."
L.HINT_RENAME = "Type a new name to enable Rename and Save as New."
L.NAME_EMPTY = "Type a name."
L.NAME_SAME = "That is the current name."
L.NAME_TAKEN = "Another set already uses that name."
L.SAVE_CHANGES_Q = "Save changes to \"%s\"?"
L.DELETE_SET_Q = "Delete the set \"%s\"?"
L.DUP_ONE_COPY = "%s is in both Main Hand and Off Hand, but you only have one. Not saved."
L.SET_SAVED = "Saved \"%s\"."
L.SET_CREATED = "Created \"%s\"."
L.SET_DELETED = "Deleted \"%s\"."
L.SET_RENAMED = "Renamed \"%s\" to \"%s\"."
L.DEFAULT_SET_NAME = "Set %d"

-- Slot tooltips
L.TIP_LEFT_PICK = "Left-click: pick up the item"
L.TIP_LEFT_DROP = "Left-click: drop the held item here"
L.TIP_RIGHT_CYCLE = "Right-click: change state (Item, Empty, Leave alone)"
L.TIP_RIGHT_CYCLE_NOITEM = "Right-click: change state (Empty, Leave alone)"
L.TIP_DRAG = "Drag an item from your bags or character sheet here, or hover to pick from a list."
L.TIP_EQUIPPED = "You are wearing this item."
L.TIP_MISSING = "Missing: not in your bags or equipped."
L.TIP_IN_BANK = "Missing: it is in your bank."
L.TIP_CLOSEST = "No exact copy found. Using the closest match."
L.TIP_BOE = "Bind on Equip: not bound yet."
L.TIP_TRADE = "Tradeable: still in its loot trade window."
L.TIP_REFUND = "Refundable: still in its vendor refund window."
L.TIP_REMEMBERED = "Remembered item: %s"
L.TIP_AMMO_HIDDEN = "Ammo is only used with a bow, gun, or crossbow in the Ranged slot."

-- Badges on slots (keep very short)
L.BADGE_BOE = "BoE"
L.BADGE_TRADE = "T"
L.BADGE_REFUND = "R"

-- Item rules
L.ERR_WRONG_SLOT = G("ERR_WRONG_SLOT", "That item doesn't go in that slot.")
L.ERR_AMMO_MISMATCH = "That ammo doesn't fit the ranged weapon in this set."
L.ERR_NO_RANGED_FOR_AMMO = "Put a bow, gun, or crossbow in the Ranged slot first."
L.ERR_CANT_DUAL_WIELD = G("ERR_CANT_DUAL_WIELD", "You cannot dual-wield")
L.ERR_PROFICIENCY = G("ERR_PROFICIENCY_NEEDED", "You do not have the required proficiency for that item.")
L.ERR_LEVEL = G("ERR_CANT_EQUIP_LEVEL_I", "You must reach level %d to use that item.")
L.ERR_NEVER = G("ERR_CANT_EQUIP_EVER", "You can never use that item.")
L.ERR_NOT_EQUIPPABLE = G("ERR_ITEM_CANT_BE_EQUIPPED", "That item can't be equipped.")
L.AMMO_AUTO_PICKED = "Picked your best ammo: %s"
L.AMMO_NONE = "You have no matching ammo."
L.FLYOUT_EMPTY = "Nothing in your bags fits here."

-- Key bindings
L.KEY_PRESS = "Press a key"
L.KEY_NONE = "Not bound"
L.KEY_CLICK_TO_BIND = "Click, then press a key or mouse button."
L.KEY_RIGHT_TO_CLEAR = "Right-click to clear."
L.KEY_ESC_CANCEL = "Escape cancels."
L.KEY_NO_KEY_BOUND = "No key bound"
L.KEY_NO_KEY_BOUND_TIP = "This set lost its key to the Equipment Toggle. Bind a new key."
L.KEY_SHARED = "Shared with: %s (pressing cycles)"
L.KEY_PLAIN_CLICK = "Plain left and right click can't be bound."
L.KEY_IN_USE = "This key is used by %s. Use it anyway?"
L.KEY_IN_USE_SETS = "This key is used by the set(s) %s. They will lose their key. Use it anyway?"
L.KEY_TOGGLE_OWNS = "That key belongs to the Equipment Toggle. Pick another key, or change the toggle key in Settings."
L.KEY_CLICK_WARNING = "Modified mouse clicks may clash with item linking or targeting."
L.KEY_ANOTHER_ADDON = "%s (another add-on's button)"
L.KEY_PENDING = "Saved. It goes live when combat ends."
L.KEY_BOUND = "%s bound to %s."
L.KEY_TOO_MANY = "Only %d different set keys can be active at once. Sets on the extra keys won't respond until you free some keys."

-- Swapping
L.SWAP_MISSING = "Can't equip %s: missing items."
L.SWAP_MISSING_DETAIL = "Can't equip \"%s\". Missing: %s"
L.SWAP_IN_BANK = "%s (in your bank)"
L.SWAP_BAGS_FULL = G("ERR_INV_FULL", "Inventory is full.")
L.SWAP_BAGS_FULL_DETAIL = "Bags full: \"%s\" needs %d free bag slot(s), you have %d."
L.SWAP_CONFIRM = "Equipping \"%s\" will equip:\n\n%s\n\nContinue?"
L.SWAP_CONFIRM_BOE = "Bind on Equip (it will become soulbound)"
L.SWAP_CONFIRM_TRADE = "Still tradeable (equipping may end the trade window)"
L.SWAP_CONFIRM_REFUND = "Still refundable (equipping may end the refund)"
L.SWAP_CONFIRM_NOTE = "The game may still ask you to confirm binding."
L.SWAP_CURSOR_BUSY = "Your cursor is holding an item or a spell. Clear it first."
L.SWAP_NOTHING = "\"%s\" is already equipped."
L.SWAP_NO_SET = "No set named \"%s\"."
L.SWAP_FAILED = "The swap didn't finish. Some items may not have moved."
L.SWAP_COMBAT_BLOCKED = "WoW Forever blocked equipping in combat. Swaps will wait until combat ends. (Please report this; see the Testing Checklist.)"
L.SWAP_AMMO_SKIPPED = "Ammo skipped: it doesn't fit the ranged weapon you're wearing."
L.SWAP_QUEUED = "\"%s\" queued until %s."

-- Equipment Toggle
L.TOGGLE_DESC = "One key unequips your Main Hand, Off Hand, and Ranged weapons and remembers them. Press it again with empty hands to put them back. Ammo and relics are left alone. Handy to save durability before a wipe, for role-play, or anything else."
L.TOGGLE_OFF = "Weapons unequipped. Press again to put them back."
L.TOGGLE_ON = "Weapons re-equipped."
L.TOGGLE_NOTHING = "Nothing to put back."
L.TOGGLE_MISSING = "Couldn't put back: %s"

-- Settings
L.SETTINGS_TITLE = "ForeverWeaponRack"
L.SETTINGS_SUBTITLE = "Weapon set swapper for WoW Forever. Experimental."
L.SETTING_LOCK = "Lock the window"
L.SETTING_SCALE = "Window scale"
L.SETTING_FLYOUT_DELAY = "Hover flyout delay"
L.SETTING_FLYOUT_DELAY_TIP = "How long to hover a slot before the item list opens."
L.SETTING_MINIMAP = "Show minimap button"
L.SETTING_TOGGLE_KEY = "Equipment Toggle key"
L.SETTING_TOGGLE_PER_CHAR = "Use a key for this character only"
L.SETTING_TOGGLE_PER_CHAR_TIP = "Off: the key is stored in the profile and shared by every character using it. On: this character has its own key."
L.SETTING_PROFILE = "Profile"
L.SETTING_PROFILE_TIP = "Profiles hold window position, scale, lock, flyout delay, and global keys. Sets are always per character."
L.PROFILE_NEW = "New"
L.PROFILE_COPY = "Copy"
L.PROFILE_DELETE = "Delete"
L.PROFILE_RESET = "Reset"
L.PROFILE_NEW_Q = "Name for the new profile (starts as a copy of the current one):"
L.PROFILE_DELETE_Q = "Delete the profile \"%s\"?"
L.PROFILE_RESET_Q = "Reset the profile \"%s\" to defaults?"
L.PROFILE_EXISTS = "A profile with that name already exists."
L.PROFILE_ACTIVE = "Using profile \"%s\"."
L.SECONDS = "%.2f sec"

-- Minimap
L.MINIMAP_TIP_LEFT = "Left-click: open or close the window"
L.MINIMAP_TIP_RIGHT = "Right-click: settings"
L.MINIMAP_TIP_DRAG = "Drag: move this button"

-- Slash commands
L.SLASH_HELP = "Commands: /fwr (toggle window), /fwr equip <set name>, /fwr settings, /fwr debug [swaps|mh|oh|ranged|ammo|bags|<item link>|bag <bag> <slot>]"

-- Data
L.DATA_NEWER = "Saved %s data comes from a newer version of the add-on. It was left untouched."
L.DATA_MIGRATED = "Updated saved data to version %d."

-- Startup
L.LOADED = "v%s loaded. EXPERIMENTAL: in-combat swapping is not confirmed yet in WoW Forever. Type /fwr to open."
