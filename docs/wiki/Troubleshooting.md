# Troubleshooting

> ForeverWeaponRack is **experimental**. Some problems may be WoW Forever behaving differently than expected. Please report them (see the bottom of this page).

## The add-on doesn't load

- Check the folder: `World of Warcraft\_forever_\Interface\AddOns\ForeverWeaponRack\ForeverWeaponRack.toc`. See [[Installation]].
- On the character screen, click **AddOns** and make sure it's ticked.
- If it says **Out of date**, tick **Load out of date AddOns**, or update the Interface number (see [[Installation]]).

## A key does nothing

- Open the window and check the set's **Key** box shows the key.
- If the window header shows **Queued**, the key is waiting for combat to end. Key changes only go live out of combat.
- If you're already wearing that set, nothing happens. That's expected.
- A red **"No key bound"** means the [[Equipment Toggle]] took the key. Bind a new one.
- Another add-on may have grabbed the key after we did. Bind it again in ForeverWeaponRack and accept the conflict question.

## "Can't equip …: missing items"

The set needs an item that isn't in your bags or equipped. The chat message lists it, and says if it's in your bank. Get it back, or change the set.

## "Inventory is full" / bags full

Free up bag slots. Every item the swap unequips needs a free slot in a normal bag, and quivers or ammo pouches don't count. A two-hander replacing a one-hander plus shield needs room for the shield.

## A popup asks about Bind on Equip, trading or refunds

That's the safety check. Accept to go ahead, Cancel to stop. The game may ask again about binding. Equip such items by hand once, before you rely on them in combat.

## "WoW Forever blocked equipping in combat"

The game refused an equip from the add-on in combat. From then on (until you reload), swaps in combat are queued and run when combat ends. Please report this with `/fwr debug`. It's test 1 on the [[Testing Checklist]].

## "The swap didn't finish"

The game refused one of the moves, for example because an item was locked or something else used the cursor. Press the key again. If it keeps happening, report it with what you were swapping.

## The wrong copy of an item goes on

The add-on matches enchants, gems and random stats, then temporary enchants. If two copies are truly identical, it takes the one already in the slot, then the first in your bags. See [[Sets and Slot States]]. If it still picks the wrong one, report it with `/fwr debug bags`.

## Items in the hover list are missing

The list only shows items that fit the slot **and** that you can equip right now: right class, level and weapon skill. For Ammo, it only shows ammo that fits the set's ranged weapon.

## `/wr` opens another add-on

Another add-on also uses `/wr`, and it loaded last. Use `/fwr` or `/weaponrack`. `/fwr debug` lists the other `/wr` registration (a name like `SLASH_SOMEADDON1`, which usually gives away the add-on).

## Reporting a problem

1. Type `/fwr debug` (or `/fwr debug mh`, `/fwr debug bags`, …). A window opens: press **Ctrl+A** then **Ctrl+C**.
2. Open an issue at <https://github.com/Azotorp/ForeverWeaponRack/issues> with the report, what you did, and what happened.
3. If WoW showed a Lua error, include it. The `/console scriptErrors 1` command makes errors show on screen.
