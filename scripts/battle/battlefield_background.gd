class_name BattlefieldBackground
extends Node2D
## Static pixel-style ground. Redrawn only when the screen size changes.

const TILE := 16.0

var _area := Rect2(0, 0, 390, 844)
var _field_top := 60.0
var _base_top := 700.0


func set_area(area: Rect2, field_top: float, base_top: float) -> void:
	_area = area
	_field_top = field_top
	_base_top = base_top
	queue_redraw()


func _draw() -> void:
	var grass_a := Color(0.27, 0.45, 0.24)
	var grass_b := Color(0.24, 0.41, 0.22)
	draw_rect(_area, grass_a)
	var y := 0.0
	var row := 0
	while y < _area.size.y:
		var x := TILE if row % 2 == 1 else 0.0
		while x < _area.size.x:
			draw_rect(Rect2(x, y, TILE, TILE), grass_b)
			x += TILE * 2.0
		y += TILE
		row += 1
	# Enemy gate area at the top.
	draw_rect(Rect2(0, 0, _area.size.x, _field_top + 24.0), Color(0.2, 0.17, 0.2))
	draw_rect(Rect2(0, _field_top + 20.0, _area.size.x, 4.0), Color(0.45, 0.15, 0.15))
	# Dirt road down the middle.
	var road_w := minf(140.0, _area.size.x * 0.36)
	draw_rect(Rect2(_area.size.x * 0.5 - road_w * 0.5, _field_top + 24.0, road_w,
			_base_top - _field_top - 24.0), Color(0.46, 0.36, 0.24, 0.55))
