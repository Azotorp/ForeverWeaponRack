--[[
  Debug.lua
  /fwr debug: output for the in-game testing plan (DESIGN 9). Everything is
  printed to chat and also put in a copy window, so it can be pasted into a
  bug report.

    /fwr debug                  environment report: build, the trade-window
                                string (test 6), API availability, combat
                                block state (test 1), /wr clash (test 9),
                                temp enchants on equipped weapons (test 7)
    /fwr debug mh|oh|ranged|ammo  tooltip lines and types for an equipped item
    /fwr debug bag <bag> <slot>   the same for a bag item (bag 0 = backpack)
    /fwr debug bags             one line per weapon in your bags: BoE,
                                tradeable, refundable, temp enchant (test 7)
    /fwr debug <item link>      tooltip lines for a linked item (shift-click
                                an item into the command). A link has no
                                location, so trade/refund/temp can't show.
]]

local _, FWR = ...
local Tooltip = FWR.Tooltip
local Identity = FWR.Identity
local UI = FWR.UI

local Debug = {}
FWR.Debug = Debug

local out

local function Add(text)
  out[#out + 1] = text
end

local function Show(v)
  if v == nil then return "nil" end
  if FWR.IsSecret(v) then return "<secret>" end
  return tostring(v)
end

local function Hex(r, g, b)
  if type(r) ~= "number" then return "------" end
  return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Strip escape codes so the copy window shows plain text.
local function Plain(text)
  if type(text) ~= "string" then return Show(text) end
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|", "||"))
end

local function DumpLines(where, label)
  Add(("-- Tooltip lines for %s --"):format(label))
  local lines = Tooltip.GetLines(where)
  if #lines == 0 then
    Add("  (no lines; the item may not be cached yet, try again)")
  end
  for i, line in ipairs(lines) do
    Add(("  #%d type=%s (%s) L=\"%s\" [%s] R=\"%s\" [%s]%s%s"):format(
      i, Show(line.type), Tooltip.LineTypeName(line.type),
      Plain(line.left or ""), Hex(line.lr, line.lg, line.lb),
      Plain(line.right or ""), Hex(line.rr, line.rg, line.rb),
      line.bonding ~= nil and (" bonding=" .. Show(line.bonding)) or "",
      line.secret and " SECRET" or ""))
  end
end

local function Detection(entry)
  Add("-- Detection --")
  Add("  Unbound BoE: " .. Show(Tooltip.IsUnboundBoE(entry) and true or false))
  Add("  Tradeable: " .. Show(Tooltip.IsTradeable(entry) and true or false))
  Add("  Refundable: " .. Show(Tooltip.IsRefundable(entry) and true or false))
  Add("  Temp enchant: " .. Show(Tooltip.GetTempEnchant(entry)))
  Add("  Restriction: " .. Show(Tooltip.FindRestriction(entry)))
  local usable, err = FWR.Item.CheckUsable(entry)
  Add("  Usable: " .. Show(usable) .. (err and (" (" .. err .. ")") or ""))
  Add("  Item string: " .. Show(entry.str))
end

local function EquippedEntry(word)
  local map = { mh = "MAINHAND", oh = "OFFHAND", ranged = "RANGED", ammo = "AMMO" }
  local slotKey = map[word]
  if not slotKey then return nil end
  Identity.Invalidate()
  return Identity.Equipped(slotKey), slotKey
end

-- Other add-ons using /wr (testing plan item 9).
local function SlashClash()
  local users = {}
  for name, value in pairs(_G) do
    if type(name) == "string" and name:find("^SLASH_") and type(value) == "string"
        and value:lower() == "/wr" and not name:find("^SLASH_FOREVERWEAPONRACK") then
      users[#users + 1] = name
    end
  end
  return users
end

local function WeaponEnchants()
  local api = C_Item and C_Item.GetWeaponEnchantInfo
  if api and Enum and Enum.WeaponSlot then
    for _, slotName in ipairs({ "MainHand", "OffHand", "Ranged" }) do
      local slot = Enum.WeaponSlot[slotName]
      if slot then
        local ok, list = pcall(api, slot)
        if not ok then
          Add(("  C_Item.GetWeaponEnchantInfo(%s): error %s"):format(slotName, Show(list)))
        elseif FWR.IsSecret(list) then
          Add(("  C_Item.GetWeaponEnchantInfo(%s): <secret>"):format(slotName))
        else
          for _, e in ipairs(list or {}) do
            Add(("  %s: hasEnchant=%s type=%s timeLeft=%s charges=%s enchantID=%s"):format(slotName,
              Show(e.hasEnchant), Show(e.enchantType), Show(e.timeLeft), Show(e.charges), Show(e.enchantID)))
          end
          if not list or #list == 0 then Add(("  %s: none"):format(slotName)) end
        end
      end
    end
  elseif _G.GetWeaponEnchantInfo then
    local hasMain, mainTime, _, mainID, hasOff, offTime, _, offID = _G.GetWeaponEnchantInfo()
    Add(("  GetWeaponEnchantInfo: main=%s (%s ms, id %s) off=%s (%s ms, id %s)"):format(
      Show(hasMain), Show(mainTime), Show(mainID), Show(hasOff), Show(offTime), Show(offID)))
  else
    Add("  No weapon enchant API found.")
  end
end

local function Environment()
  local version, build, date, interface = GetBuildInfo()
  Add(("ForeverWeaponRack %s debug report"):format(FWR.version))
  Add(("Client: %s build %s (%s) interface %s, locale %s"):format(
    Show(version), Show(build), Show(date), Show(interface), Show(GetLocale())))
  Add("-- Test 6: trade window string --")
  Add("  BIND_TRADE_TIME_REMAINING = " .. Plain(_G.BIND_TRADE_TIME_REMAINING or "nil"))
  Add("  pattern = " .. Show(Tooltip.Patterns().trade))
  Add("  loose text = " .. Show(Tooltip.Patterns().tradeLiteral))
  local lt = Enum and Enum.TooltipDataLineType
  Add("  line type TradeTimeRemaining = " .. Show(lt and lt.TradeTimeRemaining)
    .. ", ItemBinding = " .. Show(lt and lt.ItemBinding))
  Add("  ITEM_BIND_ON_EQUIP = " .. Plain(_G.ITEM_BIND_ON_EQUIP or "nil"))
  Add("-- APIs --")
  Add("  C_TooltipInfo: " .. Show(_G.C_TooltipInfo ~= nil)
    .. ", C_Item.CanBeRefunded: " .. Show(C_Item and C_Item.CanBeRefunded ~= nil)
    .. ", C_Item.IsBound: " .. Show(C_Item and C_Item.IsBound ~= nil)
    .. ", C_PlayerInfo.CanUseItem: " .. Show(C_PlayerInfo and C_PlayerInfo.CanUseItem ~= nil))
  Add("  Secret values: " .. Show(_G.issecretvalue ~= nil)
    .. ", AMMO_DAMAGE_TEMPLATE: " .. Plain(_G.AMMO_DAMAGE_TEMPLATE or "nil"))
  Add("  Temp enchant patterns: " .. #Tooltip.Patterns().temp)
  Add("-- Test 1: combat --")
  Add("  In combat: " .. Show(InCombatLockdown()) .. ", combat swaps blocked this session: "
    .. Show(FWR.Queue.combatBlocked))
  Add("-- Test 7: temp enchants on equipped weapons --")
  WeaponEnchants()
  for _, word in ipairs({ "mh", "oh" }) do
    local entry = EquippedEntry(word)
    if entry then Add(("  %s tooltip temp enchant: %s"):format(word, Show(Tooltip.GetTempEnchant(entry)))) end
  end
  Add("-- Test 9: /wr --")
  local clash = SlashClash()
  if #clash == 0 then
    Add("  No other add-on registers /wr.")
  else
    Add("  Also registered by: " .. table.concat(clash, ", ") .. " (the last one loaded wins /wr)")
  end
  Add("Usage: /fwr debug [mh|oh|ranged|ammo|bags|bag <bag> <slot>|<item link>]")
end

local function BagSummary()
  Add("-- Weapons in bags (test 7: temp enchants on bag items) --")
  Identity.Invalidate()
  local count = 0
  for _, entry in ipairs(Identity.Scan()) do
    if entry.where == "bag" then
      count = count + 1
      Add(("  bag %d slot %d %s: BoE=%s trade=%s refund=%s temp=%s"):format(entry.bag, entry.slot,
        Plain(entry.link), Show(Tooltip.IsUnboundBoE(entry) and true or false),
        Show(Tooltip.IsTradeable(entry) and true or false),
        Show(Tooltip.IsRefundable(entry) and true or false), Show(Tooltip.GetTempEnchant(entry))))
    end
  end
  if count == 0 then Add("  (no weapons, ammo or relics in your bags)") end
end

function Debug.Run(args)
  out = {}
  args = FWR.Util.Trim(args or "")
  local word = (args:match("^(%S+)") or ""):lower()

  if args == "" then
    Environment()
  elseif word == "bags" then
    BagSummary()
  elseif word == "bag" then
    local bag, slot = args:match("^%S+%s+(%-?%d+)%s+(%d+)")
    bag, slot = tonumber(bag), tonumber(slot)
    local entry = bag and slot and Identity.FindAt(bag, slot)
    if not (bag and slot) then
      Add("Usage: /fwr debug bag <bag> <slot>  (bag 0 = backpack, slots from 1)")
    elseif entry then
      DumpLines(entry, Plain(entry.link))
      Detection(entry)
    else
      DumpLines({ where = "bag", bag = bag, slot = slot }, ("bag %d slot %d"):format(bag, slot))
    end
  elseif word == "mh" or word == "oh" or word == "ranged" or word == "ammo" then
    local entry, slotKey = EquippedEntry(word)
    if entry then
      DumpLines(entry, slotKey .. " " .. Plain(entry.link))
      Detection(entry)
    else
      Add("Nothing equipped in " .. word)
    end
  elseif args:find("|Hitem:") then
    local link = args:match("|c%x+|Hitem:.-|h.-|h|r") or args:match("|Hitem:.-|h.-|h")
    DumpLines(link, Plain(link))
    Add("(A link has no bag position, so trade, refund and temp enchants can't be read. Use /fwr debug bags.)")
  else
    Add("Usage: /fwr debug [mh|oh|ranged|ammo|bags|bag <bag> <slot>|<item link>]")
  end

  for _, line in ipairs(out) do
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7FWR|r " .. line)
  end
  UI.CopyWindow(table.concat(out, "\n"))
end

------------------------------------------------------------------------------
-- Copy window: select all and copy, for bug reports.
------------------------------------------------------------------------------

local copyFrame

function UI.CopyWindow(text)
  if not copyFrame then
    copyFrame = CreateFrame("Frame", "ForeverWeaponRackCopyFrame", UIParent, "BackdropTemplate")
    copyFrame:SetSize(620, 360)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
    copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
    UI.ApplyBackdrop(copyFrame, 0.97)
    tinsert(UISpecialFrames, "ForeverWeaponRackCopyFrame")

    local title = UI.Label(copyFrame, "ForeverWeaponRack debug (Ctrl+A, Ctrl+C to copy)", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(570)
    edit:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    scroll:SetScrollChild(edit)
    copyFrame.edit = edit
  end
  copyFrame.edit:SetText(text)
  copyFrame:Show()
  copyFrame.edit:SetFocus()
  copyFrame.edit:HighlightText()
end
