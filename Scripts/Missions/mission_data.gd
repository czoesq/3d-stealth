class_name MissionData
extends Resource

@export var id: String
@export var title: String
@export var description: String
@export var scene_path: String
@export var is_campaign: bool = false
@export var is_available: bool = false
@export var is_completed: bool = false
@export var mutually_exclusive_with_id: String = ""
@export var prerequisites: Array[String] = []
@export var rewards: Dictionary = {
	"money": 0,
	"xp": 0,
	"neural_stimulators": 0,
	"story_flags": {},
}
