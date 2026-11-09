--[[
  Tooltip.lua
  Reads item tooltips and flags, always through the game's own strings and
  flags, never hard-coded English text (DESIGN 7):

    - Bind on Equip     item bind type flag + C_Item.IsBound; tooltip line
                        type ItemBinding / ITEM_BIND_ON_EQUIP as fallback
    - Trade window      tooltip line type TradeTimeRemaining; then a pattern
                        built from BIND_TRADE_TIME_REMAINING; then a looser
                        match on that string's longest plain-text piece plus
                        a number
    - Refundable        C_Item.CanBeRefunded / container purchase info
    - Temp enchant      a line matching ITEM_ENCHANT_TIME_LEFT_* patterns
    - Restrictions      red lines (what the game shows for wrong class,
                        untrained weapon skill, level)
    - Ammo damage       AMMO_DAMAGE_TEMPLATE

  Forever's client can return "secret" values. A secret line is skipped and
  counted, so callers can tell "no" apart from "couldn't read".
]]

local _, FWR = ...
local Util = FWR.Util
local Readable = FWR.Readable

local Tooltip = {}
FWR.Tooltip = Tooltip

local LineType = (Enum and Enum.TooltipDataLineType) or {}
local Binding = (Enum and Enum.TooltipDataItemBinding) or {}
local ItemBind = (Enum and Enum.ItemBind) or {}
local BIND_ON_EQUIP = ItemBind.OnEquip or 2

Tooltip.LineType = LineType

------------------------------------------------------------------------------
-- Patterns from the game's global strings (built once, on first use)
------------------------------------------------------------------------------

local patterns

local function Patterns()
  if patterns then return patterns end
  patterns = {}
  -- TODO(test 6): confirm BIND_TRADE_TIME_REMAINING exists in Forever
  -- (/dump BIND_TRADE_TIME_REMAINING). If it doesn't, only the line type
  -- check below can find tradeable items.
  patterns.trade = Util.FormatToPattern(_G.BIND_TRADE_TIME_REMAINING)
  patterns.tradeLiteral = Util.LongestLiteral(_G.BIND_TRADE_TIME_REMAINING)
  patterns.boe = _G.ITEM_BIND_ON_EQUIP
  patterns.durability = Util.FormatToPattern(_G.DURABILITY_TEMPLATE)
  patterns.ammoDPS = Util.FormatToPattern(_G.AMMO_DAMAGE_TEMPLATE)
  patterns.temp = {}
  for _, name in ipairs({ "ITEM_ENCHANT_TIME_LEFT_DAYS", "ITEM_ENCHANT_TIME_LEFT_HOURS",
                          "ITEM_ENCHANT_TIME_LEFT_MIN", "ITEM_ENCHANT_TIME_LEFT_SEC" }) do
    local p = Util.FormatToPattern(_G[name])
    if p then patterns.temp[#patterns.temp + 1] = p end
  end
  return patterns
end
Tooltip.Patterns = Patterns

------------------------------------------------------------------------------
-- Reading lines
-- Every line becomes:
--   { left, right, lr, lg, lb, rr, rg, rb, type, bonding, secret }
------------------------------------------------------------------------------

local function ColorParts(color)
  if type(color) ~= "table" then return nil end
  local r, g, b = Readable(color.r), Readable(color.g), Readable(color.b)
  if type(r) ~= "number" then return nil end
  return r, g, b
end

-- Older clients pack line fields into an args list; newer ones surface them.
local function SurfaceArgs(line)
  if line.leftText == nil and type(line.args) == "table" then
    for _, arg in ipairs(line.args) do
      if arg.field then
        line[arg.field] = arg.stringVal or arg.intVal or arg.floatVal or arg.colorVal
          or arg.boolVal or arg.guidVal
      end
    end
  end
end

local function NormalizeLine(raw)
  SurfaceArgs(raw)
  local out = { secret = false }
  if FWR.IsSecret(raw.leftText) or FWR.IsSecret(raw.rightText) then
    out.secret = true
  end
  out.left = Readable(raw.leftText)
  out.right = Readable(raw.rightText)
  out.lr, out.lg, out.lb = ColorParts(raw.leftColor)
  out.rr, out.rg, out.rb = ColorParts(raw.rightColor)
  out.type = Readable(raw.type)
  out.bonding = Readable(raw.bonding)
  return out
end

-- Fallback when C_TooltipInfo is missing: a hidden scanning tooltip.
local scanTip
local function ScanWithGameTooltip(setter, ...)
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "ForeverWeaponRackScanTooltip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
  scanTip:ClearLines()
  if not scanTip[setter] then return {} end
  scanTip[setter](scanTip, ...)
  local lines = {}
  for i = 1, scanTip:NumLines() do
    local leftFS = _G["ForeverWeaponRackScanTooltipTextLeft" .. i]
    local rightFS = _G["ForeverWeaponRackScanTooltipTextRight" .. i]
    local line = { secret = false }
    if leftFS then
      line.left = Readable(leftFS:GetText())
      line.lr, line.lg, line.lb = leftFS:GetTextColor()
    end
    if rightFS and rightFS:IsShown() then
      line.right = Readable(rightFS:GetText())
      line.rr, line.rg, line.rb = rightFS:GetTextColor()
    end
    lines[#lines + 1] = line
  end
  return lines
end

--[[
  Tooltip.GetLines(where)
  where: an inventory entry ({where="bag", bag, slot} or {where="inv", inv}),
         or an item link / item string.
  Returns a list of normalized lines (possibly empty).
]]
-- Tooltip reads are wrapped in pcall: if the game refuses one (for example
-- in combat), the check simply finds nothing instead of breaking a swap.
local function Call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

function Tooltip.GetLines(where)
  local data
  local api = _G.C_TooltipInfo
  if type(where) == "table" then
    if where.where == "bag" then
      if api and api.GetBagItem then
        data = Call(api.GetBagItem, where.bag, where.slot)
      else
        return Call(ScanWithGameTooltip, "SetBagItem", where.bag, where.slot) or {}
      end
    elseif where.where == "inv" then
      if api and api.GetInventoryItem then
        data = Call(api.GetInventoryItem, "player", where.inv)
      else
        return Call(ScanWithGameTooltip, "SetInventoryItem", "player", where.inv) or {}
      end
    end
  elseif type(where) == "string" then
    if api and api.GetHyperlink then
      data = Call(api.GetHyperlink, where)
    else
      return Call(ScanWithGameTooltip, "SetHyperlink", where) or {}
    end
  end
  if FWR.IsSecret(data) or (type(data) == "table" and FWR.IsSecret(data.lines)) then return {} end
  local lines = {}
  if type(data) == "table" and type(data.lines) == "table" then
    for _, raw in ipairs(data.lines) do
      lines[#lines + 1] = NormalizeLine(raw)
    end
  end
  return lines
end

------------------------------------------------------------------------------
-- Line helpers
------------------------------------------------------------------------------

local function IsRed(r, g, b)
  return type(r) == "number" and r > 0.9 and g < 0.25 and b < 0.25
end
Tooltip.IsRed = IsRed

-- Reverse lookup: line type number -> enum name (for /fwr debug).
function Tooltip.LineTypeName(typeValue)
  if typeValue == nil then return "nil" end
  for name, value in pairs(LineType) do
    if value == typeValue then return name end
  end
  return "?"
end

------------------------------------------------------------------------------
-- Per-inventory-generation cache, so repeated checks don't re-read tooltips.
------------------------------------------------------------------------------

local cache, cacheGeneration = {}, -1

local function Cached(kind, entry, compute)
  if type(entry) ~= "table" or not entry.key then
    return compute()
  end
  local generation = FWR.Identity and FWR.Identity.Generation() or 0
  if generation ~= cacheGeneration then
    cache, cacheGeneration = {}, generation
  end
  local k = kind .. "|" .. entry.key
  local value = cache[k]
  if value == nil then
    value = compute()
    cache[k] = (value == nil) and false or value
  end
  if value == false then return nil end
  return value
end

------------------------------------------------------------------------------
-- Detection
------------------------------------------------------------------------------

local function ItemLocationFor(entry)
  local IL = _G.ItemLocation
  if type(entry) ~= "table" or not IL then return nil end
  if entry.where == "bag" and IL.CreateFromBagAndSlot then
    return IL:CreateFromBagAndSlot(entry.bag, entry.slot)
  elseif entry.where == "inv" and IL.CreateFromEquipmentSlot then
    return IL:CreateFromEquipmentSlot(entry.inv)
  end
  return nil
end
Tooltip.ItemLocationFor = ItemLocationFor

-- Unbound Bind on Equip item? (DESIGN 4.6, 6.2.3, 7)
function Tooltip.IsUnboundBoE(entry)
  return Cached("boe", entry, function()
    local link = entry.link
    local bindType = select(14, FWR.API.GetItemInfo(link))
    if bindType ~= nil and bindType ~= BIND_ON_EQUIP then return false end

    -- Bound flag from the game, when we can get it.
    local location = ItemLocationFor(entry)
    if bindType == BIND_ON_EQUIP and location and C_Item and C_Item.IsBound then
      local ok, bound = pcall(C_Item.IsBound, location)
      if ok and bound ~= nil and not FWR.IsSecret(bound) then return not bound end
    end
    if bindType == BIND_ON_EQUIP and entry.isBound ~= nil then
      return not entry.isBound
    end

    -- Tooltip fallback: the binding line says "Binds when equipped".
    for _, line in ipairs(Tooltip.GetLines(entry)) do
      if LineType.ItemBinding and line.type == LineType.ItemBinding and line.bonding ~= nil then
        return line.bonding == Binding.BindOnEquip
      end
      if line.left and Patterns().boe and line.left == Patterns().boe then
        return true
      end
    end
    return false
  end)
end

-- Still in its loot trade window? (DESIGN 4.6, 6.2.3, 7)
function Tooltip.IsTradeable(entry)
  return Cached("trade", entry, function()
    local p = Patterns()
    for _, line in ipairs(Tooltip.GetLines(entry)) do
      if LineType.TradeTimeRemaining and line.type == LineType.TradeTimeRemaining then
        return true
      end
      local text = line.left
      if text then
        if p.trade and text:match(p.trade) then return true end
        -- Looser fallback: the plain-text part of the game's string, plus a number.
        if p.tradeLiteral and text:find(p.tradeLiteral, 1, true) and text:find("%d") then
          return true
        end
      end
    end
    return false
  end)
end

-- Still refundable at a vendor? (DESIGN 4.6, 7) If Forever has no refunds,
-- this is always false.
function Tooltip.IsRefundable(entry)
  return Cached("refund", entry, function()
    -- TODO(test 8): confirm whether Forever has vendor refunds at all.
    local location = ItemLocationFor(entry)
    if location and C_Item and C_Item.CanBeRefunded then
      local ok, refundable = pcall(C_Item.CanBeRefunded, location)
      if ok and refundable ~= nil and not FWR.IsSecret(refundable) then
        return refundable and true or false
      end
    end
    local getPurchase = C_Container and C_Container.GetContainerItemPurchaseInfo
    if getPurchase and entry.where == "bag" then
      local ok, info = pcall(getPurchase, entry.bag, entry.slot, false)
      if ok and type(info) == "table" then
        local seconds = Readable(info.refundSeconds)
        return type(seconds) == "number" and seconds > 0
      end
    end
    return false
  end)
end

--[[
  Temporary enchant name on a specific copy, e.g. "Sharpened (+3 Damage)",
  or nil. Used as an identity tiebreaker (DESIGN 6.4).
  TODO(test 7): confirm that bag items show temp enchant lines in Forever.
  If they don't, bag copies read as "no temp enchant" and identity falls
  back to the next rule (copy already in the slot, then bag order).
]]
function Tooltip.GetTempEnchant(entry)
  return Cached("temp", entry, function()
    local p = Patterns()
    for _, line in ipairs(Tooltip.GetLines(entry)) do
      local text = line.left
      if text then
        for _, pattern in ipairs(p.temp) do
          local name = text:match(pattern)
          if name and name ~= "" then
            return Util.Trim(name)
          end
        end
      end
    end
    return nil
  end)
end

--[[
  Red restriction line, as the game shows for items you can't use.
  Returns "level", "class", "skill", or nil. Durability lines are ignored
  (a broken weapon is red but can still be equipped).
]]
function Tooltip.FindRestriction(entryOrLink)
  local compute = function()
    local p = Patterns()
    local levelText = _G.ITEM_MIN_LEVEL and Util.FormatToPattern(_G.ITEM_MIN_LEVEL)
    local classText = _G.ITEM_CLASSES_ALLOWED and Util.FormatToPattern(_G.ITEM_CLASSES_ALLOWED)
    local raceText = _G.ITEM_RACES_ALLOWED and Util.FormatToPattern(_G.ITEM_RACES_ALLOWED)
    for index, line in ipairs(Tooltip.GetLines(entryOrLink)) do
      -- Line 1 is the item name; never a restriction.
      if index > 1 then
        local leftRed = IsRed(line.lr, line.lg, line.lb)
        local rightRed = IsRed(line.rr, line.rg, line.rb)
        if leftRed or rightRed then
          local text = line.left or ""
          if not (p.durability and text:match(p.durability)) then
            if levelText and text:match(levelText) then return "level" end
            if (classText and text:match(classText)) or (raceText and text:match(raceText)) then
              return "class"
            end
            return "skill"
          end
        end
      end
    end
    return nil
  end
  if type(entryOrLink) == "table" then
    return Cached("restrict", entryOrLink, compute)
  end
  return compute()
end

-- Ammo damage per second from the tooltip ("Adds %s damage per second").
function Tooltip.ReadAmmoDPS(link)
  local p = Patterns()
  if not p.ammoDPS then return nil end
  for _, line in ipairs(Tooltip.GetLines(link)) do
    local text = line.left
    if text then
      local value = text:match(p.ammoDPS)
      if value then return Util.ParseNumber(value) end
    end
  end
  return nil
end
