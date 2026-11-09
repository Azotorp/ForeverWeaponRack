-- luacheck configuration for ForeverWeaponRack.
-- Run from the repository root:  luacheck ForeverWeaponRack
--
-- read_globals lists every game API the add-on uses. A typo in an API name
-- shows up as "accessing undefined variable", which is the main reason to
-- keep this list exact.

std = "lua51"
max_line_length = false
codes = true
self = false

exclude_files = { "tests/**" }

ignore = {
  "212/self",   -- unused self argument in methods
  "212/_.*",    -- unused arguments starting with _
  "211/_.*",    -- unused locals starting with _
  "213/_.*",    -- unused loop variables starting with _
  "542",        -- empty if branch (used for readable "nothing to do" cases)
}

globals = {
  -- Saved variables and our own globals
  "ForeverWeaponRack",
  "ForeverWeaponRackDB",
  "ForeverWeaponRackCharDB",
  "SLASH_FOREVERWEAPONRACK1",
  "SLASH_FOREVERWEAPONRACK2",
  "SLASH_FOREVERWEAPONRACK3",
  "SlashCmdList",
  "UISpecialFrames",
}

read_globals = {
  -- Lua / WoW Lua extensions
  "geterrorhandler", "hooksecurefunc", "issecretvalue", "wipe", "strsplit",
  "strtrim", "tinsert", "tremove", "date", "time", "debugstack", "format",

  -- Frames and widgets
  "CreateFrame", "UIParent", "WorldFrame", "Minimap", "GameTooltip",
  "UIErrorsFrame", "DEFAULT_CHAT_FRAME", "GameFontNormal", "GameFontHighlight",
  "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisable",
  "GameFontDisableSmall", "GameFontRed", "GameFontNormalLarge",
  "NumberFontNormal", "NumberFontNormalSmall", "ChatFontNormal",
  "GameFontHighlightLarge", "GameFontGreen", "GameFontNormalHuge",
  "AddonCompartmentFrame", "SettingsPanel", "InterfaceOptions_AddCategory",
  "InterfaceOptionsFrame_OpenToCategory", "Settings", "GetMinimapShape",
  "GetCursorPosition", "GetScreenWidth", "GetScreenHeight", "PlaySound",
  "SOUNDKIT", "MenuUtil", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
  "IsMetaKeyDown", "IsModifiedClick", "HandleModifiedItemClick", "ChatEdit_InsertLink",
  "GetMouseFocus", "GetMouseFoci",

  -- Timers
  "C_Timer", "GetTime",

  -- Items, containers, inventory
  "C_Container", "C_Item", "C_TooltipInfo", "C_PlayerInfo", "C_PaperDollInfo",
  "C_AddOns", "ItemLocation", "Item", "TooltipUtil",
  "GetContainerItemInfo", "GetContainerNumSlots", "GetContainerNumFreeSlots",
  "GetContainerItemLink", "PickupContainerItem",
  "GetItemInfo", "GetItemInfoInstant", "GetItemCount", "IsEquippableItem",
  "GetDetailedItemLevelInfo", "GetItemStats", "GetItemQualityColor",
  "GetAddOnMetadata", "GetInventorySlotInfo", "GetInventoryItemID",
  "GetInventoryItemLink", "GetInventoryItemTexture", "GetInventoryItemCount",
  "GetInventoryItemQuality", "IsInventoryItemLocked", "PickupInventoryItem",
  "GetWeaponEnchantInfo", "CursorHasItem", "GetCursorInfo", "ClearCursor",
  "CanDualWield", "UnitHasRelicSlot", "ITEM_QUALITY_COLORS",
  "NUM_BAG_SLOTS", "BACKPACK_CONTAINER", "INVSLOT_MAINHAND", "INVSLOT_OFFHAND",
  "INVSLOT_RANGED", "INVSLOT_AMMO",

  -- Unit, combat, player state
  "UnitName", "UnitLevel", "UnitClass", "GetRealmName", "InCombatLockdown",
  "UnitIsDeadOrGhost", "UnitCastingInfo", "UnitChannelInfo", "GetBuildInfo",
  "GetLocale",

  -- Bindings
  "SetOverrideBindingClick", "ClearOverrideBindings", "GetBindingAction",
  "GetBindingText", "GetBindingName", "GetConvertedKeyOrButton",
  "IsKeyPressIgnoredForBinding", "CreateKeyChordStringUsingMetaKeyState",
  "GetBindingKey",

  -- Enums and constants
  "Enum", "Constants", "RED_FONT_COLOR", "GREEN_FONT_COLOR", "NORMAL_FONT_COLOR",
  "HIGHLIGHT_FONT_COLOR", "GRAY_FONT_COLOR", "YELLOW_FONT_COLOR",
  "WHITE_FONT_COLOR",
}
