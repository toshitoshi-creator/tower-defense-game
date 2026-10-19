class_name UnitIcon
extends Control
## Draws a unit's pixel-art placeholder inside UI (summon buttons).

@export var pixel_scale: int = 3

var data: UnitData


func set_unit(unit_data: UnitData) -> void:
	data = unit_data
	if data != null:
		custom_minimum_size = PixelArt.get_size(data.placeholder_pattern, pixel_scale)
	queue_redraw()


func _draw() -> void:
	if data != null:
		PixelArt.draw_unit(self, data, size * 0.5, pixel_scale)
