# Swapping

> ForeverWeaponRack is **experimental**. See [[Home]].

What happens when you press a set's key, click **Equip** on the Sets tab, or run `/fwr equip <name>`.

## 1. Checks first

All checks run before anything moves. If one fails, or you cancel, **nothing changes**.

1. **Missing items.** If any item the set needs isn't in your bags or equipped, the swap is cancelled and the missing items are listed. Items in your bank are named as such.
2. **Bag space.** Everything that gets unequipped needs a free slot in a normal bag (not a quiver or ammo pouch). That includes an off hand the game pushes off when a two-hander goes on. If there isn't enough room, you get a "bags full" message.
3. **Bind, trade and refund warnings.** If the swap would equip an unbound **Bind on Equip** item, an item still in its **loot trade window**, or a **refundable** vendor item, the add-on asks first with its own Accept/Cancel popup. The game's own bind popup may still appear afterwards. The add-on never clicks it for you. Tip: equip such items by hand once before you rely on them in combat.

These popups only appear when equipping, never when you add an item to a set.

## 2. Equip order

Main Hand → Off Hand → Ranged → Ammo. This makes sure a two-hander or fishing pole is replaced before the off hand goes on.

Most swaps happen in one go, straight from your key press. When one move depends on another (for example, an item has to leave a slot before another item can use it), the second move waits a moment for the game to finish the first.

## 3. The queue

Some swaps can't happen right now. They're **queued** and run as soon as the game allows:

- while you're **dead**
- while you're **casting**
- in **combat**, if WoW Forever turns out to block equipping in combat through add-ons. This is still being tested (see [[Testing Checklist]]). If the game blocks it, the add-on notices, tells you once, and from then on queues swaps until combat ends.

Only the **latest** request is kept. Earlier queued requests are dropped. The window header shows a **Queued** indicator. Hover it to see what's waiting, and **right-click** it to cancel.

## 4. Pressing keys quickly

Items lock for a moment while they move. Presses during a swap are held back, and only the latest one runs when the swap finishes.

## Already wearing it

If you're already wearing the set, nothing happens. With a shared key, the next set is chosen instead (see [[Key Bindings]]).
