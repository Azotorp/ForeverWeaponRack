-- Item identity, resolution and "already wearing".
local test, check, eq, S, FWR = T.test, T.check, T.eq, T.S, T.FWR

local function slots(mh, oh, ranged, ammo)
  local function s(v)
    if v == nil then return { state = "skip" } end
    if v == "empty" then return { state = "empty" } end
    return { state = "item", item = v }
  end
  return { MAINHAND = s(mh), OFFHAND = s(oh), RANGED = s(ranged), AMMO = s(ammo) }
end

local function ref(id, enchant, temp)
  local link = S.Link(id, enchant)
  return { id = id, link = link, str = FWR.Identity.ItemString(link), temp = temp }
end

test("ItemString ignores link level and zero fields", function()
  local a = FWR.Identity.ItemString("|Hitem:100:0:0:0:0:0:0:0:60:250:0:0:0|h[x]|h")
  local b = FWR.Identity.ItemString("|Hitem:100::::::::12:0:::|h[x]|h")
  eq(a, b, "same item at different levels")
  check(FWR.Identity.ItemString("|Hitem:100:1900:::::::60|h[x]|h") ~= a, "enchant differs")
end)

test("Exact copy beats a same-id copy; closest match used when no exact", function()
  S.bags[0][1] = S.Item(100)           -- plain
  S.bags[0][2] = S.Item(100, 1900)     -- crusader
  FWR.Identity.Invalidate()
  local res = FWR.Identity.Resolve(slots(ref(100, 1900)))
  eq(res.MAINHAND.entry.key, "bag:0:2", "exact enchant chosen")
  check(not res.MAINHAND.closest, "exact")
  S.bags[0][2] = nil
  FWR.Identity.Invalidate()
  res = FWR.Identity.Resolve(slots(ref(100, 1900)))
  eq(res.MAINHAND.entry.key, "bag:0:1", "falls back to same item")
  check(res.MAINHAND.closest, "flagged closest")
end)

test("Temp enchant breaks ties; worn-off falls back", function()
  S.bags[0][1] = S.Item(100)
  S.bags[0][2] = S.Item(100)
  S.tempEnchants["bag:0:2"] = "Sharpened (+3 Damage)"
  FWR.Identity.Invalidate()
  local res = FWR.Identity.Resolve(slots(ref(100, nil, "Sharpened (+3 Damage)")))
  eq(res.MAINHAND.entry.key, "bag:0:2", "sharpened copy")
  S.tempEnchants["bag:0:2"] = nil
  FWR.Identity.Invalidate()
  res = FWR.Identity.Resolve(slots(ref(100, nil, "Sharpened (+3 Damage)")))
  eq(res.MAINHAND.entry.key, "bag:0:1", "first by bag order")
  S.tempEnchants = {}
end)

test("Identical copies: in-slot first, then bag, then other hand", function()
  S.equipped[17] = S.Item(101)
  S.bags[0][3] = S.Item(101)
  FWR.Identity.Invalidate()
  local res = FWR.Identity.Resolve(slots(ref(101)))
  eq(res.MAINHAND.entry.key, "bag:0:3", "bag copy preferred over the other hand")
  S.equipped[16] = S.Item(101)
  FWR.Identity.Invalidate()
  res = FWR.Identity.Resolve(slots(ref(101), ref(101)))
  eq(res.MAINHAND.entry.key, "inv:16", "MH keeps its copy")
  eq(res.OFFHAND.entry.key, "inv:17", "OH keeps its copy")
end)

test("One copy can't fill two slots", function()
  S.bags[0][1] = S.Item(101)
  FWR.Identity.Invalidate()
  local res = FWR.Identity.Resolve(slots(ref(101), ref(101)))
  check(res.MAINHAND.entry ~= nil, "MH found")
  check(res.OFFHAND.missing, "OH missing")
end)

test("Missing and in-bank detection", function()
  S.bankCounts[100] = 1
  FWR.Identity.Invalidate()
  local res = FWR.Identity.Resolve(slots(ref(100)))
  check(res.MAINHAND.missing, "missing")
  check(res.MAINHAND.inBank, "in bank")
end)

test("Ammo is Leave alone unless Ranged holds a bow, gun or crossbow", function()
  eq(FWR.Identity.EffectiveState(slots(nil, nil, ref(402), ref(500)), "AMMO"), "skip", "wand")
  eq(FWR.Identity.EffectiveState(slots(nil, nil, nil, ref(500)), "AMMO"), "skip", "ranged leave alone")
  eq(FWR.Identity.EffectiveState(slots(nil, nil, "empty", ref(500)), "AMMO"), "skip", "ranged empty")
  eq(FWR.Identity.EffectiveState(slots(nil, nil, ref(400), ref(500)), "AMMO"), "item", "bow")
  eq(FWR.Identity.EffectiveState(slots(nil, nil, ref(404), "empty"), "AMMO"), "empty", "crossbow + empty ammo")
end)

test("IsWearingSlots", function()
  S.equipped[16] = S.Item(100)
  S.equipped[18] = S.Item(400)
  S.equipped[0] = { id = 501, link = S.Link(501), count = 1 }
  S.bags[0][1] = S.Item(501, nil, 200)
  FWR.Identity.Invalidate()
  check(FWR.Identity.IsWearingSlots(slots(ref(100), "empty", ref(400), ref(501))), "exact match")
  check(not FWR.Identity.IsWearingSlots(slots(ref(100), ref(300))), "OH differs")
  check(FWR.Identity.IsWearingSlots(slots(ref(100))), "only MH matters")
  check(not FWR.Identity.IsWearingSlots(slots()), "all leave alone is never worn")
  check(not FWR.Identity.IsWearingSlots(slots(nil, nil, ref(400), ref(500))), "different ammo")
end)
