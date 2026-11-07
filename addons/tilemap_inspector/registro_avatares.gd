@tool
extends RefCounted

## Registro de avatares de NPC (SpriteFrames) con nombre legible, guardado en
## registro_avatares.json. Todo es estático: el inspector y la galería comparten
## la misma copia en memoria, que se relee sola si el JSON cambió en disco (mtime).
##
## Formato:
## { "version": 1, "recientes": ["uid://..."],
##   "avatares": [ { "nombre": "...", "uid": "uid://...", "ruta": "res://...tres", "tags": [] } ] }
##
## Cada entrada se identifica por su "clave": el uid si lo tiene, si no la ruta.
## No usa EditorInterface: se puede ejercitar en headless con `--script`.

const RUTA_REGISTRO := "res://addons/tilemap_inspector/registro_avatares.json"
const CARPETA_AVATARES := "res://escenas/avatares"
const VERSION_FORMATO := 1
const MAX_RECIENTES := 8
const INTERVALO_CHEQUEO_MS := 500
## Orden de preferencia de la animación usada como miniatura.
const ANIMACIONES_MINIATURA: Array[StringName] = [&"camina_abajo_1", &"default"]

## Ruta del JSON en uso (las pruebas la redirigen a un archivo temporal).
static var ruta_registro: String = RUTA_REGISTRO

static var _datos: Dictionary = {}
static var _cargado: bool = false
static var _mtime: int = -1
## Último chequeo de mtime (ms): el inspector consulta mucho, basta con mirar el
## disco cada INTERVALO_CHEQUEO_MS.
static var _ultimo_chequeo_ms: int = -INTERVALO_CHEQUEO_MS
## Índices de búsqueda, reconstruidos en cada carga/modificación.
static var _por_uid: Dictionary = {}
static var _por_ruta: Dictionary = {}
## ruta -> Texture2D (o null si el recurso no se pudo cargar). Evita recalcular
## miniaturas con muchos NPC en el mapa.
static var _miniaturas: Dictionary = {}


# ─── Carga / guardado ────────────────────────────────────────────────────────────

## Carga el JSON si todavía no está en memoria o si cambió en disco. Si el archivo
## no existe, lo crea vacío.
static func asegurar_cargado(forzar: bool = false) -> void:
	var ahora := Time.get_ticks_msec()
	if _cargado and not forzar and ahora - _ultimo_chequeo_ms < INTERVALO_CHEQUEO_MS:
		return
	_ultimo_chequeo_ms = ahora
	if not FileAccess.file_exists(ruta_registro):
		if not _cargado or forzar:
			_datos = _datos_vacios()
			_cargado = true
			guardar()
		return
	var mtime := int(FileAccess.get_modified_time(ruta_registro))
	if _cargado and not forzar and mtime == _mtime:
		return
	_cargado = true
	_mtime = mtime
	_datos = _datos_vacios()
	var texto := FileAccess.get_file_as_string(ruta_registro)
	if texto.strip_edges().is_empty():
		_reconstruir_indices()
		return
	var json := JSON.new()
	if json.parse(texto) != OK:
		push_warning("[PKRPG] registro_avatares.json inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		_reconstruir_indices()
		return
	var leido: Variant = json.data
	if leido is Dictionary:
		_normalizar(leido as Dictionary)
	_reconstruir_indices()

## Escribe el registro (JSON indentado con tabs). Devuelve false si no pudo.
static func guardar() -> bool:
	if _datos.is_empty():
		_datos = _datos_vacios()
	var archivo := FileAccess.open(ruta_registro, FileAccess.WRITE)
	if archivo == null:
		push_warning("[PKRPG] No se pudo escribir %s (error %d)" % [ruta_registro, FileAccess.get_open_error()])
		return false
	archivo.store_string(JSON.stringify(_datos, "\t", false) + "\n")
	archivo.close()
	_mtime = int(FileAccess.get_modified_time(ruta_registro))
	_reconstruir_indices()
	return true

static func _datos_vacios() -> Dictionary:
	return {"version": VERSION_FORMATO, "recientes": [], "avatares": []}

## Copia el JSON leído a la estructura esperada, descartando basura.
static func _normalizar(leido: Dictionary) -> void:
	var avatares: Array = []
	var crudos: Variant = leido.get("avatares", [])
	if crudos is Array:
		for item: Variant in crudos:
			if not item is Dictionary:
				continue
			var d := item as Dictionary
			var uid := str(d.get("uid", "")).strip_edges()
			var ruta := str(d.get("ruta", "")).strip_edges()
			if uid.is_empty() and ruta.is_empty():
				continue
			var tags: Array = []
			var tags_crudos: Variant = d.get("tags", [])
			if tags_crudos is Array:
				for t: Variant in tags_crudos:
					tags.append(str(t))
			var nombre := str(d.get("nombre", "")).strip_edges()
			if nombre.is_empty():
				nombre = ruta.get_file().get_basename()
			avatares.append({"nombre": nombre, "uid": uid, "ruta": ruta, "tags": tags})
	var recientes: Array = []
	var recientes_crudos: Variant = leido.get("recientes", [])
	if recientes_crudos is Array:
		for r: Variant in recientes_crudos:
			var clave := str(r)
			if not clave.is_empty() and not recientes.has(clave) and recientes.size() < MAX_RECIENTES:
				recientes.append(clave)
	_datos = {"version": VERSION_FORMATO, "recientes": recientes, "avatares": avatares}

static func _reconstruir_indices() -> void:
	_por_uid.clear()
	_por_ruta.clear()
	for entrada: Dictionary in _lista_avatares():
		var uid := str(entrada.get("uid", ""))
		var ruta := str(entrada.get("ruta", ""))
		if not uid.is_empty():
			_por_uid[uid] = entrada
		if not ruta.is_empty():
			_por_ruta[ruta] = entrada

## Array vivo de entradas dentro de _datos (se crea si falta).
static func _lista_avatares() -> Array:
	var lista: Variant = _datos.get("avatares")
	if not lista is Array:
		lista = []
		_datos["avatares"] = lista
	return lista as Array


# ─── Consulta ────────────────────────────────────────────────────────────────────

## Entradas del registro (referencias vivas: no modificarlas directamente).
static func obtener_avatares() -> Array[Dictionary]:
	asegurar_cargado()
	var resultado: Array[Dictionary] = []
	for entrada: Variant in _lista_avatares():
		resultado.append(entrada as Dictionary)
	return resultado

## Entradas ordenadas alfabéticamente por nombre (orden natural, sin mayúsculas).
static func obtener_avatares_ordenados() -> Array[Dictionary]:
	var lista := obtener_avatares()
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("nombre", "")).naturalnocasecmp_to(str(b.get("nombre", ""))) < 0
	)
	return lista

## Entradas recientes (las más nuevas primero), solo las que siguen registradas.
static func obtener_recientes() -> Array[Dictionary]:
	asegurar_cargado()
	var resultado: Array[Dictionary] = []
	var recientes: Variant = _datos.get("recientes", [])
	if recientes is Array:
		for clave: Variant in recientes:
			var entrada := buscar_por_clave(str(clave))
			if not entrada.is_empty():
				resultado.append(entrada)
	return resultado

static func cantidad() -> int:
	asegurar_cargado()
	return _lista_avatares().size()

## uid si existe, si no ruta: identifica a la entrada dentro del registro.
static func clave_de(entrada: Dictionary) -> String:
	var uid := str(entrada.get("uid", ""))
	return uid if not uid.is_empty() else str(entrada.get("ruta", ""))

static func buscar_por_uid(uid: String) -> Dictionary:
	asegurar_cargado()
	if uid.is_empty():
		return {}
	return _por_uid.get(uid, {})

static func buscar_por_ruta(ruta: String) -> Dictionary:
	asegurar_cargado()
	if ruta.is_empty():
		return {}
	return _por_ruta.get(ruta, {})

static func buscar_por_clave(clave: String) -> Dictionary:
	if clave.begins_with("uid://"):
		var entrada := buscar_por_uid(clave)
		if not entrada.is_empty():
			return entrada
	return buscar_por_ruta(clave)

## Busca la entrada de un recurso: primero por ruta (barato), luego por uid (lee la
## cabecera del .tres). Si la encuentra por uid con otra ruta (archivo movido o
## renombrado), actualiza la ruta y guarda.
static func buscar_por_recurso(recurso: Resource) -> Dictionary:
	if recurso == null:
		return {}
	return buscar_por_ruta_o_uid(recurso.resource_path)

static func buscar_por_ruta_o_uid(ruta: String) -> Dictionary:
	if ruta.is_empty() or ruta.contains("::"):
		return {}
	var entrada := buscar_por_ruta(ruta)
	if not entrada.is_empty():
		return entrada
	entrada = buscar_por_uid(uid_de_ruta(ruta))
	if not entrada.is_empty() and str(entrada.get("ruta", "")) != ruta:
		entrada["ruta"] = ruta
		guardar()
	return entrada

## Texto "uid://..." del recurso, o "" si no tiene uid.
static func uid_de_ruta(ruta: String) -> String:
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return ""
	var id := ResourceLoader.get_resource_uid(ruta)
	if id == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(id)

## Ruta actual del recurso de la entrada: por uid primero, si no por ruta guardada.
## Si el uid apunta a otra ruta, actualiza la entrada solo en memoria: usar
## sincronizar_rutas() para corregir y guardar en bloque.
static func resolver_ruta(entrada: Dictionary) -> String:
	var uid := str(entrada.get("uid", ""))
	if not uid.is_empty():
		var id := ResourceUID.text_to_id(uid)
		if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
			var ruta_uid := ResourceUID.get_id_path(id)
			if not ruta_uid.is_empty() and ResourceLoader.exists(ruta_uid):
				if ruta_uid != str(entrada.get("ruta", "")):
					entrada["ruta"] = ruta_uid
				return ruta_uid
	var ruta := str(entrada.get("ruta", ""))
	if not ruta.is_empty() and ResourceLoader.exists(ruta):
		return ruta
	return ""

## Carga el SpriteFrames de la entrada (null si ya no existe o no es SpriteFrames).
static func resolver_recurso(entrada: Dictionary) -> SpriteFrames:
	var ruta := resolver_ruta(entrada)
	if ruta.is_empty():
		return null
	return ResourceLoader.load(ruta) as SpriteFrames

## Recorre todas las entradas, corrige rutas movidas (según su uid) y completa uids
## faltantes. Guarda solo si algo cambió. Devuelve la cantidad de entradas corregidas.
static func sincronizar_rutas() -> int:
	asegurar_cargado()
	var cambios := 0
	for entrada: Variant in _lista_avatares():
		var d := entrada as Dictionary
		var antes_ruta := str(d.get("ruta", ""))
		var ruta := resolver_ruta(d)
		if str(d.get("uid", "")).is_empty() and not ruta.is_empty():
			var uid := uid_de_ruta(ruta)
			if not uid.is_empty() and not _por_uid.has(uid):
				d["uid"] = uid
				cambios += 1
				continue
		if str(d.get("ruta", "")) != antes_ruta:
			cambios += 1
	if cambios > 0:
		guardar()
	return cambios


# ─── Modificación ────────────────────────────────────────────────────────────────

## Registra el SpriteFrames de `ruta`. Si ya estaba (por uid o ruta) devuelve la
## entrada existente sin duplicarla. Devuelve {} si la ruta no es un SpriteFrames.
static func agregar(ruta: String, nombre: String = "", tags: Array = [], guardar_ahora: bool = true) -> Dictionary:
	asegurar_cargado()
	if not es_sprite_frames(ruta):
		return {}
	var uid := uid_de_ruta(ruta)
	var existente := buscar_por_uid(uid) if not uid.is_empty() else {}
	if existente.is_empty():
		existente = buscar_por_ruta(ruta)
	if not existente.is_empty():
		return existente
	var nombre_final := nombre.strip_edges()
	if nombre_final.is_empty():
		nombre_final = nombre_de_archivo(ruta)
	var tags_limpios: Array = []
	for t: Variant in tags:
		var tag := str(t).strip_edges()
		if not tag.is_empty():
			tags_limpios.append(tag)
	var entrada := {"nombre": nombre_final, "uid": uid, "ruta": ruta, "tags": tags_limpios}
	_lista_avatares().append(entrada)
	_reconstruir_indices()
	if guardar_ahora:
		guardar()
	return entrada

static func renombrar(clave: String, nombre: String) -> bool:
	var entrada := buscar_por_clave(clave)
	var nombre_final := nombre.strip_edges()
	if entrada.is_empty() or nombre_final.is_empty():
		return false
	entrada["nombre"] = nombre_final
	return guardar()

static func cambiar_tags(clave: String, tags: Array) -> bool:
	var entrada := buscar_por_clave(clave)
	if entrada.is_empty():
		return false
	var tags_limpios: Array = []
	for t: Variant in tags:
		var tag := str(t).strip_edges()
		if not tag.is_empty() and not tags_limpios.has(tag):
			tags_limpios.append(tag)
	entrada["tags"] = tags_limpios
	return guardar()

## Quita la entrada del registro (no toca el .tres) y de los recientes.
static func quitar(clave: String) -> bool:
	var entrada := buscar_por_clave(clave)
	if entrada.is_empty():
		return false
	_lista_avatares().erase(entrada)
	var recientes: Variant = _datos.get("recientes", [])
	if recientes is Array:
		var lista := recientes as Array
		lista.erase(str(entrada.get("uid", "")))
		lista.erase(str(entrada.get("ruta", "")))
	return guardar()

## Pone la entrada al frente de "recientes" (máximo MAX_RECIENTES).
static func registrar_reciente(clave: String) -> void:
	var entrada := buscar_por_clave(clave)
	if entrada.is_empty():
		return
	var clave_real := clave_de(entrada)
	var recientes: Variant = _datos.get("recientes", [])
	var lista: Array = recientes as Array if recientes is Array else []
	if not lista.is_empty() and str(lista[0]) == clave_real:
		return
	lista.erase(clave_real)
	lista.push_front(clave_real)
	while lista.size() > MAX_RECIENTES:
		lista.pop_back()
	_datos["recientes"] = lista
	guardar()


# ─── Archivos ────────────────────────────────────────────────────────────────────

static func nombre_de_archivo(ruta: String) -> String:
	return ruta.get_file().get_basename()

## true si `ruta` es un SpriteFrames. Para .tres lee solo la cabecera (sin cargar);
## solo los .res binarios se cargan para comprobarlo.
static func es_sprite_frames(ruta: String) -> bool:
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return false
	var extension := ruta.get_extension().to_lower()
	if extension == "tres":
		var archivo := FileAccess.open(ruta, FileAccess.READ)
		if archivo == null:
			return false
		var cabecera := archivo.get_line()
		archivo.close()
		return cabecera.begins_with("[gd_resource") and cabecera.contains("type=\"SpriteFrames\"")
	if extension == "res":
		return ResourceLoader.load(ruta) is SpriteFrames
	return false

## Rutas de SpriteFrames bajo `carpeta` (recursivo) que no están en el registro.
static func escanear_no_registrados(carpeta: String = CARPETA_AVATARES) -> PackedStringArray:
	asegurar_cargado()
	var encontrados := PackedStringArray()
	_escanear(carpeta.trim_suffix("/"), encontrados)
	var resultado := PackedStringArray()
	for ruta in encontrados:
		if not buscar_por_ruta(ruta).is_empty():
			continue
		var uid := uid_de_ruta(ruta)
		if not uid.is_empty() and not buscar_por_uid(uid).is_empty():
			continue
		resultado.append(ruta)
	resultado.sort()
	return resultado

static func _escanear(carpeta: String, salida: PackedStringArray) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while not nombre.is_empty():
		if not nombre.begins_with("."):
			var ruta := carpeta + "/" + nombre
			if dir.current_is_dir():
				_escanear(ruta, salida)
			elif nombre.get_extension().to_lower() == "tres" and es_sprite_frames(ruta):
				salida.append(ruta)
		nombre = dir.get_next()
	dir.list_dir_end()

## Registra de una vez todas las rutas indicadas usando el nombre de archivo.
## Devuelve cuántas se agregaron.
static func agregar_varios(rutas: PackedStringArray) -> int:
	var antes := cantidad()
	for ruta in rutas:
		agregar(ruta, "", [], false)
	var agregados := cantidad() - antes
	if agregados > 0:
		guardar()
	return agregados


# ─── Miniaturas ──────────────────────────────────────────────────────────────────

## Animación usada para la miniatura: camina_abajo_1, si no default, si no la primera.
static func animacion_miniatura(frames: SpriteFrames) -> StringName:
	if frames == null:
		return &""
	for anim in ANIMACIONES_MINIATURA:
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			return anim
	for anim in frames.get_animation_names():
		if frames.get_frame_count(anim) > 0:
			return StringName(anim)
	return &""

## Frame 0 de la animación de miniatura (sin cache).
static func miniatura_de_frames(frames: SpriteFrames) -> Texture2D:
	var anim := animacion_miniatura(frames)
	if anim == &"":
		return null
	return frames.get_frame_texture(anim, 0)

## Tamaño en píxeles de un fotograma del avatar (el de la animación de miniatura).
## Vector2i.ZERO si no hay frames. Sirve para deducir `tamano_sprite` del NPC.
static func tamano_de_frames(frames: SpriteFrames) -> Vector2i:
	var textura := miniatura_de_frames(frames)
	if textura == null:
		return Vector2i.ZERO
	return Vector2i(textura.get_size())

## Miniatura cacheada por ruta del recurso.
static func miniatura_de_recurso(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	var ruta := frames.resource_path
	if ruta.is_empty() or ruta.contains("::"):
		return miniatura_de_frames(frames)
	if _miniaturas.has(ruta) and _miniaturas[ruta] != null:
		return _miniaturas[ruta]
	var textura := miniatura_de_frames(frames)
	_miniaturas[ruta] = textura
	return textura

## Miniatura cacheada por ruta (carga el recurso solo la primera vez).
static func miniatura_de_ruta(ruta: String) -> Texture2D:
	if ruta.is_empty():
		return null
	if _miniaturas.has(ruta):
		return _miniaturas[ruta]
	var textura: Texture2D = null
	if ResourceLoader.exists(ruta):
		textura = miniatura_de_frames(ResourceLoader.load(ruta) as SpriteFrames)
	_miniaturas[ruta] = textura
	return textura

static func miniatura_en_cache(ruta: String) -> bool:
	return _miniaturas.has(ruta)

static func limpiar_cache_miniaturas() -> void:
	_miniaturas.clear()

## Texturas del ciclo de caminata hacia abajo (camina_abajo_1 + camina_abajo_2) para
## la vista previa animada; si no existen, los frames de la animación de miniatura.
static func frames_vista_previa(frames: SpriteFrames) -> Array[Texture2D]:
	var resultado: Array[Texture2D] = []
	if frames == null:
		return resultado
	var anims: Array[StringName] = []
	if frames.has_animation(&"camina_abajo_1"):
		anims.append(&"camina_abajo_1")
		if frames.has_animation(&"camina_abajo_2"):
			anims.append(&"camina_abajo_2")
	else:
		var anim := animacion_miniatura(frames)
		if anim != &"":
			anims.append(anim)
	for anim in anims:
		for i in frames.get_frame_count(anim):
			var tex := frames.get_frame_texture(anim, i)
			if tex != null:
				resultado.append(tex)
	return resultado

## Velocidad (fps) de la animación de vista previa.
static func velocidad_vista_previa(frames: SpriteFrames) -> float:
	var anim := &"camina_abajo_1" if frames != null and frames.has_animation(&"camina_abajo_1") else animacion_miniatura(frames)
	if anim == &"":
		return 0.0
	return frames.get_animation_speed(anim)
