class_name ItemData
extends Resource
## Base resource for all items in the game.
## Derived types: WeaponData, ArmorData, FoodData.

@export var id: int = 0
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var is_stackable: bool = false
@export var max_stack: int = 1
@export var weight: float = 0.0
@export var value: int = 0  # Gold value

## Item category for sorting/filtering
@export_enum("General", "Weapon", "Armor", "Food", "Tool", "Resource", "Quest") var category: String = "General"

## Whether the item can be equipped
@export var is_equippable: bool = false

## The 3D model to show when dropped on the ground
@export var world_model: PackedScene

## Path to .glb model for inventory icon rendering
@export var model_path: String = ""


func get_display_name() -> String:
	return item_name if item_name != "" else "Unknown Item"
