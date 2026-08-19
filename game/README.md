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

The current main scene is `res://scenes/main_3d.tscn`. All current runtime models are procedural low-poly Godot geometry and require no downloaded art packs. The browser prototype under `../web/` is retained as a simulation reference, not as the production renderer.
