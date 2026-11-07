@tool
extends MapaDecoracion
class_name MapaDecoracionHabitacion

@export var casa: int = 1

func capturar_original() -> bool:
	if _capturado:
		return true
	var datos: Dictionary = DatosHabitacionDecoracion.habitacion(casa)
	if datos.is_empty() or capa_fondo == null or capa_suelo == null or capa_superior == null \
		or datos_tiles == null or contenedor_sprites == null:
		return false
	var celdas: Dictionary = {}
	for y: int in int(datos["alto"]):
		for x: int in int(datos["ancho"]):
			var p: Vector2i = Vector2i(x, y)
			var atlas: Vector2i = capa_suelo.get_cell_atlas_coords(p)
			var clave: String = "%d:%d:%d:%d" % [capa_suelo.get_cell_source_id(p), atlas.x, atlas.y, capa_suelo.get_cell_alternative_tile(p)]
			if not datos["atlas_comportamientos"].has(clave):
				return false  # Tile editado desconocido: no inventar apoyos.
			var celda: Dictionary = (datos["celdas"][y * int(datos["ancho"]) + x] as Dictionary).duplicate(true)
			for campo: String in ["metatile_id", "tipo_capa_original", "colision_original", "elevacion_original"]:
				celda[campo] = int(celda[campo])
			celda["comportamiento"] = int(datos["atlas_comportamientos"][clave])
			celda["flags"] = datos_tiles.get_flags(Vector2(p))
			celda["superficie"] = SuperficiesDecoracion.tipo(int(celda["comportamiento"]))
			celdas[p] = celda
	for capa: TileMapLayer in _capas():
		_original_capas.append((capa.get("tile_map_data") as PackedByteArray).duplicate())
	_original_flags = datos_tiles.tile_data.duplicate(true)
	_original_celdas = celdas
	_celdas = celdas.duplicate(true)
	_capturado = true
	return true


func snapshot_validacion(jugador: Vector2i, externos: Array[Vector2i]) -> Dictionary:
	if not _capturado:
		return {}
	var datos: Dictionary = DatosHabitacionDecoracion.habitacion(casa)
	var objetos: Array[Vector2i] = externos.duplicate()
	for p: Vector2i in _celdas:
		if _celdas[p].has("copia_sprite") and not objetos.has(p):
			objetos.append(p)
	return {"contexto": &"habitacion", "casa": casa, "limites": Rect2i(0, 0, int(datos["ancho"]), int(datos["alto"])),
		"celdas": _celdas.duplicate(true), "jugador": jugador, "objetos": objetos}


func recomponer(colocaciones: Array[Dictionary]) -> StringName:
	if colocaciones.size() > SistemaBasesSecretas.LIMITE_HABITACION:
		return &"limite_colocaciones"
	for colocacion: Dictionary in colocaciones:
		var decoracion: Dictionary = DatosBasesSecretas.decoracion(int(colocacion.get("decoracion_id", -1)))
		if decoracion.get("categoria", "") not in ["MUNECOS", "COJINES"]:
			return &"no_admitida"
	return super.recomponer(colocaciones)
