extends Node
## ItemRegistry — Maps item IDs to .tres resource paths for save/load.
## Registered as "ItemRegistry" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.
##
## Uses a hardcoded manifest instead of DirAccess scanning because
## DirAccess.open() cannot enumerate directories inside Android APKs.
## When adding new items, add their ID and path to ITEM_MANIFEST below.

var _id_to_path: Dictionary = {}
var _id_to_resource: Dictionary = {}
var _initialized: bool = false

# Hardcoded manifest: item_id -> res:// path
# DirAccess cannot enumerate packed APK resources on Android, so we
# list every item explicitly. Add new items here when creating them.
var ITEM_MANIFEST = {
	315: "res://Data/Food/shrimps.tres",
	317: "res://Data/Items/raw_shrimps.tres",
	323: "res://Data/Food/burnt_food.tres",
	333: "res://Data/Food/trout.tres",
	335: "res://Data/Food/raw_trout.tres",
	436: "res://Data/Items/copper_ore.tres",
	526: "res://Data/Items/bones.tres",
	995: "res://Data/Items/coins.tres",
	1117: "res://Data/Armor/bronze_platebody.tres",
	1139: "res://Data/Armor/bronze_med_helm.tres",
	1277: "res://Data/Weapons/bronze_sword.tres",
	1279: "res://Data/Weapons/iron_sword.tres",
	1281: "res://Data/Weapons/steel_sword.tres",
	1351: "res://Data/Weapons/bronze_axe.tres",
	1353: "res://Data/Weapons/iron_axe.tres",
	1511: "res://Data/Items/logs.tres",
	1521: "res://Data/Items/oak_logs.tres",
}


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for item_id in ITEM_MANIFEST.keys():
		var path = ITEM_MANIFEST[item_id]
		_id_to_path[item_id] = path
		var res = load(path)
		if res != null:
			_id_to_resource[item_id] = res
		else:
			FileLogger.log_msg("ItemRegistry: failed to load %s" % path)
	FileLogger.log_msg("ItemRegistry: registered %d items" % _id_to_resource.size())


func get_item_by_id(item_id: int):
	if _id_to_resource.has(item_id):
		return _id_to_resource[item_id]
	if _id_to_path.has(item_id):
		var res = load(_id_to_path[item_id])
		if res:
			_id_to_resource[item_id] = res
		return res
	FileLogger.log_msg("ItemRegistry: unknown item id %d" % item_id)
	return null


func has_item(item_id: int) -> bool:
	return _id_to_path.has(item_id)
