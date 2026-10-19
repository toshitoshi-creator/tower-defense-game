class_name RouletteWheel
extends Control
## Clear-reward roulette. Slice sizes are proportional to the real odds (the weights in
## GameCatalog.ROULETTE). The result is decided before spinning; spin_to() only shows it.

signal spin_finished

const COLORS := [Color(0.85, 0.62, 0.2), Color(0.72, 0.45, 0.16)]
const ORB_COLOR := Color(0.45, 0.35, 0.9)

var coin_multiplier: float = 1.0
## Current rotation of the wheel, in radians.
var spin: float = 0.0:
	set(value):
		spin = value
		queue_redraw()

var _spinning: bool = false


func is_spinning() -> bool:
	return _spinning


## Segment centers, in wheel coordinates (0 = right, clockwise), before rotation.
func segment_center_angle(segment: int) -> float:
	var total := _total_weight()
	var start := 0.0
	for i in segment:
		start += TAU * int(GameCatalog.ROULETTE[i]["weight"]) / total
	return start + PI * int(GameCatalog.ROULETTE[segment]["weight"]) / total


## Spins a few turns and stops with `segment` under the pointer at the top.
func spin_to(segment: int, duration: float = 2.6) -> void:
	if _spinning:
		return
	_spinning = true
	var top := -PI / 2.0
	var target := top - segment_center_angle(segment)
	while target < spin + TAU * 4.0:
		target += TAU
	var tween := create_tween()
	tween.tween_property(self, "spin", target, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_stopped)


## The segment currently under the pointer.
func segment_at_pointer() -> int:
	var angle := fposmod(-PI / 2.0 - spin, TAU)
	var total := _total_weight()
	var start := 0.0
	for i in GameCatalog.ROULETTE.size():
		var width := TAU * int(GameCatalog.ROULETTE[i]["weight"]) / total
		if angle < start + width:
			return i
		start += width
	return GameCatalog.ROULETTE.size() - 1


func _on_stopped() -> void:
	_spinning = false
	spin_finished.emit()


func _total_weight() -> float:
	var total := 0.0
	for entry in GameCatalog.ROULETTE:
		total += int(entry["weight"])
	return total


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 6.0
	var font := get_theme_default_font()
	var total := _total_weight()
	var start := spin
	for i in GameCatalog.ROULETTE.size():
		var entry: Dictionary = GameCatalog.ROULETTE[i]
		var width := TAU * int(entry["weight"]) / total
		var points := PackedVector2Array([center])
		var steps := maxi(3, int(width * 20.0))
		for s in steps + 1:
			points.append(center + Vector2.from_angle(start + width * s / steps) * radius)
		var color: Color = ORB_COLOR if int(entry["orbs"]) > 0 else COLORS[i % 2]
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([center]), Color(0.1, 0.07, 0.05), 2.0)
		var label := "オーブ" if int(entry["orbs"]) > 0 else str(roundi(int(entry["coins"]) * coin_multiplier))
		draw_set_transform(center, start + width * 0.5)
		draw_string(font, Vector2(radius * 0.32, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		start += width
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.1, 0.07, 0.05), 3.0)
	draw_circle(center, 10.0, Color(0.95, 0.85, 0.5))
	# Pointer at the top.
	var tip := center + Vector2(0, -radius + 10)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -18), tip + Vector2(10, -18)]),
			Color(0.95, 0.25, 0.25))
