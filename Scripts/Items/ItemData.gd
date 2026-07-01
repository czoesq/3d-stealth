extends Resource

enum SlotType { WEAPON, CONSUMABLE }

@export var item_name: String = "Item"
@export var description: String = ""
@export var slot_type: SlotType = SlotType.WEAPON
@export var icon: Texture2D
