class_name BattleLayout
extends RefCounted
## Shared, mutable description of the battlefield geometry (viewport coordinates).
## Updated in place when the screen size changes so every unit sees the new values.

var left: float = 0.0
var right: float = 390.0
## Y where enemies appear.
var spawn_y: float = 60.0
## Enemies reaching this line are attacking the base.
var base_line_y: float = 700.0
## Y where allies appear (just in front of the base).
var ally_spawn_y: float = 690.0
## Formation, from the wall upward: archers' home, the shields' defense line,
## the assault rally point. Archers never advance above archer_limit_y.
var archer_home_y: float = 660.0
var guard_y: float = 630.0
var rally_y: float = 580.0
var archer_limit_y: float = 470.0
## Soldiers go out to meet enemies only once they cross this line (mid-field).
var assault_limit_y: float = 300.0


func center_x() -> float:
	return (left + right) * 0.5


func clamp_x(x: float, margin: float) -> float:
	return clampf(x, left + margin, right - margin)
