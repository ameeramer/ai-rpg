extends Node
## Autoload singleton for OSRS-style combat attack styles.
## Manages the current attack style, available styles per weapon,
## and XP distribution based on selected style.
## No class_name — autoloads are accessed by name, not type.

signal style_changed()

# Current attack style: "accurate", "aggressive", "defensive", "controlled"
var current_style: String = "accurate"
var _initialized: bool = false

# Style definitions per weapon category
# Each entry: {name, style, attack_type, xp_skills}
# xp_skills maps skill_name -> multiplier (out of total XP)
# style: the combat style name used for invisible boosts
# attack_type: Stab/Slash/Crush for accuracy roll

var WEAPON_STYLES = {}


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_build_weapon_styles()
	FileLogger.log_msg("CombatStyle initialized, style=%s" % current_style)


func _build_weapon_styles() -> void:
	# sword: 3 styles
	WEAPON_STYLES["sword"] = [
		{"name": "Stab", "style": "accurate", "attack_type": "Stab",
		 "xp": {"Attack": 4.0, "Hitpoints": 1.33}},
		{"name": "Slash", "style": "aggressive", "attack_type": "Slash",
		 "xp": {"Strength": 4.0, "Hitpoints": 1.33}},
		{"name": "Block", "style": "defensive", "attack_type": "Slash",
		 "xp": {"Defence": 4.0, "Hitpoints": 1.33}},
	]
	# scimitar: 4 styles (has controlled)
	WEAPON_STYLES["scimitar"] = [
		{"name": "Chop", "style": "accurate", "attack_type": "Slash",
		 "xp": {"Attack": 4.0, "Hitpoints": 1.33}},
		{"name": "Slash", "style": "aggressive", "attack_type": "Slash",
		 "xp": {"Strength": 4.0, "Hitpoints": 1.33}},
		{"name": "Lunge", "style": "controlled", "attack_type": "Stab",
		 "xp": {"Attack": 1.33, "Strength": 1.33, "Defence": 1.33, "Hitpoints": 1.33}},
		{"name": "Block", "style": "defensive", "attack_type": "Slash",
		 "xp": {"Defence": 4.0, "Hitpoints": 1.33}},
	]
	# axe: 3 styles (2 aggressive with different types)
	WEAPON_STYLES["axe"] = [
		{"name": "Chop", "style": "accurate", "attack_type": "Slash",
		 "xp": {"Attack": 4.0, "Hitpoints": 1.33}},
		{"name": "Hack", "style": "aggressive", "attack_type": "Slash",
		 "xp": {"Strength": 4.0, "Hitpoints": 1.33}},
		{"name": "Block", "style": "defensive", "attack_type": "Slash",
		 "xp": {"Defence": 4.0, "Hitpoints": 1.33}},
	]
	# mace: 4 styles (has controlled)
	WEAPON_STYLES["mace"] = [
		{"name": "Pound", "style": "accurate", "attack_type": "Crush",
		 "xp": {"Attack": 4.0, "Hitpoints": 1.33}},
		{"name": "Pummel", "style": "aggressive", "attack_type": "Crush",
		 "xp": {"Strength": 4.0, "Hitpoints": 1.33}},
		{"name": "Spike", "style": "controlled", "attack_type": "Stab",
		 "xp": {"Attack": 1.33, "Strength": 1.33, "Defence": 1.33, "Hitpoints": 1.33}},
		{"name": "Block", "style": "defensive", "attack_type": "Crush",
		 "xp": {"Defence": 4.0, "Hitpoints": 1.33}},
	]
	# unarmed: 3 styles
	WEAPON_STYLES["unarmed"] = [
		{"name": "Punch", "style": "accurate", "attack_type": "Crush",
		 "xp": {"Attack": 4.0, "Hitpoints": 1.33}},
		{"name": "Kick", "style": "aggressive", "attack_type": "Crush",
		 "xp": {"Strength": 4.0, "Hitpoints": 1.33}},
		{"name": "Block", "style": "defensive", "attack_type": "Crush",
		 "xp": {"Defence": 4.0, "Hitpoints": 1.33}},
	]


func get_styles_for_weapon() -> Array:
	var weapon = PlayerEquipment.call("get_weapon")
	var cat = "unarmed"
	if weapon != null:
		var wcat = weapon.get("weapon_category")
		if wcat != null and WEAPON_STYLES.has(wcat):
			cat = wcat
	return WEAPON_STYLES.get(cat, WEAPON_STYLES["unarmed"])


func get_current_style_info() -> Dictionary:
	var styles = get_styles_for_weapon()
	for s in styles:
		if s["style"] == current_style:
			return s
	# Fallback to first style if current not available for this weapon
	if styles.size() > 0:
		current_style = styles[0]["style"]
		return styles[0]
	return {"name": "Punch", "style": "accurate", "attack_type": "Crush",
		"xp": {"Attack": 4.0, "Hitpoints": 1.33}}


func set_style(style_name: String) -> void:
	var styles = get_styles_for_weapon()
	for s in styles:
		if s["style"] == style_name:
			current_style = style_name
			style_changed.emit()
			FileLogger.log_msg("CombatStyle: changed to %s (%s)" % [s["name"], style_name])
			return
	FileLogger.log_msg("CombatStyle: style %s not available" % style_name)


func get_invisible_boost() -> Dictionary:
	# Returns invisible level boosts based on current style
	# accurate: +3 Attack, aggressive: +3 Strength, defensive: +3 Defence
	# controlled: +1 Attack, +1 Strength, +1 Defence
	var info = get_current_style_info()
	var style = info.get("style", "accurate")
	if style == "accurate":
		return {"Attack": 3}
	elif style == "aggressive":
		return {"Strength": 3}
	elif style == "defensive":
		return {"Defence": 3}
	elif style == "controlled":
		return {"Attack": 1, "Strength": 1, "Defence": 1}
	return {}


func distribute_combat_xp(damage: int) -> void:
	if damage <= 0:
		return
	var info = get_current_style_info()
	var xp_map = info.get("xp", {})
	for skill_name in xp_map:
		var mult = xp_map[skill_name]
		var xp_amount = float(damage) * mult
		PlayerSkills.call("add_xp", skill_name, xp_amount)


func serialize() -> Dictionary:
	return {"current_style": current_style}


func deserialize(data: Dictionary) -> void:
	var saved = data.get("current_style", "accurate")
	current_style = saved
	FileLogger.log_msg("CombatStyle: deserialized style=%s" % current_style)
