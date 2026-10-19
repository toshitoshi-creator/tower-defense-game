class_name SafeArea
extends RefCounted
## Converts the device safe area (notch, status bar, home indicator) into
## margins in viewport (canvas) coordinates.


static func get_margins(viewport: Viewport) -> Dictionary:
	var margins := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return margins
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size.x <= 0.0:
		return margins
	var view := viewport.get_visible_rect().size
	var scale := view / window_size
	margins.left = safe.position.x * scale.x
	margins.top = safe.position.y * scale.y
	margins.right = (window_size.x - safe.end.x) * scale.x
	margins.bottom = (window_size.y - safe.end.y) * scale.y
	return margins
