class_name PixelArt
extends RefCounted
## Procedural pixel-art placeholders, shared by in-battle units and UI icons.
## Replace with real SpriteFrames via UnitData.sprite_frames when art is ready.

## 12-wide pixel maps. Keys: o outline, h helmet/armor, s skin, g goblin skin, e eye,
## r red eye, k wood, w steel, b body (UnitData.body_color), a accent (UnitData.accent_color).
const PATTERNS := {
	&"soldier": [
		"....oooo....",
		"...ohhhho...",
		"..ohhhhhho..",
		"..osssssso..",
		"..osesseso..",
		"...osssso...",
		"..oobbbboo.w",
		".obbbaabbbow",
		".osbbaabbsow",
		".oobbbbbboow",
		"...oaaaao.w.",
		"...obbbbo...",
		"...obo.obo..",
		"...ooo.ooo..",
	],
	&"archer": [
		"....oooo....",
		"...obbbbo.k.",
		"..obbbbbbo.k",
		"..obssssbo.k",
		"..obessebo.k",
		"...osssso.k.",
		"..obbbbbbok.",
		".obbaabbbbsk",
		".osbaabbbo.k",
		"..obbbbbbo.k",
		"...oaaaao.k.",
		"...obbbbok..",
		"...obo.obo..",
		"...ooo.ooo..",
	],
	&"shield": [
		"...oooooo...",
		"..ohhhhhho..",
		"..ohhhhhho..",
		"..ohssssho..",
		"..ohesseho..",
		"ooooohhhhoo.",
		"oaaaobbbbbo.",
		"oawaobbbbbbo",
		"oawaobbbbbbo",
		"oaaaobbbbbo.",
		".oaaohhhho..",
		"..ooobbbbo..",
		"....obo.obo.",
		"....ooo.ooo.",
	],
	&"spearman": [
		"....oooo..w.",
		"...ohhhho.w.",
		"..ohhhhhhok.",
		"..ossssssok.",
		"..osessesok.",
		"...osssso.k.",
		"..oobbbbook.",
		".obbbaabbbk.",
		".osbbaabbsk.",
		".oobbbbbbok.",
		"...oaaaao.k.",
		"...obbbbo.k.",
		"...obo.obok.",
		"...ooo.oook.",
	],
	&"knight": [
		"....oaao....",
		"...ohhhho...",
		"..ohhhhhho..",
		"..osssssso..",
		"..osesseso..",
		"...osssso...",
		"..oohhhhoo.w",
		".ohhhaahhhow",
		".oshhaahhsow",
		".oohhhhhhoow",
		"...oaaaao.w.",
		"...ohhhho...",
		"...obo.obo..",
		"...ooo.ooo..",
	],
	&"heavy": [
		"...oooooo...",
		"..ohhhhhho..",
		"..ohhhhhho..",
		"..ohhhhhho..",
		"..oheeeeho..",
		"ooooohhhhoo.",
		"oaaaobbbbbo.",
		"oawaobbbbbbo",
		"oawaobbbbbbo",
		"oaaaobbbbbo.",
		".oaaohhhho..",
		"..ooobbbbo..",
		"....obo.obo.",
		"....ooo.ooo.",
	],
	&"mage": [
		".....oo.....",
		"....obbo..a.",
		"...obbbbo.a.",
		"..obssssbok.",
		"..obessebok.",
		"...osssso.k.",
		"..obbbbbbok.",
		".obbaabbbbk.",
		".osbaabbbok.",
		"..obbbbbbok.",
		"...oaaaao.k.",
		"...obbbbo.k.",
		"...obo.obok.",
		"...ooo.ooo..",
	],
	&"healer": [
		"....oooo....",
		"...obbbbo.a.",
		"..obbbbbboa.",
		"..obssssbok.",
		"..obessebok.",
		"...osssso.k.",
		"..obbbbbbok.",
		".obbaabbbbk.",
		".osbaabbbok.",
		"..obbbbbbok.",
		"...oaaaao.k.",
		"...obbbbo.k.",
		"...obo.obok.",
		"...ooo.ooo..",
	],
	&"goblin": [
		"...oooooo...",
		"o.oggggggo.o",
		"ogoggggggogo",
		".ooggggggoo.",
		"..ogrggrgo..",
		"...oggggo...",
		"..obbbbbbo..",
		".obbabbabbo.",
		"ogobbbbbbogo",
		"..oaaaaaao..",
		"..obbbbbbo..",
		"..ogo..ogo..",
		"..ooo..ooo..",
	],
	&"brute": [
		"...oooooo...",
		"..ohhhhhho..",
		"..ogrggrgo..",
		"..oggwwggo..",
		".oohhhhhhoo.",
		"ohhhhhhhhhho",
		"ogohhaahhogo",
		"ogohhhhhhogo",
		"...oaaaao...",
		"..obbo.obbo.",
		"..oooo.oooo.",
	],
	&"ogre": [
		"..w......w..",
		"..woooooow..",
		"..obbbbbbo..",
		".obbrbbrbbo.",
		".obbbbbbbbo.",
		".obbwbbwbbo.",
		"..obbbbbbo..",
		"oobbbbbbbboo",
		"obbbbbbbbbbo",
		"obobaaaabobo",
		"oo.oaaaao.oo",
		"...obbbbo...",
		"..obbo.obbo.",
		"..oooo.oooo.",
	],
	&"demon_king": [
		"..a.a..a.a..",
		"..aaaaaaaa..",
		"..oaaaaaao..",
		"..obbbbbbo..",
		"..obrbbrbo..",
		"o..obbbbo..o",
		"oo.obbbbo.oo",
		"obooaaaaoobo",
		"obbbbbbbbbbo",
		"obobbaabbobo",
		".o.obbbbo.o.",
		"...obbbbo...",
		"..obbo.obbo.",
		"..oooo.oooo.",
	],
}
const FIXED_COLORS := {
	"o": Color(0.08, 0.07, 0.1),
	"h": Color(0.62, 0.66, 0.72),
	"s": Color(0.96, 0.78, 0.6),
	"g": Color(0.45, 0.72, 0.3),
	"e": Color(0.1, 0.1, 0.15),
	"r": Color(1.0, 0.25, 0.2),
	"k": Color(0.55, 0.36, 0.18),
	"w": Color(0.86, 0.9, 0.95),
}


static func get_rows(pattern: StringName) -> Array:
	return PATTERNS.get(pattern, PATTERNS[&"soldier"])


static func get_size(pattern: StringName, pixel_scale: int) -> Vector2:
	var rows := get_rows(pattern)
	return Vector2((rows[0] as String).length(), rows.size()) * pixel_scale


static func make_palette(data: UnitData) -> Dictionary:
	var palette := FIXED_COLORS.duplicate()
	palette["b"] = data.body_color
	palette["a"] = data.accent_color
	return palette


## Draws the unit's pattern centered on `center` into any CanvasItem's _draw().
static func draw_unit(canvas: CanvasItem, data: UnitData, center: Vector2, pixel_scale: int) -> void:
	var rows := get_rows(data.placeholder_pattern)
	var palette := make_palette(data)
	var origin := (center - get_size(data.placeholder_pattern, pixel_scale) * 0.5).floor()
	var px := Vector2(pixel_scale, pixel_scale)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if palette.has(key):
				canvas.draw_rect(Rect2(origin + Vector2(x, y) * pixel_scale, px), palette[key])


# ---------------------------------------------------------------- animated sprites

## Animation names shared by generated placeholders and real art (UnitData.sprite_frames).
const ANIM_IDLE := &"idle"
const ANIM_MOVE := &"move"
const ANIM_ATTACK := &"attack"
const ANIM_HURT := &"hurt"
const ANIM_DEATH := &"death"
## Rows at the bottom of every pattern that are legs (used by the walk frame).
const LEG_ROWS := 2

## One SpriteFrames per pattern + colors, shared by every unit that uses it.
static var _frames_cache: Dictionary = {}


## Placeholder animations generated from the pattern, at 1 texel per pattern pixel
## (display with scale = pixel_scale and nearest filtering).
static func build_sprite_frames(data: UnitData) -> SpriteFrames:
	var key := "%s|%s|%s" % [data.placeholder_pattern, data.body_color.to_html(), data.accent_color.to_html()]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var base := _padded(get_rows(data.placeholder_pattern))
	var palette := make_palette(data)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_anim(frames, ANIM_IDLE, [base, _breathe(base)], palette, 2.0, true)
	_add_anim(frames, ANIM_MOVE, [base, _step(base)], palette, 6.0, true)
	_add_anim(frames, ANIM_ATTACK, [_shift(base, 0, -1), base], palette, 10.0, false)
	_add_anim(frames, ANIM_HURT, [base], palette, 10.0, false, 0.65)
	_add_anim(frames, ANIM_DEATH, [base, _squash(base, 3), _squash(base, 2)], palette, 10.0, false)
	_frames_cache[key] = frames
	return frames


static func _add_anim(frames: SpriteFrames, anim: StringName, frame_rows: Array, palette: Dictionary,
		fps: float, loop: bool, whiten: float = 0.0) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for rows in frame_rows:
		frames.add_frame(anim, _to_texture(rows, palette, whiten))


static func _to_texture(rows: Array, palette: Dictionary, whiten: float) -> ImageTexture:
	var image := Image.create((rows[0] as String).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if palette.has(row[x]):
				image.set_pixel(x, y, (palette[row[x]] as Color).lerp(Color.WHITE, whiten))
	return ImageTexture.create_from_image(image)


## One transparent pixel of margin on every side, so frames can shift without clipping.
static func _padded(rows: Array) -> Array:
	var width := (rows[0] as String).length() + 2
	var out := [".".repeat(width)]
	for r in rows:
		out.append("." + r + ".")
	out.append(".".repeat(width))
	return out


static func _shift(rows: Array, dx: int, dy: int) -> Array:
	var width := (rows[0] as String).length()
	var out := []
	for y in rows.size():
		var src_y := y - dy
		var line := ""
		for x in width:
			var src_x := x - dx
			var inside := src_y >= 0 and src_y < rows.size() and src_x >= 0 and src_x < width
			line += (rows[src_y] as String)[src_x] if inside else "."
		out.append(line)
	return out


## Upper body sinks one pixel onto the legs.
static func _breathe(rows: Array) -> Array:
	var legs_start := rows.size() - 1 - LEG_ROWS
	var out := rows.duplicate()
	for y in range(legs_start - 1, 0, -1):
		out[y] = rows[y - 1]
	return out


## Walking frame: the two legs step toward each other.
static func _step(rows: Array) -> Array:
	var width := (rows[0] as String).length()
	var half := width / 2.0
	var out := rows.duplicate()
	for y in range(rows.size() - 1 - LEG_ROWS, rows.size() - 1):
		var row: String = rows[y]
		var line := ""
		for x in width:
			var src_x := x - 1 if x < half else x + 1
			line += row[src_x] if src_x >= 0 and src_x < width and (src_x < half) == (x < half) else "."
		out[y] = line
	return out


## Death squash: drops every n-th row and lets the rest sit on the feet.
static func _squash(rows: Array, drop_every: int) -> Array:
	var kept := []
	for y in rows.size():
		if y % drop_every != 0:
			kept.append(rows[y])
	var width := (rows[0] as String).length()
	var out := []
	for i in rows.size() - kept.size():
		out.append(".".repeat(width))
	out.append_array(kept)
	return out
