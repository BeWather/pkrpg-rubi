class_name HierbaCenizaMapa
extends Node

## Hierba alta cubierta de ceniza (MB_ASHGRASS de Emerald). Cuando el jugador
## empieza un paso (o aterriza de un salto) en una celda con HIERBA_CENIZA sin
## limpiar, la celda queda registrada como limpia al momento y, 4/60 s después,
## el tile de `capa_hierba` pasa de `atlas_ceniza` a `atlas_limpia` y aparecen la
## hierba pisada fija y la nube de ceniza. Con el Saco Hollín, cada celda limpiada
## suma 1 al contador de partida `ceniza_saco_hollin` (máximo 9999).
##
## Las celdas limpiadas viven solo en memoria: AdministradorMapa llama a
## `regenerar_estado_volatil()` cuando el mapa vuelve a ser el actual desde otro
## mapa, desde un interior o al cargar la partida. Al guardar, las celdas limpias
## del área visible (±7 tiles) se escriben en la partida con
## `guardar_estado_visible()` y, al cargarla, se vuelven a limpiar sin efectos.

const GRUPO_VOLATIL := &"estado_mapa_volatil"
const GRUPO := &"hierba_ceniza"
const RETARDO_LIMPIEZA := 4.0 / 60.0
const OBJETO_SACO := "SACOHOLLIN"
## Clave de bolsillo de la mochila para objetos clave (bolsillo_id 5 en la BD).
const BOLSILLO_CLAVE := 4
const CONTADOR := "ceniza_saco_hollin"
const MAX_CONTADOR := 9999
## Texto de partida con el área visible al guardar: PREFIJO_VISTA + nombre_interno.
const PREFIJO_VISTA := "hierba_ceniza_vista:"
## Tiles hacia cada lado del jugador que se conservan limpios al guardar.
const RADIO_VISTA := 7
const ESCENA_NUBE: PackedScene = preload("res://escenas/overworld/nube_ceniza.tscn")
## Origen de las entidades en celda·16 + (8,14): la hierba pisada va 1 px por
## debajo (se dibuja encima del jugador) y la nube 1 px más (encima de todo).
const DESPLAZAMIENTO_PASTO := Vector2(8.0, 15.0)
const DESPLAZAMIENTO_NUBE := Vector2(8.0, 16.0)

## Capa de tiles con la hierba (en Ruta 113, `Arbolado`).
@export var capa_hierba: TileMapLayer
@export var fuente_atlas: int = 0
@export var atlas_ceniza: Vector2i = Vector2i(5, 26)
@export var atlas_limpia: Vector2i = Vector2i(2, 27)
## Solo en builds de depuración: da el Saco Hollín al jugador al regenerar el mapa.
@export var debug_dar_saco_hollin: bool = false

## Vector2i -> {"source": int, "atlas": Vector2i, "alt": int} (tile original).
var celdas_limpias: Dictionary = {}
## Doble inyectable con tiene_objeto/get_contador/incrementar_contador/
## dar_objeto_jugador/get_texto/set_texto; si es null se usa el autoload
## SistemaGuardado.
var almacen: Object = null
## Inyectable en tests; si es null se busca /root/AdministradorMapa.
var administrador: Node = null

var _mapa: MapaConfiguracion = null
## Cambia en cada regeneración: invalida las limpiezas con retardo en vuelo.
var _generacion: int = 0


func _enter_tree() -> void:
	add_to_group(GRUPO_VOLATIL)
	add_to_group(GRUPO)
	_mapa = _buscar_mapa_padre()


func esta_limpia(celda: Vector2i) -> bool:
	return celdas_limpias.has(celda)


## Llamado por el jugador al empezar un paso o aterrizar en `celda`. Devuelve true
## si la celda tenía ceniza sin limpiar (el llamador no debe lanzar entonces la
## hierba pisada normal).
func intentar_limpiar(celda: Vector2i) -> bool:
	if celdas_limpias.has(celda) or capa_hierba == null:
		return false
	var tp := _obtener_tp()
	if tp == null or not tp.has_flag(Vector2(celda), TPTileDataMap.Flags.HIERBA_CENIZA):
		return false
	celdas_limpias[celda] = {
		"source": capa_hierba.get_cell_source_id(celda),
		"atlas": capa_hierba.get_cell_atlas_coords(celda),
		"alt": capa_hierba.get_cell_alternative_tile(celda),
	}
	_sumar_ceniza_recogida()
	if is_inside_tree():
		get_tree().create_timer(RETARDO_LIMPIEZA).timeout.connect(
			_aplicar_limpieza.bind(celda, _generacion)
		)
	return true


## CORTE sobre una celda que el jugador ya limpió (HierbaCortableMapa): vuelve a
## su tile original y deja de estar registrada, así el corte parte de la ceniza.
func restaurar_celda(celda: Vector2i) -> void:
	if not celdas_limpias.has(celda):
		return
	if capa_hierba != null:
		var original: Dictionary = celdas_limpias[celda]
		if int(original.source) < 0:
			capa_hierba.erase_cell(celda)
		else:
			capa_hierba.set_cell(celda, int(original.source), original.atlas, int(original.alt))
	celdas_limpias.erase(celda)


## Restaura el tile original de todas las celdas limpiadas y vacía el registro.
## Con `desde_carga` (AdministradorMapa al cargar la partida), vuelve a limpiar sin
## efectos ni contador las celdas del área visible guardada y vacía ese texto.
func regenerar_estado_volatil(desde_carga: bool = false) -> void:
	_generacion += 1
	if capa_hierba != null:
		for celda: Vector2i in celdas_limpias:
			var original: Dictionary = celdas_limpias[celda]
			if int(original.source) < 0:
				capa_hierba.erase_cell(celda)
			else:
				capa_hierba.set_cell(celda, int(original.source), original.atlas, int(original.alt))
	celdas_limpias.clear()
	if desde_carga:
		_restaurar_estado_visible()
	_dar_saco_debug()


## Equivale a SaveMapView de Emerald: guarda en el texto de partida las celdas
## limpias hasta RADIO_VISTA tiles hacia cada lado de `celda_jugador` ("x,y;x,y",
## o "" si no hay ninguna).
func guardar_estado_visible(celda_jugador: Vector2i) -> void:
	var destino := _obtener_almacen()
	var clave := _clave_vista()
	if destino == null or clave.is_empty():
		return
	var rect := Rect2i(
		celda_jugador - Vector2i(RADIO_VISTA, RADIO_VISTA),
		Vector2i(RADIO_VISTA * 2 + 1, RADIO_VISTA * 2 + 1)
	)
	var partes: PackedStringArray = []
	for celda: Vector2i in celdas_limpias:
		if rect.has_point(celda):
			partes.append("%d,%d" % [celda.x, celda.y])
	destino.call("set_texto", clave, ";".join(partes))


func _restaurar_estado_visible() -> void:
	var destino := _obtener_almacen()
	var clave := _clave_vista()
	if destino == null or clave.is_empty():
		return
	var texto := String(destino.call("get_texto", clave))
	var tp := _obtener_tp()
	if capa_hierba != null and tp != null:
		for parte: String in texto.split(";", false):
			var coords := parte.split(",")
			if coords.size() != 2 or not coords[0].is_valid_int() or not coords[1].is_valid_int():
				continue
			var celda := Vector2i(coords[0].to_int(), coords[1].to_int())
			if celdas_limpias.has(celda):
				continue
			if not tp.has_flag(Vector2(celda), TPTileDataMap.Flags.HIERBA_CENIZA):
				continue
			celdas_limpias[celda] = {
				"source": capa_hierba.get_cell_source_id(celda),
				"atlas": capa_hierba.get_cell_atlas_coords(celda),
				"alt": capa_hierba.get_cell_alternative_tile(celda),
			}
			capa_hierba.set_cell(celda, fuente_atlas, atlas_limpia)
	destino.call("set_texto", clave, "")


func _clave_vista() -> String:
	if _mapa == null:
		_mapa = _buscar_mapa_padre()
	if _mapa == null or _mapa.nombre_interno.is_empty():
		return ""
	return PREFIJO_VISTA + _mapa.nombre_interno


func _aplicar_limpieza(celda: Vector2i, generacion: int) -> void:
	if generacion != _generacion or not celdas_limpias.has(celda):
		return
	if capa_hierba == null or not is_instance_valid(capa_hierba) or not _es_mapa_actual():
		return
	capa_hierba.set_cell(celda, fuente_atlas, atlas_limpia)
	_crear_efectos(celda)


## Hierba pisada fija en su último frame y, encima, la nube de ceniza. Ambas en el
## contenedor y-sort `NPCs` del mapa, por encima del jugador.
func _crear_efectos(celda: Vector2i) -> Array[Node2D]:
	var contenedor: Node = _mapa.get_node_or_null("NPCs") if _mapa != null else null
	if contenedor == null:
		return []
	var base := Vector2(celda) * 16.0
	var pasto := Singleton.animacion_pisar_pasto.instantiate() as Node2D
	var sprite := pasto.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.autoplay = ""
	pasto.position = base + DESPLAZAMIENTO_PASTO
	contenedor.add_child(pasto)
	if sprite != null:
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count(sprite.animation) - 1
	# pasto_pisado se libera en cuanto nadie ocupa su celda; el jugador todavía
	# está a mitad de paso, así que su comprobación espera a que acabe la nube.
	pasto.set_process(false)
	var nube := ESCENA_NUBE.instantiate() as Node2D
	nube.position = base + DESPLAZAMIENTO_NUBE
	nube.tree_exiting.connect(_reactivar_pasto.bind(pasto))
	contenedor.add_child(nube)
	return [pasto, nube]


## `pasto` es Variant: CORTE puede haber liberado la pisada antes de que acabe la
## nube y un Object liberado no se puede pasar como argumento.
func _reactivar_pasto(pasto: Variant) -> void:
	if is_instance_valid(pasto) and not (pasto as Node).is_queued_for_deletion():
		(pasto as Node).set_process(true)


func _sumar_ceniza_recogida() -> void:
	var destino := _obtener_almacen()
	if destino == null:
		return
	if not bool(destino.call("tiene_objeto", OBJETO_SACO, 1, BOLSILLO_CLAVE)):
		return
	if int(destino.call("get_contador", CONTADOR)) >= MAX_CONTADOR:
		return
	destino.call("incrementar_contador", CONTADOR, 1)


func _dar_saco_debug() -> void:
	if not debug_dar_saco_hollin or not OS.is_debug_build():
		return
	var destino := _obtener_almacen()
	if destino == null or bool(destino.call("tiene_objeto", OBJETO_SACO, 1, BOLSILLO_CLAVE)):
		return
	destino.call("dar_objeto_jugador", OBJETO_SACO)


func _obtener_almacen() -> Object:
	if almacen != null:
		return almacen
	if not is_inside_tree():
		return null
	var sistema := get_tree().root.get_node_or_null("SistemaGuardado")
	if sistema == null or sistema.get("datos_vivos") == null:
		return null
	return sistema


func _obtener_tp() -> TPTileDataMap:
	if _mapa == null:
		_mapa = _buscar_mapa_padre()
	if _mapa == null:
		return null
	return _mapa.get_capa_resuelta(Singleton.capa_activa)


func _es_mapa_actual() -> bool:
	var admin := administrador
	if admin == null and is_inside_tree():
		admin = get_tree().root.get_node_or_null("AdministradorMapa")
	if admin == null:
		return true
	return admin.get("mapa_actual") == _mapa


func _buscar_mapa_padre() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	return null
