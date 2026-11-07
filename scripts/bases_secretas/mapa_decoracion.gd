@tool
extends Node
class_name MapaDecoracion

## Compositor de una escena declarativa: NO crea capas, contenedores ni UI.
## Solo instancia PackedScene de muebles dinámicos y modifica celdas existentes.
## recomponer() recibe colocaciones ya validadas por terreno (fase 5).
const MAX_SPRITES: int = SistemaBasesSecretas.LIMITE_SPRITES

@export var interior_id: int = -1
@export var capa_fondo: TileMapLayer
@export var capa_suelo: TileMapLayer
@export var capa_superior: TileMapLayer
@export var datos_tiles: TPTileDataMap
@export var contenedor_sprites: Node2D

var _capturado: bool = false
var _original_capas: Array[PackedByteArray] = []
var _original_flags: Dictionary = {}
var _original_celdas: Dictionary = {}
var _celdas: Dictionary = {}
var _sprites: Array[Node2D] = []


func _ready() -> void:
	capturar_original()


## Snapshot de la escena, incluidas ediciones de tiles/flags hechas en el editor.
## No recapturar después de componer: convertiría los muebles en suelo original.
func capturar_original() -> bool:
	if _capturado:
		return true
	var datos: Dictionary = DatosInterioresBases.interior(interior_id)
	if datos.is_empty() or capa_fondo == null or capa_suelo == null \
		or capa_superior == null or datos_tiles == null or contenedor_sprites == null:
		return false
	for capa: TileMapLayer in _capas():
		var bytes: PackedByteArray = capa.get("tile_map_data")
		_original_capas.append(bytes.duplicate())
	_original_flags = datos_tiles.tile_data.duplicate(true)
	for y: int in int(datos["alto"]):
		for x: int in int(datos["ancho"]):
			var posicion: Vector2i = Vector2i(x, y)
			var celda: Dictionary = DatosInterioresBases.celda(interior_id, posicion)
			if capa_suelo.get_cell_source_id(posicion) == 1:
				var id_tile: int = DatosInterioresBases.id_desde_atlas(capa_suelo.get_cell_atlas_coords(posicion))
				var meta: Dictionary = DatosInterioresBases.metatile(id_tile)
				if not meta.is_empty():
					celda["metatile_id"] = id_tile
					celda["comportamiento"] = int(meta["comportamiento"])
			celda["flags"] = datos_tiles.get_flags(Vector2(posicion))
			if (int(celda["colision_original"]) != 0) != datos_tiles.has_flag(Vector2(posicion), TPTileDataMap.Flags.BLOQUEO):
				celda["colision_original"] = 3 if datos_tiles.has_flag(Vector2(posicion), TPTileDataMap.Flags.BLOQUEO) else 0
			celda["superficie"] = SuperficiesDecoracion.tipo(int(celda["comportamiento"]))
			_original_celdas[posicion] = celda
	_celdas = _original_celdas.duplicate(true)
	_capturado = true
	return true


func obtener_celda(posicion: Vector2i) -> Dictionary:
	return (_celdas.get(posicion, {}) as Dictionary).duplicate(true)


## Adaptador de lectura para el validador. Exige captura/composición previa.
## El editor debe aportar TODOS los objetos activos ajenos al compositor,
## en coordenadas locales de celdas (cualquier elevación: consulta GBA z=0).
## No deduce ocupación de BLOQUEO ni confunde marcadores PC/warp con object events.
func snapshot_validacion(jugador: Vector2i, objetos_externos: Array[Vector2i]) -> Dictionary:
	if not _capturado:
		return {}
	var datos: Dictionary = DatosInterioresBases.interior(interior_id)
	var objetos: Array[Vector2i] = objetos_externos.duplicate()
	for posicion: Vector2i in _celdas:
		if _celdas[posicion].has("copia_sprite") and not objetos.has(posicion):
			objetos.append(posicion)
	return {"contexto": SistemaBasesSecretas.CONTEXTO_BASE, "interior_id": interior_id,
		"limites": Rect2i(0, 0, int(datos["ancho"]), int(datos["alto"])),
		"celdas": _celdas.duplicate(true), "jugador": jugador, "objetos": objetos}


## Planifica sin mutar la escena. Un registro roto no deja restauración a medias.
func recomponer(colocaciones: Array[Dictionary]) -> StringName:
	if not capturar_original():
		return &"mapa_no_configurado"
	var candidatas: Dictionary = _original_celdas.duplicate(true)
	var copias: Dictionary = {}
	var planes_sprites: Array[Dictionary] = []
	# Rubí reconstruye primero metatiles, después object events (muñecos/cojines).
	for colocacion: Dictionary in colocaciones:
		var copia: Variant = colocacion.get("copia_id")
		var id_decoracion: Variant = colocacion.get("decoracion_id")
		var x: Variant = colocacion.get("x")
		var y: Variant = colocacion.get("y")
		if not copia is int or copia <= 0 or copias.has(copia) or not id_decoracion is int \
			or not x is int or not y is int:
			return &"colocacion_invalida"
		copias[copia] = true
		var decoracion: Dictionary = DatosBasesSecretas.decoracion(id_decoracion)
		if decoracion.is_empty():
			return &"decoracion_invalida"
		var ancla: Vector2i = Vector2i(x, y)
		var huella: Dictionary = ValidadorDecoracion.preparar_huella(id_decoracion, ancla)
		if huella["resultado"] != &"huella_preparada":
			return huella["resultado"]
		# Comparte geometría, NO autorización: llamar al validador antes de registrar.
		for posicion: Vector2i in huella["huella_grafica"]:
			if not candidatas.has(posicion):
				return &"posicion_invalida"
		if decoracion["tipo_grafico"] == "sprite":
			var visual: Dictionary = DatosGraficosDecoracion.decoracion(id_decoracion)
			var escena: PackedScene = load(str(visual.get("escena", ""))) as PackedScene
			if escena == null:
				return &"grafico_invalido"
			planes_sprites.append({"copia_id": copia, "ancla": ancla, "escena": escena})
			if planes_sprites.size() > MAX_SPRITES:
				return &"limite_sprites"
		else:
			var resultado: StringName = _componer_metatiles(candidatas, decoracion, ancla)
			if resultado != &"exito":
				return resultado
	var instancias: Array[Node2D] = []
	for plan: Dictionary in planes_sprites:
		var escena: PackedScene = plan["escena"]
		var nodo: Node = escena.instantiate()
		if not nodo is Node2D:
			nodo.free()
			for creada: Node2D in instancias:
				creada.free()
			return &"grafico_invalido"
		var instancia: Node2D = nodo as Node2D
		instancia.name = "Decoracion_%d" % int(plan["copia_id"])
		instancia.set_meta("copia_id", int(plan["copia_id"]))
		instancia.position = Vector2(plan["ancla"]) * 16.0 + Vector2(8, 16)
		instancias.append(instancia)
		# Los object events bloquean su celda de ancla, no la cabeza dibujada encima.
		var celda: Dictionary = candidatas[plan["ancla"]]
		celda["flags"] = int(celda["flags"]) | TPTileDataMap.Flags.BLOQUEO
		celda["copia_sprite"] = int(plan["copia_id"])
	_restaurar_visual()
	_celdas = candidatas
	var capas: Array[TileMapLayer] = _capas()
	for posicion: Vector2i in _celdas:
		var celda: Dictionary = _celdas[posicion]
		if bool(celda.get("decoracion_metatile", false)):
			var atlas: Vector2i = DatosInterioresBases.atlas_metatile(int(celda["metatile_id"]))
			for fuente: int in 3:
				capas[fuente].set_cell(posicion, fuente, atlas)
		var flags: Dictionary = datos_tiles.get_cell_data(Vector2(posicion)).duplicate(true)
		flags["flags"] = int(celda["flags"])
		datos_tiles.set_cell_data(Vector2(posicion), flags)
	for instancia: Node2D in instancias:
		contenedor_sprites.add_child(instancia)
		_sprites.append(instancia)
	return &"exito"


func restaurar_original() -> bool:
	if not _capturado:
		return false
	_restaurar_visual()
	_celdas = _original_celdas.duplicate(true)
	return true


func _restaurar_visual() -> void:
	for sprite: Node2D in _sprites:
		if is_instance_valid(sprite):
			sprite.free()  # Solo instancias propias; nunca NPCs u otros hijos del mapa.
	_sprites.clear()
	for i: int in 3:
		_capas()[i].set("tile_map_data", _original_capas[i].duplicate())
	datos_tiles.tile_data = _original_flags.duplicate(true)


func _componer_metatiles(celdas: Dictionary, decoracion: Dictionary, ancla: Vector2i) -> StringName:
	var ancho: int = int(decoracion["ancho"])
	var alto: int = int(decoracion["alto"])
	var permiso: String = str(decoracion["permiso"])
	var elevaciones: Array = DatosGraficosDecoracion.decoracion(int(decoracion["id"])).get("elevaciones", [])
	for fila: int in alto:
		for columna: int in ancho:
			var indice: int = fila * ancho + columna
			var posicion: Vector2i = ancla + Vector2i(columna, fila - alto + 1)
			var celda: Dictionary = celdas[posicion]
			var id_tile: int = 512 + int(decoracion["graficos_originales"][indice])
			var atributo: Dictionary = DatosInterioresBases.metatile(id_tile)
			if atributo.is_empty():
				return &"metatile_invalido"
			var bloqueo: bool = int(atributo["comportamiento"]) == SuperficiesDecoracion.MB_IMPASSABLE \
				or (permiso != "PASS_FLOOR" and int(atributo["tipo_capa"]) != 0)
			# sub_80FF1EC: la variante +1 deja los pósteres intactos y adapta adornos a pared norte.
			if permiso != "NA_WALL" and int(celda["comportamiento"]) == SuperficiesDecoracion.MB_NORTH_WALL:
				id_tile += 1
			atributo = DatosInterioresBases.metatile(id_tile)
			if atributo.is_empty():
				return &"metatile_invalido"
			celda["metatile_id"] = id_tile
			celda["decoracion_metatile"] = true
			celda["comportamiento"] = int(atributo["comportamiento"])
			celda["superficie"] = SuperficiesDecoracion.tipo(int(atributo["comportamiento"]))
			celda["colision_original"] = 3 if bloqueo else 0
			celda["flags"] = (int(celda["flags"]) & ~TPTileDataMap.Flags.BLOQUEO) \
				| (TPTileDataMap.Flags.BLOQUEO if bloqueo else 0)
			if not elevaciones.is_empty():
				celda["elevacion_original"] = int(elevaciones[indice])
	return &"exito"


func _capas() -> Array[TileMapLayer]:
	return [capa_fondo, capa_suelo, capa_superior]
