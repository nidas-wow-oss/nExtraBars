*[Leer en español](README.es.md)*

# nExtraBars

An addon for **World of Warcraft 3.3.5a (WotLK)** that adds **two extra action bars** (left and right), movable and configurable, with class bar offset support.

**Version:** 2.2.2 · **Author:** Nidhaus

## What it does

- Two additional action bars, **Left** and **Right**, independent of Blizzard's own.
- **Movable**: drag each bar wherever you want and the position is saved.
- **Class bar offset support** (stance/shapeshift), so they never overlap.
- Its own keybindings through `Bindings.xml`, configurable from the standard in-game menu.
- **Per-character** settings (`SavedVariablesPerCharacter: NEB_DB`), so every alt keeps its own layout.

## Installation

1. Close the game.
2. Copy the `nExtraBars` folder into `World of Warcraft\Interface\AddOns\`.
3. Start the game and enable the addon on the character selection screen.

Coming from an older version? Your saved settings are preserved.

## Commands

| Command | Action |
|---|---|
| `/neb` | Open the options panel |
| `/nextrabars` | Long alias |

## What's new in 2.2.2

A bugfix release focused on the **pet bar and crowd control**:

- Fixed the pet bar desyncing when the pet is hit by Fear, Polymorph, Hibernate or any other CC.
- Fixed the bug that appeared when the **player** lost control (Fear, Stun) and broke the pet bar.
- Fixed the case where **both player and pet** are crowd controlled at the same time.

Technically, the button system now listens to `PET_BAR_UPDATE`, `PET_BAR_UPDATE_COOLDOWN`, `UNIT_PET`, `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED` and `UNIT_AURA`, so updates fire even in combat for everything that does not require protected changes.

Full history in [`CHANGELOG.txt`](CHANGELOG.txt).

## Compatibility

Interface 30300 — WotLK 3.3.5a. Tested on Warmane.

## License

Free to use. If you redistribute it or build on it, keep the credit to the author.
