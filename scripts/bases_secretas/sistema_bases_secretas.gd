extends RefCounted
class_name SistemaBasesSecretas

## Estado local puro de base/ habitación e inventario de adornos de Rubí.
## No crea escenas ni valida terreno. registrar_colocacion_validada() se llama
## SOLO después de revalidar el snapshot fresco en el editor.
## Los getters/to_dict devuelven snapshots, nunca referencias al estado vivo.
const VERSION: int = 1
const LIMITE_BASE: int = 16
const LIMITE_HABITACION: int = 12
const LIMITE_SPRITES: int = 14  # Slots de object event para decoración en Rubí.
const MAX_MUDANZAS: int = 0xFFFFFF  # IncrementGameStat, src/overworld.c de pokeruby.
const MAX_ID_COPIA: int = 2147483647
const CONTEXTO_BASE: StringName = &"base"
const CONTEXTO_HABITACION: StringName = &"habitacion"

var avisos_carga: Array[String] = []
var _inventario: Array[Dictionary] = []
var _base: Dictionary = {}
var _habitacion: Array[Dictionary] = []
var _retorno: Dictionary = {}
var _siguiente_copia_id: int = 1
var _visitas: int = 0
var _mudanzas: int = 0
var _datos_incompatibles: Dictionary = {}


func es_compatible() -> bool:
	return _datos_incompatibles.is_empty()


func tiene_base() -> bool:
	return not _base.is_empty()


func id_base() -> int:
	return int(_base.get("id", 0))


func obtener_base() -> Dictionary:
	return _base.duplicate(true)


func obtener_inventario() -> Array[Dictionary]:
	return _inventario.duplicate(true)


func obtener_retorno() -> Dictionary:
	return _retorno.duplicate(true)


func visitas() -> int:
	return _visitas


func mudanzas() -> int:
	return _mudanzas


func obtener_copia(copia_id: int) -> Dictionary:
	for copia: Dictionary in _inventario:
		if int(copia["copia_id"]) == copia_id:
			return copia.duplicate(true)
	return {}


func cantidad_categoria(categoria: StringName) -> int:
	var cantidad: int = 0
	for copia: Dictionary in _inventario:
		if _categoria(int(copia["decoracion_id"])) == categoria:
			cantidad += 1
	return cantidad


func puede_agregar_decoracion(decoracion_id: int) -> bool:
	var categoria: StringName = _categoria(decoracion_id)
	return es_compatible() and _siguiente_copia_id < MAX_ID_COPIA \
		and cantidad_categoria(categoria) < DatosBasesSecretas.capacidad_categoria(categoria)


## Devuelve ID estable de la copia nueva; -1 si ID inválido, sin espacio o incompatible.
func agregar_decoracion(decoracion_id: int) -> int:
	if not puede_agregar_decoracion(decoracion_id):
		return -1
	var copia_id: int = _siguiente_copia_id
	_siguiente_copia_id += 1
	_inventario.append({"copia_id": copia_id, "decoracion_id": decoracion_id})
	return copia_id


func contexto_de_copia(copia_id: int) -> StringName:
	for contexto: StringName in [CONTEXTO_BASE, CONTEXTO_HABITACION]:
		for colocacion: Dictionary in _colocaciones(contexto):
			if int(colocacion["copia_id"]) == copia_id:
				return contexto
	return &""


func copia_disponible(copia_id: int) -> bool:
	return es_compatible() and not obtener_copia(copia_id).is_empty() \
		and contexto_de_copia(copia_id) == &""


func copias_disponibles(categoria: StringName = &"") -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for copia: Dictionary in _inventario:
		if copia_disponible(int(copia["copia_id"])) \
			and (categoria == &"" or _categoria(int(copia["decoracion_id"])) == categoria):
			resultado.append(copia.duplicate(true))
	return resultado


func tirar_decoracion(copia_id: int) -> StringName:
	if not es_compatible():
		return &"version_incompatible"
	if obtener_copia(copia_id).is_empty():
		return &"copia_invalida"
	if not copia_disponible(copia_id):
		return &"en_uso"
	for i: int in _inventario.size():
		if int(_inventario[i]["copia_id"]) == copia_id:
			_inventario.remove_at(i)
			return &"exito"
	return &"copia_invalida"


func establecer_base(entrada_id: int, jugador: Dictionary) -> StringName:
	if not es_compatible():
		return &"version_incompatible"
	if DatosBasesSecretas.entrada(entrada_id).is_empty():
		return &"entrada_invalida"
	if tiene_base():
		return &"ya_tiene_base"
	_base = {"id": entrada_id, "propietario": _normalizar_propietario(jugador), "decoraciones": []}
	_visitas = 0
	_retorno.clear()
	return &"exito"


## Desmontar después de confirmar. Devuelve ID de la entrada a cerrar; 0 si no hay.
## Conserva retorno hasta que el coordinador haya salido del interior.
func recoger_base() -> int:
	if not es_compatible() or not tiene_base():
		return 0
	var anterior: int = id_base()
	_base.clear()
	_visitas = 0
	_mudanzas = mini(_mudanzas + 1, MAX_MUDANZAS)
	return anterior


func registrar_visita() -> bool:
	if not es_compatible() or not tiene_base():
		return false
	_visitas = mini(_visitas + 1, 255)
	return true


func registrar_retorno(posicion: Dictionary) -> bool:
	if not es_compatible() or not tiene_base():
		return false
	var normalizado: Dictionary = _normalizar_retorno(posicion)
	var entrada: Dictionary = DatosBasesSecretas.entrada(id_base())
	if normalizado.is_empty() or normalizado["mapa_actual"] != entrada["mapa"]:
		return false
	_retorno = normalizado
	return true


func limpiar_retorno() -> void:
	if es_compatible():
		_retorno.clear()


func obtener_colocaciones(contexto: StringName = CONTEXTO_BASE) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for colocacion: Dictionary in _colocaciones(contexto):
		resultado.append(colocacion.duplicate(true))
	return resultado


## Reserva la copia y persiste un ancla ya validada; NO decide si el suelo admite el mueble.
func registrar_colocacion_validada(copia_id: int, celda: Vector2i,
		contexto: StringName = CONTEXTO_BASE) -> StringName:
	if not es_compatible():
		return &"version_incompatible"
	if contexto != CONTEXTO_BASE and contexto != CONTEXTO_HABITACION:
		return &"contexto_invalido"
	if contexto == CONTEXTO_BASE and not tiene_base():
		return &"sin_base"
	var copia: Dictionary = obtener_copia(copia_id)
	if copia.is_empty():
		return &"copia_invalida"
	if not copia_disponible(copia_id):
		return &"en_uso"
	var decoracion_id: int = int(copia["decoracion_id"])
	if contexto == CONTEXTO_HABITACION and not DatosBasesSecretas.admite_habitacion(decoracion_id):
		return &"no_admitida"
	var colocaciones: Array = _colocaciones(contexto)
	var limite: int = LIMITE_BASE if contexto == CONTEXTO_BASE else LIMITE_HABITACION
	if colocaciones.size() >= limite:
		return &"limite_colocaciones"
	if DatosBasesSecretas.decoracion(decoracion_id).get("tipo_grafico", "") == "sprite":
		var cantidad_sprites: int = 0
		for colocacion: Dictionary in colocaciones:
			if DatosBasesSecretas.decoracion(int(colocacion["decoracion_id"])).get("tipo_grafico", "") == "sprite":
				cantidad_sprites += 1
		if cantidad_sprites >= LIMITE_SPRITES:
			return &"limite_sprites"
	if not _ancla_representable(celda, contexto):
		return &"posicion_invalida"
	colocaciones.append({"copia_id": copia_id, "decoracion_id": decoracion_id, "x": celda.x, "y": celda.y})
	return &"exito"


func guardar_decoracion(copia_id: int, contexto: StringName = CONTEXTO_BASE) -> StringName:
	return guardar_decoraciones([copia_id] as Array[int], contexto)


## Devolución agrupada de soporte y muñecos; preflight completo, sin parciales.
func guardar_decoraciones(copias: Array[int], contexto: StringName = CONTEXTO_BASE) -> StringName:
	if not es_compatible():
		return &"version_incompatible"
	if contexto != CONTEXTO_BASE and contexto != CONTEXTO_HABITACION:
		return &"contexto_invalido"
	var colocaciones: Array = _colocaciones(contexto)
	if copias.is_empty():
		return &"no_colocada"
	var vistas: Dictionary = {}
	for copia: int in copias:
		if vistas.has(copia):
			return &"copia_invalida"
		vistas[copia] = true
		var encontrada: bool = false
		for colocacion: Dictionary in colocaciones:
			if int(colocacion["copia_id"]) == copia:
				encontrada = true
				break
		if not encontrada:
			return &"no_colocada"
	for i: int in range(colocaciones.size() - 1, -1, -1):
		if vistas.has(int(colocaciones[i]["copia_id"])):
			colocaciones.remove_at(i)
	return &"exito"


func to_dict() -> Dictionary:
	if not es_compatible():
		return _datos_incompatibles.duplicate(true)
	return {
		"version": VERSION, "siguiente_copia_id": _siguiente_copia_id,
		"inventario": _inventario.duplicate(true), "base": _base.duplicate(true),
		"habitacion": _habitacion.duplicate(true), "retorno": _retorno.duplicate(true),
		"visitas": _visitas, "mudanzas": _mudanzas,
	}


## Devuelve false para un esquema desconocido (se preserva intacto y se bloquea mutación).
## Los registros inválidos de versión 1 se descartan con avisos de diagnóstico.
func from_dict(datos: Dictionary) -> bool:
	_inventario.clear()
	_base.clear()
	_habitacion.clear()
	_retorno.clear()
	_siguiente_copia_id = 1
	_visitas = 0
	_mudanzas = 0
	_datos_incompatibles.clear()
	avisos_carga.clear()
	if _entero(datos.get("version", VERSION), -1) != VERSION:
		_datos_incompatibles = datos.duplicate(true)
		avisos_carga.append("Versión de bases secretas incompatible; bloque preservado sin modificaciones.")
		return false
	_cargar_inventario(datos.get("inventario", []))
	_siguiente_copia_id = maxi(_siguiente_copia_id, clampi(
		_entero(datos.get("siguiente_copia_id", 1), 1), 1, MAX_ID_COPIA))
	_cargar_base(datos.get("base", {}))
	_cargar_colocaciones(datos.get("habitacion", []), CONTEXTO_HABITACION)
	_retorno = _normalizar_retorno(datos.get("retorno", {}))
	if tiene_base():
		_visitas = clampi(_entero(datos.get("visitas", 0)), 0, 255)
		if not _retorno.is_empty() and _retorno["mapa_actual"] != DatosBasesSecretas.entrada(id_base())["mapa"]:
			avisos_carga.append("Retorno descartado: no coincide con el exterior de la base.")
			_retorno.clear()
	_mudanzas = clampi(_entero(datos.get("mudanzas", 0)), 0, MAX_MUDANZAS)
	return true


func _cargar_inventario(datos: Variant) -> void:
	if not datos is Array:
		avisos_carga.append("Inventario inválido: se esperaba un array.")
		return
	for item: Variant in datos:
		if not item is Dictionary:
			avisos_carga.append("Copia descartada: formato inválido.")
			continue
		var copia_id: int = _entero(item.get("copia_id", 0))
		var decoracion_id: int = _entero(item.get("decoracion_id", 0))
		var categoria: StringName = _categoria(decoracion_id)
		if copia_id <= 0 or copia_id >= MAX_ID_COPIA or not obtener_copia(copia_id).is_empty() \
			or cantidad_categoria(categoria) >= DatosBasesSecretas.capacidad_categoria(categoria):
			avisos_carga.append("Copia %d descartada: ID, duplicado o capacidad inválidos." % copia_id)
			continue
		_inventario.append({"copia_id": copia_id, "decoracion_id": decoracion_id})
		_siguiente_copia_id = maxi(_siguiente_copia_id, copia_id + 1)


func _cargar_base(datos: Variant) -> void:
	if not datos is Dictionary:
		avisos_carga.append("Base descartada: formato inválido.")
		return
	if datos.is_empty():
		return
	var entrada_id: int = _entero(datos.get("id", 0))
	if DatosBasesSecretas.entrada(entrada_id).is_empty():
		avisos_carga.append("Base descartada: entrada desconocida.")
		return
	var propietario: Variant = datos.get("propietario", {})
	_base = {"id": entrada_id, "propietario": _normalizar_propietario(
		propietario if propietario is Dictionary else {}), "decoraciones": []}
	_cargar_colocaciones(datos.get("decoraciones", []), CONTEXTO_BASE)


func _cargar_colocaciones(datos: Variant, contexto: StringName) -> void:
	if not datos is Array:
		avisos_carga.append("Colocaciones de %s descartadas: formato inválido." % contexto)
		return
	for item: Variant in datos:
		if not item is Dictionary:
			avisos_carga.append("Colocación descartada: formato inválido.")
			continue
		var copia_id: int = _entero(item.get("copia_id", 0))
		var copia: Dictionary = obtener_copia(copia_id)
		if copia.is_empty() or _entero(item.get("decoracion_id", 0)) != int(copia["decoracion_id"]):
			avisos_carga.append("Colocación descartada: copia/adorno no coinciden.")
			continue
		var celda: Vector2i = Vector2i(_entero(item.get("x", -1), -1), _entero(item.get("y", -1), -1))
		var resultado: StringName = registrar_colocacion_validada(copia_id, celda, contexto)
		if resultado != &"exito":
			avisos_carga.append("Colocación descartada: %s." % resultado)


func _colocaciones(contexto: StringName) -> Array:
	if contexto == CONTEXTO_HABITACION:
		return _habitacion
	if contexto == CONTEXTO_BASE and tiene_base():
		return _base["decoraciones"]
	return []


func _ancla_representable(celda: Vector2i, contexto: StringName) -> bool:
	if celda.x < 0 or celda.y < 0 or celda.x > 15 or celda.y > 15:
		return false
	if contexto == CONTEXTO_BASE:
		var entrada: Dictionary = DatosBasesSecretas.entrada(id_base())
		var interior: Dictionary = DatosBasesSecretas.interior(int(entrada["interior_id"]))
		return celda.x < int(interior["ancho"]) and celda.y < int(interior["alto"])
	return true


static func _categoria(decoracion_id: int) -> StringName:
	return StringName(str(DatosBasesSecretas.decoracion(decoracion_id).get("categoria", "")))


static func _entero(valor: Variant, defecto: int = 0) -> int:
	if valor is int and valor >= -MAX_ID_COPIA and valor <= MAX_ID_COPIA:
		return valor
	if valor is float and is_finite(valor) and valor == floorf(valor) \
		and valor >= -MAX_ID_COPIA and valor <= MAX_ID_COPIA:
		return int(valor)
	return defecto


static func _normalizar_propietario(datos: Dictionary) -> Dictionary:
	return {"id": maxi(_entero(datos.get("id", 0)), 0),
		"nombre": str(datos.get("nombre", "")),
		"sexo": "F" if datos.get("sexo", "M") == "F" else "M"}


static func _normalizar_retorno(datos: Variant) -> Dictionary:
	if not datos is Dictionary or datos.is_empty():
		return {}
	var mapa: Variant = datos.get("mapa_actual", "")
	var capa: int = _entero(datos.get("capa_datos", 0), -1)
	var x: int = _entero(datos.get("cx"), MAX_ID_COPIA)
	var y: int = _entero(datos.get("cy"), MAX_ID_COPIA)
	var direccion: Variant = datos.get("direccion", [0, 1])
	if not mapa is String or mapa.is_empty() or capa < 0 or capa > 25 \
		or abs(x) > 32767 or abs(y) > 32767 or not direccion is Array or direccion.size() != 2:
		return {}
	var dx: int = _entero(direccion[0], 2)
	var dy: int = _entero(direccion[1], 2)
	if abs(dx) + abs(dy) != 1:
		return {}
	return {"mapa_actual": mapa, "cx": x, "cy": y, "capa_datos": capa,
		"direccion": [dx, dy], "nombre_lugar": str(datos.get("nombre_lugar", ""))}


## Validación sin mutación para contexto volátil de navegación/vista previa.
static func normalizar_retorno(datos: Dictionary) -> Dictionary:
	return _normalizar_retorno(datos)
