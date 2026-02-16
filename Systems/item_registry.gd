extends Node
## ItemRegistry — Maps item IDs to .tres resource paths for save/load.
## Registered as "ItemRegistry" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.

var _id_to_path: Dictionary = {}
var _id_to_resource: Dictionary = {}
var _initialized: bool = false

var ITEM_DIRS = [
	"res://Data/Items",
	"res://Data/Weapons",
	"res://Data/Armor",
	"res://Data/Food"
]


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for dir_path in ITEM_DIRS:
		_scan_directory(dir_path)
	FileLogger.log_msg("ItemRegistry: registered %d items" % _id_to_path.size())


func _scan_directory(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		FileLogger.log_msg("ItemRegistry: cannot open %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = dir_path + "/" + file_name
			var res = load(full_path)
			if res != null:
				var item_id = res.get("id")
				if item_id != null and item_id > 0:
					_id_to_path[item_id] = full_path
					_id_to_resource[item_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


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
