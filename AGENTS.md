# Repository Instructions

## Project Shape

- This is a Godot 4.x project; the executable is `godot` rather than `godot4` in the current environment.
- `project.godot` starts `scenes/levels/main.tscn`. That scene owns the test world and HUD and instances the reusable `scenes/player/player.tscn` scene.
- Player movement and mouse capture live in `scripts/player/first_person_controller.gd`. Movement and camera tuning belong in its exported properties, not level-specific scripts.
- The controller requires a direct child named `Head` via `$Head`. The camera's three-meter `InteractionRay` is already configured for future interaction logic.
- `.agents/` and `skills-lock.json` are agent-tooling metadata, not game runtime code.

## Project Contracts

- Define gameplay inputs in `project.godot` and consume actions in code. Existing actions are `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, and `sprint`; mouse release uses built-in `ui_cancel`.
- Physics layer 1 is `World`; layer 2 is `Player`. The player is on layer 2 and scans layer 1 for body and ray collisions.
- The compatibility renderer is intentional for non-Vulkan systems. Do not switch renderers incidentally.
- Keep `scenes/levels/main.tscn` HUD instructions and `README.md` controls synchronized with input behavior.
- `.godot/` is generated import/editor state and must not be edited or committed.

## Verification

Run from the repository root, in this order:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 2
```

The first command imports and parses project resources; the second starts the configured main scene and catches startup/runtime errors. There is currently no separate test, lint, formatter, or export pipeline. Headless checks do not verify mouse feel, movement, collisions, or rendering, so gameplay changes still need an editor playtest.
