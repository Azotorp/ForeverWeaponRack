# Key Bindings

> ForeverWeaponRack is **experimental**. See [[Home]].

Each set can have its own key, and the [[Equipment Toggle]] has one too.

## Binding a key to a set

1. On the **Edit Set** tab, select the set.
2. Click the **Key** box. It says "Press a key".
3. Press the key or mouse button. **Escape** cancels.

**Right-click** the Key box to clear the key.

### What you can bind

- Any keyboard key, with or without Alt, Ctrl or Shift.
- Middle click (Mouse 3), Mouse 4, Mouse 5, wheel up and wheel down, with or without modifiers.
- Shift-, Ctrl- or Alt- left or right click, if the game allows it. You get a warning, because these can clash with linking items or targeting.
- **Plain left click and plain right click can never be bound.**

## How keys are stored

Keys are stored by the add-on and go live through the game's binding system as **override bindings**:

- They work like any other key, and other add-ons that check what a key does can see them.
- **Set keys are per character.** They never reach your other characters.
- The Equipment Toggle key is stored in the **profile**, or per character if you choose (see [[Settings]]).
- They **don't** appear in the game's Key Bindings window. Set and clear them in the add-on.
- Binding changes are blocked by the game in combat. Changes you make in combat are saved right away and go live when combat ends. The **Queued** indicator in the window header shows while that's waiting.

## When a key is already used

The add-on checks the whole game: the default UI, action bar add-ons like Bartender, and any other add-on's bindings. If the key is taken, you see:

> This key is used by *Move Forward*. Use it anyway?

- **Accept:** our key wins on this character. The other binding stays in your saved Blizzard bindings and comes back if you clear our key or disable the add-on.
- **Cancel:** nothing changes.

## Shared keys (cycling)

Give several sets the **same key** to cycle through them:

- Each press equips the **next** set with that key, in the order of the **Sets** tab. Sets with other keys are skipped.
- After the last one it wraps back to the first.
- The add-on remembers which set the key equipped last. The memory belongs to the set, not its position: if you delete that set, the next press goes to the set that came after it.
- **Skip rule:** a set is only skipped if you're already wearing an exact match for it.

Example: "Sword and Board" and "Two-Hander" both on `F`. Each press of `F` flips between them.

The Key box shows "Shared with: …" when a key is shared.

## The Equipment Toggle key is exclusive

If you give the Equipment Toggle a key that a set uses, that set **loses its key**. The set then shows a red **"No key bound"** warning on the Edit Set tab, and a warning icon on the Sets tab, until you give it a new key. A set can't take the Equipment Toggle's key either.

## Pressing keys quickly

Items lock for a moment while they move. Presses during a swap are held back. When the swap finishes, only the **latest** press runs.

## Macros

`/fwr equip <set name>` equips a set by name. You can put it in a macro, for example:

```
/fwr equip Sword and Board
```
