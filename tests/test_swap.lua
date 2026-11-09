-- Swap engine, queue and Equipment Toggle, against the simulated client.
local test, check, eq, S, FWR = T.test, T.check, T.eq, T.S, T.FWR

local confirmCalls = {}
FWR.Confirm = function(text, onAccept) confirmCalls[#confirmCalls + 1] = { text = text, accept = onAccept } end

local function ref(id, enchant)
  local link = S.Link(id, enchant)
  return { id = id, link = link, str = FWR.Identity.ItemString(link) }
end

local function makeSet(name, spec)
  local db = FWR.Data.char
  db.sets, db.order, db.cycle, db.nextSetId = {}, {}, {}, 1
  local slots = FWR.Sets.NewSlots()
  for slotKey, v in pairs(spec) do
    if v == "empty" then slots[slotKey] = { state = "empty" }
    else slots[slotKey] = { state = "item", item = ref(v) } end
  end
  return FWR.Sets.Create(name, slots)
end

local function equipSet(set, source)
  return FWR.Swap.Request({ kind = "set", setId = set.id, source = source or "click" })
end

local function idAt(inv) return S.equipped[inv] and S.equipped[inv].id end

local function bagHas(id)
  for bag = 0, 4 do
    for _, it in pairs(S.bags[bag]) do if it.id == id then return true end end
  end
  return false
end

local function settle()
  for _ = 1, 6 do S.Settle() end
end

test("Bag to Main Hand and Off Hand", function()
  S.bags[0][1] = S.Item(100)
  S.bags[0][2] = S.Item(300)
  local set = makeSet("Tank", { MAINHAND = 100, OFFHAND = 300 })
  eq(equipSet(set), "started")
  settle()
  eq(idAt(16), 100, "MH")
  eq(idAt(17), 300, "OH")
  check(not FWR.Swap.busy, "finished")
  check(FWR.Identity.IsWearing(set), "wearing")
end)

test("Two-hander to one-hander plus shield", function()
  S.equipped[16] = S.Item(200)
  S.bags[0][1] = S.Item(100)
  S.bags[0][2] = S.Item(300)
  local set = makeSet("Tank", { MAINHAND = 100, OFFHAND = 300 })
  equipSet(set)
  settle()
  eq(idAt(16), 100, "MH")
  eq(idAt(17), 300, "OH")
  check(bagHas(200), "2H in bags")
end)

test("One-hander plus shield to two-hander", function()
  S.equipped[16] = S.Item(100)
  S.equipped[17] = S.Item(300)
  S.bags[0][1] = S.Item(200)
  local set = makeSet("DPS", { MAINHAND = 200, OFFHAND = "empty" })
  equipSet(set)
  settle()
  eq(idAt(16), 200, "2H on")
  eq(idAt(17), nil, "OH off")
  check(bagHas(100) and bagHas(300), "both in bags")
end)

test("Bags full cancels before anything moves", function()
  S.equipped[16] = S.Item(100)
  S.equipped[17] = S.Item(300)
  S.bagSizes[0] = 1
  S.bags[0][1] = S.Item(200)
  local set = makeSet("DPS", { MAINHAND = 200, OFFHAND = "empty" })
  eq(equipSet(set), "nothing")
  eq(idAt(16), 100, "nothing moved")
  check(S.uiErrors[1] ~= nil, "error shown")
end)

test("Missing item cancels the whole swap", function()
  S.bags[0][1] = S.Item(100)
  local set = makeSet("Dual", { MAINHAND = 100, OFFHAND = 101 })
  eq(equipSet(set), "nothing")
  eq(idAt(16), nil, "nothing moved")
end)

test("Hands trade places in one move", function()
  S.equipped[16] = S.Item(100)
  S.equipped[17] = S.Item(101)
  local set = makeSet("Swap", { MAINHAND = 101, OFFHAND = 100 })
  equipSet(set)
  eq(#S.log, 1, "one move")
  settle()
  eq(idAt(16), 101)
  eq(idAt(17), 100)
end)

test("Main-hand-only weapon can't go to the off hand: unequipped first", function()
  S.equipped[16] = S.Item(102)
  S.equipped[17] = S.Item(100)
  local set = makeSet("S", { MAINHAND = 100, OFFHAND = "empty" })
  equipSet(set)
  settle()
  eq(idAt(16), 100, "sword moved to MH")
  eq(idAt(17), nil, "OH empty")
  check(bagHas(102), "mace in bags")
end)

test("Ranged and ammo", function()
  S.bags[0][1] = S.Item(400)
  S.bags[0][2] = S.Item(501, nil, 200)
  local set = makeSet("Hunter", { RANGED = 400, AMMO = 501 })
  equipSet(set)
  settle()
  eq(idAt(18), 400, "bow")
  eq(idAt(0), 501, "arrows")
end)

test("Unbound BoE asks first; Accept equips", function()
  confirmCalls = {}
  S.bags[0][1] = S.Item(600)
  local set = makeSet("New", { MAINHAND = 600 })
  eq(equipSet(set), "nothing", "waits for the popup")
  eq(#confirmCalls, 1, "popup shown")
  eq(idAt(16), nil, "nothing moved yet")
  confirmCalls[1].accept()
  settle()
  eq(idAt(16), 600, "equipped after Accept")
end)

test("Key spam: only the latest press runs after the swap", function()
  S.bags[0][1] = S.Item(100)
  S.bags[0][2] = S.Item(101)
  S.bags[0][3] = S.Item(102)
  local db = FWR.Data.char
  db.sets, db.order, db.cycle, db.nextSetId = {}, {}, {}, 1
  local function mk(name, id)
    local slots = FWR.Sets.NewSlots()
    slots.MAINHAND = { state = "item", item = ref(id) }
    return FWR.Sets.Create(name, slots)
  end
  local a, b, c = mk("A", 100), mk("B", 101), mk("C", 102)
  eq(equipSet(a), "started")
  check(FWR.Swap.busy, "busy while waiting for the game")
  eq(equipSet(b), "pending")
  eq(equipSet(c), "pending")
  settle()
  eq(idAt(16), 102, "latest press (C) won")
end)

test("Dead: queued, runs when alive", function()
  S.bags[0][1] = S.Item(100)
  local set = makeSet("A", { MAINHAND = 100 })
  S.dead = true
  eq(equipSet(set), "queued")
  check(FWR.Queue.request ~= nil, "in queue")
  S.dead = false
  S.Fire("PLAYER_ALIVE")
  settle()
  eq(idAt(16), 100, "ran after")
  eq(FWR.Queue.request, nil, "queue empty")
end)

test("Combat block detected: queued until combat ends", function()
  FWR.Queue.combatBlocked = false
  S.bags[0][1] = S.Item(100)
  local set = makeSet("A", { MAINHAND = 100 })
  S.combat, S.blockCombat = true, true
  equipSet(set, "key")
  check(FWR.Queue.combatBlocked, "learned the block")
  eq(FWR.Queue.reason, "combat", "queued for combat")
  check(not FWR.Swap.busy, "not stuck busy")
  eq(S.cursor, nil, "cursor cleared")
  S.combat, S.blockCombat = false, false
  S.Fire("PLAYER_REGEN_ENABLED")
  settle()
  eq(idAt(16), 100, "ran after combat")
  FWR.Queue.combatBlocked = false
end)

test("Equipment Toggle: off and back on; ammo and relic left alone", function()
  S.equipped[16] = S.Item(100)
  S.equipped[17] = S.Item(300)
  S.equipped[18] = S.Item(400)
  S.equipped[0] = { id = 501, link = S.Link(501), count = 1 }
  S.bags[0][1] = S.Item(501, nil, 100)
  FWR.Data.char.toggle = { active = false, items = {} }
  FWR.Swap.Request({ kind = "toggle", source = "key" })
  settle()
  eq(idAt(16), nil); eq(idAt(17), nil); eq(idAt(18), nil)
  eq(idAt(0), 501, "ammo untouched")
  check(FWR.Toggle.HasMemory(), "remembered")
  FWR.Swap.Request({ kind = "toggle", source = "key" })
  settle()
  eq(idAt(16), 100); eq(idAt(17), 300); eq(idAt(18), 400)
  check(not FWR.Toggle.HasMemory(), "memory cleared")
end)

test("Equipment Toggle: relic is not a weapon", function()
  S.equipped[18] = S.Item(403)
  FWR.Data.char.toggle = { active = false, items = {} }
  check(not FWR.Toggle.HoldingWeapon(), "relic alone = empty hands")
  S.equipped[16] = S.Item(100)
  FWR.Identity.Invalidate()
  FWR.Swap.Request({ kind = "toggle", source = "key" })
  settle()
  eq(idAt(16), nil, "MH off")
  eq(idAt(18), 403, "relic stays")
end)

test("Equipment Toggle: sold item warns, re-equips the rest", function()
  S.equipped[16] = S.Item(100)
  S.equipped[17] = S.Item(300)
  FWR.Data.char.toggle = { active = false, items = {} }
  FWR.Swap.Request({ kind = "toggle", source = "key" })
  settle()
  -- "sell" the shield
  for slot, it in pairs(S.bags[0]) do if it.id == 300 then S.bags[0][slot] = nil end end
  FWR.Identity.Invalidate()
  FWR.Swap.Request({ kind = "toggle", source = "key" })
  settle()
  eq(idAt(16), 100, "sword back")
  eq(idAt(17), nil, "shield gone")
  local warned = false
  for _, line in ipairs(S.chat) do if line:find("Couldn't put back") then warned = true end end
  check(warned, "warned")
end)

test("Plan: 2H displacement counts bag space", function()
  local equipped = {
    MAINHAND = { key = "inv:16", where = "inv", inv = 16, slotKey = "MAINHAND", equipLoc = "INVTYPE_WEAPON", link = S.Link(100) },
    OFFHAND = { key = "inv:17", where = "inv", inv = 17, slotKey = "OFFHAND", equipLoc = "INVTYPE_SHIELD", link = S.Link(300) },
  }
  local twoHand = { key = "bag:0:1", where = "bag", bag = 0, slot = 1, equipLoc = "INVTYPE_2HWEAPON", link = S.Link(200) }
  local desired = {
    MAINHAND = { state = "item", entry = twoHand }, OFFHAND = { state = "skip" },
    RANGED = { state = "skip" }, AMMO = { state = "skip" },
  }
  local plan = FWR.Swap.Plan(desired, equipped, nil)
  eq(#plan.ops, 1, "one equip")
  eq(plan.bagSlotsNeeded, 1, "shield needs a slot")
end)
