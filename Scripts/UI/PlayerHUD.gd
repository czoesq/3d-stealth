extends CanvasLayer

var _stance_icon: TextureRect
var _stamina_bg: ColorRect
var _stamina_fill: ColorRect
var _health_bg: ColorRect
var _health_fill: ColorRect
var _player: Node
var _normal_stamina_color: Color = Color(1.0, 0.8, 0.0, 0.9)
var _full_health_color: Color = Color(0.0, 0.8, 0.2, 0.9)

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

	call_deferred("_layout")
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
	_on_movement_state("walk")
	_on_stamina(_player.stamina, _player.max_stamina)
	_on_health(_player.health, _player.max_health)


func _layout() -> void:
	var vs = get_viewport().size
	if vs.length_squared() <= 0.0:
		return
	var m := 20
	var icon_s := 48
	var bar_gap := 8

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


func _on_health(current: float, max_val: float) -> void:
	var pct := current / max_val
	_health_fill.size.x = _health_bg.size.x * pct
	if current >= max_val:
		_health_bg.modulate = Color(1, 1, 1, 0.3)
		_health_fill.modulate = Color(1, 1, 1, 0.3)
	else:
		_health_bg.modulate = Color.WHITE
		_health_fill.modulate = Color.WHITE
