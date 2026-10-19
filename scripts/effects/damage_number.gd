class_name DamageNumber
extends Label
## Floating damage popup. Capped so large fights don't flood the screen.

const MAX_ACTIVE := 40

static var _active: int = 0


static func spawn(layer: Node, at: Vector2, amount: int, is_ally_hurt: bool) -> void:
	if layer == null or not layer.is_inside_tree() or _active >= MAX_ACTIVE:
		return
	var label := DamageNumber.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color",
			Color(1.0, 0.55, 0.45) if is_ally_hurt else Color(1.0, 0.95, 0.5))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 18)
	label.position = at - Vector2(20, 9) + Vector2(randf_range(-4, 4), 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)


func _enter_tree() -> void:
	_active += 1


func _exit_tree() -> void:
	_active -= 1


func _ready() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 18.0, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
