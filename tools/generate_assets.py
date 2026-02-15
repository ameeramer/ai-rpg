#!/usr/bin/env python3
"""
Meshy AI 3D Asset Generator for AI RPG
Generates low-poly OSRS-style 3D models using the Meshy Text-to-3D API.
Downloads GLB files into the project's Assets/ directories.

Uses batch parallelism: submits all preview tasks, polls them all,
then submits all refine tasks, polls them all, then downloads everything.
"""

import json
import os
import sys
import time
import requests
from pathlib import Path

API_KEY = os.environ.get("MESHY_API_KEY", "msy_aYUfjthg9Ag91m5r8qJSQ5QdwKiay7QDQaIw")
BASE_URL = "https://api.meshy.ai/openapi/v2"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / "Assets"
STATE_FILE = PROJECT_ROOT / "tools" / ".generation_state.json"

POLL_INTERVAL = 10
MAX_POLL_TIME = 600

ASSETS = [
    # Characters
    {"name": "player_character", "prompt": "Low-poly fantasy RPG player character, medieval adventurer, simple humanoid warrior, Old School RuneScape style, blocky proportions, standing idle pose, no weapons equipped, game-ready character model", "negative_prompt": "high detail, realistic, photorealistic, complex, smooth, modern clothing", "output_dir": "Models/Characters", "filename": "player_character.glb", "target_polycount": 8000},
    # Enemies
    {"name": "goblin", "prompt": "Low-poly green goblin enemy, small humanoid creature, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, aggressive stance, pointy ears, game-ready enemy model", "negative_prompt": "high detail, realistic, photorealistic, smooth, complex", "output_dir": "Models/Enemies", "filename": "goblin.glb", "target_polycount": 5000},
    {"name": "skeleton", "prompt": "Low-poly skeleton warrior enemy, undead bones humanoid, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, standing menacingly, game-ready enemy model", "negative_prompt": "high detail, realistic, photorealistic, smooth, muscles, skin", "output_dir": "Models/Enemies", "filename": "skeleton.glb", "target_polycount": 5000},
    # Weapons
    {"name": "bronze_sword", "prompt": "Low-poly bronze sword, medieval fantasy short sword, brownish-orange metal blade, simple crossguard and grip, Old School RuneScape style weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex handle, glowing", "output_dir": "Models/Weapons", "filename": "bronze_sword.glb", "target_polycount": 2000},
    {"name": "iron_sword", "prompt": "Low-poly iron sword, medieval fantasy short sword, silver-grey metal blade, simple crossguard and grip, Old School RuneScape style weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex handle, glowing, golden", "output_dir": "Models/Weapons", "filename": "iron_sword.glb", "target_polycount": 2000},
    {"name": "bronze_axe", "prompt": "Low-poly bronze axe, medieval fantasy woodcutting axe, brownish-orange metal head with wooden handle, Old School RuneScape style tool weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, double-headed, glowing", "output_dir": "Models/Weapons", "filename": "bronze_axe.glb", "target_polycount": 2000},
    # Armor
    {"name": "bronze_platebody", "prompt": "Low-poly bronze platebody armor, medieval fantasy chest plate, brownish-orange metal torso armor, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex engravings, glowing", "output_dir": "Models/Armor", "filename": "bronze_platebody.glb", "target_polycount": 3000},
    {"name": "bronze_med_helm", "prompt": "Low-poly bronze medium helmet, medieval fantasy half-face helm, brownish-orange metal, Old School RuneScape style, game item headgear, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, full face cover, visor, complex", "output_dir": "Models/Armor", "filename": "bronze_med_helm.glb", "target_polycount": 2000},
    # Food
    {"name": "cooked_trout", "prompt": "Low-poly cooked fish trout, brown grilled fish, Old School RuneScape style food item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, raw, complex, restaurant", "output_dir": "Models/Food", "filename": "cooked_trout.glb", "target_polycount": 1500},
    {"name": "cooked_shrimps", "prompt": "Low-poly cooked shrimps, small orange-pink prawns, Old School RuneScape style food item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, raw, complex, restaurant", "output_dir": "Models/Food", "filename": "cooked_shrimps.glb", "target_polycount": 1500},
    # Items / Resources
    {"name": "logs", "prompt": "Low-poly wooden logs, stack of two simple brown wood logs, Old School RuneScape style resource item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex bark, forest, trees", "output_dir": "Models/Items", "filename": "logs.glb", "target_polycount": 1500},
    {"name": "oak_logs", "prompt": "Low-poly oak logs, stack of darker brown wood logs, slightly larger than normal logs, Old School RuneScape style resource item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex bark, forest, leaves", "output_dir": "Models/Items", "filename": "oak_logs.glb", "target_polycount": 1500},
    {"name": "raw_shrimps", "prompt": "Low-poly raw shrimps, small grey-pink uncooked prawns, Old School RuneScape style resource item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, cooked, complex, restaurant", "output_dir": "Models/Items", "filename": "raw_shrimps.glb", "target_polycount": 1500},
    {"name": "copper_ore", "prompt": "Low-poly copper ore chunk, brownish-orange rough rock with metallic veins, Old School RuneScape style mining resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, crystal, gem", "output_dir": "Models/Items", "filename": "copper_ore.glb", "target_polycount": 1500},
    {"name": "bones", "prompt": "Low-poly bones, simple white-beige skeletal remains, two crossed bones, Old School RuneScape style drop item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, skeleton, complex, skull", "output_dir": "Models/Items", "filename": "bones.glb", "target_polycount": 1000},
    {"name": "coins", "prompt": "Low-poly gold coins, small stack of shiny yellow gold coins, Old School RuneScape style currency, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex engravings, treasure chest", "output_dir": "Models/Items", "filename": "coins.glb", "target_polycount": 1500},
    # World / Environment
    {"name": "tree_normal", "prompt": "Low-poly fantasy tree, simple green canopy with brown trunk, Old School RuneScape style game environment object, deciduous tree, game-ready, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex leaves, autumn, dead", "output_dir": "Models/World", "filename": "tree_normal.glb", "target_polycount": 4000},
    {"name": "tree_oak", "prompt": "Low-poly large oak tree, wider green canopy with thick brown trunk, Old School RuneScape style game environment, big deciduous tree, game-ready, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex leaves, autumn, dead, thin", "output_dir": "Models/World", "filename": "tree_oak.glb", "target_polycount": 5000},
    {"name": "rock_copper", "prompt": "Low-poly copper mining rock, brownish-orange rocky formation with visible ore veins, Old School RuneScape style mining node, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, crystal, gem, complex", "output_dir": "Models/World", "filename": "rock_copper.glb", "target_polycount": 3000},
    {"name": "fishing_spot", "prompt": "Low-poly small circular pond with water ripples, fishing spot water feature, Old School RuneScape style, game environment, blue water surface, small rocks around edges, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ocean, complex, waterfall", "output_dir": "Models/World", "filename": "fishing_spot.glb", "target_polycount": 2000},
    {"name": "rock_depleted", "prompt": "Low-poly depleted grey rock, empty mining rock with no ore, dark grey rocky formation, Old School RuneScape style, game environment, mined out rock, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, colorful, ore veins, crystal", "output_dir": "Models/World", "filename": "rock_depleted.glb", "target_polycount": 2000},
    {"name": "tree_stump", "prompt": "Low-poly tree stump, cut brown wooden stump left after chopping a tree, Old School RuneScape style, game environment, small flat stump, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex roots, mushrooms, moss", "output_dir": "Models/World", "filename": "tree_stump.glb", "target_polycount": 1500},

    # ── BATCH 2: Additional Weapons ──
    {"name": "steel_sword", "prompt": "Low-poly steel sword, medieval fantasy short sword, bright silvery metal blade, simple crossguard and leather grip, Old School RuneScape style weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, glowing, magical", "output_dir": "Models/Weapons", "filename": "steel_sword.glb", "target_polycount": 2000},
    {"name": "rune_sword", "prompt": "Low-poly rune sword, medieval fantasy short sword, cyan-blue tinted metal blade, simple crossguard, Old School RuneScape style weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, glowing effects, complex", "output_dir": "Models/Weapons", "filename": "rune_sword.glb", "target_polycount": 2000},
    {"name": "iron_axe", "prompt": "Low-poly iron axe, medieval fantasy woodcutting axe, silver-grey metal head with wooden handle, Old School RuneScape style tool weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, double-headed, glowing", "output_dir": "Models/Weapons", "filename": "iron_axe.glb", "target_polycount": 2000},
    {"name": "steel_axe", "prompt": "Low-poly steel axe, medieval fantasy woodcutting axe, bright silvery metal head with wooden handle, Old School RuneScape style tool weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, double-headed, magical", "output_dir": "Models/Weapons", "filename": "steel_axe.glb", "target_polycount": 2000},
    {"name": "iron_dagger", "prompt": "Low-poly iron dagger, short stabbing knife, silver-grey metal blade with small grip, Old School RuneScape style weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, curved, magical", "output_dir": "Models/Weapons", "filename": "iron_dagger.glb", "target_polycount": 1500},
    {"name": "iron_mace", "prompt": "Low-poly iron mace, medieval fantasy flanged mace, silver-grey metal head with wooden handle, Old School RuneScape style weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, spiked ball, magical", "output_dir": "Models/Weapons", "filename": "iron_mace.glb", "target_polycount": 2000},
    {"name": "wooden_shield", "prompt": "Low-poly wooden shield, round medieval shield made of brown wood planks with metal rim, Old School RuneScape style, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, heraldry, glowing", "output_dir": "Models/Weapons", "filename": "wooden_shield.glb", "target_polycount": 2000},
    {"name": "iron_shield", "prompt": "Low-poly iron kiteshield, medieval fantasy kite-shaped shield, silver-grey metal, Old School RuneScape style defense equipment, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, heraldry, glowing, complex", "output_dir": "Models/Weapons", "filename": "iron_shield.glb", "target_polycount": 2500},
    {"name": "shortbow", "prompt": "Low-poly wooden shortbow, simple curved bow made of brown wood with bowstring, Old School RuneScape style ranged weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, compound bow, modern, magical", "output_dir": "Models/Weapons", "filename": "shortbow.glb", "target_polycount": 1500},
    {"name": "longbow", "prompt": "Low-poly wooden longbow, tall curved bow made of brown wood with bowstring, Old School RuneScape style ranged weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, compound bow, modern, magical", "output_dir": "Models/Weapons", "filename": "longbow.glb", "target_polycount": 1500},
    {"name": "staff", "prompt": "Low-poly wooden magic staff, long brown wooden rod with simple blue crystal on top, Old School RuneScape style magic weapon, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex runes, particle effects", "output_dir": "Models/Weapons", "filename": "staff.glb", "target_polycount": 2000},

    # ── BATCH 2: Additional Armor ──
    {"name": "iron_platebody", "prompt": "Low-poly iron platebody armor, medieval fantasy chest plate, silver-grey metal torso armor, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex engravings, glowing", "output_dir": "Models/Armor", "filename": "iron_platebody.glb", "target_polycount": 3000},
    {"name": "iron_med_helm", "prompt": "Low-poly iron medium helmet, medieval fantasy half-face helm, silver-grey metal, Old School RuneScape style, game item headgear, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, full face cover, visor", "output_dir": "Models/Armor", "filename": "iron_med_helm.glb", "target_polycount": 2000},
    {"name": "steel_platebody", "prompt": "Low-poly steel platebody armor, medieval fantasy chest plate, bright silvery metal torso armor, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex engravings, glowing", "output_dir": "Models/Armor", "filename": "steel_platebody.glb", "target_polycount": 3000},
    {"name": "steel_med_helm", "prompt": "Low-poly steel medium helmet, medieval fantasy half-face helm, bright silvery metal, Old School RuneScape style, game item headgear, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, full face cover, complex", "output_dir": "Models/Armor", "filename": "steel_med_helm.glb", "target_polycount": 2000},
    {"name": "leather_body", "prompt": "Low-poly leather body armor, simple brown leather torso vest, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, metal, plate armor", "output_dir": "Models/Armor", "filename": "leather_body.glb", "target_polycount": 2500},
    {"name": "leather_chaps", "prompt": "Low-poly leather chaps, simple brown leather leg armor, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, metal, plate armor", "output_dir": "Models/Armor", "filename": "leather_chaps.glb", "target_polycount": 2500},
    {"name": "bronze_platelegs", "prompt": "Low-poly bronze platelegs, medieval fantasy leg armor, brownish-orange metal greaves, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex engravings", "output_dir": "Models/Armor", "filename": "bronze_platelegs.glb", "target_polycount": 3000},
    {"name": "iron_platelegs", "prompt": "Low-poly iron platelegs, medieval fantasy leg armor, silver-grey metal greaves, Old School RuneScape style, game item equipment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, complex engravings", "output_dir": "Models/Armor", "filename": "iron_platelegs.glb", "target_polycount": 3000},

    # ── BATCH 2: Additional Enemies ──
    {"name": "giant_rat", "prompt": "Low-poly giant rat enemy, oversized brown rat creature, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, aggressive stance, game-ready enemy model", "negative_prompt": "high detail, realistic, photorealistic, smooth, cute, cartoon", "output_dir": "Models/Enemies", "filename": "giant_rat.glb", "target_polycount": 4000},
    {"name": "giant_spider", "prompt": "Low-poly giant spider enemy, large dark brown arachnid, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, eight legs, game-ready enemy model", "negative_prompt": "high detail, realistic, photorealistic, smooth, cute, furry", "output_dir": "Models/Enemies", "filename": "giant_spider.glb", "target_polycount": 5000},
    {"name": "zombie", "prompt": "Low-poly zombie enemy, undead humanoid with torn clothes and green-grey skin, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, shambling pose, game-ready", "negative_prompt": "high detail, realistic, photorealistic, smooth, gore, modern, blood", "output_dir": "Models/Enemies", "filename": "zombie.glb", "target_polycount": 5000},
    {"name": "dark_wizard", "prompt": "Low-poly dark wizard enemy, evil robed mage with dark purple cloak and pointed hat, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, casting pose, game-ready", "negative_prompt": "high detail, realistic, photorealistic, smooth, modern, complex staff", "output_dir": "Models/Enemies", "filename": "dark_wizard.glb", "target_polycount": 5000},
    {"name": "cow", "prompt": "Low-poly cow, simple brown and white dairy cow, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, standing idle, game-ready passive mob", "negative_prompt": "high detail, realistic, photorealistic, smooth, detailed hide pattern", "output_dir": "Models/Enemies", "filename": "cow.glb", "target_polycount": 5000},
    {"name": "chicken", "prompt": "Low-poly chicken, small white farm chicken with red comb, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, standing idle, game-ready passive mob", "negative_prompt": "high detail, realistic, photorealistic, smooth, feathers, detailed", "output_dir": "Models/Enemies", "filename": "chicken.glb", "target_polycount": 3000},

    # ── BATCH 2: Additional Food & Resources ──
    {"name": "bread", "prompt": "Low-poly bread loaf, simple brown baked bread roll, Old School RuneScape style food item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, sliced, complex, bakery", "output_dir": "Models/Food", "filename": "bread.glb", "target_polycount": 1000},
    {"name": "cooked_chicken", "prompt": "Low-poly cooked chicken drumstick, brown roasted chicken leg, Old School RuneScape style food item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, raw, complex, restaurant plate", "output_dir": "Models/Food", "filename": "cooked_chicken.glb", "target_polycount": 1500},
    {"name": "cooked_meat", "prompt": "Low-poly cooked meat, brown grilled steak piece, Old School RuneScape style food item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, raw, complex, restaurant plate", "output_dir": "Models/Food", "filename": "cooked_meat.glb", "target_polycount": 1500},
    {"name": "iron_ore", "prompt": "Low-poly iron ore chunk, dark grey rough rock with silver metallic veins, Old School RuneScape style mining resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, crystal, gem", "output_dir": "Models/Items", "filename": "iron_ore.glb", "target_polycount": 1500},
    {"name": "coal", "prompt": "Low-poly coal ore chunk, dark black rough rock, Old School RuneScape style mining resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, shiny, diamond", "output_dir": "Models/Items", "filename": "coal.glb", "target_polycount": 1000},
    {"name": "tin_ore", "prompt": "Low-poly tin ore chunk, light grey rough rock with silver veins, Old School RuneScape style mining resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, crystal, gem", "output_dir": "Models/Items", "filename": "tin_ore.glb", "target_polycount": 1500},
    {"name": "bronze_bar", "prompt": "Low-poly bronze bar, flat rectangular brownish-orange metal ingot, Old School RuneScape style crafting resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, complex shape, decorated", "output_dir": "Models/Items", "filename": "bronze_bar.glb", "target_polycount": 1000},
    {"name": "iron_bar", "prompt": "Low-poly iron bar, flat rectangular silver-grey metal ingot, Old School RuneScape style crafting resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, complex shape, decorated", "output_dir": "Models/Items", "filename": "iron_bar.glb", "target_polycount": 1000},
    {"name": "feather", "prompt": "Low-poly feather, single white bird feather, Old School RuneScape style item, simple game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex, quill pen, colorful", "output_dir": "Models/Items", "filename": "feather.glb", "target_polycount": 800},
    {"name": "raw_chicken", "prompt": "Low-poly raw chicken, uncooked pink chicken carcass, Old School RuneScape style resource item, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, cooked, brown, complex", "output_dir": "Models/Items", "filename": "raw_chicken.glb", "target_polycount": 1500},
    {"name": "cowhide", "prompt": "Low-poly cowhide, flat brown and white animal hide, Old School RuneScape style crafting resource, game item, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex, fur, 3D animal", "output_dir": "Models/Items", "filename": "cowhide.glb", "target_polycount": 1000},

    # ── BATCH 2: Additional World / Environment ──
    {"name": "tree_willow", "prompt": "Low-poly willow tree, drooping green branches with thin trunk, Old School RuneScape style game environment, weeping willow, game-ready, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex leaves, autumn, dead", "output_dir": "Models/World", "filename": "tree_willow.glb", "target_polycount": 5000},
    {"name": "rock_iron", "prompt": "Low-poly iron mining rock, dark grey-brown rocky formation with silver ore veins, Old School RuneScape style mining node, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, crystal, gem, complex", "output_dir": "Models/World", "filename": "rock_iron.glb", "target_polycount": 3000},
    {"name": "rock_tin", "prompt": "Low-poly tin mining rock, light grey rocky formation with silver-white ore veins, Old School RuneScape style mining node, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, crystal, gem, complex", "output_dir": "Models/World", "filename": "rock_tin.glb", "target_polycount": 3000},
    {"name": "rock_coal", "prompt": "Low-poly coal mining rock, dark black rocky formation with coal seams, Old School RuneScape style mining node, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, smooth, shiny, diamond, complex", "output_dir": "Models/World", "filename": "rock_coal.glb", "target_polycount": 3000},
    {"name": "furnace", "prompt": "Low-poly stone furnace, medieval smelting furnace with opening and chimney, Old School RuneScape style, game environment object, crafting station, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, industrial, complex machinery", "output_dir": "Models/World", "filename": "furnace.glb", "target_polycount": 4000},
    {"name": "anvil", "prompt": "Low-poly iron anvil, medieval blacksmith anvil on wooden block base, Old School RuneScape style, game environment object, crafting station, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, complex, decorative", "output_dir": "Models/World", "filename": "anvil.glb", "target_polycount": 2000},
    {"name": "cooking_range", "prompt": "Low-poly medieval cooking range, stone oven with fire opening, Old School RuneScape style, game environment object, cooking station, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern kitchen, microwave, complex", "output_dir": "Models/World", "filename": "cooking_range.glb", "target_polycount": 4000},
    {"name": "bank_booth", "prompt": "Low-poly bank booth counter, medieval wooden counter with bars window, Old School RuneScape style, game environment object, banking station, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern bank, ATM, complex", "output_dir": "Models/World", "filename": "bank_booth.glb", "target_polycount": 4000},
    {"name": "campfire", "prompt": "Low-poly campfire, small stone ring with burning wood logs and flames, Old School RuneScape style, game environment object, firemaking spot, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex, particle effects", "output_dir": "Models/World", "filename": "campfire.glb", "target_polycount": 2000},
    {"name": "chest", "prompt": "Low-poly treasure chest, medieval wooden chest with iron bands and latch, Old School RuneScape style, game environment object, loot container, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, ornate, gold, jewels, open", "output_dir": "Models/World", "filename": "chest.glb", "target_polycount": 2000},
    {"name": "fence_section", "prompt": "Low-poly wooden fence section, simple brown wood plank fence piece, Old School RuneScape style, game environment object, boundary, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, metal, complex, modern", "output_dir": "Models/World", "filename": "fence_section.glb", "target_polycount": 1500},
    {"name": "gate", "prompt": "Low-poly wooden gate, medieval brown wood double gate with iron hinges, Old School RuneScape style, game environment object, entrance, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, metal, modern, portcullis", "output_dir": "Models/World", "filename": "gate.glb", "target_polycount": 2000},
    {"name": "house_small", "prompt": "Low-poly small medieval house, simple stone and wood cottage with thatched roof, single door and window, Old School RuneScape style building, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, complex, skyscraper", "output_dir": "Models/World", "filename": "house_small.glb", "target_polycount": 6000},
    {"name": "shop_building", "prompt": "Low-poly medieval shop building, stone and wood market building with counter and sign, Old School RuneScape style, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, mall, complex", "output_dir": "Models/World", "filename": "shop_building.glb", "target_polycount": 6000},
    {"name": "bridge_wooden", "prompt": "Low-poly wooden bridge, simple brown plank bridge with rope railings spanning a gap, Old School RuneScape style, game environment, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, metal, suspension bridge", "output_dir": "Models/World", "filename": "bridge_wooden.glb", "target_polycount": 3000},
    {"name": "altar", "prompt": "Low-poly prayer altar, simple stone altar table with carved sides, Old School RuneScape style, game environment object, prayer training station, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, complex, ornate church", "output_dir": "Models/World", "filename": "altar.glb", "target_polycount": 2500},
    {"name": "signpost", "prompt": "Low-poly wooden signpost, medieval brown wood post with directional arrow signs, Old School RuneScape style, game environment object, navigation marker, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, metal, complex", "output_dir": "Models/World", "filename": "signpost.glb", "target_polycount": 1500},
    {"name": "bush", "prompt": "Low-poly green bush, simple round green shrub with brown stems, Old School RuneScape style, game environment decoration, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, complex leaves, flowers, tall", "output_dir": "Models/World", "filename": "bush.glb", "target_polycount": 2000},
    {"name": "well", "prompt": "Low-poly stone well, medieval circular stone well with wooden roof and bucket, Old School RuneScape style, game environment object, village decoration, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, complex, fountain", "output_dir": "Models/World", "filename": "well.glb", "target_polycount": 3000},
    {"name": "barrel", "prompt": "Low-poly wooden barrel, simple brown wood barrel with metal bands, Old School RuneScape style, game environment object, decoration, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, complex, wine bottle", "output_dir": "Models/World", "filename": "barrel.glb", "target_polycount": 1500},
    {"name": "crate", "prompt": "Low-poly wooden crate, simple brown wood shipping crate box, Old School RuneScape style, game environment object, decoration, isolated on blank background", "negative_prompt": "high detail, realistic, photorealistic, modern, cardboard, complex", "output_dir": "Models/World", "filename": "crate.glb", "target_polycount": 1000},

    # ── BATCH 2: NPCs ──
    {"name": "npc_shopkeeper", "prompt": "Low-poly NPC shopkeeper, medieval merchant with apron and friendly pose, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, standing behind counter, game-ready", "negative_prompt": "high detail, realistic, photorealistic, smooth, modern clothing", "output_dir": "Models/Characters", "filename": "npc_shopkeeper.glb", "target_polycount": 6000},
    {"name": "npc_guard", "prompt": "Low-poly NPC town guard, medieval soldier with iron armor and spear, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, standing at attention, game-ready", "negative_prompt": "high detail, realistic, photorealistic, smooth, modern military", "output_dir": "Models/Characters", "filename": "npc_guard.glb", "target_polycount": 6000},
    {"name": "npc_banker", "prompt": "Low-poly NPC banker, medieval money lender with formal robes, fantasy RPG style, Old School RuneScape aesthetic, blocky proportions, standing behind booth, game-ready", "negative_prompt": "high detail, realistic, photorealistic, smooth, modern suit", "output_dir": "Models/Characters", "filename": "npc_banker.glb", "target_polycount": 6000},
]


def load_state() -> dict:
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"completed": [], "preview_tasks": {}, "refine_tasks": {}}


def save_state(state: dict):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def create_preview(asset: dict) -> str | None:
    payload = {
        "mode": "preview",
        "prompt": asset["prompt"],
        "negative_prompt": asset.get("negative_prompt", ""),
        "art_style": "realistic",
        "target_polycount": asset.get("target_polycount", 5000),
        "topology": "triangle",
        "should_remesh": True,
    }
    try:
        resp = requests.post(f"{BASE_URL}/text-to-3d", headers=HEADERS, json=payload, timeout=30)
        if resp.status_code in (200, 202):
            task_id = resp.json().get("result")
            return task_id
        else:
            print(f"    ERROR: {resp.status_code} - {resp.text[:200]}")
            return None
    except Exception as e:
        print(f"    ERROR: {e}")
        return None


def create_refine(preview_id: str) -> str | None:
    payload = {
        "mode": "refine",
        "preview_task_id": preview_id,
        "enable_pbr": True,
    }
    try:
        resp = requests.post(f"{BASE_URL}/text-to-3d", headers=HEADERS, json=payload, timeout=30)
        if resp.status_code in (200, 202):
            return resp.json().get("result")
        else:
            print(f"    ERROR: {resp.status_code} - {resp.text[:200]}")
            return None
    except Exception as e:
        print(f"    ERROR: {e}")
        return None


def check_task(task_id: str) -> dict:
    try:
        resp = requests.get(f"{BASE_URL}/text-to-3d/{task_id}", headers=HEADERS, timeout=30)
        if resp.status_code == 200:
            return resp.json()
        return {"status": "ERROR", "task_error": resp.text[:200]}
    except Exception as e:
        return {"status": "ERROR", "task_error": str(e)}


def poll_batch(task_map: dict[str, str], stage: str) -> dict[str, dict]:
    """Poll all tasks in a batch until they all complete. Returns {name: task_data}."""
    results = {}
    pending = dict(task_map)  # name -> task_id
    start = time.time()

    while pending and (time.time() - start) < MAX_POLL_TIME:
        done_names = []
        for name, task_id in pending.items():
            data = check_task(task_id)
            status = data.get("status", "UNKNOWN")
            progress = data.get("progress", 0)

            if status == "SUCCEEDED":
                results[name] = data
                done_names.append(name)
                print(f"  [{stage}] {name}: DONE")
            elif status in ("FAILED", "CANCELED", "EXPIRED"):
                results[name] = None
                done_names.append(name)
                print(f"  [{stage}] {name}: {status} - {data.get('task_error', '')}")
            else:
                pass  # still running

        for n in done_names:
            del pending[n]

        if pending:
            remaining = [f"{n}({check_task(tid).get('progress', '?')}%)" for n, tid in list(pending.items())[:5]]
            extra = f" +{len(pending) - 5} more" if len(pending) > 5 else ""
            print(f"  [{stage}] Waiting: {', '.join(remaining)}{extra}")
            time.sleep(POLL_INTERVAL)

    # Mark remaining as failed
    for name in pending:
        results[name] = None
        print(f"  [{stage}] {name}: TIMEOUT")

    return results


def download_glb(url: str, output_path: Path) -> bool:
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        resp = requests.get(url, timeout=120, stream=True)
        if resp.status_code == 200:
            with open(output_path, "wb") as f:
                for chunk in resp.iter_content(chunk_size=8192):
                    f.write(chunk)
            size_kb = output_path.stat().st_size / 1024
            print(f"  Downloaded: {output_path.name} ({size_kb:.1f} KB)")
            return True
        print(f"  Download failed: {resp.status_code}")
        return False
    except Exception as e:
        print(f"  Download error: {e}")
        return False


def main():
    print("=" * 60)
    print("Meshy AI 3D Asset Generator for AI RPG")
    print(f"Total assets: {len(ASSETS)}")
    print("=" * 60)
    sys.stdout.flush()

    state = load_state()

    # Ensure directories
    for asset in ASSETS:
        (ASSETS_DIR / asset["output_dir"]).mkdir(parents=True, exist_ok=True)

    # Filter to assets that still need work
    to_generate = []
    for asset in ASSETS:
        name = asset["name"]
        output_path = ASSETS_DIR / asset["output_dir"] / asset["filename"]
        if name in state["completed"] and output_path.exists():
            print(f"  SKIP (done): {name}")
            continue
        to_generate.append(asset)

    if not to_generate:
        print("\nAll assets already generated!")
        return 0

    print(f"\nAssets to generate: {len(to_generate)}")
    sys.stdout.flush()

    # ── PHASE 1: Submit all preview tasks ──
    print("\n--- PHASE 1: Submitting preview tasks ---")
    sys.stdout.flush()
    preview_tasks = {}  # name -> task_id
    for asset in to_generate:
        name = asset["name"]
        # Check if we already have a preview task from a previous run
        if name in state.get("preview_tasks", {}):
            task_id = state["preview_tasks"][name]
            # Verify it still exists and is valid
            data = check_task(task_id)
            if data.get("status") == "SUCCEEDED":
                preview_tasks[name] = task_id
                print(f"  {name}: reusing previous preview {task_id}")
                sys.stdout.flush()
                continue

        task_id = create_preview(asset)
        if task_id:
            preview_tasks[name] = task_id
            state.setdefault("preview_tasks", {})[name] = task_id
            print(f"  {name}: submitted preview {task_id}")
        else:
            print(f"  {name}: FAILED to submit preview")
        sys.stdout.flush()
        time.sleep(0.5)  # small delay to avoid rate limiting

    save_state(state)

    # ── PHASE 2: Poll all preview tasks ──
    print(f"\n--- PHASE 2: Polling {len(preview_tasks)} preview tasks ---")
    sys.stdout.flush()
    preview_results = poll_batch(preview_tasks, "preview")

    # ── PHASE 3: Submit all refine tasks ──
    print("\n--- PHASE 3: Submitting refine tasks ---")
    sys.stdout.flush()
    refine_tasks = {}  # name -> task_id
    for name, data in preview_results.items():
        if data is None:
            print(f"  {name}: skipping refine (preview failed)")
            sys.stdout.flush()
            continue
        # Check for existing refine task
        if name in state.get("refine_tasks", {}):
            task_id = state["refine_tasks"][name]
            check = check_task(task_id)
            if check.get("status") == "SUCCEEDED":
                refine_tasks[name] = task_id
                print(f"  {name}: reusing previous refine {task_id}")
                sys.stdout.flush()
                continue

        preview_id = preview_tasks[name]
        task_id = create_refine(preview_id)
        if task_id:
            refine_tasks[name] = task_id
            state.setdefault("refine_tasks", {})[name] = task_id
            print(f"  {name}: submitted refine {task_id}")
        else:
            print(f"  {name}: FAILED to submit refine (will use preview)")
        sys.stdout.flush()
        time.sleep(0.5)

    save_state(state)

    # ── PHASE 4: Poll all refine tasks ──
    if refine_tasks:
        print(f"\n--- PHASE 4: Polling {len(refine_tasks)} refine tasks ---")
        sys.stdout.flush()
        refine_results = poll_batch(refine_tasks, "refine")
    else:
        refine_results = {}

    # ── PHASE 5: Download all models ──
    print("\n--- PHASE 5: Downloading models ---")
    sys.stdout.flush()
    asset_map = {a["name"]: a for a in ASSETS}
    successes = 0
    failures = 0

    for asset in to_generate:
        name = asset["name"]
        output_path = ASSETS_DIR / asset["output_dir"] / asset["filename"]

        # Try refined model first, fallback to preview
        glb_url = None
        if name in refine_results and refine_results[name]:
            glb_url = refine_results[name].get("model_urls", {}).get("glb")
        if not glb_url and name in preview_results and preview_results[name]:
            glb_url = preview_results[name].get("model_urls", {}).get("glb")
            if glb_url:
                print(f"  {name}: using preview model (refine unavailable)")

        if glb_url:
            if download_glb(glb_url, output_path):
                successes += 1
                state["completed"].append(name)
            else:
                failures += 1
        else:
            print(f"  {name}: NO model URL available")
            failures += 1
        sys.stdout.flush()

    save_state(state)

    print("\n" + "=" * 60)
    print(f"DONE: {successes} succeeded, {failures} failed")
    already = len(ASSETS) - len(to_generate)
    if already:
        print(f"  ({already} were already completed)")
    print("=" * 60)
    sys.stdout.flush()

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
