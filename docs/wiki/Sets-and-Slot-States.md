# Sets and Slot States

> ForeverWeaponRack is **experimental**. See [[Home]].

A **set** is a named group of four slots, swapped in this order: **Main Hand → Off Hand → Ranged → Ammo**.

| Slot | Takes |
|---|---|
| Main Hand | One-handers, main-hand-only weapons, two-handers, staves, polearms, fishing poles |
| Off Hand | Shields, off-hand weapons, held-in-off-hand items (and one-handers if you can dual wield) |
| Ranged | Bows, guns, crossbows, thrown weapons, wands, librams, idols, totems |
| Ammo | Arrows or bullets. Only shown when Ranged holds a bow, gun or crossbow |

## Slot states

Every slot is in one of three states:

| State | Swap does | Looks like |
|---|---|---|
| **Item** | Equips that item | The item's icon, with a border in its quality color |
| **Empty** | Unequips whatever is there | The character-sheet empty-slot picture, with an orange "empty on purpose" border |
| **Leave alone** | Never touches the slot | A faded empty-slot picture, no border |

**Right-click** a slot to change its state:

- If the slot has a remembered item: **Item → Empty → Leave alone → Item …**
- If it never had an item: **Empty ↔ Leave alone**

The slot remembers its item through the cycle, so you don't need to drag it in again.

## Picking items

- **Drag and drop.** Drag an item from your bags or the character sheet onto a slot. The item goes straight back where it came from; only the set changes.
- **Hover list (flyout).** Hover a slot for a moment (the delay is in [[Settings]]). A panel of every item in your bags and equipped gear that fits, and that you can actually equip, pops out. Click one to use it. The list is sorted by type (daggers, fist weapons, swords, axes, maces, then two-handed swords, axes, maces, polearms, staves), then highest item level, then quality. The Main Hand list includes two-handers.
- **Fake cursor.** Left-click a slot to pick its item up, then click another slot to drop it. If that slot had an item, you pick that one up next, so you can shuffle items around. Clicking anywhere else undoes the whole shuffle. Switching sets or right-clicking also undoes it. The real item never leaves your bags, so the game's "destroy item?" popup can't appear.
- **Shift-click** a slot to link its item in chat.

## Smart rules

- **Two-handers** always go in the Main Hand. Dropping one on the Off Hand puts it in the Main Hand.
- Picking a two-hander for the Main Hand sets the Off Hand to **Empty**. The Off Hand remembers its item, so right-clicking it brings it back. If you then switch the Off Hand back to an item, the Main Hand becomes Empty (remembering the two-hander). The latest choice wins.
- **Ammo must match.** Bows and crossbows take arrows, guns take bullets. Wrong ammo is refused. Wands, thrown weapons and relics hide the Ammo slot. When the Ammo slot is hidden, it counts as Leave alone.
- **Best ammo is picked for you** when the Ranged slot gets a bow, gun or crossbow: highest damage per second, then item level. If you switch from a bow to a gun, the arrows are replaced with your best bullets. Ammo you picked yourself is kept as long as it fits.
- **Only usable items.** Items the game won't let you equip (wrong class, level too high, weapon skill not trained) are refused with the game's red error text.
- **One copy, two slots.** If a set uses the same item in both hands but you only own one, Save warns you and refuses.
- Any slot can be **Leave alone**, including Main Hand, Ranged and Ammo.
- **Empty Main Hand with an Off Hand** is fine (for example fist plus shield, for role-play).
- **All-Empty sets** are fine, for example to unequip everything before a wipe.
- **All-Leave-alone sets** do nothing, so Save is grayed out with a hint.

## Slot indicators

- **Quality border:** the item's quality color.
- **Green check:** you're wearing that item (or the slot is already empty, for Empty).
- **Red tint:** the item isn't in your bags or equipped. The tooltip says if it's in your bank.
- **BoE:** a Bind on Equip item that isn't bound yet.
- **T:** still tradeable (inside its loot trade window).
- **R:** still refundable at a vendor.
- **Tooltips** everywhere explain the state and what clicks do.

## Saving, names and the Sets tab

- Item changes are a **draft** until you click **Save**. **Cancel** throws the draft away. If you switch sets, switch tabs or close the window with unsaved changes, you're asked whether to save.
- **Editing never equips anything**, and it works in combat.
- **Rename** and **Save as New** light up once you type a name that's new. Names don't care about capitals: "Tank" and "tank" count as the same name. Save as New copies the set, including unsaved item changes. The copy has no key.
- The **Sets** tab shows every set with **Rename**, **Save as New**, **Edit**, **Equip**, **Up**, **Down** and **Delete** (Delete asks first). **Add Set** is under the table. The list order is the order shared keys cycle in (see [[Key Bindings]]).
- A green check next to a set (Sets tab and the set dropdown) means you're wearing it. The window header turns **yellow** when you aren't wearing any saved set.

## Copies of the same item

If you own several copies of a weapon, the add-on picks the right one:

1. The **exact item**: same enchant, random stats and gems. Item level from your level and spec is ignored.
2. A **temporary enchant** (sharpening stone, weightstone, oil, poison) breaks ties. If it wore off, the next-closest copy is used.
3. **Truly identical copies:** a copy already in that slot, then the first one in your bags, then one in your other hand.

If no copy matches exactly (say you re-enchanted the weapon after saving the set), the same item with a different enchant is used as the closest match. Its tooltip says so.

The same check decides whether you're "already wearing" a set.
