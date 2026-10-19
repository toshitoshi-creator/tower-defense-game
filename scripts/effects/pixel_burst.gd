class_name PixelBurst
extends Node2D
## A handful of square "pixels" flying outward and fading: hit sparks, death puffs,
## boss explosions. Globally capped so big fights stay cheap on phones.

const MAX_ACTIVE := 30

static var _active: int = 0

var _pieces: Array[Dictionary] = []
var _size: float = 3.0
var _progress: float = 0.0


static func spawn(layer: Node, at: Vector2, color: Color, count: int = 6, speed: float = 60.0,
		size: float = 3.0, duration: float = 0.35) -> void:
	if layer == null or not layer.is_inside_tree() or _active >= MAX_ACTIVE:
		return
	var burst := PixelBurst.new()
	burst.position = at
	burst._size = size
	for i in count:
		var angle := TAU * i / count + randf_range(-0.4, 0.4)
		burst._pieces.append({
			"dir": Vector2.from_angle(angle) * speed * randf_range(0.6, 1.2),
			"color": color.lerp(Color.WHITE, randf_range(0.0, 0.35)),
		})
	layer.add_child(burst)
	var tween := burst.create_tween()
	tween.tween_method(burst._set_progress, 0.0, 1.0, duration)
	tween.tween_callback(burst.queue_free)


func _enter_tree() -> void:
	_active += 1


func _exit_tree() -> void:
	_active -= 1


func _set_progress(value: float) -> void:
	_progress = value
	modulate.a = 1.0 - value * value
	queue_redraw()


func _draw() -> void:
	for piece in _pieces:
		var p: Vector2 = (piece["dir"] as Vector2) * _progress * 0.5
		draw_rect(Rect2(p.round() - Vector2(_size, _size) * 0.5, Vector2(_size, _size)), piece["color"])
