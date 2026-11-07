@tool
extends "res://scripts/npc/npc_base.gd"
class_name NpcRegaloMT43

const PAUSA: StringName = &"regalo_mt43"
const DIALOGO: PackedScene = preload("res://UI/maquinas/dialogo_activacion.tscn")
var _dialogo: DialogoBaseSecreta
var _sesion: int = 0
var _contexto: Dictionary = {}
var _activa: bool = false
var _entregado: bool = false
var _fanfarria_pendiente: bool = false


func aplicar_bandera_ocultar() -> void:
	if _activa: return
	visible = not RegaloMT43.recibido()


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _activa or RegaloMT43.recibido(): return
	if not is_inside_tree() or nodo_administrador == null or jugador == null \
		or nodo_administrador.cuadro_dialogo == null or nodo_administrador.mapa_actual != _obtener_mapa_propio() \
		or nodo_administrador.coneccion != 0 or not nodo_administrador.puede_actuar_jugador() \
		or Singleton.capa_activa != capa_datos: return
	_ejecutar()


func _ejecutar() -> void:
	_sesion += 1
	var sesion: int = _sesion
	_activa = true
	_entregado = false
	_contexto = {"partida": SistemaGuardado.datos_vivos, "mapa": _obtener_mapa_propio(),
		"jugador": jugador, "admin": nodo_administrador, "posicion": jugador.global_position,
		"frente": jugador.facing_direction, "capa": Singleton.capa_activa,
		"cuadro": nodo_administrador.cuadro_dialogo,
		"raiz_cuadro": nodo_administrador.cuadro_dialogo.nodo_raiz,
		"jugador_cuadro": nodo_administrador.cuadro_dialogo.nodo_jugador}
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()
	Singleton.mantener_pausa(PAUSA, true)
	# El cuadro no posee control global durante esta sesión; solo la pausa propia.
	nodo_administrador.cuadro_dialogo.nodo_raiz = null
	nodo_administrador.cuadro_dialogo.nodo_jugador = null
	_dialogo = DIALOGO.instantiate() as DialogoBaseSecreta
	_dialogo.cuadro = nodo_administrador.cuadro_dialogo
	nodo_administrador.get_node("Menu").add_child(_dialogo)
	var acepta: bool = await _dialogo.preguntar(RegaloMT43.texto("MT43_REGALO_PROPUESTA"))
	if not _vigente(sesion): return
	if not acepta:
		await _dialogo.mensaje(RegaloMT43.texto("MT43_REGALO_RECHAZO"))
	elif RegaloMT43.entregar(_contexto["partida"]):
		_entregado = true
		# Cuadro y fanfarria existentes; poll cancelable en la misma sesión.
		_dialogo.show()
		_dialogo.cuadro.mostrar(RegaloMT43.texto("MT43_REGALO_OBTENIDO"), false, false, _dialogo.texto_terminado.emit)
		_reproducir_obtenido(sesion)
		while _vigente(sesion) and (_dialogo.cuadro.estado_dialogo == _dialogo.cuadro.EstadoDialogo.APARECIENDO or _fanfarria_pendiente):
			await get_tree().process_frame
		if not _vigente(sesion): return
		await _dialogo.mensaje(RegaloMT43.texto("MT43_REGALO_GUARDADO"))
		if not _vigente(sesion): return
		await _dialogo.mensaje(RegaloMT43.texto("MT43_REGALO_EXPLICACION"))
		if not _vigente(sesion): return
		for paso: Vector2i in RegaloMT43.retirada(_contexto["frente"]):
			mover_npc(Vector2(paso), true)
			while paso_en_curso and _vigente(sesion): await get_tree().process_frame
			if not _vigente(sesion): return
	else:
		await _dialogo.mensaje(RegaloMT43.texto("MT43_REGALO_SIN_ESPACIO"))
	if _vigente(sesion): cancelar()


func _reproducir_obtenido(sesion: int) -> void:
	_fanfarria_pendiente = true
	await Fanfarria.reproducir_cancelable(self, "OBTENIDA_UNA_MT", _vigente.bind(sesion))
	if sesion == _sesion: _fanfarria_pendiente = false


func _vigente(sesion: int) -> bool:
	var admin: Variant = _contexto.get("admin")
	var actor: Variant = _contexto.get("jugador")
	return _activa and sesion == _sesion and is_inside_tree() and not is_queued_for_deletion() \
		and is_instance_valid(_dialogo) and not _dialogo.is_queued_for_deletion() \
		and is_instance_valid(admin) and is_instance_valid(actor) and is_visible_in_tree() \
		and _contexto.get("partida") == SistemaGuardado.datos_vivos and admin.jugador == actor \
		and is_instance_valid(_contexto.get("cuadro")) and admin.cuadro_dialogo == _contexto.get("cuadro") \
		and admin.mapa_actual == _contexto.get("mapa") and int(admin.coneccion) == 0 \
		and actor.global_position == _contexto.get("posicion") and actor.facing_direction == _contexto.get("frente") \
		and Singleton.capa_activa == int(_contexto.get("capa", -1)) \
		and (_entregado or not RegaloMT43.recibido())


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _activa and not _vigente(_sesion): cancelar()
	super._process(delta)


func cancelar() -> void:
	if not _activa: return
	_sesion += 1
	_activa = false
	_fanfarria_pendiente = false
	Singleton.mantener_pausa(PAUSA, false)
	var dialogo: DialogoBaseSecreta = _dialogo
	_dialogo = null
	if is_instance_valid(dialogo):
		dialogo.cancelar()
		dialogo.queue_free()
	var cuadro: Variant = _contexto.get("cuadro")
	if is_instance_valid(cuadro):
		cuadro.nodo_raiz = _contexto.get("raiz_cuadro") if is_instance_valid(_contexto.get("raiz_cuadro")) else null
		cuadro.nodo_jugador = _contexto.get("jugador_cuadro") if is_instance_valid(_contexto.get("jugador_cuadro")) else null
	_contexto.clear()
	_completar_paso_en_curso()
	cambiar_estado(EstadoNPC.IDLE)
	_volver_a_direccion_base()
	aplicar_bandera_ocultar()


func _exit_tree() -> void:
	if not Engine.is_editor_hint(): cancelar()


func _notification(what: int) -> void:
	super._notification(what)
	# El enabler del mapa puede parar _process al ocultarlo: cancelar aquí también.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not Engine.is_editor_hint() \
		and _activa and not is_visible_in_tree(): cancelar()
