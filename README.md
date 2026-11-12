# maps

A grid-based city-building game for Roblox, written in strict Luau and synced with Rojo.

## Running it

1. In a terminal: `cd ~/maps && rojo serve`
2. In Roblox Studio (a place of its own): Plugins → Rojo → Connect.
3. Press Play.

## Layout

| Folder | Goes to | What it holds |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage/Shared` | Config, grid maths, terrain generation, map data access |
| `src/server` | `ServerScriptService/Server` | Authoritative map, terrain writing, player handling |
| `src/client` | `StarterPlayerScripts/Client` | Camera, grid cursor, debug panel |

## Controls (Phase 1)

- **W A S D / arrows**: move. Hold **Shift** to move faster.
- **Q / E** or **right-drag**: rotate.
- **Scroll**: zoom.
- **G**: show the build grid around the pointer.

## Status

Phase 1 of 10: project structure, grid, procedural terrain, camera.
