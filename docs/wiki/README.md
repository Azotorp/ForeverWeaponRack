# Wiki pages

These are the pages for the GitHub wiki (Azotorp/ForeverWeaponRack.wiki). They live here because the wiki couldn't be pushed from the session that wrote them.

To publish them (the wiki repo already exists, with a placeholder Home page):

```
git clone https://github.com/Azotorp/ForeverWeaponRack.wiki.git
cp docs/wiki/*.md ForeverWeaponRack.wiki/
rm ForeverWeaponRack.wiki/README.md        # this file isn't a wiki page
cd ForeverWeaponRack.wiki
git add -A
git commit -m "Add wiki pages"
git push
```

File names map to page titles: `Getting-Started.md` becomes "Getting Started", and `_Sidebar.md` is the sidebar. Links between pages use `[[Page Name]]`.
