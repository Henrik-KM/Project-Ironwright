# Native Godot runtime

`game/` is the primary production runtime for Project Ironwright.

Run the project with Godot 4.7.1:

```bash
godot --path game
```

Run its headless tests:

```bash
godot --headless --path game --script res://tests/test_runner.gd
```

The current main scene is `res://scenes/main_3d.tscn`. The Mechromancer uses the original authored glTF asset at `res://assets/mechromancer/mechromancer.gltf`; friendly robots and organic enemies remain procedural low-poly Godot geometry. No downloaded art packs are required. The browser prototype under `../web/` is retained as a simulation reference, not as the production renderer.
