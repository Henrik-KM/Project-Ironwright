# Implementation status

## Native Godot 3D — complete end-to-end systemic alpha

The default scene is `game/scenes/main_3d.tscn`. It boots `IronwrightCompleteGameWorld3D`, which preserves the aesthetic, opening UX, progression, and outpost layers while adding the full start-to-victory systemic run.

## Connected game implemented

### Opening survival

- high-angle 3D camera with player, map and physical-group follow modes;
- weak automatic Mechromancer pistol;
- indispensable Bulwark companion;
- world-space wreck marker and route guidance;
- timed manual salvage that disables attack and emits ecological noise;
- timed manual early robot fabrication;
- Scrapper, Warden, Pathfinder, Engineer and Bulwark frames;
- finished Mechromancer field-kit silhouette with asymmetrical protection,
  visible communications hardware, boot cuffs and a wrist tool loop;
- three class-wide levels with rare-core gates;
- macro Defend, Salvage and Expedition focus;
- coordinated physical local salvage and North Ruins expedition.

### Heartforge and autonomy progression

- progression phases from Embers through Sovereignty;
- Heartforge tiers I–V;
- data-driven technology prerequisites, costs and effects;
- manual exposed Heartforge evolution;
- autonomous ordinary machine replacement after Forge Assistance;
- broad tier-based machine composition without a maintained production queue;
- optional Rapid March, Deep Operations, Signal Dampening and Distributed Continuity technologies.

### Autonomous outposts

- fixed physical sites discovered through real excursions;
- Resource, Defence, Scout and Repair roles;
- physical Engineer and escort construction groups;
- shared pace, cohesion and regrouping;
- automatic operation and self-repair;
- physical protected resource hauling;
- organic attacks, destruction and automatic escorted rebuilding;
- tier upgrades through another real construction journey;
- persistent discovery, role, tier, health, destruction and stored Scrap.

### Multi-region world

- twelve persistent regions with stable IDs, physical centres, routes and landmarks;
- Heartforge District, North Ruins, West Grid, East Tenements, Municipal Glasshouse, Flood Market, Riverworks, Tram Graveyard, Cathedral Quarter, Observatory Ridge, Buried Laboratories and Root Cistern;
- discovery, ecological pressure and suppression state;
- region-specific physical salvage after discovery;
- authored visual identity for every district kind, including original high-definition Riverworks pump/sluice, Cathedral nave/choir and Observatory survey landmark shells plus the authored Root Cistern organ shell.
- the Tram Graveyard now has an original high-definition carriage and maintenance landmark shell while retaining the existing rail encounter and operation contracts.
- Buried Laboratories now has an original high-definition containment-hall shell while retaining the existing research encounter and operation contracts.
- Municipal Glasshouse now has an original high-definition climate-frame shell while retaining the existing greenhouse encounter and operation contracts.
- North Ruins now has an original high-definition civic archive shell while retaining the existing salvage and expedition contracts.
- East Tenements now has an original high-definition residential block shell while retaining the existing vertical-life encounter contract.
- Flood Market now has an original high-definition canopy-and-water service shell while retaining the existing commercial encounter contract.

### Long-range operations

- reusable operation data and director;
- role-based team selection without individual orders;
- physical outbound travel, exposed work and physical return;
- formation-relative roles, shared pace, cohesion and regrouping;
- escort response to nearby organisms;
- rewards retained locally until the group returns;
- West Grid survey;
- Vital Membrane recovery;
- Cathedral Brood suppression;
- Genome Prism excavation;
- Root Cistern mapping;
- optional Apex lure.
- twelve authored operation records, including the mid-game Riverworks pump restart and Observatory calibration routes.

### Continuous organic ecology

- local noise-driven ecology retained;
- regional ecological capacity and pressure;
- disturbance memory and suppression;
- individual regional spawning rather than wave schedules;
- causal organic migrations from high-pressure districts;
- pressure reduction from important kills and successful suppression;
- Skitterling, Razorhound, Veilstalker, Burrower, Sporecaster, Broodmass and Apex forms;
- final-protocol escalation tied to deliberate player action.

### Endgame and first victory

- unique Vital Membrane, Choral Gland, Genome Prism and Root Map components;
- Severance research and ending;
- Containment research and ending;
- responsive final-protocol interface;
- player-triggered irreversible final crisis;
- sustained Heartforge defence without recurring numbered waves;
- optional Apex lure pressure reduction;
- first-victory end state;
- optional one-use Distributed Continuity recovery.

### Persistence and validation

- one transactional run save with a versioned envelope;
- atomic temporary-file promotion with two rotating backups;
- migration from the original foundation save and full-game extension save;
- unified foundation, progression, outpost, region, operation, ecology, machine-society, endgame, continuity and victory state;
- browser and repository contract tests;
- core native tests;
- aesthetic tests;
- first-session UX tests;
- outpost/progression tests;
- transactional persistence tests including backup recovery and legacy migration;
- accelerated native start-to-victory complete-alpha test.

The complete-game save path now checkpoints active long-range operations with
their stable operation id, route, physical anchor, work clocks and robot names;
loading resumes the group through the same world-space operation director. The
full-game outpost path applies the same contract to build, upgrade, rebuild and
haul convoys, and the local autonomy director now checkpoints distributed
salvage assignments and the North expedition against stable robot and wreck
identities. Manual channels remain finish-before-save.

## Presentation implemented

- readable blue-hour environment and controlled fog;
- warm inhabited Heartforge sanctuary;
- wet streets, lights, windows, signs, clutter, vegetation, embers and smoke;
- procedural character, robot and organic animation;
- combat, interaction, construction and noise feedback;
- responsive forge, evolution, outpost, operation and endgame interfaces;
- physical region landmarks and discovery beacons;
  - bounded transient notifications and clear objective hierarchy.

## Focused tactical framing milestone

- tightened the release opening camera to a 16.8 height and 10.0 distance
  frame so the authored Mechromancer and companion remain legible beside the
  Heartforge without adding a permanent HUD or changing gameplay reach;
- added executable coverage for the tighter actor-scale framing contract.
- removed the oversized anchored portrait from the tactical render while
  retaining the source texture and node contract for non-tactical presentation.

## Focused Mechromancer asset milestone

- replaced the procedural player mannequin with the original
  `mechromancer.player.v1` glTF asset;
- rebuilt the source around a human field-engineer silhouette with a rounded
  hood and brim, visible face forms, split coat tails, offset field pack,
  harness, belt pouches, gloves, tool attachments and readable weak sidearm;
- added original wear textures, normal relief and beveled/tapered forms for
  fabric, leather, oxidized metal and skin;
- corrected rear-facing coat, hood and pack placement for the production
  isometric camera rather than validating only the front portrait;
- added authored Idle, Walk, Fire, Work and Hit presentation clips;
- added socket-based player lighting and muzzle resolution;
- added a baked HUD portrait rendered from the same Blender source model while
  preserving all gameplay interfaces;
- rebuilt the canonical Blender source/export path with smoother cloth panels,
  curved hood and scarf forms, cheek and mouth facial detail, refined boots,
  pack layers and heavier coat tails;
- regenerated the editable `.blend`, separated glTF/bin export, normal-relief
  textures and portrait from that source;
- increased only the authored presentation scale so the Mechromancer reads at
  tactical-camera distance without changing collision or targeting (source
  scale 1.0, runtime visual scale 1.28);
- added executable coverage for the imported animation player and all five
  required presentation clips.

## Focused robot family presentation milestone

- added layered chassis, armour, optic, joint and service-cable details shared
  across the friendly machine family;
- added role-readable salvager, guardian, scout and engineer silhouettes with
  cargo, weapon, sensor and construction-tool details;
- added subtle role-specific presentation motion for salvage drums, pistons,
  tools, scout fins, forge coils and guardian shield ribs;
- added executable aesthetic coverage for each robot archetype's detail sockets.

## Focused Veilstalker presentation milestone

- added the original `veilstalker.predator.v1` high-definition glTF shell and
  manifest, with layered thorax ribs, shell plates, sensory cowl, threat eyes,
  veil membranes, hooks and tendrils;
- flattened the imported shell under `OrganicModel` so the existing release
  material path and late-spawn continuity remain stable;
- added a layered authored family pass with asymmetric thorax, dorsal plates,
  veil membranes, tendon forelimbs, hooks and sensory tendrils;
- added state-driven stalking, membrane sway, tendril motion and attack lunge
  presentation while keeping ecology and combat simulation unchanged;
- increased shared primitive mesh resolution for smoother high-definition
  procedural presentation;
- retained the pre-alpha requirement for human visual acceptance of the family.

## Focused organic family presentation milestone

- added an authored `razorhound.predator.v1` shell and manifest for the common
  early predator, preserving the stable `OrganicModel/Torso/TorsoCore` release
  path;
- added species-specific silhouettes for Skitterling, Razorhound, Burrower,
  Sporecaster, Broodmass and Apex instead of relying on the shared torso/head
  blockout alone;
- added readable feelers, muzzle and tail anatomy, drill tooling, breathing
  spore sacs, mass lobes and apex crown/jaw forms;
- added restrained species-specific motion for pack tails, antennae, sacs,
  jaws, spines and broodmass lobes;
- added executable aesthetic coverage for all twelve current organic families.

## Focused complete-organic-roster shell milestone

- added original high-definition Roofleaper, Glassmoth, Miremaw, Carrion Bell
  and Rootweaver glTF shells with stable anatomy sockets and Idle, Walk and
  Attack clips;
- wired the five remaining tiered families through the same imported-shell
  handoff used by the opening and late authored creatures;
- removed the duplicate release-time procedural geometry for those families so
  the authored shells are the production presentation source while tier
  signals, collision, ecology, reduced-detail simulation and combat remain
  runtime-owned;
- expanded manifest validation and native aesthetic coverage to keep all twelve
  implemented organic families on an authored high-definition contract.

## Focused combat-feel milestone

- organic attacks now enter a species-scaled wind-up before applying damage;
- attack-start signals drive a bounded ground warning, local flash and subtle
  camera response;
- organic jaws, mandibles and bodies visibly anticipate the strike;
- attacks can miss when the target leaves the telegraphed resolution radius;
- executable coverage proves warning-before-damage and post-wind-up resolution.

## Focused survival sound-feedback milestone

- added a spatial audio director with a compact original sound vocabulary for
  pistol fire, machine fire, salvage, fabrication, organic attacks and deaths,
  causal noise pulses and Heartforge damage;
- connected sound events to the existing gameplay signals rather than adding a
  second simulation path or recurring player task;
- generated deterministic WAV streams at runtime so the current alpha has real
  audible feedback without external asset dependencies;
- added executable coverage for all required sound profiles and a live event
  emission.

## Focused remote-detail continuity milestone

- added a shared operation-detail director with active/reduced hysteresis based
  on camera distance;
- long-range, outpost and local autonomy directors retain the same route or
  assignment state while reduced-detail groups skip per-frame actor steering;
- reduced-detail formation and salvage placement remains deterministic and
  returns to active steering when the player approaches;
- added executable coverage for transition thresholds and hysteresis.

## Focused collision-aware movement milestone

- active robots and organic actors detect repeated physical blockage after
  `move_and_slide()` and take a bounded lateral recovery arc;
- recovery preserves the existing macro goal, formation abstraction and
  ecological objective rather than introducing per-unit route orders;
- both actor paths expose a short diagnostic reason and have regression
  coverage against a physical wall and floor.

## Focused organic contact-feedback milestone

- organic attack wind-up, landing and damage remain separate readable events;
- landed strikes now emit a bounded impact burst, local flash and restrained
  camera response at the physical contact point;
- executable vertical-slice coverage verifies the dedicated landing impact is
  attached to the presentation feedback director.

## Focused adaptive Heartforge milestone

- Heartforge progression tiers now rebuild a presentation-only geometry layer
  from structural buttresses through signal conduits, masts and a sovereignty
  crown;
- the tier change is driven by the existing progression signal and does not
  add placement, power-grid or recurring maintenance work;
- aesthetic coverage verifies the tier-5 result and its lower-tier landmarks.

## Focused persistent-region atmosphere milestone

- a presentation-only director resolves the player’s physical position against
  the authored region registry;
- sanctuary, industrial, commercial, nest, research and endgame families now
  carry distinct ambient, fog, grading and glow targets with smooth crossing;
- native coverage verifies the West Grid transition and palette separation
  without changing discovery, pressure, routing or player obligations.

## Focused regional audio identity milestone

- the existing generated spatial audio library now includes a bounded regional
  transition profile;
- region kind shapes the cue’s pitch and the cue is emitted only from the
  existing atmosphere transition signal;
- native coverage verifies the West Grid cue without introducing ambient
  chatter, a new resource, or a player-managed audio setting.

## Focused region landmark presentation LOD milestone

- nearby region landmarks retain their full authored geometry while distant
  landmarks reduce to persistent beacon presentation;
- the LOD director changes only rendering detail and never removes region
  identity, discovery, pressure, position or save state;
- native coverage verifies full detail for the current West Grid region and
  beacon detail for a distant endgame region.

## Focused final-protocol capstone milestone

- added a presentation-only Heartforge lattice for the player-triggered final
  protocols, with bounded staged geometry driven by the existing progress
  signal;
- added a sanctuary crown resolution state and save/load rehydration for
  active or completed protocol presentation;
- added dedicated generated audio cues for protocol start, escalation stages,
  completion and failure;
- complete-game coverage verifies signal wiring, continuous progress coupling,
  completion resolution and the retained systemic victory path.

## Focused Heartforge maintenance-detail milestone

- added a presentation-only maintenance bay around the Heartforge with paired
  pressure vessels, gauge panels, routed feed lines, a cyan coolant manifold
  and a rear service rail;
- added warm vessel and cool-manifold practicals to strengthen the existing
  sanctuary lighting hierarchy without changing gameplay light, collision or
  route state;
- aesthetic coverage verifies the layer is attached to the representative
  Heartforge slice.

## Focused authored-region encounter-dressing milestone

- added a discovery-driven presentation director that attaches one bounded
  human-scale vignette to every non-sanctuary region;
- region identities now gain specific encounter-space props such as archive
  record crates, substation tanks, laundry rails, irrigation beds, market
  awnings, dock bollards, rail signals, brood arches, survey optics, lab
  specimen cases and Root Cistern signal pylons;
- all dressing is parented under persistent landmark presentation geometry, so
  landmark LOD continues to reduce distant visuals while discovery, pressure,
  save state, routing and collision remain unchanged;
- aesthetic and complete-game coverage verify attachment on discovery.

## Focused runtime material-continuity and machine-finish milestone

- kept the release material pass live for meshes created after boot, including
  fabricated robots, spawned organic families, outpost upgrades and discovered
  region dressing;
- added a shared final manufacturing pass to friendly robot frames with inset
  service panels, fasteners, protected cable runs, joint collars and status
  lighting while retaining role-specific cargo, weapon, sensor and tool reads;
- release coverage verifies that late-created robot and organic meshes receive
  their intended high-definition material families.

## Focused friendly-machine role-signature milestone

- added a shared louvered hard-surface kit for believable heat and air paths;
- Warden frames now expose a heat exchanger, ammunition panel and recoil rings;
- Scrapper frames now expose a dedicated salvage intake and paired magnetic
  collection heads;
- Pathfinder frames now expose a sensor pod, dish hub and paired range lenses;
- aesthetic coverage keeps these details attached to the role-specific
  silhouettes without changing collision, autonomy or economy state.

## Focused Veilstalker threat-language milestone

- the authored shell is now wired into `OrganicEnemy3D` without changing
  species stats, collision, ecology or reduced-detail simulation;
- added attack-wind-up motion for the Veilstalker veil membranes, forelimbs,
  sensory cowl, tendrils and counterbalancing tail;
- the family now visibly expands and loads its silhouette before an organic
  attack lands, while reduced-detail simulation and combat state remain
  unchanged;
- the procedural motion remains presentation-only and deterministic per actor.

## Focused authored Cistern Apex milestone

- added an original high-definition glTF shell for the late-world Apex, with
  layered torso segments, crowned sensory head, articulated jaws, flank roots,
  threat eyes and restrained membrane fins;
- wired the shell into `OrganicEnemy3D` without changing Apex stats, collision,
  ecology, operations, persistence or reduced-detail simulation;
- retained stable anatomy and production-asset markers for import validation,
  save-safe runtime material treatment and later animation refinement;
- live opening-route review confirmed the mesh reads at tactical distance and
  remains compatible with the existing organic impact feedback.

## Focused authored Sporecaster milestone

- added an original high-definition glTF shell for the ranged infestation
  family, with layered torso segments, a seven-blade gill fan, five suspended
  spore sacs, stalks and paired sensory oculi;
- wired the shell into `OrganicEnemy3D` without changing Sporecaster targeting,
  impairment, noise, ecology, operations or attack timing;
- retained stable sac, stem, gill and oculus names for import validation and
  future state-driven motion refinement;
- live opening-route review confirmed the silhouette reads beside the player
  and companion without adding a recurring task or new simulation state.

## Focused authored Broodmass milestone

- added an original high-definition glTF shell for the large nest organism,
  with layered torso plates, paired brood lobes, a forward maw, crown spines,
  hooked legs and side membrane fins;
- wired the shell into `OrganicEnemy3D` without changing Broodmass health,
  movement, attacks, nest pressure, ecology or reduced-detail simulation;
- retained stable lobe, maw, spine and fin names for import validation and
  future state-driven motion refinement;
- live opening-route review confirmed the broad encounter-space silhouette
  reads without adding a new objective or recurring management task.

## Focused authored Burrower milestone

- added an original high-definition glTF shell for the territorial drill
  family, with layered torso plates, concentric drill rings, a bore tip,
  red bore lamps, jaw hooks and side fins;
- wired the shell into `OrganicEnemy3D` without changing Burrower patrol,
  collision, attack timing, terrain contact or ecology;
- retained stable drill, tip, ring and lamp names for import validation and
  future state-driven motion refinement;
- live opening-route review confirmed the drilling silhouette remains readable
  without adding a new objective or recurring management task.

## Focused authored Skitterling milestone

- added an original high-definition glTF shell for the common scavenger, with
  layered carapace ridges, paired antennae, mandibles, sensory fins and
  articulated legs;
- wired the shell into `OrganicEnemy3D` without changing noise attraction,
  feeding, fleeing, attack timing or ecology;
- retained stable carapace, antenna, mandible and sensory-fan names for import
  validation and future state-driven motion refinement;
- live opening-route review confirmed the common silhouette reads at gameplay
  scale without adding a new objective or recurring management task.

## Focused authored Root Cistern milestone

- added an original high-definition glTF landmark shell for the late Root
  Cistern, with a layered root core, crown ribs, signal pylons and tethered
  pulse cables;
- replaced only the endgame landmark's shared procedural centerpiece while
  preserving region discovery, presentation LOD, pressure, endgame protocols
  and persistence ownership;
- retained stable core, layer, rib, pylon, signal, cable and production-marker
  names for import validation and future late-world animation refinement;
- complete-world aesthetic coverage confirms the authored shell attaches to the
  persistent Root Cistern landmark without adding collision or player work.

## Focused autonomous-labor staging milestone

- added a bounded presentation signature for an autonomous Scrapper actively
  dismantling a wreck: one amber target ring, work core and short machine-to-
  wreck link;
- derives the signature from the existing `salvage_target` and `salvaging`
  state, removes it when work ends, and keeps all autonomy, cargo, noise and
  persistence rules unchanged;
- added runtime aesthetic coverage proving one active labor signature is
  created without an unbounded effect list or new player-managed queue;
- live release-opening review confirmed the work actor and wreck remain
  readable inside the normal tactical frame.

## Focused channel-and-tracer feedback milestone

- weapon fire now leaves a short-lived directional tracer between the firing
  socket and physical target before the existing impact burst;
- manual salvage and fabrication channels now show a restrained three-ring
  field and vertical core that follows the player while the existing spark
  cadence remains bounded;
- cancellation fades the field without changing channel lockout, save or
  simulation state, and vertical-slice coverage verifies both feedback forms.

## Focused authored-region surface-finish milestone

- added a bounded surface-finish layer to every non-sanctuary landmark, keeping
  district identity under the persistent presentation geometry and its existing
  distance LOD;
- ruin bodies now carry layered service spines with louvered panels, inset
  plates, cable runs and scar rails instead of exposing only broad shell masses;
- archive, industrial, tenement, greenhouse, commercial, waterfront, rail,
  nest, observatory, research and endgame landmarks each gain a distinct
  facade, growth, signal or utility signature;
- every non-sanctuary region now receives a bounded presentation-only ground
  apron, inset and illuminated perimeter markers so the district reads as a
  place when reached physically instead of a floating landmark in empty space;
- live West Grid review confirmed the industrial apron and service vignette
  remain readable beside the player and companion, while live Root Cistern
  review confirmed the late authored shell remains legible inside the darker
  organic palette, without adding collision, objectives or management work.

## Focused Heartforge service-surface readability milestone

- replaced the broad emissive assembly plate with a recessed high-definition
  service surface and three dark access slots;
- reduced the cyan service-material bloom so the plate reads as powered
  hardware without flattening into a white screen in the tactical frame;
- live opening-run review confirmed the Heartforge, Mechromancer and Bulwark
  retain their visual hierarchy while the forge interaction surface remains
  legible;
- the broader opening composition remains pre-alpha and still requires the
  final lighting/material pass plus explicit human acceptance.

## Focused opening threshold-composition milestone

- added a presentation-only foreground refuge threshold with broken service
  slabs, wet seams, route-edge markers and low practical lights;
- the threshold gives the tactical camera a grounded lower frame and a clear
  sense of movement out from the warm Heartforge without changing collision,
  navigation, objectives or player-managed structure;
- live opening review confirmed the player can move across the threshold while
  the forge, companion and objective remain readable.

## Focused autonomous-construction staging milestone

- active build, upgrade and automatic-rebuild operations now expose one
  bounded elevated work frame above the real outpost site;
- the frame uses a rotating target ring, central work core, four construction
  pylons and links to the physically present operation members;
- the signature is presentation-only, clears outside the working state, and
  does not add a queue, worker assignment or player maintenance surface;
- live review at the North Transit Yard confirmed the construction frame reads
  above the existing site marker while the machine escort remains visible.

## Focused autonomous-construction audio milestone

- `outpost_construction` noise now reaches the spatial audio director instead
  of being silently omitted;
- the cue reuses the bounded noise-pulse vocabulary with a lower mechanical
  pitch so construction is distinct from manual salvage and forge work;
- live construction-site review confirmed the cue path alongside the elevated
  work frame, with runtime coverage asserting the spatial event.

## Focused organic-attack telegraph milestone

- attack warnings now use a brighter emissive target disc and ring with four
  short perimeter pylons, so the wind-up remains readable in the busy
  Heartforge frame;
- the warning remains transient and bounded to the existing organic wind-up,
  while the impact burst and spatial audio caption continue to resolve on
  contact;
- live opening combat review confirmed the revised warning/impact language,
  with aesthetic runtime coverage asserting the ring attachment.

## Focused opening-plaza material milestone

- the Heartforge plaza now uses a restrained dark wet-concrete variant across
  a bounded subset of broken pavers;
- the alternating value break strengthens rain-slick ground depth without
  changing collision, route readability or the warm refuge lighting hierarchy;
- live opening review confirmed the paver variation remains subordinate to the
  forge, Mechromancer and Bulwark silhouettes.

## Focused regional practical-lighting milestone

- every non-sanctuary landmark now receives two bounded local practicals using
  the authored region palette, so district geometry remains readable outside
  the Heartforge lighting envelope;
- practical energy follows the existing landmark presentation LOD and reduces
  at distance, while the 24m local falloff keeps moving actors readable across
  a district apron without changing discovery, routing, ecology or save state;
- live East Tenements review confirmed the residential walkways, hanging cloth,
  facade details and actor silhouettes remain readable in the remote blue-hour
  frame;
- native aesthetic coverage verifies both practical sockets on every
  non-sanctuary region.

## Focused hostile-nest composition milestone

- tightened the Cathedral Quarter nest shell into a side-weighted ruin mass so
  the brood core, membrane fan and surrounding organic spires carry the frame;
- the close-range opaque shell now yields to the organic read inside the
  existing tactical approach envelope, preventing presentation-only geometry
  from intersecting the camera while leaving the persistent landmark intact;
- live Cathedral Quarter movement review confirmed the nest remains readable
  before and during approach without changing collision, ecology, objective
  state or player-managed work;
- native aesthetic coverage verifies the isolated close-range shell contract.

## Focused Flood Market authored-space milestone

- added three bounded market stall canopies with hanging signs, cable details
  and a warmer/cooler commercial palette around the existing tables;
- added two shallow presentation-only flood channels with illuminated waterline
  breaks so the drowned market identity survives beyond the central landmark;
- retained the existing collision, salvage, ecology, routing and persistence
  ownership while extending only the authored remote-region presentation;
- native aesthetic coverage verifies the market canopy and water-channel
  signatures.

## Focused Riverworks authored-space milestone

- added a bounded sluice assembly with a darkened retaining wall, cap rail and
  control panel so the waterfront landmark reads as infrastructure rather than
  a generic ruin block;
- added a shallow water channel, dock pylons, waterline breaks and restrained
  organic bank growth around the existing pump housings;
- added the original high-definition `riverworks.landmark.v1` glTF shell with
  named pump, rotor, valve, sluice-gate, signal and growth details, plus
  deterministic presentation motion for the powered infrastructure;
- retained the existing collision, routing, ecology, discovery and persistence
  ownership while extending only the authored remote-region presentation;
- native aesthetic coverage verifies the authored asset manifest, named sockets,
  sluice, waterline and channel signatures, and the live release review
  accepted the resulting frame.

## Focused Cathedral Quarter authored-space milestone

- added the original high-definition `cathedral.quarter.v1` shell with a
  weathered nave, tower bell, rose window, choir core, signal and organic vein
  sockets so the nest reads as a damaged civic place overtaken by biology;
- retained the existing nest occlusion, ecology, pressure, discovery and
  operation ownership while keeping the new geometry presentation-only;
- native aesthetic and release coverage verifies the named cathedral sockets
  and deterministic choir/bell motion; live release review accepted the
  readable approach frame, with broader angles still part of pre-alpha review.

## Focused Observatory Ridge authored-space milestone

- added the original high-definition `observatory.ridge.v1` shell with an
  open survey dish, feed signal, mast, control cabin and service cables so the
  ridge reads as a functioning observatory rather than a solid dome;
- retained the existing optics-station encounter dressing, route, ecology,
  discovery and operation ownership while keeping the new geometry
  presentation-only;
- native aesthetic and release coverage verifies the named dish/feed sockets
  and deterministic survey motion; live district review remains required for
  this new slice.

## Focused Tram Graveyard authored-space milestone

- added the original high-definition `tram.graveyard.v1` shell with damaged
  carriages, readable windows and door hardware, rails and sleepers,
  maintenance pit, overhead service frame, signal mast and restrained organic
  seepage;
- retained the existing rail encounter dressing, salvage, route, ecology,
  discovery and operation ownership; the new geometry is presentation-only;
- native aesthetic and release coverage verifies the named sockets and
  deterministic signal/seepage motion; live district review remains required.

## Focused Buried Laboratories authored-space milestone

- added the original high-definition `buried.labs.v1` shell with a
  containment hall, three specimen vessels, luminous cores, transfer rail,
  sealed door, warning panel, service cables and restrained organic
  contamination;
- retained the existing research encounter dressing, salvage, route, ecology,
  discovery and operation ownership; the new geometry is presentation-only;
- native aesthetic and release coverage verifies the named sockets and
  deterministic containment-light/contamination motion; live district review
  remains required.

## Focused Municipal Glasshouse authored-space milestone

- added the original high-definition `glasshouse.municipal.v1` shell with a
  climate frame, cold-glass panels, growth beds, luminous canopy, climate
  louver, service door and broken skylight;
- retained the existing greenhouse encounter dressing, salvage, route,
  ecology, discovery and operation ownership; the new geometry is
  presentation-only;
- native aesthetic and release coverage verifies the named sockets and
  deterministic canopy/growth motion; live district review remains required.

## Focused North Ruins authored-space milestone

- added the original high-definition `archive.north_ruins.v1` shell with a
  civic facade, sealed vault door, archive stacks, surviving roof beacon,
  cold-glass windows and restrained organic creep;
- retained the existing North Ruins encounter dressing, salvage, expedition,
  discovery and operation ownership; the new geometry is presentation-only;
- native aesthetic and release coverage verifies the named sockets and
  deterministic beacon/creep motion; live district review remains required.

## Focused East Tenements authored-space milestone

- added the original high-definition `tenement.east_blocks.v1` shell with
  residential blocks, windows, balconies, fire escape, roof water tank,
  hanging cloth and restrained organic creep;
- retained the existing tenement encounter dressing, salvage, route, ecology,
  discovery and operation ownership; the new geometry is presentation-only;
- native aesthetic and release coverage verifies the named sockets and
  deterministic organic-creep motion; live district review remains required.

## Focused Flood Market authored-space milestone

- added the original high-definition `flood.market.v1` shell with continuous
  market canopies, stalls, flood channels, illuminated waterline signals,
  service crane, hanging hardware and restrained organic growth;
- retained the existing Flood Market encounter dressing, salvage, route,
  ecology, discovery and operation ownership; the new geometry is
  presentation-only;
- native aesthetic and release coverage verifies the named sockets and
  deterministic waterline/growth motion; live district review remains
  required.

## Focused remote-ground continuity milestone

- added persistent non-visual ground collision sized from every remote
  region’s authored radius, extending physical traversal beyond the original
  city-floor extent without turning presentation meshes into hidden gameplay
  blockers;
- live Riverworks traversal now keeps the Mechromancer grounded, visible and
  camera-followed after a lateral input at the remote landmark;
- native presentation coverage verifies remote floor ownership and prevents a
  regression to falling through the long-world surface.

## Focused contextual tactical-HUD milestone

- the permanent control legend now clears after the onboarding window instead
  of occupying the tactical frame indefinitely;
- the healthy sanctuary badge now fades after the opening read and returns only
  for a damaged or critical Heartforge state;
- direct interaction prompts and the command-map banner remain explicit, while
  objective, reserve, health and operation information remain available;
- the release shell was live-reviewed through opening, settled tactical and map
  states, and aesthetic coverage verifies the hide-and-reappear exception path.

## Focused progression-aware machine-finish milestone

- level 2 frames now gain raised shoulder rails, signal strips and a dorsal
  service panel, making learned machine capability visible in the silhouette;
- level 3 frames add a material-matched crown ring, mast and status beacons for
  a grounded-to-futuristic progression read;
- the assemblies are rebuilt from the existing stable frame level and remain
  presentation-only, with no new per-unit controls, jobs or maintenance work;
- a live Heartforge review confirmed evolved Guardian, Scrapper and Pathfinder
  frames remain readable around the tactical camera while the full aesthetic
  and native matrix passes stay green.

## Focused Bulwark protection-finish milestone

- replaced the opening companion's procedural base silhouette with the original
  high-definition `bulwark.companion.v1` glTF shell, preserving stable sensor,
  weapon-muzzle and protection-emitter presentation sockets;
- recorded the runtime/source/animation contract in
  `game/data/bulwark_asset_manifest.json` and
  `game/assets/bulwark/source/README.md`;
- added a restrained cyan shield arc, protected emitter spine and side guard
  panels to the opening Bulwark silhouette;
- kept the finish presentation-only: existing personal-interception behavior,
  collision, save state and autonomy workload are unchanged;
- added native aesthetic coverage for the authored shell and Bulwark protection
  signature;
- a live release-opening review confirmed the companion remains readable beside
  the Mechromancer inside the warm Heartforge composition.

## Focused Warden authored-shell milestone

- replaced the guardian's procedural base silhouette with the original
  high-definition `warden.guardian.v1` glTF shell, preserving stable sensor,
  weapon-muzzle and recoil presentation sockets;
- added broad escort armour, a protected autocannon breech, counterweight,
  heat-exchanger louvers, sensor mast and warm/cyan status hardware;
- recorded the runtime/source/animation contract in
  `game/data/warden_asset_manifest.json` and
  `game/assets/warden/source/README.md`;
- kept the finish presentation-only: guardian collision, attack, formation,
  autonomy workload, progression gates and save state are unchanged;
- added native aesthetic coverage for the authored shell and guardian role
  silhouette.

## Focused Scrapper authored-shell milestone

- replaced the salvager's procedural base silhouette with the original
  high-definition `scrapper.salvager.v1` glTF shell, preserving stable sensor,
  salvage-tool, cargo and drum presentation sockets;
- added deep cargo, paired dismantler arms, magnetic claws, intake hardware,
  salvage drum and protected service surfaces;
- recorded the runtime/source/animation contract in
  `game/data/scrapper_asset_manifest.json` and
  `game/assets/scrapper/source/README.md`;
- kept the finish presentation-only: Scrap extraction, target selection,
  movement, formation behavior, autonomy workload and save state are unchanged;
- added native aesthetic coverage for the authored shell and salvage role
  silhouette.

## Focused Pathfinder authored-shell milestone

- replaced the scout's procedural base silhouette with the original
  high-definition `pathfinder.scout.v1` glTF shell, preserving stable sensor,
  survey-mast, scout-optic and beacon presentation sockets;
- added asymmetric fins, paired optics, a protected sensor pod, tall survey mast,
  dish, hub and beacon ring;
- recorded the runtime/source/animation contract in
  `game/data/pathfinder_asset_manifest.json` and
  `game/assets/pathfinder/source/README.md`;
- kept the finish presentation-only: route selection, physical travel,
  formation screening, reduced-detail simulation and save state are unchanged;
- added native aesthetic coverage for the authored shell and scout role
  silhouette.

## Focused Engineer authored-shell milestone

- replaced the constructor's procedural base silhouette with the original
  high-definition `engineer.constructor.v1` glTF shell, preserving stable
  sensor, construction-tool, material-cradle and forge-coil presentation
  sockets;
- added the material cradle, piston joints, welder and assembly arms, tool
  heads, forge coil and warm construction status hardware;
- recorded the runtime/source/animation contract in
  `game/data/engineer_asset_manifest.json` and
  `game/assets/engineer/source/README.md`;
- kept the finish presentation-only: construction authorization, physical
  travel, assembly behavior, collision and save state are unchanged;
- added native aesthetic coverage for the authored shell and constructor role
  silhouette.

## Focused Buried Laboratories authored-vignette milestone

- added a bounded containment-vessel bank with specimen consoles, protected
  signal cores and capped vessels to give Buried Laboratories a readable
  research identity at the normal tactical camera distance;
- added an overhead transfer rail with three physical drop arms and a restrained
  violet/cyan instrumentation palette;
- kept the vignette presentation-only: region discovery, salvage, ecology,
  collision, operations and persistence are unchanged;
- added native aesthetic coverage for the containment vessels and transfer rail.

## Focused population-driven enemy escalation milestone

- pulled the latest population-driven ecology PR into the integration branch and
  preserved its tier director, physical nest sources, capped replenishment,
  tier-aware enemy intelligence, command-map report and persistent save fields;
- kept lower-tier population headroom distinct from long-term nest suppression,
  with no recurring wave timer or new player resource;
- preserved explicit patrol, brood-protection and scouting directives when
  tiered enemies are configured before entering the scene tree;
- fixed presentation teardown handling for freed model nodes and extended the
  repository/aesthetic validators to recognize the tiered entrypoint while still
  requiring the release presentation chain;
- live tiered opening review reached the title screen and opening tactical frame;
  broader balance and long-run ecological review remain part of pre-alpha work.

## Focused remaining-organic-family presentation milestone

- added a high-definition procedural presentation pass for Roofleaper,
  Glassmoth, Miremaw, Carrion Bell and Rootweaver, including layered shells,
  membranes, wing structures, signal anatomy, crowns and radial tendrils;
- kept the new anatomy inside the existing stable OrganicModel contract so
  release material continuity, animation attachment and tier intelligence do
  not need separate runtime paths;
- expanded the aesthetic scenario coverage from the original seven sampled
  families to all twelve mapped organic species;
- live presentation-gallery review confirmed the five previously thin families
  now have distinct, readable silhouettes at gameplay scale.

## Focused autonomous-outpost presentation milestone

- upgraded the existing four autonomous outpost roles with high-definition
  hard-surface treatment, including beveled shelters, service panels, vents,
  role-specific machinery and readable tier frames;
- retained one bounded `OutpostRoleSignature` assembly per outpost so role
  identity is visible without introducing worker, queue, inventory or power
  management;
- preserved the existing outpost save, repair, combat, haul and rebuild
  contracts while adding aesthetic coverage for Resource, Defence, Scout and
  Repair role silhouettes at tier 3;
- live presentation review remains required for the next authored encounter
  space/content pass; this milestone does not claim final retail art.

## Focused East-Tenements encounter-space milestone

- added a bounded vertical residential vignette with a recessed facade shell,
  readable window bays, service louvers, fire-escape landings and a climbable-
  looking but presentation-only ladder silhouette;
- added rooftop water-service hardware, cyan utility routing, one warm occupied
  window and an organic breach marker so the district communicates habitation,
  infrastructure and ecological intrusion in one frame;
- retained the existing collision, navigation, route, operation and region
  pressure contracts; the new detail is owned by the discovery-driven encounter
  dressing layer and adds no player-managed task;
- aesthetic coverage now verifies the tenement vertical-life, fire-escape and
  rooftop-service signatures after region discovery.

## Focused Heartforge core-cladding milestone

- added a layered eight-segment armored core cladding, raised caps and side
  signal rails so the indispensable machine reads as an engineered civic
  furnace rather than a bare stack of cylinders;
- added a front powered service louver and inspection port with restrained
  cyan emission, preserving the warm furnace/cool infrastructure hierarchy;
- retained the Heartforge collision, interaction radius, progression geometry,
  health and save contracts; this is presentation-only model detail;
- aesthetic coverage now verifies the stable core-cladding and service-surface
  signatures in the opening Heartforge model.

## Focused North-Ruins archive encounter-space milestone

- added an authored civic archive facade with a recessed vault door, varied
  record-room windows, climate grille, service rail and surviving roof beacon;
- added one warm occupied archive room and one cool powered reader so the first
  expedition destination communicates preserved human infrastructure under
  organic intrusion rather than reading as generic crates and a plinth;
- retained the archive’s discovery, route, salvage, operation and pressure
  contracts; all new geometry remains presentation-only;
- aesthetic coverage now verifies the archive facade, vault entrance and roof
  beacon signatures after discovery.

## Focused Municipal-Glasshouse encounter-space milestone

- added a high-definition light canopy with broken skylight, varied luminous
  panes, roof tank, climate louver and suspended irrigation lines;
- added restrained warm/cyan lighting and facade growth so the district reads
  as a failed botanical facility where infrastructure and membrane life compete
  for light;
- retained the greenhouse’s discovery, traversal, ecology and operation
  contracts; all new geometry remains presentation-only;
- aesthetic coverage now verifies the canopy, climate hardware and broken
  skylight signatures after discovery.

## Focused Tram-Graveyard encounter-space milestone

- added an authored maintenance bay with a readable carriage shell, windows,
  service door, infestation, overhead hoist and inspection pit;
- added restrained cyan work lighting and warm pit lighting so the district
  communicates abandoned municipal maintenance rather than only parallel rails;
- retained the tram region’s discovery, physical route, rare-stock, ecology and
  operation contracts; the new geometry remains presentation-only;
- aesthetic coverage now verifies the maintenance bay, carriage door and pit
  signatures after discovery.

## Focused Observatory-Ridge encounter-space milestone

- added an authored survey station with control cabin, varied observation
  windows, access reader, service rail, relay mast and a readable lens barrel;
- added warm/cool survey lighting and a star-map console so the late region
  communicates deliberate town-scale observation rather than a single dish;
- retained the observatory’s discovery, mapping, ecology and operation
  contracts; all new geometry remains presentation-only;
- aesthetic coverage now verifies the optics station, survey lens and console
  signatures after discovery.

## Browser reference retained

The dependency-free browser implementation remains under `web/` for deterministic simulation regression. Godot is the production runtime.

## Focused authored-shell material continuity milestone

- extended the release material director to recognize the stable node-family
  identifiers of the authored Bulwark, Warden, Scrapper, Pathfinder, Engineer,
  Veilstalker, Razorhound, Sporecaster, Broodmass, Burrower, Skitterling and
  Apex glTF shells;
- applied the existing brushed-metal, chitin and membrane triplanar families
  to those imported meshes without replacing their authored geometry or
  altering collision and gameplay state;
- added release-runtime coverage for the opening Bulwark and a late-spawned
  Veilstalker shell so future material changes cannot silently leave production
  models on flat imported defaults.

The current high-definition shell library remains a production-facing pass;
final retail art, animation and external visual approval are still required.

## Commercial work still remaining

Version 1.0.0-rc.1 is game-complete in systemic structure and has a
commercial-release candidate shell, but it is not an unqualified final retail
release.

Remaining production work includes:

- authored production models, rigs, animations, VFX and encounter-space art
  beyond the current procedural/high-definition presentation library;
- substantially more environmental detail and authored encounter spaces;
- profiling and tuning of active/reduced-detail simulation at much larger world
  and entity scale;
- deeper navigation, baked-region pathing and route recovery under long-run
  disruption;
- broader content variants, technologies, operations and site dressing;
- performance profiling and optimization on agreed target hardware;
- environmental narrative and run variation;
- 30–100-hour balance and repeated full internal runs;
- professional localization review of all remaining gameplay prose;
- external alpha, beta, packaging, store assets, signing and release QA.

The roadmap now refines and expands an actual complete game loop rather than extrapolating from a disconnected prototype.
