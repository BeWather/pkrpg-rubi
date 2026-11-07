## ItemOverworld.gd
## Objeto recogible en el overworld (pokéball en el suelo, objeto escondido...).
## Va como hijo directo del nodo `NPCs` del mapa: AdministradorMapa lo detecta por
## `coord_celda` (y `capa_datos`) y llama a `evento_accion()` al accionarlo.
##
## Flujo: mensaje "¡{PN} encontró {key}!" (sin esperar tecla) → se entrega el
## objeto, se marca la bandera y el item desaparece → fanfarria → "{PN} puso {key} en
## el BOLSILLO de {bname}." (espera tecla y cierra). El jugador queda bloqueado
## todo el flujo y se libera al cerrar el último mensaje.
##
## Si `objeto_a_entregar` no existe en la BD (tabla Objetos) no se entrega nada,
## no se marca la bandera y se avisa con push_warning.
@tool
extends Node2D

## Constantes para posicionamiento
const TILE_SIZE = 16
const OFFSET = Vector2(8, 14)

## Prefijo de la bandera en SistemaGuardado (datos_persistentes.banderas), para no
## chocar con otras banderas del juego (p. ej. "<npc_id>_combate").
const PREFIJO_BANDERA: String = "item_"
## Clave por defecto del mensaje de "encontrado" si `id_texto` está vacío.
const ID_TEXTO_POR_DEFECTO: String = "OBJETO_ENCONTRADO"
## Clave del mensaje de "guardado en la mochila".
const ID_TEXTO_GUARDADO: String = "OBJETO_GUARDADO"

## Capa de datos donde aplicar: -1 todas, >=0 solo capa especificada
## (mismo criterio que PokemonInicialOverworld; lo lee AdministradorMapa.next_to_npc).
@export var capa_datos: int = -1

## Identificador único (o casi) del item. La partida guarda una bandera propia
## con la clave "item_" + id_item (datos_persistentes.banderas), así que el item
## no reaparece tras recogerlo. Convención: mapa_objeto_nn, p. ej.
## "villa_raiz_casa1_piso2_sitrus_01". Si se deja vacío el item reaparece cada vez
## que se recarga el mapa; si dos items comparten id, recoger uno oculta el otro.
@export var id_item: String = "":
	set(value):
		id_item = value
		if is_inside_tree():
			update_configuration_warnings()

## nombre_interno del objeto en la tabla Objetos de poke.db (p. ej. BAYAZIDRA).
## Se guarda en mayúsculas; la BD lo tiene en minúsculas y la búsqueda no distingue.
@export var objeto_a_entregar: String = "":
	set(value):
		objeto_a_entregar = value.to_upper().strip_edges()
		if is_inside_tree():
			update_configuration_warnings()

## Cuántas unidades se entregan.
@export_range(1, 99) var cantidad: int = 1

## Oculta únicamente la representación visual. El nodo raíz permanece activo para
## que el jugador pueda encontrarlo interactuando con la casilla.
@export var oculto: bool = false:
	set(value):
		oculto = value
		_actualizar_visibilidad_visual()

## Clave de dialogos.csv del mensaje "encontrado". Admite {key} (nombre del objeto)
## y {PN} (nombre del jugador). El plugin del inspector le pinta el botón ✎.
@export var id_texto: String = ID_TEXTO_POR_DEFECTO:
	set(value):
		id_texto = value
		if is_inside_tree():
			update_configuration_warnings()

## Como en NpcBase: solo se ve (y se puede recoger) mientras esta condición se cumple
## (CondicionTexto: bandera, "MEDALLA_n"…). Vacía = sin condición. Se vuelve a
## comprobar cada vez que su mapa pasa a ser el actual (FLAG_ITEM_*/FLAG_HIDE_* que un
## evento limpia más tarde).
@export var bandera_mostrar: String = ""

## Inverso: se oculta mientras esta condición se cumple.
@export var bandera_ocultar: String = ""

## Bandera extra de SistemaGuardado que se activa al entregar el objeto (cuando otro
## evento comparte el FLAG_RECEIVED_* con el objeto del suelo). Vacía = ninguna.
@export var bandera_al_recoger: String = ""

var coord_celda: Vector2i = Vector2i.ZERO
@export var coord: Vector2i = Vector2i.ZERO:  ## Coordenada en tiles
	set(value):
		coord = value
		coord_celda = value
		if is_inside_tree():
			position = Vector2(value.x * TILE_SIZE + OFFSET.x, value.y * TILE_SIZE + OFFSET.y)
			update_configuration_warnings()

## Evita doble activación mientras dura el flujo de diálogos.
var _en_proceso: bool = false
## Permite omitir la reproducción real en las pruebas del flujo de mensajes.
var con_fanfarrias: bool = true
var _control_previo: bool = false
var _admin_interaccion: Node


func _ready() -> void:
	## Habilitar notificaciones de transformación en el editor
	if Engine.is_editor_hint():
		set_notify_transform(true)

	## Agregar al grupo NPC para que sea detectable por el sistema de interacción
	add_to_group("NPC")
	_actualizar_visibilidad_visual()
	if not Engine.is_editor_hint():
		# Diferido: PokemonEstaticoOverworld pone su textura después de este _ready.
		_crear_fuente_reflejo.call_deferred()

	## Verificar si ya fue recogido (solo en juego: en el editor no hay partida)
	if not Engine.is_editor_hint() and _ya_recogido():
		visible = false
	if not Engine.is_editor_hint() and not (bandera_mostrar.is_empty() and bandera_ocultar.is_empty()):
		aplicar_banderas_visibilidad()
		var mapa: Node = _buscar_mapa()
		if mapa != null and not mapa.mapa_activado.is_connected(_on_mapa_activado):
			mapa.mapa_activado.connect(_on_mapa_activado)


## ReflexionesAgua refleja AnimatedSprite2D: esta copia transparente del sprite le sirve de fuente, para
## que la bola se refleje en el agua como en Rubí. Un objeto escondido no tiene nada que reflejar.
func _crear_fuente_reflejo() -> void:
	var item := get_node_or_null("Item") as Sprite2D
	if oculto or item == null or item.texture == null:
		return
	var frames := SpriteFrames.new()
	frames.add_frame(&"default", item.texture)
	var fuente := AnimatedSprite2D.new()
	fuente.name = "FuenteReflejo"
	fuente.sprite_frames = frames
	fuente.centered = item.centered
	fuente.offset = item.offset
	fuente.self_modulate.a = 0.0
	fuente.set_meta(&"reflejo_aunque_bajo", true)
	add_child(fuente)


## Mapa (MapaConfiguracion) del que cuelga el objeto; null si no hay.
func _buscar_mapa() -> Node:
	var nodo: Node = get_parent()
	while nodo != null and not nodo.has_signal("mapa_activado"):
		nodo = nodo.get_parent()
	return nodo


func _on_mapa_activado(_por_warp: bool) -> void:
	aplicar_banderas_visibilidad()


## Oculta el objeto si `bandera_ocultar` se cumple, `bandera_mostrar` no se cumple o ya
## se recogió; lo muestra en otro caso.
func aplicar_banderas_visibilidad() -> void:
	visible = (bandera_ocultar.is_empty() or not CondicionTexto.cumple(bandera_ocultar)) \
		and (bandera_mostrar.is_empty() or CondicionTexto.cumple(bandera_mostrar)) \
		and not _ya_recogido()


func _actualizar_visibilidad_visual() -> void:
	var visual := get_node_or_null("Item") as CanvasItem
	if visual != null:
		visual.visible = not oculto


## ¿Impide pisar su celda? Un objeto visible es un objeto del mapa (pokéball) y
## bloquea como un NPC. Uno oculto es un bg_hidden_item_event de pokeruby: no
## ocupa la celda, se puede cruzar y solo se encuentra mirándola y pulsando A desde
## una celda contigua (AdministradorMapa.next_to_npc lo sigue devolviendo para
## interactuar; las colisiones usan AdministradorMapa.ocupante_bloqueante).
func bloquea_paso() -> bool:
	return not oculto


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if id_item.strip_edges().is_empty():
		avisos.append("id_item está vacío: el item reaparecerá cada vez que se recargue el mapa.")
	if objeto_a_entregar.is_empty():
		avisos.append("objeto_a_entregar está vacío: el item no entregará nada.")
	if id_texto.strip_edges().is_empty():
		avisos.append("id_texto está vacío: se usará la clave por defecto %s." % ID_TEXTO_POR_DEFECTO)
	return avisos


# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		coord = Vector2i(round((position.x - OFFSET.x) / TILE_SIZE), round((position.y - OFFSET.y) / TILE_SIZE))
		position = Vector2(coord.x * TILE_SIZE + OFFSET.x, coord.y * TILE_SIZE + OFFSET.y)


## Función llamada por el sistema de interacción (AdministradorMapa)
func evento_accion() -> void:
	recoger_item()


func recoger_item() -> void:
	if _en_proceso or not visible:
		return

	# Verificar si ya fue recogido
	if _ya_recogido():
		visible = false
		return

	# Validar ANTES de mostrar nada: un objeto inexistente no debe dejar al
	# jugador bloqueado ni marcar la bandera.
	var datos: Dictionary = _datos_objeto_validos()
	if datos.is_empty():
		return

	var admin: Node = _obtener_administrador()
	if admin == null or admin.get("cuadro_dialogo") == null:
		push_warning("[ItemOverworld] '%s': AdministradorMapa/cuadro de diálogo no disponible." % id_item)
		return

	_en_proceso = true
	_admin_interaccion = admin
	# Capturar ANTES de activar nuestra pausa: Character.no_control incluye
	# las pausas globales, no es solo el estado local que escribe su setter.
	if admin.get("jugador"):
		_control_previo = bool(admin.jugador.no_control)
	Singleton.mantener_pausa(&"item_overworld", true)
	# Bloquear al jugador ya (el cuadro de diálogo lo libera al cerrarse).
	if admin.get("jugador"):
		admin.jugador.no_control = true

	var mensaje: String = _traducir(_id_texto_efectivo()).replace("{key}", str(datos.get("nombre", objeto_a_entregar)))
	# Sin esperar tecla y sin cerrar: al terminar el texto se ejecuta el callback,
	# que entrega el objeto y encadena el segundo mensaje.
	admin.cuadro_dialogo.mostrar(mensaje, false, false, _on_aviso_completo)


## Callback del primer mensaje: entrega el objeto y muestra dónde se guardó.
func _on_aviso_completo() -> void:
	var admin: Node = _obtener_administrador()
	var metas: Dictionary = _entregar_objeto()

	if not metas.get("exito", false):
		# No debería ocurrir (se validó antes), pero nunca dejar al jugador atascado.
		_abortar_interaccion(admin)
		return
	# El texto de encontrado permanece visible mientras suena la fanfarria.
	# No reproducir al examinar objetos inválidos o ya recogidos.
	if con_fanfarrias:
		await _reproducir_fanfarria_objeto()
	if not _interaccion_vigente():
		_liberar_jugador()
		return

	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto_a_entregar)
	var mensaje: String = _traducir(ID_TEXTO_GUARDADO)
	mensaje = mensaje.replace("{key}", str(datos.get("nombre", objeto_a_entregar)))
	mensaje = mensaje.replace("{bname}", str(metas.get("bolsillo_nombre", "")).to_upper())
	if not is_instance_valid(admin) or admin.get("cuadro_dialogo") == null:
		_liberar_jugador()
		return
	# Espera tecla y cierra; al cerrar se libera al jugador.
	admin.cuadro_dialogo.mostrar(mensaje, true, true, _liberar_jugador)


## Entrega el objeto a la mochila, marca la bandera y oculta el item.
## Devuelve el resultado de dar_objeto_jugador ({exito, bolsillo_id, bolsillo_nombre,
## mensaje}); con exito=false si el objeto no existe en la BD (no se entrega nada,
## no se marca la bandera y el item sigue visible).
func _entregar_objeto() -> Dictionary:
	if _datos_objeto_validos().is_empty():
		return {"exito": false, "bolsillo_id": -1, "bolsillo_nombre": "", "mensaje": "objeto inexistente"}

	SistemaGuardado.inicializar_mochila_estructura()
	var metas: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto_a_entregar, cantidad)
	if metas.get("exito", false):
		_set_bandera(true)
		if not bandera_al_recoger.is_empty() and is_instance_valid(SistemaGuardado):
			SistemaGuardado.set_flag(bandera_al_recoger, true)
		visible = false
	return metas


## Datos del objeto (SistemaGuardado.obtener_datos_objeto_completos) si existe en la
## BD y tiene bolsillo válido; diccionario vacío (con push_warning) si no.
func _datos_objeto_validos() -> Dictionary:
	if objeto_a_entregar.is_empty():
		push_warning("[ItemOverworld] '%s': objeto_a_entregar vacío." % id_item)
		return {}
	if not is_instance_valid(SistemaGuardado):
		return {}

	# Comprobación previa sobre la fila cruda: obtener_datos_objeto_completos rompe
	# con bolsillo NULL o fuera de los bolsillos activos.
	if is_instance_valid(DatabaseManager) and DatabaseManager.esta_conectado():
		var fila: Dictionary = DatabaseManager.obtener_datos_objeto(objeto_a_entregar)
		var bolsillo_bd: Variant = fila.get("bolsillo_id")
		if fila.is_empty() or bolsillo_bd == null \
				or int(bolsillo_bd) < 1 or int(bolsillo_bd) > DatabaseManager.obtener_nombres_bolsillos().size():
			push_warning("[ItemOverworld] '%s': el objeto '%s' no existe en la tabla Objetos o no tiene bolsillo válido." % [id_item, objeto_a_entregar])
			return {}

	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto_a_entregar)
	if int(datos.get("bolsillo_id", -1)) < 0:
		push_warning("[ItemOverworld] '%s': el objeto '%s' no existe en la BD; no se entrega." % [id_item, objeto_a_entregar])
		return {}
	return datos


## Cierra el diálogo abierto y libera al jugador (rama de error tras el primer mensaje).
func _abortar_interaccion(admin: Node) -> void:
	if admin != null and admin.get("cuadro_dialogo") != null:
		admin.cuadro_dialogo.cerrar()
	_liberar_jugador()


func _liberar_jugador() -> void:
	Singleton.mantener_pausa(&"item_overworld", false)
	if is_instance_valid(_admin_interaccion) and is_instance_valid(_admin_interaccion.get("jugador")):
		_admin_interaccion.jugador.no_control = _control_previo
	_en_proceso = false
	_admin_interaccion = null


func _interaccion_vigente() -> bool:
	return is_inside_tree() and _en_proceso and is_instance_valid(_admin_interaccion) \
		and _obtener_administrador() == _admin_interaccion


func _reproducir_fanfarria_objeto() -> void:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto_a_entregar)
	var tema: String = Fanfarria.tema_objeto_obtenido(int(datos.get("bolsillo_id", -1)))
	await Fanfarria.reproducir_cancelable(self, tema, _interaccion_vigente)


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and _en_proceso:
		_liberar_jugador()


func _id_texto_efectivo() -> String:
	var clave: String = id_texto.strip_edges()
	return clave if not clave.is_empty() else ID_TEXTO_POR_DEFECTO


## tr() con aviso si la clave no está en las traducciones (tr devuelve la propia clave).
func _traducir(clave: String) -> String:
	var texto: String = tr(clave)
	if texto == clave and not clave.contains(" "):
		push_warning("[ItemOverworld] '%s': la clave de diálogo '%s' no existe en dialogos.csv." % [id_item, clave])
	return texto


## get_node_or_null: al ejecutar una escena de mapa suelta (F6) el AdministradorMapa
## puede no existir todavía; no es un error.
func _obtener_administrador() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Clave real de la bandera en la partida ("item_" + id_item).
func _clave_bandera() -> String:
	return PREFIJO_BANDERA + id_item.strip_edges()


func _ya_recogido() -> bool:
	return not id_item.strip_edges().is_empty() and _get_bandera()


func _get_bandera() -> bool:
	if Engine.is_editor_hint():
		return false
	if is_instance_valid(SistemaGuardado):
		return SistemaGuardado.get_flag(_clave_bandera())
	return false


func _set_bandera(valor: bool) -> void:
	if Engine.is_editor_hint() or id_item.strip_edges().is_empty():
		return
	if is_instance_valid(SistemaGuardado):
		SistemaGuardado.set_flag(_clave_bandera(), valor)


## Función para resetear el item (útil para debug)
func resetear_item() -> void:
	_set_bandera(false)
	visible = true
	_en_proceso = false
