# First Person Foundation

A small Godot 4.x 3D project with a reusable first-person controller and a playable test level.

## Run

Open this folder in Godot and press `F6` or `F5`. The project uses the compatibility renderer so it also runs on systems without Vulkan support.

The project starts in offline mode by default. Experimental multiplayer uses direct ENet connections over UDP and supports one host plus three clients:

```bash
# Host on the default UDP port 7000.
godot --path . -- --host

# Join a host. Localhost is useful for testing multiple instances.
godot --path . -- --join=127.0.0.1

# Override the port on both the host and its clients.
godot --path . -- --host --port=7001
godot --path . -- --join=127.0.0.1 --port=7001
```

There is no connection UI, matchmaking, reconnection, NAT traversal, or production security. Internet hosts must manually forward the selected UDP port.

See [Experimental Multiplayer Tutorial](MULTIPLAYER.md) for LAN and internet connection instructions.

## Controls

- `W`, `A`, `S`, `D`: move
- `Shift`: sprint for up to about four seconds; stamina starts regenerating 2.5 seconds after sprinting stops
- `Space`: jump
- Mouse: look
- Hold right click: zoom the camera by 60% over 0.7 seconds
- `Escape`: release the mouse
- Left click: capture the mouse again

## Structure

- `project.godot`: project settings and input actions
- `scenes/levels/main.tscn`: starting level, multiplayer session, and HUD
- `scenes/effects/retro_screen_effect.tscn`: reusable full-screen retro post-process
- `scenes/player/player.tscn`: reusable player node tree
- `scripts/player/first_person_controller.gd`: movement and camera controller

Player tuning values are exported on the root of `player.tscn`. The camera includes a three-meter `InteractionRay` ready for interaction logic.

## Tests

The project includes a dependency-free GDScript test runner. Run it from the repository root:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Add test files directly under `tests/` with names ending in `_test.gd`. Extend `res://tests/test_case.gd` and define zero-argument methods beginning with `test_`. The base test case provides `before_each` and `after_each` hooks plus assertions for booleans, equality, and null values.
