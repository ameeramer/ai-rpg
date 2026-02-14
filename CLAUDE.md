# AI RPG — Single-Player OSRS-Style Mobile RPG

## Project Overview
A single-player, Old School RuneScape-inspired RPG built with **Godot 4.x** and **GDScript**, targeting Android (mobile-first) with PC debug support. No multiplayer — this is a solo adventure with OSRS-style mechanics (skills, tick-based combat, click-to-move, gathering, crafting).

## Tech Stack
- **Engine**: Godot 4.6+
- **Language**: GDScript (primary)
- **Target Platform**: Android (mobile-first), with PC for testing
- **3D Style**: Low-poly (OSRS aesthetic)
- **Asset Format**: .glTF / .glb for 3D models
- **Version Control**: Git

## Architecture: Data-Driven Node-Component

### Key Principles
1. **No monolithic classes** — Use Godot's node composition. A Player is a CharacterBody3D with child nodes for each system (inventory, skills, combat, etc.).
2. **Resources for data** — All game data (items, weapons, skills, NPCs) are `.tres` Resource files. Never hardcode stats.
3. **Finite State Machine (FSM)** — Player behavior is state-driven: Idle → Moving → Interacting → Combat.
4. **Signals over polling** — Use Godot signals for decoupled communication between systems.
5. **Tick system** — OSRS runs on 0.6s game ticks. Our game uses a similar tick system for combat, skilling, and movement.

### Directory Structure
```
res://
├── Actors/              # Player, NPCs, Enemies
│   ├── Player/          # Player scene, controller, states
│   └── Enemies/         # Enemy scenes and AI
├── Data/                # Resource scripts and .tres data files
│   ├── Items/           # Item .tres files
│   ├── Weapons/         # Weapon .tres files
│   ├── Armor/           # Armor .tres files
│   ├── Food/            # Food .tres files
│   └── Skills/          # Skill definition .tres files
├── Systems/             # Core game systems (singletons, managers)
│   ├── GameManager.gd
│   ├── TickSystem.gd
│   ├── InputManager.gd
│   └── StateMachine/    # FSM framework
├── UI/                  # All UI scenes and scripts
│   ├── HUD/
│   ├── Inventory/
│   ├── Skills/
│   └── ActionLog/
├── Scenes/              # World scenes, levels
│   └── World/
└── Assets/              # Raw assets (models, textures, audio)
    ├── Models/
    ├── Textures/
    └── Audio/
```

### Autoloads (Singletons)
- `GameManager` — Global game state, save/load, tick system
- `InputManager` — Unified input for mouse (PC) and touch (Android)

## Android / Mobile Conventions
- **Input**: Always handle both `InputEventScreenTouch` and `InputEventMouseButton`. Map touch to the same logic as mouse click so we can debug on PC and deploy to Android.
- **UI Touch Targets**: Minimum 48px touch targets. Use Godot Control nodes with anchors set to "Full Rect" for responsive layout.
- **Performance**: Target 60fps on mid-range Android. Use low-poly models, baked lighting where possible, and LOD.
- **Screen Orientation**: Landscape only.

## OSRS-Style Game Mechanics
- **Game Tick**: 0.6 seconds. All actions (combat hits, skill ticks, movement steps) align to game ticks.
- **Skills**: Attack, Strength, Defence, Hitpoints, Ranged, Prayer, Magic, Cooking, Woodcutting, Fishing, Mining, Smithing, Crafting, Firemaking, Agility, Thieving. XP table follows OSRS formula.
- **Combat**: Tick-based auto-attack. Player clicks enemy → walks to range → attacks every N ticks based on weapon speed.
- **Click-to-Move**: Tap/click a location → player pathfinds via NavigationAgent3D. Tap an object → player pathfinds to interaction range, then interacts.
- **Inventory**: 28 slots (like OSRS). Items can be stackable or individual.

## Coding Conventions
- Use `snake_case` for variables and functions (GDScript standard).
- Use `PascalCase` for class/node names.
- Prefix signals with `on_` or use past tense (e.g., `item_added`, `skill_leveled_up`).
- Keep scripts under 200 lines where possible — split into components.
- Use `@export` for inspector-configurable properties.
- Use `class_name` to register custom types globally.
- Always type-hint function parameters and return types.

## Testing
- Test on PC first using mouse input (maps 1:1 with touch).
- Use Godot's built-in debugger and print statements for rapid iteration.
- Android deploy via Godot's one-click export when ready.

## File Naming
- Scripts: `snake_case.gd` (e.g., `player_controller.gd`)
- Scenes: `PascalCase.tscn` (e.g., `Player.tscn`)
- Resources: `snake_case.tres` (e.g., `bronze_sword.tres`)
- Data scripts: `PascalCase.gd` (e.g., `ItemData.gd`, `WeaponData.gd`)
