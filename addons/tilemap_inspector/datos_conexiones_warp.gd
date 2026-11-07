@tool
extends RefCounted
## Índice de mapas y warps del editor. La clave de un mapa es el nombre de su
## escena, no nombre_interno (que puede ser distinto en los interiores).

const CARPETA_MAPAS := "res://escenas/mapas/"
const SCRIPT_MAPA := "res://escenas/mapas/MapaConfiguracion.gd"
const SCRIPT_WARP := "res://scripts/warp.gd"
const TAM_TILE := 16.0

## Valores de Warp.ModoDireccion (sin referenciar la clase para no compilar warp.gd).
const MODO_FIJA := 0
const MODO_MANTENER := 1
const MODO_INVERTIR := 2
## Desplegable «Mirar» de los editores de warp: las 4 direcciones fijas (modo
## FIJA) y después los modos MANTENER e INVERTIR.
const DIRECCIONES_FIJAS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
const OPCIONES_MIRAR: Array[String] = ["Abajo", "Arriba", "Izquierda", "Derecha", "Mantener dirección", "Invertir dirección"]
const MIRAR_MANTENER := 4
const MIRAR_INVERTIR := 5


static func listar_mapas() -> Array[Dictionary]:
	var rutas: Array[String] = []
	_recorrer(CARPETA_MAPAS, rutas)
	var mapas: Array[Dictionary] = []
	for ruta in rutas:
		var mapa := _informacion_basica(ruta)
		if not mapa.is_empty():
			mapas.append(mapa)
	mapas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.clave).naturalnocasecmp_to(str(b.clave)) < 0
	)
	return mapas


static func _recorrer(carpeta: String, rutas: Array[String]) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var nombre := dir.get_next()
		if nombre.is_empty():
			break
		if nombre.begins_with("."):
			continue
		if dir.current_is_dir():
			_recorrer(carpeta + nombre + "/", rutas)
		elif nombre.get_extension().to_lower() == "tscn":
			rutas.append(carpeta + nombre)
	dir.list_dir_end()


## Escanear el catálogo sin instanciar todos los mapas ni cargar decenas de
## TileSets. Los nodos de cada mapa se leen al seleccionarlo por primera vez.
static func _informacion_basica(ruta: String) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}
	var texto := archivo.get_as_text()
	archivo.close()
	var inicio := texto.find("[node ")
	if inicio < 0:
		return {}
	var fin := texto.find("\n[node ", inicio + 1)
	var bloque := texto.substr(inicio, fin - inicio) if fin >= 0 else texto.substr(inicio)
	var regex := RegEx.new()
	regex.compile("(?m)^script = ExtResource\\(\"([^\"]+)\"\\)")
	var match_script := regex.search(bloque)
	if match_script == null:
		return {}
	var id := match_script.get_string(1)
	var ruta_script := ""
	regex.compile("path=\"([^\"]+)\"")
	for linea in texto.substr(0, inicio).split("\n"):
		if linea.contains("[ext_resource type=\"Script\"") and linea.contains("id=\"%s\"" % id):
			var match_ruta := regex.search(linea)
			if match_ruta != null:
				ruta_script = match_ruta.get_string(1)
			break
	if ruta_script.is_empty():
		return {}
	if not _script_es_mapa(ruta_script):
		return {}
	return {
		"ruta": ruta,
		"clave": ruta.get_file().get_basename(),
		"interior": bloque.contains("\nesInterior = true"),
		"warps": [],
		"cargado": false,
	}


static func _script_es_mapa(ruta_script: String) -> bool:
	if ruta_script == SCRIPT_MAPA:
		return true
	var archivo := FileAccess.open(ruta_script, FileAccess.READ)
	if archivo == null:
		return false
	# El catálogo solo necesita el tipo de raíz. No cargar scripts @tool ni
	# dependencias de cada plantilla al listar los mapas.
	for _i in 20:
		if archivo.eof_reached():
			break
		var linea := archivo.get_line().strip_edges()
		if linea.begins_with("extends "):
			var base := linea.trim_prefix("extends ").strip_edges()
			if base == "MapaConfiguracion":
				return true
			if base.begins_with('"res://') and base.ends_with('"'):
				return _script_es_mapa(base.trim_prefix('"').trim_suffix('"'))
			return false
	return false


## Para las escenas abiertas se lee la raíz *viva*, nunca una segunda copia del
## archivo. Esto incluye cambios pendientes y escenas abiertas en otras pestañas.
static func raiz_abierta(ruta: String) -> Node:
	if not Engine.is_editor_hint():
		return null
	for raiz in EditorInterface.get_open_scene_roots():
		if is_instance_valid(raiz) and raiz.scene_file_path == ruta:
			return raiz
	return null


static func leer_mapa(ruta: String, raiz_viva: Node = null) -> Dictionary:
	var raiz := raiz_viva
	var temporal := false
	if raiz == null:
		var escena := load(ruta) as PackedScene
		if escena == null:
			return {}
		raiz = escena.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		temporal = true
	if raiz == null or not _hereda_script(raiz, SCRIPT_MAPA):
		if temporal and raiz != null:
			raiz.free()
		return {}
	var mapa: Dictionary = {
		"ruta": ruta,
		"clave": ruta.get_file().get_basename(),
		"interior": bool(raiz.get("esInterior")),
		"warps": [],
		"cargado": true,
	}
	var warps: Array[Dictionary] = []
	_reunir_warps(raiz, raiz, warps)
	mapa.warps = warps
	if temporal:
		raiz.free()
	return mapa


static func _hereda_script(nodo: Node, ruta: String) -> bool:
	return _script_hereda(nodo.get_script() as Script, ruta)


static func _script_hereda(script_objeto: Script, ruta: String) -> bool:
	var script := script_objeto
	while script != null:
		if script.resource_path == ruta:
			return true
		script = script.get_base_script()
	return false


static func _reunir_warps(raiz: Node, actual: Node, warps: Array[Dictionary]) -> void:
	for hijo in actual.get_children():
		if hijo is Node2D and _hereda_script(hijo, SCRIPT_WARP):
			var nodo := hijo as Node2D
			var posicion: Vector2 = (raiz as Node2D).to_local(nodo.global_position)
			warps.append({
				"nodo": _ruta_relativa(raiz, nodo),
				"nombre": str(nodo.name),
				"celda": Vector2i((posicion / TAM_TILE).floor()),
				"destino": str(nodo.get("ruta_mapa_destino")),
				"llegada": Vector2(nodo.get("posicion_destino")),
				"modo_direccion": modo_direccion_de(nodo),
				"direccion": Vector2(nodo.get("direccion")),
				"dar_paso": bool(nodo.get("dar_paso")),
				"tipo": int(nodo.get("tipo_warp")),
			})
		# No seguir dentro de escenas instanciadas: pertenecen a otra escena.
		if hijo.scene_file_path.is_empty():
			_reunir_warps(raiz, hijo, warps)


static func _ruta_relativa(raiz: Node, nodo: Node) -> NodePath:
	var nombres: Array[String] = []
	var actual := nodo
	while actual != null and actual != raiz:
		nombres.push_front(str(actual.name))
		actual = actual.get_parent()
	return NodePath("/".join(nombres))


static func por_clave(mapas: Array[Dictionary], clave: String) -> Dictionary:
	for mapa in mapas:
		if str(mapa.clave).to_lower() == clave.strip_edges().to_lower():
			return mapa
	return {}


static func por_ruta(mapas: Array[Dictionary], ruta: String) -> Dictionary:
	for mapa in mapas:
		if mapa.ruta == ruta:
			return mapa
	return {}


## Solo una ayuda para buscar, nunca una restricción de navegación. Los destinos
## existentes se muestran aunque no coincidan con el texto de este filtro.
static func filtro_sugerido(mapa: Dictionary) -> String:
	var clave := str(mapa.get("clave", ""))
	if not bool(mapa.get("interior", false)):
		return clave
	var guion_bajo := clave.find("_")
	var guion := clave.find("-")
	if guion_bajo < 0:
		return clave.substr(0, guion) if guion >= 0 else clave
	if guion < 0:
		return clave.substr(0, guion_bajo)
	return clave.substr(0, mini(guion_bajo, guion))


static func retornos_posibles(mapa_derecho: Dictionary, mapa_izquierdo: Dictionary, celda_origen: Vector2i) -> Array[Dictionary]:
	var posibles: Array[Dictionary] = []
	for warp in mapa_derecho.get("warps", []):
		if str(warp.destino).to_lower() == str(mapa_izquierdo.clave).to_lower():
			var entrada: Dictionary = warp.duplicate()
			entrada["exacto"] = Vector2(warp.llegada) == Vector2(celda_origen)
			posibles.append(entrada)
	posibles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return bool(a.exacto) and not bool(b.exacto)
	)
	return posibles


## Modo de dirección de un warp; FIJA si la propiedad no existe (script antiguo).
static func modo_direccion_de(nodo: Object) -> int:
	var modo: Variant = nodo.get("modo_direccion")
	return int(modo) if modo != null else MODO_FIJA


## Índice del desplegable «Mirar» para un warp; -1 si es una dirección fija no
## estándar (los editores añaden entonces un ítem «Actual …»). FIJA con (0, 0)
## conserva la dirección igual que MANTENER.
static func indice_mirar(modo: int, direccion: Vector2) -> int:
	match modo:
		MODO_MANTENER:
			return MIRAR_MANTENER
		MODO_INVERTIR:
			return MIRAR_INVERTIR
	if direccion == Vector2.ZERO:
		return MIRAR_MANTENER
	return DIRECCIONES_FIJAS.find(direccion)


## {"modo_direccion", "direccion"} que se guardan al elegir un índice del
## desplegable; vacío para índices fuera de OPCIONES_MIRAR (ítem «Actual …»).
static func valores_mirar(indice: int) -> Dictionary:
	if indice >= 0 and indice < DIRECCIONES_FIJAS.size():
		return {"modo_direccion": MODO_FIJA, "direccion": DIRECCIONES_FIJAS[indice]}
	if indice == MIRAR_MANTENER:
		return {"modo_direccion": MODO_MANTENER, "direccion": Vector2.ZERO}
	if indice == MIRAR_INVERTIR:
		return {"modo_direccion": MODO_INVERTIR, "direccion": Vector2.ZERO}
	return {}


## Valores de un warp tal y como quedarían al guardarlo desde el desplegable sin
## tocarlo; las direcciones no estándar se conservan tal cual.
static func mirar_normalizado(modo: int, direccion: Vector2) -> Dictionary:
	var valores := valores_mirar(indice_mirar(modo, direccion))
	return valores if not valores.is_empty() else {"modo_direccion": modo, "direccion": direccion}
