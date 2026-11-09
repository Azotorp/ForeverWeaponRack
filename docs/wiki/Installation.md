# Installation

> ForeverWeaponRack is **experimental**. See [[Home]].

## Manual install

1. Download the latest release ZIP, or the repository as a ZIP (green **Code** button > **Download ZIP**).
2. Open the ZIP and find the folder named **`ForeverWeaponRack`** (the one with `ForeverWeaponRack.toc` inside).
3. Copy that folder into your WoW Forever add-ons folder:

   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```

   You should end up with:

   ```
   World of Warcraft\_forever_\Interface\AddOns\ForeverWeaponRack\ForeverWeaponRack.toc
   ```

   If the `.toc` is one folder deeper (for example `...\AddOns\ForeverWeaponRack-main\ForeverWeaponRack\`), the game won't find it. Move the inner folder up.
4. Start WoW Forever. On the character screen, click **AddOns** and make sure **ForeverWeaponRack** is ticked.
5. Log in. You should see this in chat: `ForeverWeaponRack: v0.1.0-experimental loaded.`

## Updating

Close the game, delete the old `ForeverWeaponRack` folder, and copy in the new one. Your sets and settings are not in that folder (they're in `WTF`), so they're kept. When the saved data layout changes, the add-on upgrades your old data instead of wiping it.

## "Out of date"

The `.toc` uses `## Interface: 16001`, the same number ForeverAuras uses in WoW Forever 1.60.x. If a later Forever patch marks the add-on "Out of date":

1. In game, type:

   ```
   /dump (select(4, GetBuildInfo()))
   ```

2. Open `ForeverWeaponRack.toc` in a text editor and put the printed number on the `## Interface:` line.

Or tick **Load out of date AddOns** on the AddOns screen.

## Where your data is saved

| What | File |
|---|---|
| Profiles (global settings) | `WTF\Account\<ACCOUNT>\SavedVariables\ForeverWeaponRack.lua` |
| Sets, set keys, toggle memory | `WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\ForeverWeaponRack.lua` |

## Uninstalling

Delete the `ForeverWeaponRack` folder from `Interface\AddOns`. Any key you shadowed with a set key works again straight away, because the add-on never changes your saved Blizzard key bindings (see [[Key Bindings]]).
