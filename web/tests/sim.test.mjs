import test from 'node:test';
import assert from 'node:assert/strict';
import { loadSimulationModule } from './source_loader.mjs';

const sim = await loadSimulationModule();

function quietWorld(seed = 1234) {
  const world = sim.createWorld(seed);
  world.enemies = [];
  world.nests = [];
  world.projectiles = [];
  return world;
}

test('the world contains only organic hostile species and no scheduled-wave state', () => {
  const world = sim.createWorld(11);
  assert.ok(world.enemies.length > 0);
  assert.ok(world.enemies.every((enemy) => enemy.organic === true));
  assert.ok(world.enemies.every((enemy) => Object.hasOwn(sim.ORGANIC_ENEMY_TYPES, enemy.type)));
  const serialized = JSON.stringify(world).toLowerCase();
  assert.equal(serialized.includes('wave_timer'), false);
  assert.equal(serialized.includes('next_wave'), false);
  assert.equal(serialized.includes('hostile_robot'), false);
});

test('the Mechromancer automatically targets and fires at the nearest enemy in range', () => {
  const world = quietWorld(22);
  const near = {
    id: 'enemy-near', type: 'skitterling', organic: true,
    x: world.player.x + 120, y: world.player.y,
    hp: 80, maxHp: 80, speed: 0, damage: 0,
    attackRange: 0, attackInterval: 99, attackCooldown: 99,
    radius: 13, threat: 1, nestId: null, targetKind: null,
    targetId: null, heading: 0, wanderTimer: 0, dead: false,
  };
  const far = { ...near, id: 'enemy-far', x: world.player.x + 250 };
  world.enemies = [far, near];
  sim.stepWorld(world, {}, 1 / 60);
  assert.equal(world.player.targetId, 'enemy-near');
  assert.equal(world.projectiles.length, 1);
  for (let index = 0; index < 20; index += 1) sim.stepWorld(world, {}, 1 / 60);
  assert.ok(near.hp < 80, 'automatic projectile should hit the enemy');
});

test('automatic fire remains silent when no enemy is in range', () => {
  const world = quietWorld(33);
  world.enemies = [{
    id: 'enemy-distant', type: 'razorhound', organic: true,
    x: world.player.x + world.player.fireRange + 500, y: world.player.y,
    hp: 100, maxHp: 100, speed: 0, damage: 0,
    attackRange: 0, attackInterval: 99, attackCooldown: 99,
    radius: 18, threat: 2, nestId: null, targetKind: null,
    targetId: null, heading: 0, wanderTimer: 0, dead: false,
  }];
  sim.stepWorld(world, {}, 1 / 60);
  assert.equal(world.player.targetId, null);
  assert.equal(world.projectiles.length, 0);
});

test('restoration delegates routine gathering instead of opening a production queue', () => {
  const world = quietWorld(44);
  world.scrap = sim.HEARTFORGE_REPAIR_COST;
  world.player.x = world.heartforge.x;
  world.player.y = world.heartforge.y;
  const result = sim.interact(world);
  assert.equal(result.kind, 'heartforge_restored');
  assert.equal(world.progress.autonomyLevel, 1);
  assert.ok(world.robots.length >= 2);
  assert.equal(Object.hasOwn(world, 'productionQueue'), false);
  for (let index = 0; index < 240; index += 1) sim.stepWorld(world, {}, 1 / 60);
  assert.ok(world.robots.some((robot) => ['autonomous_salvage', 'delivering_scrap'].includes(robot.state)));
});

test('authorized expedition robots physically travel through the persistent world', () => {
  const world = quietWorld(55);
  world.scrap = 1000;
  world.player.x = world.heartforge.x;
  world.player.y = world.heartforge.y;
  sim.interact(world);
  assert.equal(sim.chooseEvolution(world, 'machines'), true);
  assert.equal(sim.authorizeExpedition(world), true);
  const convoy = world.robots.filter((robot) => robot.expedition);
  const starting = convoy.map((robot) => ({ id: robot.id, x: robot.x, y: robot.y }));
  for (let index = 0; index < 180; index += 1) sim.stepWorld(world, {}, 1 / 60);
  for (const robot of convoy) {
    const origin = starting.find((entry) => entry.id === robot.id);
    assert.ok(sim.distance(robot, origin) > 45, `${robot.id} should have moved away from the base`);
    assert.ok(sim.distance(robot, sim.NORTH_RUINS_POS) > 400, `${robot.id} should not teleport to the ruins`);
  }
  assert.equal(world.progress.expeditionStage, 'outbound');
});

test('the convoy completes a real outbound and return journey rather than resolving as a timer', () => {
  const world = quietWorld(56);
  world.scrap = 1000;
  world.player.x = world.heartforge.x;
  world.player.y = world.heartforge.y;
  sim.interact(world);
  sim.chooseEvolution(world, 'machines');
  sim.authorizeExpedition(world);
  let sawNorthRuins = false;
  for (let index = 0; index < 6000 && world.progress.expeditionStage !== 'returned'; index += 1) {
    sim.stepWorld(world, {}, 0.05);
    if (world.robots.some((robot) => robot.expedition && sim.distance(robot, sim.NORTH_RUINS_POS) < 150)) {
      sawNorthRuins = true;
    }
  }
  assert.equal(sawNorthRuins, true);
  assert.equal(world.progress.expeditionStage, 'returned');
  assert.equal(world.rareItems.cognitionCore, true);
  assert.ok(world.robots.every((robot) => !robot.expedition));
});

test('save and load preserve exact remote entity positions and decision reasons', () => {
  const world = quietWorld(66);
  world.scrap = 500;
  world.player.x = world.heartforge.x;
  world.player.y = world.heartforge.y;
  sim.interact(world);
  sim.chooseEvolution(world, 'machines');
  sim.authorizeExpedition(world);
  for (let index = 0; index < 120; index += 1) sim.stepWorld(world, {}, 1 / 60);
  const serialized = sim.serializeWorld(world);
  const loaded = sim.deserializeWorld(serialized);
  assert.deepEqual(
    loaded.robots.map(({ id, x, y, state, reason }) => ({ id, x, y, state, reason })),
    world.robots.map(({ id, x, y, state, reason }) => ({ id, x, y, state, reason })),
  );
  assert.equal(loaded.schemaVersion, sim.SCHEMA_VERSION);
});

test('the apex attack is caused by installing the returned core', () => {
  const world = quietWorld(77);
  world.heartforge.restored = true;
  world.progress.evolution = 'machines';
  world.progress.expeditionAuthorized = true;
  world.progress.expeditionStage = 'returned';
  world.rareItems.cognitionCore = true;
  world.player.x = world.heartforge.x;
  world.player.y = world.heartforge.y;
  assert.equal(world.enemies.some((enemy) => enemy.type === 'cathedral_beast'), false);
  const result = sim.interact(world);
  assert.equal(result.kind, 'core_installed');
  assert.equal(world.enemies.filter((enemy) => enemy.type === 'cathedral_beast').length, 1);
  assert.equal(world.progress.apexSpawned, true);
});

test('the ordinary economy exposes Scrap but no parallel stockpiled currencies', () => {
  const world = sim.createWorld(88);
  assert.equal(typeof world.scrap, 'number');
  for (const forbidden of ['fuel', 'energy', 'alloy', 'food', 'ammo', 'credits', 'population']) {
    assert.equal(Object.hasOwn(world, forbidden), false, `${forbidden} must not be a stockpiled resource`);
  }
});
