# CODEBASE.md — 3d-stealth

Token-preserving reference. Update when files change.

## Project Layout
```
.
├── CODEBASE.md              # This file
├── design_principles.md     # Design doc (51 lines)
├── project.godot            # Godot 4.6, Forward Plus, Jolt Physics
├── icon.svg
 ├── Scripts/
│   ├── AI/
│   │   ├── enemy_controller.gd        # 1152 lines: enemy AI state machine
│   │   └── TakedownIndicator.gd       # 174 lines: billboard panels above enemy
│   ├── Player/
│   │   ├── player_controller.gd       # 547 lines: player movement, step-up climb, ladder interact, M-key mission debug toggle
│   │   ├── PlayerTakedownController.gd # 344 lines: takedown + drag + door/ladder E-interact
│   │   └── PlayerData.gd              # 35 lines: autoload stub (money, story_flags)
│   ├── Interactables/
│   │   ├── Interactable.gd            # 74 lines: base interactable class (E/Q groups, range, prompt labels)
│   │   ├── InteractableIndicator.gd   # 131 lines: billboard with yellow/brown panels, hold-progress fill
│   │   └── Door.gd                    # 304 lines: swing open/close, break-apart physics (Jolt), E/Q interaction
│   ├── Props/
│   │   └── Ladder.gd                  # 195 lines: procedural ladder generation, E-interact climb system
│   ├── Navigation/ground_nav.gd       # 44 lines: runtime navmesh baking
│   ├── Camera/camera_follow.gd        # 21 lines: ortho camera follow
│   ├── Skills/
│   │   ├── SkillSaveData.gd           # 22 lines: serializable resource
│   │   └── SkillManager.gd            # 143 lines: autoload skill system
│   ├── Missions/
│   │   ├── mission_data.gd            # 18 lines: MissionData Resource
│   │   ├── objective_data.gd          # 8 lines: ObjectiveData Resource
│   │   ├── mission_progress.gd        # 5 lines: MissionProgress save Resource
│   │   ├── mission_manager.gd         # 146 lines: autoload mission system
│   │   ├── mission_runtime.gd         # 141 lines: per-mission dynamic objectives
│   │   └── mission_hud.gd             # 115 lines: right-side objective HUD
│   └── UI/
│       ├── PlayerHUD.gd               # 129 lines: HUD with stance icon, stamina bar, health bar
│       ├── SkillDebugUI.gd            # 277 lines: L-key debug panel (skills)
│       ├── MissionDebugUI.gd          # 822 lines: M-key debug panel (missions + objectives)
│       └── (editor theme files)
├── Scenes/
│   └── MissionHUD.tscn                # 9 lines: right-side objective panel scene
├── Prefabs/
│   ├── Enemy/enemy.tscn               # Enemy scene (72 lines)
│   ├── Player/player.tscn             # Player scene (24 lines)
│   └── Prop/
│       ├── Door.tscn                  # Door prefab with editor placeholder mesh
│       ├── Ladder.tscn                # Procedural ladder with E-interact
│       ├── Stairs.tscn                # Stairs with ConvexPolygonShape3D ramp collision
│       ├── Catwalk.tscn               # Catwalk walkway
│       ├── Crate.tscn                 # Crate box
│       ├── Table.tscn                 # Table prop
│       └── Vent.tscn                  # Vent prop
└── test_world.tscn                    # Test scene (196 lines)
```

## Scene Tree (test_world.tscn)
```
TestWorld (Node3D)
├── DirectionalLight3D
├── CameraPivot (camera_follow.gd)
│   └── Camera3D (ortho, size 12)
├── Ground (StaticBody3D, 20×1×20, y=-0.5)
├── WallL / WallR / WallTop (StaticBody3D)
├── Platform (StaticBody3D, 4×0.5×4, y=1.5)
├── Ramp (StaticBody3D, rotated, y=0.75)
├── Stairs (Stairs.tscn instance, (-3, 0, -2.61), rotated 180°)
├── Door (Door.tscn instance, (2, 0, -3.29))
├── Ladder (Ladder.tscn instance, (3.42, 0, 2.51))
├── Crate (Crate.tscn instance, (-3, 0, 0.5))
├── NavigationRegion3D (ground_nav.gd)
├── Enemy (enemy.tscn instance, (-5, 0.9, 2), debug=true)
└── Player (player.tscn instance, (0, 0.9, 0))
```

## Autoloads

### SkillManager (res://Scripts/Skills/SkillManager.gd)
**Role**: Global singleton managing 5 skills (stealth, hacking, subdue, awareness, gadgets).

**Signals**: `xp_changed`, `skill_upgraded`, `neural_stimulators_changed`

**Skill config** (code constants):
| Skill | Start Lv | Base XP cost | Requires stimulator? | Max Lv |
|-------|----------|-------------|---------------------|--------|
| stealth | 1 | 100 | No | 5 |
| hacking | 1 | 100 | No | 5 |
| subdue | 0 | 150 | Yes | 5 |
| awareness | 0 | 150 | Yes | 5 |
| gadgets | 0 | 200 | Yes | 5 |

**Cost scaling**: `base_cost × (current_level + 1)`.

**Persistence**: Saves to `user://SkillSaveData.tres` via `ResourceSaver.save()`.

**Key methods**: `add_xp()`, `upgrade_skill()`, `unlock_skill_tree()`, `reset_to_defaults()`, `get_next_level_xp_cost()`, `add_neural_stimulators()`.

**Note**: Uses `const SaveDataClass = preload(...)` (not `class_name`) to avoid SHADOWED_GLOBAL_IDENTIFIER warning.

### SkillSaveData (res://Scripts/Skills/SkillSaveData.gd)
`class_name SkillSaveData extends Resource`. Serializable via `@export`: `skill_levels`, `skill_unlocked`, `total_xp`, `neural_stimulators`.

### SkillDebugUI (res://Scripts/UI/SkillDebugUI.gd)
**Role**: Debug panel toggled with L key. Built programmatically (no .tscn). Close via X, L, or Escape.

### PlayerData (res://Scripts/Player/PlayerData.gd)
**Role**: Global singleton storing player currency and story flags.

**Fields**: `money: int`, `story_flags: Dictionary`

**Signals**: `money_changed`, `story_flag_set`

**Methods**: `add_money()`, `spend_money()`, `set_story_flag()`, `get_story_flag()`, `has_story_flag()`.

### MissionManager (res://Scripts/Missions/mission_manager.gd)
**Role**: Global singleton managing mission data, selection, completion, scene transitions, and persistence.

**Signals**: `mission_selected(id)`, `mission_completed(id, outcome)`, `mission_unlocked(id)`, `mission_availability_changed`

**Key fields**: `missions: Dictionary`, `current_mission_id: String`

**Methods**:
- `register_mission(data)` — registers a MissionData, restores progress from save
- `get_available_missions()` — returns Array[MissionData] of incomplete, available missions
- `select_mission(id)` / `get_mission(id)`
- `complete_mission(id, outcome)` — marks complete, applies rewards (money→PlayerData, xp/stim→SkillManager, story_flags→PlayerData), handles mutual exclusion
- `unlock_mission(id)` — persists to save
- `start_mission(id)` — selects + calls `change_scene_to_file(scene_path)`
- `is_mission_unlocked/completed(id)`

**Persistence**: `user://mission_progress.tres` (MissionProgress Resource with `completed_mission_ids` + `unlocked_mission_ids` arrays).

## Key Scripts

### enemy_controller.gd
**Role**: Enemy AI state machine — patrol → search → pursuit, vision cone + sound detection.

**States** (enum State: PATROL, SEARCH, PURSUIT, REVIVE, ALARM, GET_HELP, KNOCKED_OUT, DEAD):

| State | Enter | Process | Transition to |
|-------|-------|---------|---------------|
| PATROL | `_enter_patrol` | `_process_patrol` | SEARCH on first detection frame |
| SEARCH | `_enter_search` | `_process_search` | PURSUIT at 100% detection, PATROL after 10s no detection |
| PURSUIT | `_enter_pursuit` | `_process_pursuit` | SEARCH if detection ≤ 50% and player lost |
| REVIVE | `_enter_revive` | `_process_revive` | SEARCH on completion |
| ALARM | `_enter_alarm` | `_process_alarm` | SEARCH after alarm duration |
| GET_HELP | `_enter_get_help` | `_process_get_help` | PATROL after reaching one random patrol point |
| KNOCKED_OUT | `knock_out()` | `_process_knocked_out` | REVIVE (if ally revives) |
| DEAD | `kill()` | (none — early return) | — |

**Priority system** (`_evaluate_priority`, every 0.5s): Evaluates higher-priority transitions (PURSUIT > REVIVE > ALARM > SEARCH). GET_HELP and PATROL handled outside priority check.

**Takedown interface**:
- `is_eligible_for_takedown()` — true for PATROL, SEARCH
- `is_draggable()` — true for KNOCKED_OUT, DEAD
- `is_conscious()` — not KO'd or dead
- `can_be_revived()` — KO'd, not already being revived, not dead
- `kill()` — sets DEAD, calls `_lay_down()`
- `knock_out()` — sets KNOCKED_OUT, calls `_lay_down()`
- `_lay_down()` — hides detection bar + vision cone, disables vision area collision, tweens rotation to 90° X (lie flat)

**Detection flow** (`_update_detection`):
1. `_check_vision()` — angular FOV (80° H, 50° V half-angles) + distance + raycast LOS
2. `_check_hearing()` — distance + player noise level
3. Meter fills (vision > hearing > decay), triggers `_handle_state_transitions()`

**Rate**: `sight_detection_rate × (2.0 − dist/range×1.5) × move_factor × crouch_factor × delta`
- `sight_detection_rate = 8.0` (was 50 — reduced so player has time to close for takedown)
- 2.0× rate at 0m, 0.5× at max range (10m)
- Crouch reduces 20% (`crouch_factor = 0.8`)
- Moving increases 50% (`movement_multiplier = 1.5`)

**Vision cone**: Tessellated spherical wedge (20h×10v), MeshInstance3D child. Colors: green (idle), yellow→orange (player visible), red (PURSUIT). Rebuilt on `vision_range` change via setter.

**Detection bar**: Two BoxMesh MeshInstance3D children at y=1.2. Camera-facing via `look_at()` in `_update_detection_bar()`. Hidden when meter ≤ 0. Color: green < 30%, yellow < 60%, red ≥ 60%.

**Movement**: Navmesh path exclusively (`NavigationAgent3D`). Guards `get_next_path_position()` returning `Vector3.ZERO`. No manual raycast avoidance.

**Known issue**: Groups from `.tscn` instances NOT propagated — `add_to_group("enemy")` called in `_ready()`.

### player_controller.gd
**Role**: Player movement (WASD), sprint toggle (Shift), crouch (C), jump (Space), invisibility toggle (G), L key for skill debug, step-up auto-climb (1m), ladder climbing (E-interact).

**Movement states**: `crouching`, `sprinting` (toggle), `dragging`, `on_ladder`. Sprint auto-disables crouch; sprinting while moving drains stamina.

**Physics tuning**:
- `floor_snap_length = 0.5` — snaps player to floors up to 0.5m below
- `floor_max_angle = deg_to_rad(60)` — walkable surfaces up to 60° slope
- `max_slides = 16` — extra slide iterations for stair ramps

**Step-up auto-climb** — `_step_up(delta)` called before `move_and_slide()`:
1. **Lower ray** from ankle (feet_y+0.05) projects `probe_dist=1.2`m forward — detects obstacle face
2. **Upper ray** from `feet_y+max_step+0.1` (max 1.0m) same direction — checks clearance; if it hits, obstacle >1m, skip
3. **Downward ray** from 0.4m behind hit1's face, at `hit1.y+max_step`, straight down — finds landing surface with walkable normal (≤60° from up)
4. If all checks pass, lifts `global_position.y` to landing + 0.05m clearance, zeros `velocity.y`

**Ladder climbing** — `_handle_ladder_movement(delta)`:
- `on_ladder` flag set by `_attach_to_ladder()`, cleared by `_detach_from_ladder()`
- `_ladder_nearby: Area3D` (collision_mask=2) detects ladder ClimbArea
- W/S climbs at `climb_speed=3.0` with acceleration; X/Z clamped to ladder position
- `_ladder_grace_timer=0.4s` prevents immediate ground-detach after attaching
- Auto-detach at ground (when above 0.5m from base or pressing S near bottom) and at ladder top
- `dist_from_base` uses `player_bottom_y` (origin − half capsule height)

**Stamina** (`max_stamina=100`):
- `stamina_drain_rate=20/s` while sprinting+moving (5s max sprint)
- `stamina_recharge_rate=25/s` when not sprinting
- Depletion forces sprint off, emits `stamina_depleted`
- Signals: `stamina_changed(current, max_val)`

**Health** (`max_health=100`):
- `take_damage(amount)` / `heal(amount)` methods
- Signal: `health_changed(current, max_val)`

**Outline occlusion** (`_update_outline_occlusion()` runs every 0.1s):
- Casts 32 raycasts from camera to capsule heights
- Stores occlusion (0.0/1.0) in `PackedFloat32Array` → `set_shader_parameter("occlusion_data")`
- Sets `_outline_mesh.visible` to false when no occlusion (fully visible)

**Takedown integration**:
- `takedown_active: bool` — when true, `_physics_process` zeros velocity and returns
- `dragging: bool` — when true, `_get_speed()` returns `crouch_speed`
- `set_takedown_active(active)` — called by PlayerTakedownController during takedown anim
- `_setup_takedown_controller()` — instantiates PlayerTakedownController as child
- `_setup_hud()` — instantiates PlayerHUD as child (CanvasLayer)

### PlayerTakedownController.gd
**Role**: Handles all enemy interaction — takedowns (lethal + knockout), body dragging, and door/ladder E/Q proxied interaction.

**Target priority**: Finds nearest interactable enemy within 1.5m. Only the closest target gets indicators (solves multi-target ambiguity). Also checks for nearby interactables (doors, ladders) in `"interactable"` group and calls their `on_e_interact`/`on_q_interact` methods.

**Target types**:
- `TAKEDOWN` (PATROL/SEARCH enemies) — facing angle checked (180° = always in front)
- `DRAG` (KNOCKED_OUT/DEAD bodies) — no facing angle requirement

**Interaction**:
| Context | Q key | E key |
|---------|-------|-------|
| Near PATROL/SEARCH enemy | Instant lethal | Hold to charge knockout (1s, reduced by Subdue skill) |
| Near KO'd/dead body | — | Hold 0.5s to start dragging |
| While dragging | — | Tap to drop body |
| Near door | Q = break_apart() | E = toggle open/close |
| Near ladder | (none) | E = attach/detach climb |

**Drag behavior**: Body follows 2.0m behind player via velocity matching. Player moves at crouch speed while dragging. Drop enemy via E tap. `CollisionShape3D` left enabled.

**Indicators**: Interfaces with enemy's TakedownIndicator child via `show_takedown_indicators()`, `set_indicator_mode()`, `update_hold_progress()`. For interactables, calls `get_e_label()`/`get_q_label()` and `set_indicator_text()` on their InteractableIndicator.

**Takedown animation**: Teleports player behind enemy, freezes both for 0.5s, then applies kill/knockout.

**Ordering**: Enemy targets checked first (highest priority), then interactables (doors/ladders).

### TakedownIndicator.gd
**Role**: Billboard panels above enemy head (y=2.8) showing available actions.

**Modes** (via `set_mode()`):
- `"takedown"` — Q (red) + E (yellow) panels side by side
- `"drag"` — single E (yellow) centered with progress bar for 0.5s hold
- `"drop"` — single "DROP" (green) centered

Camera-facing via `_process()` with Basis.looking_at().

### Interactable.gd
**Role**: Base class for interactable objects (doors, ladders). `class_name Interactable extends Node3D`.

**Fields**: `interaction_range = 2.0`, indicator ref, enemy groups vars.

**Interface methods** (overridden by subclasses):
- `on_e_interact(caller)` — called when player presses E near this interactable
- `on_q_interact(caller)` — called when player presses Q near this interactable
- `get_e_label() -> String` — panel label for E action (default `"Interact"`)
- `get_q_label() -> String` — panel label for Q action (default `""`, hides Q panel)

**Groups**: `add_to_group("interactable")` in `_ready()`.

### InteractableIndicator.gd
**Role**: Billboard panel child of interactables showing E/Q labels and hold-progress.

**Structure**: Two sub-panels (E-yellow, Q-red) stacked vertically. Camera-facing via `_process()`.

**Fields**: `e_label: Label3D`, `q_label: Label3D`, `e_bg/b: ColorRect`, `q_bg/b: ColorRect`, `hold_progress_bar: ColorRect`, `outer/outer_b: ColorRect`.

**Methods**:
- `set_indicator_text(e, q)` — updates E/Q labels, hides Q panel when q empty
- `update_hold_progress(ratio)` — fills progress bar (ratio 0–1), hides bar when ≤0
- `show()` / `hide()` — visibility toggle

### Door.gd
**Role**: Swing-open door with break-apart physics. `class_name Door extends Interactable`.

**States**: `is_open`, `is_locked`, `is_broken`, `current_swing`.

**Swing interaction**:
- E toggles `_swing_open()` / `_swing_close()` over 0.35s (tween rotation on Y, limited to 110°)
- Q calls `break_apart()` — spawns BoxMesh fragments via `_spawn_fragments()`, plays `break_sound`

**Break-apart** (Jolt physics):
- Fragment pieces created as `RigidBody3D` with `BoxMesh`+`BoxShape3D` matching original collision proportions
- Each piece `collision_layer=2`, `collision_mask=1` (environment only)
- `randomize_fragment_settings()` applies random slight offset+rotation; impulse away from breaker position
- `on_break_apart` signal emitted

**Labels**: `get_e_label()` returns "Close"/"Open", `get_q_label()` returns "Break" (hidden when broken).

**Editor**: Placeholder (`EditorPlaceholder3D` child named `"Editor"`) stripped at runtime.

### Ladder.gd
**Role**: Procedural ladder with E-interact climbing. `class_name Ladder extends Interactable`.

**Dimensions**: `height = 3.0`, `width = 1.0`, `rung_spacing = 0.4`, `rail_thickness = 0.05`, `rung_thickness = 0.05`.

**Procedural generation** (`_generate()`):
- Left/right rails (BoxMesh, `width × height × rail_thickness`)
- Rungs spaced by `rung_spacing` (BoxMesh, `width × rung_thickness × rung_thickness`)
- `ClimbArea` collision shape (BoxShape3D, covers ladder volume) as Area3D child on `collision_layer=2`
- Strips children named `"Rung"*`, `"Rail"*`, `"ClimbArea"*`, `"Editor"*`, `"Prompt"*`, `"InteractableIndicator"*`

**E-interact**: `on_e_interact(caller)` checks `caller.has_method("_attach_to_ladder")` and toggles climb.

**Labels**: `get_e_label()` returns "Climb" / "Release", `get_q_label()` returns `""`.

**Physics**: `collision_layer = 2` (player passes through while climbing, interacts via Area3D).

### ground_nav.gd
**Role**: Runtime navmesh baking from all StaticBody3D colliders. `agent_max_climb = 0.5`, `agent_radius = 0.5`, `agent_height = 2.0`.

### camera_follow.gd
**Role**: Moves CameraPivot toward player with dead zone (2.5) and speed (6.0).

## Input Map (project.godot)
| Action | Key | Used by |
|--------|-----|---------|
| move_left/right/forward/back | A/D/W/S | player_controller |
| jump | Space | player_controller |
| sprint | Shift (toggle) | player_controller — tap to start/stop, also uncrouches |
| crouch_toggle | C | player_controller |
| toggle_invisibility | G | player_controller |
| skill_debug_toggle | L | player_controller (toggles SkillDebugUI) |
| mission_debug_toggle | M | player_controller (toggles MissionDebugUI) |
| knockout | E | PlayerTakedownController — also door/ladder E-interact |
| lethal_takedown | Q | PlayerTakedownController — also door Q-break |

## Known Issues / Gotchas
1. `drag_follow_distance = 2.0` — enemy may still clip through walls during sharp turns (velocity-matching drag keeps CollisionShape3D enabled).
2. Groups from instanced `.tscn` files NOT propagated — enemy calls `add_to_group("enemy")` in `_ready()`, player calls `add_to_group("player")`.
3. VisionRay at y=0.9 gives world y=1.8 (top of 1.8m capsule).
4. `_on_vision_body_exited` does NOT clear `player` ref, only `player_in_sight`. Ref persists for hearing.
5. `nav_agent.get_next_path_position()` returns `Vector3.ZERO` if no valid path — guarded in `_move_toward_target()`.
6. `SkillSaveData.tres` saved to `user://` — check `~/.local/share/godot/app_userdata/3d Stealth/`.
7. `SkillManager` uses `preload()` for save data class (not `class_name` directly) to avoid autoload resolution ordering issues.
8. `MissionRuntime` finds HUD via `get_node("/root/MissionHUD")` first (for scenes with pre-placed HUD), otherwise creates a `CanvasLayer` + `MissionHUD.tscn` instance. The HUD is scoped to the current scene.
9. `MissionManager.complete_mission()` guards against double-completion (early return if `mission_id` already in `completed_mission_ids`).
10. Mission data (MissionData Resource) is **not serialized** itself — only the progress (completed/unlocked IDs) is persisted. The actual mission definitions come from `register_mission()` calls at game start.
11. Ladder `collision_layer=2` (same as door fragments) — player Area3D uses `collision_mask=2` to detect ladder. No cross-interference with physics because ladder is StaticBody3D (no RigidBody response).
12. Step-up 3-raycast system probes 1.2m forward — may interact with surfaces at odd angles (diagonal walls, thin ledges). `floor_max_angle=60°` check on landing surface normal prevents climbing walls.
13. Door break-apart pieces spawned as RigidBody3D with `collision_layer=2` — do NOT collide with player (player on layer 1), only environment (env mask=1).
