# Persistence and Save Schema

Project Ironwright writes one run-level envelope to `user://ironwright_run.json`.
The envelope separates the durable foundation simulation from extension state so
new directors can be added without creating another save domain.

## Current envelope

Schema version 2 contains:

- `format`: `project_ironwright_run`;
- `foundation`: run state, actor positions and health, Heartforge health,
  salvage piles, living organic enemies, and ecology state;
- `extensions.full_game`: progression, outposts, discovered regions, long-range
  operations, machine society, strategic ecology, endgame, continuity, victory,
  sanctuary continuation, the post-victory archive, and persistent
  region-salvage flags.

The schema is written by `TransactionalSaveService3D`. It first writes
`ironwright_run.json.tmp`, flushes and closes it, rotates the existing primary
through `.bak1` and `.bak2`, and then promotes the temporary file. The backup
count is bounded at two files.

## Migration and recovery

Reads try the primary and both backups in order. A valid older envelope is
upgraded in memory to the current schema. Legacy `ironwright_first_light_3d.json`
and `ironwright_full_game_extension.json` files are wrapped into the same current
envelope and reported to the player as migrated state.

Active salvage, expedition, outpost-construction, and long-range operations defer
saving while their live formation references are not serializable. This keeps the
save boundary explicit instead of pretending an incomplete operation is durable.

The persistence test runner verifies current writes, backup rotation, corrupt
primary recovery, and migration of both legacy files.
