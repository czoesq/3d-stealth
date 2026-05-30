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
│   ├── AI/enemy_controller.gd        # 871 lines: enemy AI (patrol, vision, chase, detection)
│   ├── Player/player_controller.gd   # 232 lines: player movement, invisibility, noise, debug UI toggle
│   ├── Navigation/ground_nav.gd      # 44 lines: runtime navmesh baking
│   ├── Camera/camera_follow.gd       # 21 lines: ortho camera follow
│   ├── Skills/
│   │   ├── SkillSaveData.gd          # 22 lines: serializable resource for skill state
│   │   └── SkillManager.gd           # 143 lines: autoload singleton for skill system
│   └── UI/
│       └── SkillDebugUI.gd           # 268 lines: L-key debug panel for skill system
├── Prefabs/
│   ├── Enemy/enemy.tscn              # Enemy scene (72 lines)
│   └── Player/player.tscn            # Player scene (24 lines)
└── test_world.tscn                   # Test scene (179 lines)
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

**Cost scaling**: `base_cost × (current_level + 1)`. E.g., stealth lv1→lv2 costs 200, lv2→lv3 costs 300.

**Persistence**: Saves to `user://SkillSaveData.tres` via `ResourceSaver.save()` on every mutation.

**Key methods**:
- `add_xp(amount)` — adds to global pool, emits `xp_changed`, saves
- `upgrade_skill(name)` — checks unlocked + level<MAX + has XP, deducts cost, emits `skill_upgraded`, saves
- `unlock_skill_tree(name)` — consumes 1 neural stimulator, unlocks skill, saves
- `reset_to_defaults()` — replaces save_data with fresh default SkillSaveData, emits all signals
- `get_next_level_xp_cost(name)` — returns `base_cost × (level+1)` or -1 if maxed
- `add_neural_stimulators(amount)` — adds stimulators, emits signal, saves

### SkillSaveData (res://Scripts/Skills/SkillSaveData.gd)
`class_name SkillSaveData extends Resource`. Serializable via `@export`:
- `skill_levels: Dictionary` — each skill → int level
- `skill_unlocked: Dictionary` — each skill → bool
- `total_xp: int`
- `neural_stimulators: int`

### SkillDebugUI (res://Scripts/UI/SkillDebugUI.gd)
**Role**: Debug panel toggled with L key. Built programmatically (no .tscn).

**Layout**:
```
┌─────────────────────────────────────┐
│ Skills Debug                Reset X │
├─────────────────────────────────────┤
│ Skills                              │
│ Stealth   Lv 1  Upgrade (200 XP)    │
│ Hacking   Lv 1  Upgrade (200 XP)    │
│ Subdue    Lv 0  Unlock (1 stim)     │
│ Awareness Lv 0  Unlock (1 stim)     │
│ Gadgets   Lv 0  Unlock (1 stim)     │
├─────────────────────────────────────┤
│ Neural Stimulators: 0             [+]│
│ Total XP:            0             [+]│
└─────────────────────────────────────┘
```
- **Toggle**: L key (player controller), close via X, L, or Escape
- **Action buttons**: Upgrade (if affordable), Unlock (if stim available), MAX, Need N XP
- **[+] buttons**: +1 stimulator / +100 XP (debug only)
- **Reset**: Restores all skills/XP/stimulators to defaults
- Centered via `call_deferred("_center_panel")` using `vb.get_minimum_size()`

## Key Scripts

### enemy_controller.gd
**Role**: Enemy AI: patrol→suspicious→chase states, vision cone + sound detection.

**`_ready()` flow** (line 91):
1. Gets node refs (nav_agent, vision_area, hearing_area, vision_ray)
2. Sets up vision cone debug mesh, detection bar, vision/hearing areas
3. Collects patrol points (from PatrolPoints child or auto-generates)
4. Finds player via `call_deferred("_find_player_node")` (line 137-140)

**`_physics_process()`** (line 415):
- Gravity, state handler, then: `_update_detection()` → `_update_detection_bar()` → `_update_vision_cone_color()` → `_update_debug_waypoints()` → `move_and_slide()`

**States** (enum State):
| State | Enter | Process | Transition to |
|-------|-------|---------|---------------|
| IDLE | `_enter_idle:390` | `_process_idle:445` | PATROL after 2-5s timer |
| PATROL | `_enter_patrol:458` | `_process_patrol:515` | SUSPICIOUS on first detection frame |
| SUSPICIOUS | `_enter_suspicious:535` | `_process_suspicious:541` | CHASE (meter=100), PATROL (meter=0) |
| ALERT | `_enter_alert:554` | `_process_alert:562` | CHASE (meter=100), IDLE (cooldown+low meter) |
| CHASE | `_enter_chase:577` | `_process_chase:612` | ALERT (meter≤50 after lost sight) |
| KNOCKED_OUT | `knock_out:662` | `_process_knocked_out:660` | ALERT (revive complete) |

**SUSPICIOUS behavior**: Enemy stops in place, decelerates smoothly (`velocity.lerp(ZERO, 4*delta)`), rotates to face `suspicious_target`. Tracks player live via vision. New noise updates `suspicious_target` and re-orients enemy. No movement during SUSPICIOUS.

**Alert flow**: ALERT is entered only via `respond_to_alarm()` (other enemies calling for help). Direct SUSPICIOUS → CHASE transition at 100% detection.

**Vision cone debug** (line 207, 314-376):
- MeshInstance3D added as child, recreated when `_update_vision_cone_mesh()` is called
- Tessellated spherical wedge (20h×10v segments) with side panels
- Colors: green (patrol, no detection), yellow→orange (player visible), red (chase)
- Rebuilt via setter when `vision_range` changes

**Detection flow** (`_update_detection:687`):
1. `_check_vision()` — angular FOV + distance + raycast LOS
2. `_check_hearing()` — distance + player noise level
3. Meter fills (vision > hearing > decay), triggers `_handle_state_transitions()`

**`_check_vision()`** (line 759):
- Null player → false, invisible → false
- Horizontal: `acos(dot(forward, dir_to_player)) > vision_angle_h` (half-angle, default 80°)
- Vertical: `asin(dir_to_player.y) > vision_angle_v` (half-angle, default 50°)
- Distance > vision_range → false
- Raycast via VisionRay from enemy+0.9y to player pos; collider must be player or group "player"

**Movement** (`_move_toward_target:832`):
- Trusts navmesh path exclusively. No manual raycast avoidance (removed — was fighting the navmesh)
- Guards against `nav_agent.get_next_path_position()` returning `Vector3.ZERO` (invalid path)
- Smooth rotation via `transform.basis.slerp()`

**Return to patrol** (`_return_to_nearest_patrol:631`):
- Finds nearest patrol point by distance
- If already within `target_reached_distance` (1.0m), pauses briefly instead of navigating self-to-self

**Detection rate**: `sight_detection_rate × (2.0 − dist/range×1.5) × move_factor × crouch_factor × delta`
- 2.0× rate at 0m, 0.5× at max range
- Crouch reduces rate 20% (`crouch_factor = 0.8`)
- Moving player increases rate 50% (`movement_multiplier = 1.5`)

**Variables** (line 52-85):
- `player_in_sight` — set true only by raycast hit in `_check_vision()`, cleared by FOV/range/raycast misses and `_on_vision_body_exited`
- `detection_meter` — 0–100, increased by vision/hearing, decayed over time
- `last_known_player_pos` — updated by vision detection in `_update_detection()`
- `suspicious_target` — position enemy faces during SUSPICIOUS, updated by vision (live tracking) and hearing

### player_controller.gd
**Role**: Player movement (WASD+space+Shift+C+G), invisibility toggle (G), noise generation, skill debug toggle (L).

**Input**: `move_left/right/forward/back` (A/D/W/S), `jump` (space), `sprint` (Shift), `crouch_toggle` (C), `toggle_invisibility` (G), `skill_debug_toggle` (L).

**Key additions**:
- `_toggle_skill_debug()` (line 107) — instantiates/removes SkillDebugUI as child of current_scene
- L key handled in `_handle_state_toggles()` (line 105)

### ground_nav.gd
**Role**: Runtime navmesh baking from all StaticBody3D colliders in `get_tree().current_scene`.
- `agent_max_climb = 0.5`, `agent_radius = 0.5`, `agent_height = 2.0`
- `PARSED_GEOMETRY_STATIC_COLLIDERS` avoids GPU readback
- Debug mesh added as child with transparency
- 56 polygons, 51 vertices (test_world layout)

### camera_follow.gd
**Role**: Moves CameraPivot toward player with dead zone (2.5) and speed (6.0).
- Hardcoded path: `get_node("../Player")` — fragile if hierarchy changes.

## Scene Files

### enemy.tscn
- CharacterBody3D, group "enemy", CapsuleShape3D h=1.8 r=0.5
- NavigationAgent3D: path_desired=2.0, target_desired=1.0
- VisionArea: Area3D with SphereShape3D r=10 (rebuilt in code)
- HearingArea: Area3D with SphereShape3D r=8 (rebuilt in code)
- VisionRay: RayCast3D at `(0, 0.9, 0)`, enabled, hit_from_inside, mask=1
- PatrolPoints: container for Marker3D waypoints

### player.tscn
- CharacterBody3D, group "player", CapsuleShape3D h=1.8 r=0.5
- No collision_layer/mask set (defaults to layer 1, mask 1)

### test_world.tscn
- Enemy instance at `(-5, 0.9, 2)`: `target_reached_distance=1.0`, `debug=true`
- Player instance at `(0, 0.9, 0)`
- 6 patrol points (Marker3D children of Enemy/PatrolPoints)
- All physics geometry is StaticBody3D with BoxShape3D/BoxMesh

## Input Map (project.godot)
| Action | Key | Used by |
|--------|-----|---------|
| move_left/right/forward/back | A/D/W/S | player_controller |
| jump | Space | player_controller |
| sprint | Shift | player_controller |
| crouch_toggle | C | player_controller |
| toggle_invisibility | G | player_controller |
| skill_debug_toggle | L | player_controller (toggles SkillDebugUI) |

## Design Compliance (vs design_principles.md)
| Principle | Status | Notes |
|-----------|--------|-------|
| No failure from detection alone | ✓ | Meter fill + decay, no instant fail |
| Non-lethal rewarded | Partial | `knock_out()` + revive exist; skills/XP not hooked to gameplay yet |
| Lethal easier, costs resources | Partial | No combat implemented yet |
| Vision cones + sound detection | ✓ | `_check_vision()` + `_check_hearing()` working |
| Fill meter over time | ✓ | `_update_detection()` with rate × delta |
| Basic enemies: patrol, chase, alarm | ✓ | 6 states, `_call_for_help()`, `respond_to_alarm()` |
| Prototype: track lethal vs non-lethal | ✗ | Not implemented (placeholder signals only) |
| Prototype: two skills (Stealth + one) | ✗ | Skill system exists (5 skills, autoload) but not hooked to gameplay |

## Known Issues / Gotchas
1. `get_overlapping_bodies()` returns empty in `_ready()`. Also, `get_tree().get_nodes_in_group("player")` returns empty during `_ready()` because groups from instanced `.tscn` files are NOT propagated to the instance. Solution: player calls `add_to_group("player")` in its own `_ready()`, and enemy uses `call_deferred("_find_player_node")` to find the player after all `_ready()` calls complete.
2. VisionRay at y=0.9 gives world y=1.8 (top of 1.8m capsule) — works for downward angle to player center (y=0.9)
3. `_on_vision_body_exited` does NOT clear `player` ref, only `player_in_sight`. Ref persists for hearing detection.
4. `_on_hearing_body_exited` is a no-op (intentional: ref persists for range checks)
5. `nav_agent.target_position = global_position` in `_enter_idle()` may cause navigation query on self — safe but wasteful
6. `nav_agent.get_next_path_position()` returns `Vector3.ZERO` if no valid path — guarded in `_move_toward_target()` (line 840-845)
7. SkillManager uses `preload()` for `SkillSaveData` instead of `class_name` directly because autoload resolution order doesn't guarantee `class_name` registration before first use
8. `nav_agent.get_next_path_position()` can return `Vector3.ZERO` for invalid paths — `_move_toward_target()` checks this and stops
9. The `_return_to_nearest_patrol()` now checks if already within `target_reached_distance` of the nearest patrol point and pauses instead of navigating to self
10. `SkillSaveData.tres` is saved to `user://` (app data directory), not `res://` — check `~/.local/share/godot/app_userdata/3d Stealth/SkillSaveData.tres`
