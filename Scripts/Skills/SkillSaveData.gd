class_name SkillSaveData
extends Resource

@export var skill_levels: Dictionary = {
	"stealth": 1,
	"hacking": 1,
	"subdue": 0,
	"awareness": 0,
	"gadgets": 0,
}

@export var skill_unlocked: Dictionary = {
	"stealth": true,
	"hacking": true,
	"subdue": false,
	"awareness": false,
	"gadgets": false,
}

@export var total_xp: int = 0

@export var neural_stimulators: int = 0
