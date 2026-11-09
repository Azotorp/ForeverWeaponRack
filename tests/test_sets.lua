-- Set storage, naming, slot states and smart rules.
local test, check, eq, S, FWR = T.test, T.check, T.eq, T.S, T.FWR

local function ref(id, enchant)
  local link = S.Link(id, enchant)
  return { id = id, link = link, str = FWR.Identity.ItemString(link) }
end

local function clearSets()
  local db = FWR.Data.char
  db.sets, db.order, db.cycle, db.nextSetId = {}, {}, {}, 1
end

test("Naming rules are case-insensitive", function()
  clearSets()
  local Sets = FWR.Sets
  local tank = Sets.Create("Tank")
  Sets.Create("DPS")
  check(not Sets.CheckName("", "Tank"), "empty")
  check(not Sets.CheckName("tank", "Tank"), "same as original")
  check(not Sets.CheckName("dps", "Tank"), "taken by another set")
  check(Sets.CheckName("Tank 2", "Tank"), "new name ok")
  check(Sets.Rename(tank.id, "Shield"), "rename")
  eq(Sets.Get(tank.id).name, "Shield")
end)

test("Order, move and delete with cycle memory", function()
  clearSets()
  local Sets = FWR.Sets
  local a = Sets.Create("A"); a.key = "F"
  local b = Sets.Create("B"); b.key = "F"
  local c = Sets.Create("C"); c.key = "F"
  check(not Sets.Move(a.id, -1), "top can't move up")
  check(Sets.Move(a.id, 1), "move down")
  eq(Sets.All()[1].name, "B")
  check(Sets.Move(a.id, -1), "move back up")
  -- Remembered set B is deleted: next press must go to C.
  FWR.Data.char.cycle.F = b.id
  Sets.Delete(b.id)
  eq(FWR.Data.char.cycle.F, a.id, "memory moves to the set before")
  -- Remembered first set deleted: memory cleared, next press goes to the new first.
  FWR.Data.char.cycle.F = a.id
  Sets.Delete(a.id)
  eq(FWR.Data.char.cycle.F, nil, "memory cleared")
  eq(Sets.Count(), 1)
end)

test("Right-click cycle with and without a remembered item", function()
  local slots = FWR.Sets.NewSlots()
  eq(FWR.Sets.CycleState(slots, "OFFHAND"), "empty")
  eq(FWR.Sets.CycleState(slots, "OFFHAND"), "skip")
  eq(FWR.Sets.CycleState(slots, "OFFHAND"), "empty")
  slots.MAINHAND = { state = "item", item = ref(100) }
  eq(FWR.Sets.CycleState(slots, "MAINHAND"), "empty")
  eq(FWR.Sets.CycleState(slots, "MAINHAND"), "skip")
  eq(FWR.Sets.CycleState(slots, "MAINHAND"), "item")
  eq(slots.MAINHAND.item.id, 100, "item remembered through the cycle")
end)

test("Two-hander rules", function()
  local Sets = FWR.Sets
  local slots = Sets.NewSlots()
  Sets.PlaceItem(slots, "OFFHAND", ref(300))
  local ok, _, target = Sets.PlaceItem(slots, "OFFHAND", ref(200))
  check(ok, "2H dropped on OH accepted")
  eq(target, "MAINHAND", "moved to MH")
  eq(slots.MAINHAND.item.id, 200)
  eq(slots.OFFHAND.state, "empty", "OH set to Empty")
  eq(slots.OFFHAND.item.id, 300, "OH remembers the shield")
  eq(Sets.CycleState(slots, "OFFHAND"), "skip")
  eq(Sets.CycleState(slots, "OFFHAND"), "item", "shield back")
  eq(slots.MAINHAND.state, "empty", "latest choice wins: MH now Empty")
  eq(slots.MAINHAND.item.id, 200, "MH remembers the 2H")
end)

test("Wrong slot and dual wield", function()
  local Sets = FWR.Sets
  local slots = Sets.NewSlots()
  check(not Sets.PlaceItem(slots, "MAINHAND", ref(300)), "shield not in MH")
  check(not Sets.PlaceItem(slots, "RANGED", ref(100)), "sword not in ranged")
  S.canDualWield = false
  check(not Sets.PlaceItem(slots, "OFFHAND", ref(100)), "1H in OH needs dual wield")
  S.canDualWield = true
  check(Sets.PlaceItem(slots, "OFFHAND", ref(100)), "1H in OH with dual wield")
  check(Sets.PlaceItem(slots, "MAINHAND", ref(102)), "MH-only weapon in MH")
  check(not Sets.PlaceItem(slots, "OFFHAND", ref(102)), "MH-only weapon not in OH")
end)

test("Unusable items rejected (level)", function()
  S.DefineItem(700, { name = "Epic Sword", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7, minLevel = 55 })
  S.playerLevel = 10
  local ok, err = FWR.Sets.PlaceItem(FWR.Sets.NewSlots(), "MAINHAND", ref(700))
  check(not ok, "level 55 item rejected at level 10")
  check(err and err:find("55"), "error names the level")
  check(FWR.Sets.PlaceItem(FWR.Sets.NewSlots(), "MAINHAND", ref(100)), "level 1 item fine")
  S.playerLevel = 60
end)

test("Ammo rules and auto-pick", function()
  local Sets = FWR.Sets
  S.bags[0][1] = S.Item(500, nil, 200)   -- rough arrow
  S.bags[0][2] = S.Item(501, nil, 200)   -- jagged arrow (best)
  S.bags[0][3] = S.Item(502, nil, 200)   -- heavy shot
  FWR.Identity.Invalidate()
  local slots = Sets.NewSlots()
  check(not Sets.PlaceItem(slots, "AMMO", ref(500)), "no ranged yet")
  Sets.PlaceItem(slots, "RANGED", ref(400))
  eq(slots.AMMO.item.id, 501, "best arrows picked")
  check(not Sets.PlaceItem(slots, "AMMO", ref(502)), "bullets rejected for a bow")
  check(Sets.PlaceItem(slots, "AMMO", ref(500)), "manual arrows")
  Sets.PlaceItem(slots, "RANGED", ref(404))
  eq(slots.AMMO.item.id, 500, "manual choice kept with a crossbow")
  Sets.PlaceItem(slots, "RANGED", ref(401))
  eq(slots.AMMO.item.id, 502, "arrows replaced with best bullets for a gun")
  Sets.PlaceItem(slots, "RANGED", ref(402))
  eq(FWR.Identity.EffectiveState(slots, "AMMO"), "skip", "wand hides ammo")
end)

test("CanSave: all leave alone and one copy in two slots", function()
  local Sets = FWR.Sets
  local slots = Sets.NewSlots()
  check(not Sets.CanSave(slots), "all leave alone")
  slots.MAINHAND = { state = "item", item = ref(101) }
  slots.OFFHAND = { state = "item", item = ref(101) }
  S.bags[0][1] = S.Item(101)
  FWR.Identity.Invalidate()
  local ok, reason = Sets.CanSave(slots)
  check(not ok and reason:find("only have one"), "one copy refused")
  S.bags[0][2] = S.Item(101)
  FWR.Identity.Invalidate()
  check(Sets.CanSave(slots), "two copies ok")
  local empty = Sets.NewSlots()
  for _, k in ipairs(FWR.SLOT_ORDER) do empty[k] = { state = "empty" } end
  check(Sets.CanSave(empty), "all-empty set is valid")
end)

test("Draft: dirty, save, revert, snapshot", function()
  clearSets()
  local Sets = FWR.Sets
  S.bags[0][1] = S.Item(100)
  FWR.Identity.Invalidate()
  local set = Sets.Create("Main")
  local draft = Sets.NewDraft(set)
  check(not draft:IsDirty(), "clean")
  local snap = draft:Snapshot()
  draft:PlaceItem("MAINHAND", ref(100))
  check(draft:IsDirty(), "dirty")
  draft:Restore(snap)
  check(not draft:IsDirty(), "restored")
  draft:PlaceItem("MAINHAND", ref(100))
  check(draft:Save(), "saved")
  check(not draft:IsDirty(), "clean after save")
  eq(Sets.Get(set.id).slots.MAINHAND.item.id, 100)
  local copy = Sets.SaveAsNew(set.id, "Copy", draft.slots)
  check(copy and copy.key == nil, "copy has no key")
end)
