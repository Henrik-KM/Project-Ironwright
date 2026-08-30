# Native Godot runtime

`game/` is the primary production runtime for Project Ironwright.

Run the project with Godot 4.7.1:

```bash
godot --path game
```

Run its headless tests:

```bash
godot --headless --audio-driver Dummy --quiet-audio --path game --script res://tests/test_runner.gd
```

For validation or development review, keep `--audio-driver Dummy --quiet-audio`
on every Godot invocation so generated audio never reaches physical speakers.

The current main scene is `res://scenes/main_3d.tscn`. The Mechromancer uses the original authored glTF asset at `res://assets/mechromancer/mechromancer.gltf`; friendly robots use authored glTF shells, while the organic roster uses authored shells or the stable procedural production-shell contract. No downloaded art packs are required. The browser prototype under `../web/` is retained as a simulation reference, not as the production renderer.
