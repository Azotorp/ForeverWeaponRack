# ForeverWeaponRack

A weapon set swapper for **WoW Forever**. Save sets of Main Hand, Off Hand, Ranged and Ammo, bind each set to a key, and swap them in combat with one key press.

> [!WARNING]
> **EXPERIMENTAL.** ForeverWeaponRack has not been confirmed to work fully in WoW Forever yet. In particular, equipping weapons in combat through the add-on API is still being tested. Treat it as experimental until full compatibility with WoW Forever is confirmed and every feature works as intended. Please report what you find (see [Reporting problems](#reporting-problems)).

Targets WoW Forever 1.60.x. ForeverWeaponRack is not affiliated with WeaponRack by TooSoon. It was written from scratch and shares no code with it.

## What it does

- **Weapon sets.** Each set has four slots: Main Hand, Off Hand, Ranged and Ammo. You can make as many sets as you like.
- **Three states per slot.** A slot holds an **Item**, is **Empty** on purpose (the swap unequips it), or is **Leave alone** (the swap never touches it). Right-click a slot to change its state.
- **One key per set.** Bind any key, Mouse 3/4/5, or the mouse wheel (with or without Alt, Ctrl, Shift). Several sets can share one key: each press moves to the next set.
- **Swap in combat.** Swaps run straight from your key press. Anything the game won't allow right now (while dead, mid-cast, or in combat if the game blocks it) waits in a queue and runs as soon as it can.
- **Safe by default.** Before anything moves, it checks for missing items and bag space. It also asks before equipping an unbound Bind on Equip, still-tradeable or refundable item. If a check fails, nothing changes.
- **Smart rules.** Two-handers go in the Main Hand and clear the Off Hand. Ammo must match the bow, gun or crossbow, and the best ammo is picked for you. Items you can't use are refused.
- **Tells copies apart.** It matches the item's enchant, random stats and gems, and uses temporary enchants (stones, oils, poisons) to break ties. So the right copy goes on.
- **Equipment Toggle.** One key unequips your weapons and remembers them. Press it again to put them back. Handy for saving durability before a wipe, or for role-play.
- **Clear feedback.** You get quality borders, an "equipped" check, a red tint for missing items, and Bind on Equip / Tradeable / Refundable badges. The window header turns yellow when you aren't wearing any saved set.

It is meant for weapon swaps in combat. Full gear sets are left to add-ons like ItemRack.

## Install

1. Download the latest release (or this repository as a ZIP).
2. Copy the **`ForeverWeaponRack`** folder into your WoW Forever add-ons folder:
   ```
   World of Warcraft\_forever_\Interface\AddOns\ForeverWeaponRack\
   ```
   The `.toc` file must be at `...\AddOns\ForeverWeaponRack\ForeverWeaponRack.toc`, not one folder deeper.
3. Start the game (or `/reload`) and make sure **ForeverWeaponRack** is enabled in the AddOns list on the character screen.

### Interface version

The `.toc` uses `## Interface: 16001`, the same number ForeverAuras uses in WoW Forever 1.60.x. If a Forever patch makes the add-on show as "Out of date", type this in game:

```
/dump (select(4, GetBuildInfo()))
```

Put the number it prints on the `## Interface:` line of `ForeverWeaponRack.toc`. Until then, you can also tick "Load out of date AddOns" on the AddOns screen.

## Basic usage

1. Type **`/fwr`** (or click the minimap button) to open the window.
2. On the **Edit Set** tab, click **Add Set**. The new set starts with the weapons you're wearing.
3. Change a slot:
   - **Drag** an item from your bags or character sheet onto it, or
   - **Hover** the slot for a moment and pick from the list, or
   - **Left-click** a slot to pick its item up, then click another slot to drop it.
   - **Right-click** a slot to switch between Item, Empty and Leave alone.
4. Click **Save**. Editing never equips anything, so you can edit in combat.
5. Click the **Key** box and press a key. That key now equips the set.
6. On the **Sets** tab you can rename, copy, reorder, equip and delete sets.

The **Equipment Toggle** key is set in **Settings** (the gear button, or Esc > Options > AddOns > ForeverWeaponRack).

### Slash commands

| Command | What it does |
|---|---|
| `/fwr` | Open or close the window |
| `/fwr equip <set name>` | Equip a set by name (works in macros) |
| `/fwr settings` | Open the settings |
| `/fwr debug` | Testing report (see the Testing Checklist) |
| `/fwr help` | List the commands |

`/weaponrack` and `/wr` work the same way. If another add-on also uses `/wr`, the one that loads last gets it. `/fwr` and `/weaponrack` keep working.

### About key bindings

Set keys and the Equipment Toggle key are stored by the add-on and go live through the game's binding system as override bindings. So:

- They work like any other key, and other add-ons can see them.
- Set keys are per character and never reach your other characters.
- If a key is already used (by the default UI, an action bar add-on, or anything else), you're asked first. If you accept, our key wins on this character. The other binding is kept, and it comes back if you clear our key or disable the add-on.
- They don't appear in the game's Key Bindings list. Set them in the add-on.
- Key changes made in combat are saved right away and go live when combat ends.

## Reporting problems

1. Type `/fwr debug`. A window opens with a report: press Ctrl+A, then Ctrl+C to copy it.
2. Open an issue on this repository with the report, what you did, and what happened.

The [Testing Checklist](https://github.com/Azotorp/ForeverWeaponRack/wiki/Testing-Checklist) in the wiki lists everything that still needs confirming in WoW Forever.

## Documentation

See the [wiki](https://github.com/Azotorp/ForeverWeaponRack/wiki): Installation, Getting Started, Sets and Slot States, Key Bindings, Equipment Toggle, Settings, Troubleshooting and the Testing Checklist. The full design is in [`docs/DESIGN.md`](docs/DESIGN.md).

## Development

The add-on uses no libraries. The code is split by job:

| File | Job |
|---|---|
| `Core.lua` | Namespace, events, messages, chat output, API helpers |
| `Locale.lua` | All text |
| `Data.lua` | Saved data, profiles, data version and migration |
| `ItemInfo.lua` | Slot rules, usability, ammo, sort order |
| `Tooltip.lua` | BoE, trade window, refund, temp enchants (from game strings and flags) |
| `Identity.lua` | Bag scan, telling copies apart, "already wearing" |
| `Sets.lua` | Sets, slot states, smart rules, drafts |
| `Swap.lua`, `Queue.lua`, `Toggle.lua` | Swapping, the queue, Equipment Toggle |
| `Bindings.lua` | Keys, shared-key cycling, conflicts |
| `UI/*.lua` | Window, tabs, slots, fake cursor, flyout, minimap |
| `Settings.lua`, `Slash.lua`, `Debug.lua`, `Init.lua` | Settings, commands, testing output, startup |

Things that can only be confirmed in game are marked `TODO(test N)` in the code. N is the item number in the testing plan (DESIGN 9). The code handles both outcomes.

Checks you can run without the game (Lua 5.1 and luacheck):

```
luacheck ForeverWeaponRack       # lint, with the WoW API globals in .luacheckrc
lua5.1 tests/run.lua             # logic tests against a fake client
lua5.1 tests/ui_smoke.lua        # loads every file and clicks through the UI
```

The fake client in `tests/` only checks the add-on's own logic. It says nothing about how WoW Forever behaves.
