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
│   │   ├── player_controller.gd       # 380 lines: player movement, invisibility, sprint toggle, stamina, health, outline occlusion
│   │   └── PlayerTakedownController.gd # 324 lines: takedown + drag interaction, player.dragging set/reset
│   ├── Navigation/ground_nav.gd       # 44 lines: runtime navmesh baking
│   ├── Camera/camera_follow.gd        # 21 lines: ortho camera follow
│   ├── Skills/
│   │   ├── SkillSaveData.gd           # 22 lines: serializable resource
│   │   └── SkillManager.gd            # 143 lines: autoload skill system
│   └── UI/
│       ├── PlayerHUD.gd               # 129 lines: HUD with stance icon, stamina bar, health bar
│       ├── SkillDebugUI.gd            # 277 lines: L-key debug panel
│       └── (editor theme files)
├── Prefabs/
│   ├── Enemy/enemy.tscn               # Enemy scene (72 lines)
│   └── Player/player.tscn             # Player scene (24 lines)
└── test_world.tscn                    # Test scene (179 lines)
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
├── Crate (StaticBody3D, 1×1×1, y=0.5)
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
**Role**: Player movement (WASD), sprint toggle (Shift), crouch (C), jump (Space), invisibility toggle (G), L key for skill debug.

**Movement states**: `crouching`, `sprinting` (toggle), `dragging`. Sprint auto-disables crouch; sprinting while moving drains stamina.

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
**Role**: Handles all enemy interaction — takedowns (lethal + knockout) and body dragging.

**Target priority**: Finds nearest interactable enemy within 1.5m. Only the closest target gets indicators (solves multi-target ambiguity).

**Target types**:
- `TAKEDOWN` (PATROL/SEARCH enemies) — facing angle checked (180° = always in front)
- `DRAG` (KNOCKED_OUT/DEAD bodies) — no facing angle requirement

**Interaction**:
| Context | Q key | E key |
|---------|-------|-------|
| Near PATROL/SEARCH enemy | Instant lethal | Hold to charge knockout (1s, reduced by Subdue skill) |
| Near KO'd/dead body | — | Hold 0.5s to start dragging |
| While dragging | — | Tap to drop body |

**Drag behavior**: Body follows 2.0m behind player via velocity matching. Player moves at crouch speed while dragging. Drop enemy via E tap. `CollisionShape3D` left enabled (no more disable/enable toggle).

**Indicators**: Interfaces with enemy's TakedownIndicator child via `show_takedown_indicators()`, `set_indicator_mode()`, `update_hold_progress()`.

**Takedown animation**: Teleports player behind enemy, freezes both for 0.5s, then applies kill/knockout.

### TakedownIndicator.gd
**Role**: Billboard panels above enemy head (y=2.8) showing available actions.

**Modes** (via `set_mode()`):
- `"takedown"` — Q (red) + E (yellow) panels side by side
- `"drag"` — single E (yellow) centered with progress bar for 0.5s hold
- `"drop"` — single "DROP" (green) centered

Camera-facing via `_process()` with Basis.looking_at().

### PlayerHUD.gd
**Role**: Bottom-left HUD with stance indicator, stamina bar, health bar.

**Layout**: CanvasLayer → Control root. Responsive via `Viewport.size_changed`.

**Elements**:
- StanceIcon (TextureRect) — cycles crouch/walk/sprint icons (`UI/HUD/icon-{crouching,walking,sprinting}.png`)
- Stamina bar (ColorRect bg + fill) — yellow fill, hidden at 100%, flashes white on depletion
- Health bar (ColorRect bg + fill) — green fill, faded at 100%

**Wiring**: Finds player via `"player"` group, connects to `movement_state_changed`, `stamina_changed`, `stamina_depleted`, `health_changed` signals.

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
| knockout | E | PlayerTakedownController |
| lethal_takedown | Q | PlayerTakedownController |

## Known Issues / Gotchas
1. `drag_follow_distance = 2.0` — enemy may still clip through walls during sharp turns (velocity-matching drag keeps CollisionShape3D enabled).
2. Groups from instanced `.tscn` files NOT propagated — enemy calls `add_to_group("enemy")` in `_ready()`, player calls `add_to_group("player")`.
3. VisionRay at y=0.9 gives world y=1.8 (top of 1.8m capsule).
4. `_on_vision_body_exited` does NOT clear `player` ref, only `player_in_sight`. Ref persists for hearing.
5. `nav_agent.get_next_path_position()` returns `Vector3.ZERO` if no valid path — guarded in `_move_toward_target()`.
6. `SkillSaveData.tres` saved to `user://` — check `~/.local/share/godot/app_userdata/3d Stealth/`.
7. `SkillManager` uses `preload()` for save data class (not `class_name` directly) to avoid autoload resolution ordering issues.
