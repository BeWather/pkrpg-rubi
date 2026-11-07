extends Node2D
class_name PreviewDecoracion

## Dibuja en pantalla desde el mapa; nunca compone terreno o crea object events.
var mapa: Node2D
var decoracion_id: int = -1
var ancla: Vector2i
var permitido: bool = false
var _sprite: Node2D
var solo_cursor: bool = false


func _ready() -> void:
	process_priority = 101  # Después de la cámara real (100), sin desfase del sprite.


func preparar(interior: Node2D, id: int) -> void:
	limpiar()
	mapa = interior
	decoracion_id = id
	var ruta: String = str(DatosGraficosDecoracion.decoracion(id).get("escena", ""))
	if not ruta.is_empty():
		_sprite = (load(ruta) as PackedScene).instantiate() as Node2D
		add_child(_sprite)  # Únicamente PackedScene original del adorno dinámico.
	show()


func limpiar() -> void:
	if is_instance_valid(_sprite):
		_sprite.free()
	_sprite = null
	decoracion_id = -1
	mapa = null
	solo_cursor = false
	hide()
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(mapa):
		return
	if is_instance_valid(_sprite):
		_sprite.position = _pantalla(Vector2(ancla) * 16 + Vector2(8, 16))
	queue_redraw()


func _pantalla(posicion: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * (mapa.get_global_transform_with_canvas() * posicion)


func _draw() -> void:
	if not is_instance_valid(mapa):
		return
	if solo_cursor:
		draw_rect(Rect2(_pantalla(Vector2(ancla) * 16), Vector2(16, 16)), Color(0.937255, 0.431373, 0.376471), false, 1)
		return
	if decoracion_id < 0:
		return
	var datos: Dictionary = DatosBasesSecretas.decoracion(decoracion_id)
	var plan: Dictionary = ValidadorDecoracion.preparar_huella(decoracion_id, ancla)
	if datos["tipo_grafico"] != "sprite":
		var capas: Array[TileMapLayer] = mapa.mapa_decoracion._capas()
		for i: int in plan["huella_grafica"].size():
			var celda: Vector2i = plan["huella_grafica"][i]
			var id: int = 512 + int(datos["graficos_originales"][i])
			if datos["permiso"] != "NA_WALL" and int(mapa.mapa_decoracion.obtener_celda(celda).get("comportamiento", -1)) == SuperficiesDecoracion.MB_NORTH_WALL:
				id += 1
			var atlas: Vector2i = DatosInterioresBases.atlas_metatile(id)
			for fuente: int in 3:
				var textura: Texture2D = (capas[fuente].tile_set.get_source(fuente) as TileSetAtlasSource).texture
				draw_texture_rect_region(textura, Rect2(_pantalla(Vector2(celda) * 16), Vector2(16, 16)), Rect2(Vector2(atlas) * 16, Vector2(16, 16)))
	var tamano: Vector2i = plan["tamano"]
	var arriba: Vector2i = ancla + Vector2i(0, 1 - tamano.y)
	draw_rect(Rect2(_pantalla(Vector2(arriba) * 16), Vector2(tamano) * 16), Color(0.2, 1, 0.3) if permitido else Color(1, 0.3, 0.2), false, 1)
