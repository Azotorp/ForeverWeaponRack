# Testing Checklist

ForeverWeaponRack stays **experimental** until everything here is confirmed in WoW Forever. Items 1 to 9 are the testing plan from the design (DESIGN.md section 9). The rest are things the code handles both ways but can only be checked in game. In the code they're marked `TODO(test N)`.

**Before you start**

- Turn on Lua errors: `/console scriptErrors 1`
- `/fwr debug` prints a report and opens a copy window (Ctrl+A, Ctrl+C). Paste reports into an issue.
- Use a target dummy for the combat tests, if Forever has them, or any easy mob.

For each test, note **Pass**, **Fail** (with what happened), or **N/A**.

---

## Testing plan (DESIGN 9)

### 1. Equipping in combat through the add-on API

The big one. If this fails, the Macro mode branch takes over (DESIGN 10).

1. Make two sets, for example a one-hander + shield and a two-hander. Bind each to a key.
2. Enter combat. Press one key, then the other.
3. Also try the **Equip** button on the Sets tab, and a macro with `/fwr equip <name>`, in combat.

| Result | Meaning |
|---|---|
| Weapons swap straight away | **Pass** |
| A popup says "ForeverWeaponRack has been blocked from an action", or chat says "WoW Forever blocked equipping in combat", and the swap runs after combat | **Fail**: the queue fallback works, but Macro mode is needed |
| Nothing happens and there's no message | **Fail**: report with `/fwr debug` |

`/fwr debug` shows "combat swaps blocked this session: true/false". After the test, run `/fwr debug swaps` and paste the result: it lists every press, whether it was in combat, each move sent or refused, and any game error or block seen while it ran.

*Version 0.1.0 failed this test. 0.1.1 runs keys through hidden key commands (the path ItemRack Forever uses) instead of a click on a hidden button.*

### 2. Ranged slot and relics in combat

- Hunter or warrior: swap between two ranged weapons (bow ↔ gun, or a thrown weapon) in combat.
- Paladin, druid or shaman: swap relics (librams, idols, totems) in combat.

### 3. Ammo in combat

1. A set with a bow and arrows, and a set with a gun and bullets (or two kinds of arrows). Swap between them in combat.
2. Check the ammo slot on the character sheet changes.
3. Set a set's **Ammo** to **Empty** and swap: the ammo slot should clear, and no ammo should be lost, moved or split. *(`TODO(test 3)`: how the ammo slot is cleared is not confirmed.)*

### 4. A second copy of the same weapon in the off hand

1. Own two copies of the same one-hander (dual wield class).
2. Make a set with that weapon in both hands. Save should work. (With only one copy, Save should warn and refuse.)
3. Swap to it from a different set, in and out of combat. Both copies should end up equipped.
4. Put a sharpening stone or poison on one copy only. Make a set that saved the enchanted copy in the Main Hand. The enchanted copy should go in the Main Hand.

### 5. Binding modified left and right click

1. In the Key box, press **Shift + left click**, then **Ctrl + right click**. There should be a warning about item linking or targeting.
2. Accept and test the binding. Does it fire? Does shift-clicking items in bags still link them?
3. Plain left and right click must be refused ("Plain left and right click can't be bound").

### 6. Trade window string and tooltip line types

1. Type `/dump BIND_TRADE_TIME_REMAINING` and note the result.
2. Type `/fwr debug`. The "Test 6" section shows the string, the pattern built from it, and the tooltip line type numbers.
3. Loot a BoP item in a group, while you can still trade it. Type `/fwr debug bags`. It should show `trade=true` for that item, and the slot should show a **T** badge when the item is in a set.
4. Also run `/fwr debug bag <bag> <slot>` on that item. Note the line with the trade text: its `type=` and line type name.

### 7. Temporary enchants on bag items

1. Put a sharpening stone, weightstone, oil or poison on a weapon.
2. `/fwr debug`: the "Test 7" section shows the weapon enchant API result and the tooltip temp enchant for your equipped weapons.
3. Move that weapon to your bags. Type `/fwr debug bags`. Does it show `temp=<enchant name>`? *(If not, identity falls back to the next rule, which still works.)*

### 8. Vendor refunds

1. Buy a weapon from a vendor (if Forever has refunds, it can be sold back for a while).
2. `/fwr debug bags` should show `refund=true`. In a set, the slot shows an **R** badge.
3. If Forever has no refunds, it's always `false`. Note that.

### 9. Does `/wr` clash with another add-on?

`/fwr debug`, section "Test 9", lists any other add-on that registers `/wr`. Also try typing `/wr` and see which window opens.

---

## More things to confirm

### 10. A key press fires once

Bind a set key. Press it once. The swap should happen once, not twice. Holding the key shouldn't repeat it. `/fwr debug` lists each key and the command it runs (`FOREVERWEAPONRACK_KEY1`, …); anything else there means another add-on took the key back.

### 11. Two-hander ↔ one-hander + shield in combat

Swap from a two-hander to a one-hander + shield, and back, in combat. Both weapons should end up on with one key press. Going to the two-hander, the shield is put in your bags first, in the same key press (the way ItemRack Forever does it). If only one hand changes, press again, and paste `/fwr debug swaps`.

### 12. Dead and mid-cast

1. Start a long cast and press a set key. The window shows **Queued**. The swap runs when the cast ends.
2. While dead, press a set key. It runs after you resurrect.
3. Right-click **Queued** to cancel a waiting swap.

### 13. Binding a key in combat

In combat, click the Key box and press a key. It should save straight away (chat: "Saved. It goes live when combat ends.") and work after combat. Check whether the Key box can listen for keys in combat at all. Mouse buttons and the wheel always work.

### 14. Bags full

Fill your bags, then swap from one-hander + shield to a two-hander. You should get a "bags full" message and **nothing should move**.

### 15. Bind on Equip warning

Put an unbound BoE weapon in a set and swap to it. The add-on's popup should appear first. After Accept, the game's own bind popup may appear too. Accept that one yourself. The item should go on.

### 16. Interface number

The add-on shouldn't show as "Out of date" in WoW Forever 1.60.x. If it does, run `/dump (select(4, GetBuildInfo()))` and report the number.

### 17. Settings, minimap and compartment

- Esc > Options > AddOns > ForeverWeaponRack opens the panel. So do the gear button and `/fwr settings`.
- The minimap button opens the window and can be dragged around the minimap.
- If your minimap has the add-on compartment (the add-ons list button), ForeverWeaponRack is listed and opens the window.

### 18. Tooltip reading in combat (secret values)

Forever can hide some values from add-ons in combat. In combat, open the window and hover slots: badges and tooltips should still show, with no Lua errors. Run `/fwr debug mh` in combat and note any line marked `SECRET`.

### 19. Equipment Toggle

1. Set a toggle key in Settings. Press it: Main Hand, Off Hand and Ranged come off. Ammo and relics stay.
2. `/reload`, then press it again: everything goes back on.
3. Take weapons off, sell or bank one, press again: the rest goes on, with a warning about the missing one.
4. Give the toggle a key a set uses: the set should show **No key bound**.

### 20. Shared keys

Three sets on the same key. Each press equips the next, wrapping around. Delete the set that was equipped last: the next press goes to the set after it.

### 21. Profiles

Make a new profile, move and resize the window, then switch back to Default. The window should jump back. A second character on the same profile should share the window position and toggle key, but **not** sets.

### 22. Unsaved changes

Change a slot without saving, then switch sets, switch tabs, and close the window (also with Escape). Each time you should be asked to save. Cancel should keep the window and the changes.
