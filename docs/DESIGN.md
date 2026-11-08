# ForeverWeaponRack — Design Document

> **Status: Experimental.** This design assumes the add-on API can equip items in combat in WoW Forever. That has not been confirmed yet. If testing shows it can't, a Macro mode fallback will be built on a separate branch (see [Fallback plan](#fallback-plan-macro-mode)).

ForeverWeaponRack is a weapon set swapper for WoW Forever. You save sets of main hand, off hand, ranged, and ammo, bind each set to a key, and swap them live in combat. It is meant for in-combat, in-raid weapon swapping. Full gear sets are left to tools like ItemRack.

It works for any class: sword and board, two-hander, dual wield, staves, wands, ranged weapons, and relics (librams, idols, totems).

---

## 1. Goals and non-goals

**Goals**

- Fast, reliable weapon swaps in combat from a key press or a click.
- Any number of named sets, each with its own key binding.
- Clear visual feedback on what each set holds and what you're wearing.
- Safe by default. Never bind, lose, or destroy an item without asking.

**Non-goals**

- Swapping armor or full gear sets.
- Automatic swaps without a key press or click. Every swap must come from a real hardware action.
- Equipping from the bank.

---

## 2. Terminology

| Term | Meaning |
|---|---|
| **Set** | A named group of four slots: Main Hand, Off Hand, Ranged, Ammo. |
| **Slot state** | Each slot is in one of three states: **Item**, **Empty**, or **Leave alone**. |
| **Item** | The slot holds a specific saved item. Swapping equips it. |
| **Empty** | The slot is empty on purpose. Swapping unequips whatever is there. |
| **Leave alone** | The swap never touches that slot. |
| **Shared key** | One key bound to several sets. Pressing it cycles through them. |
| **Equipment Toggle** | A global key that unequips your weapons, then puts them back on the next press. |
| **Profile** | Global settings like window position, scale, and global keys. Never holds sets. |

---

## 3. Sets and slots

### 3.1 Slots

Each set has four slots:

1. **Main Hand** — one-handers, main-hand-only weapons, two-handers, staves, polearms, fishing poles.
2. **Off Hand** — shields, off-hand weapons, held-in-off-hand items.
3. **Ranged** — bows, guns, crossbows, thrown, wands, librams, idols, totems.
4. **Ammo** — arrows or bullets. Only shown when the Ranged slot holds a bow, gun, or crossbow.

Forever's character sheet has both a Ranged slot and an Ammo slot (confirmed from a screenshot).

### 3.2 Slot states (right-click cycle)

Right-clicking a slot cycles its state:

- **If the slot has a remembered item:** Item → Empty → Leave alone → Item …
- **If the slot never had an item:** Empty ↔ Leave alone.

The slot remembers its item through the cycle, so you don't need to drag it in again.

**Visuals**

| State | Background | Border |
|---|---|---|
| Item | Item icon | Item quality color |
| Empty | Solid empty-slot background, same as the character sheet | Distinct "empty on purpose" color |
| Leave alone | Semi-transparent empty-slot background | None |

### 3.3 Smart rules

- **Two-handers** (two-handed weapons, staves, polearms, fishing poles) always go in the Main Hand. Dropping one in the Off Hand moves it to the Main Hand.
- Picking a two-hander for the Main Hand sets the Off Hand to **Empty**. The Off Hand remembers its old item, so right-clicking brings it back later.
- **Ammo must match the ranged weapon.** Bows and crossbows take arrows, guns take bullets. Wrong ammo is rejected. Wands, thrown weapons, and relics hide the Ammo slot.
- **Auto-pick best ammo.** When the Ranged slot gets a bow, gun, or crossbow, the add-on picks your best matching ammo by damage per second, then item level. If arrows were saved and you switch to a gun, the arrows are replaced with your best bullets. If you drop in ammo yourself, that choice is kept.
- **Only usable items.** Items the game wouldn't let you equip (wrong class, too high level, untrained weapon skill) are rejected with the game's red error text.
- **One copy, two slots.** If a set uses the same item in both Main Hand and Off Hand but you only own one, it warns and refuses to save.
- **Any slot can be Leave alone**, including Main Hand, Ranged, and Ammo.
- **Empty Main Hand with an off hand is valid** (for example fist plus shield, for RP).
- **All-Empty sets are valid**, for example to unequip everything for RP or before a wipe.
- **All-Leave-alone sets do nothing**, so Save is grayed out with a hint.

---

## 4. The window

The window is movable, resizable from the bottom-right corner, closable, and lockable. A minimap button toggles it. It has two tabs: **Edit Set** and **Sets**.

### 4.1 Edit Set tab

- **Set dropdown** at the top. A checkmark appears next to sets you're currently wearing.
- **Name box** with **Rename** and **Save as New** buttons (see 4.3).
- **The four slots** for the selected set.
- **Key binding box** ("press a key") for that set.
- **Save** and **Cancel** buttons for item changes (see 4.4).

### 4.2 Sets tab

A table of all sets, one row per set:

| Name (editable) | Rename | Save as New | Edit | Equip | Up | Down | Delete |
|---|---|---|---|---|---|---|---|

- **Edit** jumps to the Edit Set tab with that set selected.
- **Equip** equips the set (a click is a valid hardware action).
- **Up / Down** swap the set with its neighbor. Up is grayed out at the top and Down at the bottom.
- **Delete** asks for confirmation first.
- An **Add Set** button sits below the table.
- The list order is the cycle order for shared keys.

### 4.3 Naming rules (both tabs)

- **Rename** and **Save as New** start grayed out.
- They light up as soon as you type a name that's new and not used by another set.
- They gray out again if the name matches the original, matches another set, or is empty.
- Names are case-insensitive ("Tank" and "tank" are the same).
- **Rename** changes the name in place.
- **Save as New** copies the set under the new name, including unsaved item changes.

### 4.4 Saving item changes

- Item changes are a draft until you press **Save**.
- **Save** lights up only when an item has changed. **Cancel** reverts the draft.
- If you switch sets or close the window with unsaved changes, a "Save changes?" popup appears.
- **Editing never equips anything.** Changing a set never changes what you're wearing.
- All editing works in combat, since it only changes saved data.

### 4.5 Picking items

**Drag and drop.** Drag an item from your bags or character sheet onto a slot.

**Fake cursor.** Left-clicking a slot picks up its item on a fake cursor. The real item never leaves your bags, so the game's destroy popup can never appear.

- Click another slot to drop it there. If that slot had an item, you pick that one up next.
- Slots that don't fit reject the drop.
- Clicking anywhere else puts the item back in its original slot.
- Switching sets while holding an item cancels the pickup.

**Hover flyout.** Hovering a slot (after a short delay) opens a panel of every item in your bags or equipped gear that fits.

- Each entry shows its icon, quality border, and tooltip.
- Clicking an entry puts it in the slot, with the same rules as drag and drop.
- Only items you can actually equip are listed.
- **Sort order:** grouped by type, then highest item level, then quality.
  - One-handers first: daggers, fist weapons, swords, axes, maces.
  - Then two-handers: swords, axes, maces, polearms, staves.
- **Layout:** a single column for a few items, more columns as the list grows. It flips direction if it would go off screen.
- The Main Hand flyout includes two-handers.

### 4.6 Slot indicators

- **Quality border** in the item's quality color.
- **Equipped badge:** a green ready-check checkmark in the corner of any slot whose item you're wearing.
- **Missing:** a red tint if the saved item isn't in your bags or equipped.
- **Bind on Equip:** a small badge on unbound BoE items.
- **Tradeable:** a small badge on items still in their loot trade window.
- **Refundable:** a small badge on vendor items still in their refund window.
- **Tooltips** on every slot and button.

### 4.7 Header warnings

- **Not wearing any set:** the header turns yellow when your current weapons don't match any saved set.
- **Queued:** a small indicator while something is waiting for combat to end (see 6.3). Right-clicking it cancels the queue.

---

## 5. Key bindings

### 5.1 How bindings work

- Bindings use Blizzard's real binding system, so they show up and save like any other key.
- Each set has its own binding. The Equipment Toggle has its own binding.
- The add-on checks the whole game for conflicts: the default UI, action bar add-ons like Bartender, and any other add-on's bindings.
- **Conflict popup:** "This key is used by X. Use it anyway?" with Accept or Cancel. Accepting removes the old binding.
- Binding changes made in combat are saved right away but only go live after combat (see 6.3).

### 5.2 Allowed inputs

- Any keyboard key, with or without Alt, Shift, or Ctrl.
- Middle click (Mouse 3), Mouse 4, Mouse 5, Scroll Up, Scroll Down, with or without modifiers.
- Modified left and right click, if the game allows binding them. Needs testing. The popup warns that these may clash with item linking or targeting.
- **Plain left click and plain right click are always blocked.**

### 5.3 Shared keys (cycling)

- Several sets can share one key. Pressing it cycles through them in list order, skipping sets with other keys.
- The add-on remembers which set that key equipped last and moves to the next one with the same key. It wraps back to the top after the last one.
- Cycle memory is tied to the set, not its position. If you delete the remembered set, the next press goes to the next set in line.
- **Skip rule:** the next set is skipped only if you're already wearing an exact match for it (see 6.4).

### 5.4 Equipment Toggle

- A global key, set in Settings.
- **If you're holding any weapon:** it unequips Main Hand, Off Hand, and Ranged, and remembers exactly what was on. Ammo and relics are left alone.
- **If your hands are empty:** it re-equips what it remembered, in order.
- The memory survives a reload or logout.
- If a remembered item was sold or banked, it re-equips what it can and warns about the rest.
- The toggle's key is exclusive. If you accept a key that a set uses, that set loses its binding and shows a **"No key bound"** warning.
- The description mentions using it to save durability before a wipe, for RP, or anything else.

### 5.5 Slash commands

`/fwr`, `/weaponrack`, `/wr`

- No arguments: toggle the window.
- `equip <set name>`: equip a set by name, for use in macros.
- `debug`: print tooltip lines and their types for an item, for testing (see 9).

`/wr` may clash with another add-on. If so, the last one loaded wins, and the other two still work.

---

## 6. Swapping

### 6.1 Equip order

Main Hand → Off Hand → Ranged → Ammo. This makes sure a two-hander or fishing pole is replaced before the off hand goes on.

### 6.2 Checks before swapping

All checks run before anything moves. If any check fails or you cancel, **nothing changes**.

1. **Missing items.** If any item the set needs is missing or in the bank, it warns and cancels the whole swap.
2. **Bag space.** It counts every item that will be unequipped. If there's not enough room, it shows a "Bags full" warning and cancels.
3. **Bind, trade, and refund warnings.** If the swap would equip an unbound BoE item, an item still tradeable, or a refundable vendor item, the add-on shows its own Accept/Cancel popup first. The game's own bind popup may still appear afterward, and the add-on never clicks it for you. Recommendation: equip such items by hand once before relying on them in combat.

These popups only appear when equipping, never when adding an item to a set.

### 6.3 Queue

Anything the game blocks right now gets queued and runs when it's allowed:

- Swaps or binding changes blocked in combat.
- Swaps blocked while dead or mid-cast (busy states).
- Only the **latest** request runs. Earlier queued requests are dropped.
- A **Queued** indicator shows on the window. Right-clicking it cancels.

### 6.4 Item identity

To tell copies of the same item apart, the add-on matches in this order:

1. **Full item:** item ID, enchant, random stats, gems, and anything else in the item link.
2. **Temporary enchant** as a tiebreaker: sharpening stones, weightstones, poisons, weapon chains, and similar.
   - If the set expects a temp enchant that has worn off, it falls back to the next-closest match.
   - Temp enchants on bag items may only be readable from tooltip text. To be confirmed in testing.
3. **Truly identical copies:** the first one by bag order.

The same identity check decides whether you're "already wearing" a set (for the checkmark, header warning, and cycle skip).

### 6.5 Key spam

Items lock briefly while they move. Presses during a swap are ignored until it finishes, then only the latest press runs.

---

## 7. Detection details

- **Trade window:** read using the game's own global string for the tradeable line (believed to be `BIND_TRADE_TIME_REMAINING`, to be confirmed), turned into a pattern so it matches any time value in any language. If the newer tooltip API tags the line by type, use that instead. A looser fallback looks for trade wording plus a time.
- **Bind on equip:** read from the tooltip line type or the game's BoE global string.
- **Refundable:** the game's built-in refund flag. If Forever has no refunds, this never shows.
- **Usable items:** the game's own "can equip" checks, not hand-written rules.

All detection uses the game's built-in strings or flags, never hard-coded English text, so it works in every language.

---

## 8. Settings and saved data

### 8.1 Settings

- Window lock.
- Hover flyout delay.
- Equipment Toggle key binding.
- Profile selection.
- More settings will be added as the add-on grows.

### 8.2 What's saved where

| Data | Scope |
|---|---|
| Sets, set key bindings, cycle memory | Per character |
| Equipment Toggle memory | Per character |
| Window position, scale, lock, flyout delay | Profile |
| Equipment Toggle key and future global keys | Profile, or per character if chosen |

- Profiles hold global settings only. Sets are never copied between characters, since each character owns different items.
- Saved data has a **version number**. Updates migrate old data instead of wiping it.

---

## 9. Testing plan

These need to be confirmed in game before the add-on leaves experimental status:

1. **Equipping in combat through the add-on API.** If this fails, switch to the Macro mode branch.
2. Swapping the Ranged slot and relics in combat.
3. Swapping ammo in combat.
4. Equipping a second copy of the same weapon into the off hand.
5. Binding modified left and right click.
6. `BIND_TRADE_TIME_REMAINING` (use `/dump BIND_TRADE_TIME_REMAINING`) and tooltip line types.
7. Reading temporary enchants on bag items.
8. Vendor refunds in Forever.
9. Whether `/wr` clashes with another add-on.

The `debug` command prints an item's tooltip lines and their types to help with tests 6 and 7.

---

## 10. Fallback plan: Macro mode

If the add-on API can't equip items in combat, a new branch will add Macro mode:

- Each set gets its own macro, which the add-on writes and keeps updated using item IDs.
- A macro name box, a Character or Global dropdown, and a drag button to put the macro on your bar.
- The drag button cycles through the set's item icons and glows when the macro changes.
- Macro edits are blocked in combat, since the game locks them.
- Macros can't tell enchanted copies apart, so the duplicate warning matters more.

---

## 11. Publishing notes

- **README and wiki:** install and usage guides. The README marks the add-on as experimental until all features are confirmed.
- **CurseForge description** will include a note that ForeverWeaponRack is not affiliated with WeaponRack by TooSoon (https://www.curseforge.com/wow/addons/weaponrack), and that it was written from scratch and shares no code with it.
