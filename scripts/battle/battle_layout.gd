class_name BattleLayout
extends RefCounted
## Shared, mutable description of the battlefield geometry (viewport coordinates).
## Updated in place when the screen size changes so every unit sees the new values.

var left: float = 0.0
var right: float = 390.0
## Y where enemies appear.
var spawn_y: float = 60.0
## Allies never walk above this line.
var ally_stop_y: float = 70.0
## Enemies reaching this line are attacking the base.
var base_line_y: float = 700.0
## Y where allies appear (just in front of the base).
var ally_spawn_y: float = 690.0


func clamp_x(x: float, margin: float) -> float:
	return clampf(x, left + margin, right - margin)
