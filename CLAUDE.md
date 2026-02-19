# AI RPG — Single-Player OSRS-Style Mobile RPG

## Project Overview
A single-player, Old School RuneScape-inspired RPG built with **Godot 4.x** and **GDScript**, targeting Android (mobile-first) with PC debug support. No multiplayer — this is a solo adventure with OSRS-style mechanics (skills, tick-based combat, click-to-move, gathering, crafting).

## Tech Stack
- **Engine**: Godot 4.3 (deployed on Android as 4.3-stable)
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

### Autoloads (Singletons) — load order matters
1. `FileLogger` — Logging to file + logcat (initialized first so all others can log)
2. `GameManager` — Global game state, tick system (0.6s ticks), action log
3. `InputManager` — Unified input for mouse (PC) and touch (Android)
4. `PlayerSkills` — OSRS-style skills system (16 skills, XP table, level-ups)
5. `PlayerInventory` — 28-slot OSRS inventory (items stored as `{item, quantity}` dicts)
6. `PlayerEquipment` — 10-slot OSRS equipment system
7. `ItemRegistry` — Maps item IDs to `.tres` paths for save/load serialization
8. `SaveManager` — Save/load/export/import game state, auto-saves on Android background

## Android / Mobile Conventions
- **Input**: Always handle both `InputEventScreenTouch` and `InputEventMouseButton`. Map touch to the same logic as mouse click so we can debug on PC and deploy to Android.
- **UI Touch Targets**: Minimum 48px touch targets. Use Godot Control nodes with anchors set to "Full Rect" for responsive layout.
- **Performance**: Target 60fps on mid-range Android. Use low-poly models, baked lighting where possible, and LOD.
- **Screen Orientation**: Landscape only.

## CRITICAL: Android Godot 4.3 Compatibility Rules

These rules are **mandatory** for all code that runs on Android. Violations will cause silent failures (no errors, just broken behavior).

### 1. NEVER use `has_method()` — it silently returns `false` on Android
```gdscript
# BAD — has_method() returns false even when the method exists
if target.has_method("take_damage"):
    target.take_damage(damage)

# GOOD — call directly via .call()
target.call("take_damage", damage)

# GOOD — or just call it directly if you're sure of the type
target.take_damage(damage)
```

### 2. NEVER use `is CustomType` type checks — they silently fail
```gdscript
# BAD — `is EnemyBase` returns false on Android
if collider is EnemyBase:
    collider.take_damage(damage)

# GOOD — detect by collision_layer integer value
var layer: int = collider.get("collision_layer")
if layer == 4:  # Enemy layer
    collider.call("take_damage", damage)
```

### 3. NEVER use `is_in_group()` / `get_groups()` for detection — groups appear empty
```gdscript
# BAD — groups are empty on Android
if node.is_in_group("enemies"):
    ...

# GOOD — use collision_layer values
if node.get("collision_layer") == 4:
    ...
```

### 4. Use `.get("property")` instead of direct property access guarded by type checks
```gdscript
# BAD — relies on `is` check which fails
if target is EnemyBase:
    var name = target.display_name

# GOOD — use .get() which works regardless
var name = target.get("display_name")
if name == null:
    name = target.name
```

### 5. Meshes MUST be defined as `sub_resource` in `.tscn` files
- Programmatic meshes created in `_ready()` do **NOT** render on Android
- Always define mesh geometry as `[sub_resource]` entries in the `.tscn` file
- Code can reference existing meshes via `get_node_or_null()`, but must not create new ones

### 6. Scripts MUST be in PackedScene `.tscn` files (not inline in parent scenes)
```
# BAD — inline script in parent .tscn (script never executes on Android)
[node name="Goblin" type="CharacterBody3D" parent="GoblinCamp"]
script = ExtResource("enemy_base")

# GOOD — separate PackedScene with script, instanced in parent
[node name="Goblin1" parent="GoblinCamp" instance=ExtResource("goblin")]
```
- Always create a separate `.tscn` PackedScene file (e.g., `Goblin.tscn`) with the script attached to the root node
- Instance it in the parent scene via `instance=ExtResource(...)`
- Override per-instance properties (transform, stats, drop_table) in the parent scene

### 7. Use `ensure_initialized()` pattern — `_ready()` may not fire
```gdscript
var _initialized: bool = false

func _ready() -> void:
    ensure_initialized()

func ensure_initialized() -> void:
    if _initialized:
        return
    _initialized = true
    # ... actual initialization code ...
```
- Even with PackedScene instances, `_ready()` may not fire on Android
- `Main.gd` walks the scene tree and calls `ensure_initialized()` on all game objects as a fallback
- The guard bool `_initialized` prevents double-initialization on PC where `_ready()` works

### 8. GDScript features that cause SILENT parse failures on Android
Scripts that fail to parse produce **NO error** — `_ready()` simply never fires. These features are confirmed to cause silent failures:

```gdscript
# BAD — signals with 3+ parameters may fail
signal item_added(item, quantity, slot_idx)

# GOOD — keep signals to 0-2 parameters
signal inventory_changed()

# BAD — := with Variant-returning functions (min, max, clamp, etc.)
var x := min(a, b)

# GOOD — use explicit var without :=
var x = min(a, b)
# or use if/else instead of min/max
var x = a
if b < a:
    x = b

# BAD — inferred typing with := can trigger parse failures
var slot := _find_empty_slot()

# GOOD — always use untyped var =
var slot = _find_empty_slot()
```

**Additional parse-failure triggers:**
- `const Array[String]` — use `var arr = [...]` instead
- `signal foo(x: CustomType)` — untype all signal params
- `static func` — use regular `func` instead
- `@onready var x: CustomType` — use base types (`Node`, `Node3D`)
- `var x: CustomType` — ANY variable typed with a custom `class_name` may fail
- `class_name` on scripts over ~200 lines — keep scripts short OR remove `class_name`

### 9. Hand-crafted .tscn files — UIDs must be valid or omitted
```
# BAD — human-readable UIDs cause load failures
[gd_scene load_steps=2 format=3 uid="uid://inv_ui_scene"]

# GOOD — omit uid entirely from hand-crafted .tscn files
[gd_scene load_steps=2 format=3]
```
Godot UIDs use base62 hashes (e.g., `uid://b5c3k7m9x2`). Invalid UIDs cause `load()` to silently fail on Android.

### 10. Guard autoload signal connections — scripts may not parse
```gdscript
# BAD — crashes if PlayerInventory script didn't parse
PlayerInventory.inventory_changed.connect(_on_inventory_changed)

# GOOD — check signal exists first
var sig = PlayerInventory.get("inventory_changed")
if sig:
    PlayerInventory.inventory_changed.connect(_on_inventory_changed)
```
If an autoload's script fails to parse, it exists as a bare `Node` with no signals or methods. Accessing `.signal_name` directly will crash.

### 11. Use `.call()` for cross-autoload method calls
```gdscript
# BAD — crashes if autoload script didn't parse
PlayerInventory.add_item(item, qty)

# GOOD — .call() returns null instead of crashing on missing methods
PlayerInventory.call("add_item", item, qty)
```

### 12. NEVER use `DirAccess.open()` to enumerate resource directories on Android
```gdscript
# BAD — DirAccess cannot list files inside APK-packed res:// directories
var dir = DirAccess.open("res://Data/Items")
dir.list_dir_begin()  # returns nothing on Android

# GOOD — use a hardcoded manifest (see Systems/item_registry.gd)
var ITEM_MANIFEST = {
    995: "res://Data/Items/coins.tres",
    1277: "res://Data/Weapons/bronze_sword.tres",
}
```
On Android, `res://` resources are packed inside the APK. `DirAccess.open()` silently returns an empty directory. **Always use hardcoded path lists** for any code that needs to enumerate `.tres` or other resource files at runtime. When adding new items, add their ID and path to `ITEM_MANIFEST` in `Systems/item_registry.gd`.

### 13. Pass explicit node references — avoid `get_nodes_in_group()` for critical lookups
```gdscript
# BAD — groups can appear empty on Android
var players = get_tree().get_nodes_in_group("player")

# GOOD — pass the reference explicitly from the scene that owns it
# In main.gd:
SaveManager.call("set_player", player)
```
`get_nodes_in_group()` is unreliable on Android. For critical systems like save/load, pass node references directly from `Main.gd` rather than relying on group lookups.

### Collision Layer Reference (used for type detection)
| Layer | Value | Usage |
|-------|-------|-------|
| 1 | 1 | World/Ground |
| 2 | 2 | Player |
| 3 | 4 | Enemies |
| 4 | 8 | Interactables |

Raycast mask: `1 | 4 | 8` (excludes player layer)

### UI Sizing for Mobile Touch Targets
- Toolbar buttons: min 140x72px, font size 24
- HP bar: 280x56px, font size 24
- Inventory slots: 88x88px, font size 18
- Skills rows: height 42px, fonts 20/22
- Overlay panels: 600-640px wide/tall
- Action log font: 20

## OSRS-Style Game Mechanics
- **Game Tick**: 0.6 seconds. All actions (combat hits, skill ticks, movement steps) align to game ticks.
- **Skills**: Attack, Strength, Defence, Hitpoints, Ranged, Prayer, Magic, Cooking, Woodcutting, Fishing, Mining, Smithing, Crafting, Firemaking, Agility, Thieving. XP table follows OSRS formula.
- **Combat**: Tick-based auto-attack. Player clicks enemy → walks to range → attacks every N ticks based on weapon speed.
- **Click-to-Move**: Tap/click a location → player pathfinds via NavigationAgent3D. Tap an object → player pathfinds to interaction range, then interacts.
- **Inventory**: 28 slots (like OSRS). Items can be stackable or individual.

## Coding Conventions
- Use `snake_case` for variables and functions (GDScript standard).
- Use `PascalCase` for class/node names.
- Prefix signals with `on_` or use past tense (e.g., `inventory_changed`, `level_up`).
- **Keep scripts under 200 lines** — scripts over ~200 lines may silently fail to parse on Android.
- Use `@export` for inspector-configurable properties.
- **Avoid `class_name`** on game object scripts (player, enemies, interactables) — it causes cascade failures when scripts fail to parse. OK on Data resource scripts (`ItemData`, `WeaponData`, etc.) and StateMachine framework.
- **Use `var x =` instead of `var x :=`** — inferred typing with `:=` can trigger Android parse failures, especially with Variant-returning functions.
- **Keep signals to 0-2 parameters** — 3+ param signals may cause silent parse failures on Android.
- Type-hint function params with **built-in types only** (`int`, `float`, `String`, `Node3D`, `Dictionary`, etc.). Never use custom `class_name` types in hints.
- **Android-safe method calls**: Use `.call("method", args)` instead of `has_method()` guards. Use `.get("property")` instead of `is Type` guards. Use `.get("signal_name")` before `.connect()`. See "Android Godot 4.3 Compatibility Rules" above.
- **When adding new items**: You **MUST** add the item's `id` and `.tres` path to the `ITEM_MANIFEST` dictionary in `Systems/item_registry.gd`. Without this, the save/load system cannot resolve the item and saved inventories containing it will silently lose it on load.

## Testing
- Test on PC first using mouse input (maps 1:1 with touch).
- Use Godot's built-in debugger and print statements for rapid iteration.
- Android deploy via Godot's one-click export when ready.

## File Naming
- Scripts: `snake_case.gd` (e.g., `player_controller.gd`)
- Scenes: `PascalCase.tscn` (e.g., `Player.tscn`)
- Resources: `snake_case.tres` (e.g., `bronze_sword.tres`)
- Data scripts: `PascalCase.gd` (e.g., `ItemData.gd`, `WeaponData.gd`)
