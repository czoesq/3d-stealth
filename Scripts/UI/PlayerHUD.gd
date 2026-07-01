extends CanvasLayer

var _stance_icon: TextureRect
var _stamina_bg: ColorRect
var _stamina_fill: ColorRect
var _health_bg: ColorRect
var _health_fill: ColorRect
var _player: Node
var _normal_stamina_color: Color = Color(1.0, 0.8, 0.0, 0.9)
var _full_health_color: Color = Color(0.0, 0.8, 0.2, 0.9)
var _item_notify: Label
var _notify_timer: float = 0.0

var _slot1_bg: ColorRect
var _slot1_icon: TextureRect
var _slot2_bg: ColorRect
var _slot2_icon: TextureRect
var _slot1_key: Label
var _slot2_key: Label
var _slot1_name: Label
var _slot2_name: Label

const ICON_CROUCH := preload("res://UI/HUD/icon-crouching.png")
const ICON_WALK := preload("res://UI/HUD/icon-walking.png")
const ICON_SPRINT := preload("res://UI/HUD/icon-sprinting.png")

func _ready() -> void:
	var root := Control.new()
	root.name = "HUDContainer"
	add_child(root)

	_stance_icon = TextureRect.new()
	_stance_icon.name = "StanceIcon"
	_stance_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stance_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(_stance_icon)

	_stamina_bg = ColorRect.new()
	_stamina_bg.name = "StaminaBg"
	_stamina_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	root.add_child(_stamina_bg)

	_stamina_fill = ColorRect.new()
	_stamina_fill.name = "StaminaFill"
	_stamina_fill.color = _normal_stamina_color
	root.add_child(_stamina_fill)

	_health_bg = ColorRect.new()
	_health_bg.name = "HealthBg"
	_health_bg.color = Color(0.12, 0.12, 0.12, 0.7)
	root.add_child(_health_bg)

	_health_fill = ColorRect.new()
	_health_fill.name = "HealthFill"
	_health_fill.color = _full_health_color
	root.add_child(_health_fill)

	_item_notify = Label.new()
	_item_notify.name = "ItemNotification"
	_item_notify.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_notify.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_item_notify.modulate = Color(1, 1, 0, 0)
	root.add_child(_item_notify)

	var slot_size := 40

	_slot1_bg = ColorRect.new()
	_slot1_bg.name = "Slot1Bg"
	_slot1_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_slot1_bg.custom_minimum_size = Vector2(slot_size, slot_size)
	root.add_child(_slot1_bg)

	_slot1_icon = TextureRect.new()
	_slot1_icon.name = "Slot1Icon"
	_slot1_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_slot1_icon.anchor_right = 1.0
	_slot1_icon.anchor_bottom = 1.0
	_slot1_icon.modulate = Color(1, 1, 1, 0.3)
	_slot1_bg.add_child(_slot1_icon)

	_slot1_key = Label.new()
	_slot1_key.name = "Slot1Key"
	_slot1_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot1_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot1_key.add_theme_font_size_override("font_size", 9)
	_slot1_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_slot1_key.add_theme_constant_override("shadow_offset_x", 1)
	_slot1_key.add_theme_constant_override("shadow_offset_y", 1)
	_slot1_key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_slot1_key.position = Vector2(0, 0)
	_slot1_key.size = Vector2(slot_size, slot_size)
	_slot1_key.text = "MB1"
	_slot1_bg.add_child(_slot1_key)

	_slot1_name = Label.new()
	_slot1_name.name = "Slot1Name"
	_slot1_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot1_name.add_theme_font_size_override("font_size", 10)
	_slot1_name.text = ""
	root.add_child(_slot1_name)

	_slot2_bg = ColorRect.new()
	_slot2_bg.name = "Slot2Bg"
	_slot2_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_slot2_bg.custom_minimum_size = Vector2(slot_size, slot_size)
	root.add_child(_slot2_bg)

	_slot2_icon = TextureRect.new()
	_slot2_icon.name = "Slot2Icon"
	_slot2_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_slot2_icon.anchor_right = 1.0
	_slot2_icon.anchor_bottom = 1.0
	_slot2_icon.modulate = Color(1, 1, 1, 0.3)
	_slot2_bg.add_child(_slot2_icon)

	_slot2_key = Label.new()
	_slot2_key.name = "Slot2Key"
	_slot2_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot2_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot2_key.add_theme_font_size_override("font_size", 9)
	_slot2_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_slot2_key.add_theme_constant_override("shadow_offset_x", 1)
	_slot2_key.add_theme_constant_override("shadow_offset_y", 1)
	_slot2_key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_slot2_key.position = Vector2(0, 0)
	_slot2_key.size = Vector2(slot_size, slot_size)
	_slot2_key.text = "F"
	_slot2_bg.add_child(_slot2_key)

	_slot2_name = Label.new()
	_slot2_name.name = "Slot2Name"
	_slot2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot2_name.add_theme_font_size_override("font_size", 10)
	_slot2_name.text = ""
	root.add_child(_slot2_name)

	_layout()
	get_viewport().size_changed.connect(_layout)

	call_deferred("_find_player")


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_player = players[0]
	_player.movement_state_changed.connect(_on_movement_state)
	_player.stamina_changed.connect(_on_stamina)
	_player.stamina_depleted.connect(_on_stamina_depleted)
	_player.health_changed.connect(_on_health)
	if _player.has_signal("item_collected"):
		_player.item_collected.connect(_on_item_collected)
	_player.weapon_changed.connect(_on_weapon_changed)
	_player.consumable_changed.connect(_on_consumable_changed)
	_player.weapon_activated.connect(_on_weapon_activated)
	_player.consumable_activated.connect(_on_consumable_activated)
	_on_movement_state("walk")
	_on_stamina(_player.stamina, _player.max_stamina)
	_on_health(_player.health, _player.max_health)
	_on_weapon_changed(_player.get_current_weapon())
	_on_consumable_changed(_player.get_current_consumable())


func _layout() -> void:
	var vs = get_viewport().size
	if vs.length_squared() <= 0.0:
		return
	var m := 20
	var icon_s := 48
	var bar_gap := 8

	_item_notify.position = Vector2(0, vs.y * 0.4)
	_item_notify.size = Vector2(vs.x, 40)
	_item_notify.add_theme_font_size_override("font_size", 28)

	_stance_icon.position = Vector2(m, vs.y - m - icon_s)
	_stance_icon.size = Vector2(icon_s, icon_s)

	var sw := 140
	var sh := 12
	_stamina_bg.position = Vector2(m + icon_s + bar_gap, vs.y - m - sh)
	_stamina_bg.size = Vector2(sw, sh)
	_stamina_fill.position = _stamina_bg.position
	_stamina_fill.size = Vector2(sw, sh)

	var hw := 200
	var hh := 16
	_health_bg.position = Vector2(m, _stamina_bg.position.y + sh + 4)
	_health_bg.size = Vector2(hw, hh)
	_health_fill.position = _health_bg.position
	_health_fill.size = Vector2(hw, hh)

	var slot_s := 40
	var name_h := 16
	var slot_gap := 8
	var slot1_x := _health_bg.position.x + hw + slot_gap
	var slot1_y := _health_bg.position.y - 50
	_slot1_bg.position = Vector2(slot1_x, slot1_y)
	_slot1_bg.size = Vector2(slot_s, slot_s)
	_slot1_name.position = Vector2(slot1_x, slot1_y + slot_s)
	_slot1_name.size = Vector2(slot_s, name_h)

	var slot2_x := slot1_x + slot_s + slot_gap
	_slot2_bg.position = Vector2(slot2_x, slot1_y)
	_slot2_bg.size = Vector2(slot_s, slot_s)
	_slot2_name.position = Vector2(slot2_x, slot1_y + slot_s)
	_slot2_name.size = Vector2(slot_s, name_h)


func _on_movement_state(s: String) -> void:
	match s:
		"crouch":
			_stance_icon.texture = ICON_CROUCH
		"sprint":
			_stance_icon.texture = ICON_SPRINT
		_:
			_stance_icon.texture = ICON_WALK


func _on_stamina(current: float, max_val: float) -> void:
	var pct := current / max_val
	_stamina_fill.size.x = _stamina_bg.size.x * pct
	if current >= max_val:
		_stamina_bg.hide()
		_stamina_fill.hide()
	else:
		_stamina_bg.show()
		_stamina_fill.show()


func _on_stamina_depleted() -> void:
	var tween := create_tween()
	tween.tween_property(_stamina_fill, "color", Color.WHITE, 0.1)
	tween.tween_property(_stamina_fill, "color", _normal_stamina_color, 0.4)


func _on_item_collected(item_name: String) -> void:
	_item_notify.text = "Got " + item_name + "!"
	_item_notify.modulate = Color(1, 1, 0, 1)
	_notify_timer = 2.0


func _process(delta: float) -> void:
	if _notify_timer > 0.0:
		_notify_timer -= delta
		if _notify_timer <= 0.5:
			_item_notify.modulate.a = maxf(_notify_timer / 0.5, 0.0)
		if _notify_timer <= 0.0:
			_item_notify.modulate.a = 0.0


func _on_health(current: float, max_val: float) -> void:
	var pct := current / max_val
	_health_fill.size.x = _health_bg.size.x * pct
	if current >= max_val:
		_health_bg.modulate = Color(1, 1, 1, 0.3)
		_health_fill.modulate = Color(1, 1, 1, 0.3)
	else:
		_health_bg.modulate = Color.WHITE
		_health_fill.modulate = Color.WHITE


func _make_placeholder_tex(color: Color) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _on_weapon_changed(item_name: String) -> void:
	if item_name.is_empty():
		_slot1_icon.modulate = Color(1, 1, 1, 0.3)
		_slot1_name.text = ""
	else:
		_slot1_icon.texture = _make_placeholder_tex(Color(0.3, 0.5, 1.0, 1.0))
		_slot1_icon.modulate = Color.WHITE
		_slot1_name.text = item_name


func _on_consumable_changed(item_name: String) -> void:
	if item_name.is_empty():
		_slot2_icon.modulate = Color(1, 1, 1, 0.3)
		_slot2_name.text = ""
	else:
		_slot2_icon.texture = _make_placeholder_tex(Color(0.3, 1.0, 0.5, 1.0))
		_slot2_icon.modulate = Color.WHITE
		_slot2_name.text = item_name


func _flash_slot(node: CanvasItem) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, 0.05)
	tween.tween_property(node, "modulate", Color(2, 2, 2, 1), 0.05)
	tween.tween_property(node, "modulate", Color.WHITE, 0.1)


func _on_weapon_activated(_item_name: String) -> void:
	if _slot1_icon.texture:
		_flash_slot(_slot1_icon)


func _on_consumable_activated(_item_name: String) -> void:
	if _slot2_icon.texture:
		_flash_slot(_slot2_icon)
