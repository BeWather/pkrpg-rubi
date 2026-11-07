extends Node2D
## Reusable drawing templates. Timeline/ownership live in the sequence runner.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

var kind: String = "ring"
var progress: float = 0.0
var color := Color.WHITE
var extent := Vector2(240, 112)
var points: Array[Vector2] = []

func _draw() -> void:
	var pulse := sin(progress * PI)
	match kind:
		"impact":
			var star := PackedVector2Array()
			for i in 16:
				var radius := (13.0 if i % 2 == 0 else 5.0) * (0.6 + pulse * 0.4)
				star.append(Vector2.from_angle(i * TAU / 16.0) * radius)
			draw_colored_polygon(star, color)
		"barrier":
			draw_style_box(_barrier_style(color * Color(1, 1, 1, pulse)), Rect2(-22, -32, 44, 64))
			for i in 3:
				draw_line(Vector2(-20, -24 + i * 18), Vector2(20, -14 + i * 18), Color(1, 1, 1, pulse), 1)
		"rain":
			for point in points:
				var drop := Vector2(fposmod(point.x - progress * 100, extent.x), fposmod(point.y + progress * 240, extent.y))
				draw_line(drop, drop + Vector2(-3, 7), color, 1)
		"wave":
			if pulse < 0.001:
				return
			var poly := PackedVector2Array([Vector2(0, extent.y)])
			for x in range(0, int(extent.x) + 1, 4):
				var crest := extent.y * (1 - pulse * 0.65) + sin(x * 0.08 + progress * 20) * 5
				poly.append(Vector2(x, clampf(crest, 0, extent.y - 1)))
			poly.append(extent)
			draw_colored_polygon(poly, color)
		"beam":
			draw_line(Vector2.ZERO, extent, Color(color, pulse), 5 + pulse * 5)
			draw_line(Vector2.ZERO, extent, Color(1, 1, 1, pulse), 2)
		"darken":
			draw_rect(Rect2(Vector2.ZERO, extent), Color(color, color.a * pulse))
		"clap":
			for direction in [-1, 1]:
				var x: float = direction * (14 - pulse * 9)
				draw_rect(Rect2(x - 4, -8, 8, 16), color)
				for finger in 3:
					draw_line(Vector2(x - 3 + finger * 3, -8), Vector2(x - 3 + finger * 3, -14), color, 2)
		_:
			draw_arc(Vector2.ZERO, 4 + progress * 22, 0, TAU, 32, Color(color, 1 - progress), 2)

func _barrier_style(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint, tint.a * 0.3)
	style.border_color = tint
	style.set_border_width_all(2)
	return style
