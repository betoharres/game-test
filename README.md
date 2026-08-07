# First Person Foundation

A small Godot 4.x 3D project with a reusable first-person controller and a playable test level.

## Run

Open this folder in Godot and press `F6` or `F5`. The project uses the compatibility renderer so it also runs on systems without Vulkan support.

## Controls

- `W`, `A`, `S`, `D`: move
- `Shift`: sprint
- `Space`: jump
- Mouse: look
- `Escape`: release the mouse
- Left click: capture the mouse again

## Structure

- `project.godot`: project settings and input actions
- `scenes/levels/main.tscn`: starting level and HUD
- `scenes/player/player.tscn`: reusable player node tree
- `scripts/player/first_person_controller.gd`: movement and camera controller

Player tuning values are exported on the root of `player.tscn`. The camera includes a three-meter `InteractionRay` ready for interaction logic.
