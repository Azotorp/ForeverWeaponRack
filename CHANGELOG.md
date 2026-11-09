# Changelog

## 0.1.1-experimental

Fixed

* Set keys and the Equipment Toggle key now swap weapons in combat. In 0.1.0 a key "clicked" a hidden plain button, and in WoW Forever that path doesn't swap in combat. Keys now run hidden key commands from `Bindings.xml` straight from the key press, the same path ItemRack Forever uses. Keys are still stored per character by the add-on, and still don't show in the game's Key Bindings window.
* Swapping to a two-hander puts the off hand in your bags first, in the same key press, instead of relying on the game to push it off.
* Tooltip reads during a swap can't break it any more. If the game refuses one, the check just finds nothing.

Added

* `/fwr debug swaps`: the last swaps, move by move. Shows whether each was in combat, each move sent or refused, and any game error or block seen while it ran. The plain `/fwr debug` report shows the last three swaps, plus the command each of your keys runs.
* A swap is also refused while the cursor is targeting a spell.

## 0.1.0-experimental

First build: sets, slot states, smart rules, swap engine with checks and queue, shared keys, Equipment Toggle, settings and profiles, `/fwr debug`.
