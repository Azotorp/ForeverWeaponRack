-- Core utilities and saved-data migration.
local test, check, eq, FWR = T.test, T.check, T.eq, T.FWR

test("FormatToPattern: trade time string matches any time value", function()
  local p = FWR.Util.FormatToPattern(BIND_TRADE_TIME_REMAINING)
  check(("You may trade this item with players that were also eligible to loot this item for the next 1 hour 52 min."):match(p) ~= nil, "matches hours+minutes")
  check(("You may trade this item with players that were also eligible to loot this item for the next 3 min."):match(p) ~= nil, "matches minutes")
  check(("Binds when equipped"):match(p) == nil, "does not match other lines")
end)

test("FormatToPattern: temp enchant strings capture the name", function()
  local p = FWR.Util.FormatToPattern(ITEM_ENCHANT_TIME_LEFT_MIN)
  eq(("Sharpened (+3 Damage) (29 min)"):match(p), "Sharpened (+3 Damage)", "min")
  local h = FWR.Util.FormatToPattern(ITEM_ENCHANT_TIME_LEFT_HOURS)
  eq(("Instant Poison II (1 hour)"):match(h), "Instant Poison II", "hour singular")
  eq(("Instant Poison II (2 hrs)"):match(h), "Instant Poison II", "hours plural")
end)

test("FormatToPattern: literal percent and %.1f", function()
  local p = FWR.Util.FormatToPattern("Chance %d%% to hit for %.1f")
  check(("Chance 5% to hit for 2.5"):match(p) ~= nil, "matches")
end)

test("LongestLiteral picks the biggest plain piece", function()
  eq(FWR.Util.LongestLiteral("%s (%d min)"), "min)")
  eq(FWR.Util.LongestLiteral(BIND_TRADE_TIME_REMAINING),
     "You may trade this item with players that were also eligible to loot this item for the next")
end)

test("ParseNumber handles both decimal separators", function()
  eq(FWR.Util.ParseNumber("7,5"), 7.5)
  eq(FWR.Util.ParseNumber("13.5"), 13.5)
  eq(FWR.Util.ParseNumber("1,234.5"), 1234.5)
end)

test("Migrate: unversioned data is stamped and kept", function()
  local db = { sets = { [3] = { name = "Old", slots = {} } }, order = { 3 } }
  local ok, from = FWR.Data.Migrate(db, "char")
  check(ok, "ok")
  eq(from, 0, "from")
  eq(db.dataVersion, FWR.Data.VERSION, "stamped")
  eq(db.sets[3].name, "Old", "set kept")
end)

test("Migrate: newer data is refused and untouched", function()
  local db = { dataVersion = FWR.Data.VERSION + 5, foo = 1 }
  local ok = FWR.Data.Migrate(db, "char")
  check(not ok, "refused")
  eq(db.dataVersion, FWR.Data.VERSION + 5, "version untouched")
end)

test("SanitizeChar repairs order, slots, ids and cycle memory", function()
  local db = {
    sets = {
      [2] = { name = "B", slots = { MAINHAND = { state = "item" } } },
      [5] = { name = "A", slots = {} },
      [7] = "broken",
    },
    order = { 5, 5, 9 },
    nextSetId = 1,
    cycle = { F = 9, G = 2 },
  }
  FWR.Data.SanitizeChar(db)
  eq(#db.order, 2, "two sets in order")
  eq(db.order[1], 5, "existing order kept first")
  eq(db.order[2], 2, "missing set appended")
  eq(db.sets[7], nil, "broken set dropped")
  eq(db.sets[2].slots.MAINHAND.state, "skip", "item state without item becomes skip")
  eq(db.sets[2].slots.AMMO.state, "skip", "missing slot filled")
  eq(db.nextSetId, 6, "next id above max")
  eq(db.cycle.F, nil, "dangling cycle memory removed")
  eq(db.cycle.G, 2, "valid cycle memory kept")
end)

test("Profiles: new, switch, delete, toggle key scope", function()
  local Data = FWR.Data
  eq(Data:ProfileName(), "Default")
  Data:SetToggleKey("SHIFT-T")
  eq(Data:GetToggleKey(), "SHIFT-T", "profile key")
  check(Data:NewProfile("Raid", true), "new profile")
  eq(Data:ProfileName(), "Raid")
  eq(Data:GetToggleKey(), "SHIFT-T", "copied")
  Data:SetToggleKeyPerChar(true)
  eq(Data:GetToggleKey(), "SHIFT-T", "carried to character")
  Data:SetToggleKey("CTRL-T")
  eq(Data:Profile().toggleKey, "SHIFT-T", "profile untouched")
  Data:SetToggleKeyPerChar(false)
  Data:UseProfile("Default")
  check(Data:DeleteProfile("Raid"), "deleted")
  check(not Data:DeleteProfile("Default"), "default can't be deleted")
  Data:SetToggleKey(nil)
end)
