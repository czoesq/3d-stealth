# Design Principles – [3d stealth]

## Core Identity
A low-poly, fixed-angle isometric stealth game. Real-time. PC + tablet. Steampunk industrial revolution setting, lighter colors (not grimdark). Missions from a hub. Multiple paths. Lethal or non-lethal.

## The Golden Rules
1. **No mission failure from detection alone.** Mistakes drain resources (ammo, health, time). Player always has a path forward.
2. **Non-lethal is rewarded more** (XP, faction approval) but carries risk (enemies can be revived).
3. **Lethal is easier in the moment** but costs resources, XP, and faction standing.
4. **Player choice matters** – either/or missions, branching objectives, disposition system.

## Gameplay Loop
Hub → Select Mission → Infiltrate → Achieve Objective → Return to Hub → Spend Resources → Unlock Next Missions

## Detection & Combat
- Enemies: vision cones + sound detection. Fill meter over time.
- Alarms raise alert level (more patrols, faster suspicion).
- No brawling/melee combat system. Takedowns are stealth-only (Subdue tree). Lethal combat uses guns.

## Skills (5 trees)
| Tree | Unlock Cost | Core Function |
|------|-------------|----------------|
| Stealth | Default | Slower detection |
| Hacking | Default | Faster hacking minigame |
| Subdue | Neural stimulator | Better non-lethal takedowns |
| Awareness | Neural stimulator | More HUD info |
| Gadgets | Neural stimulator | New tools (lockpicks, mines, decoys) |

## Resources
- **Money** – buy supplies. From loot, missions, selling.
- **XP** – upgrade skills. From actions, stealth bonuses.
- **Neural Stimulator** – unlock new skill trees. Rare (missions, black market).

## Hub Functions
- Level up (kiosk UI)
- Vendors (buy/sell)
- Recruit NPCs (mission rewards → new hub services)
- Dialogue (no skill checks, disposition affects offers)

## Disposition (Light RPG)
- Track global lethality (% kills vs KOs).
- Resistance favors non-lethal → better rewards.
- Black market favors lethal → discounts on ammo/weapons.

## Visual & Tone
- Low-poly (PS2 era), lighter colors, not drab.
- Steampunk elements for traversal and gadgets.
- City focus: docks, manors, warehouses, factories, labs, airships.

## Prototype Scope (First Build)
One mission. One protagonist. Vision cones + sound. Basic enemies (patrol, chase, alarm). Two skills (Stealth + one other). XP/leveling optional (debug menu first). No vendors, no hub NPCs, no either/or missions. Track lethal vs non-lethal for XP difference.
