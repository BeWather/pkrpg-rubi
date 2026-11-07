@tool
extends Marker2D
class_name EntradaBaseSecreta

## Entrada declarativa: la posición editable es Godot. ID enlaza catálogo GBA.
## Examen, apertura, traslado y navegación; acceso directo desde EQUIPO.
enum TipoEntrada { CUEVA, ARBOL, ARBUSTO }
@export var entrada_id: int = 0
@export var capa_datos: int = 0
@export var capa_visual: TileMapLayer
@export var capas_visuales: Array[TileMapLayer] = []
@export var imagen_cerrada: CanvasItem
@export var imagen_abierta: CanvasItem
@export var efecto_apertura: AnimatedSprite2D
@export var tipo_entrada: TipoEntrada = TipoEntrada.CUEVA
@export_range(0, 40) var ticks_apertura: int = 20
var administrador: Node2D
var _activa: bool = false
var _abierta: bool = false
var _temporal: bool = false
var _original: Array = []
var _originales: Array[Dictionary] = []
var _sesion_equipo: int = 0
var _operacion_equipo: Dictionary = {}
var _pose_equipo_pendiente: bool = false
const MOTIVO_PAUSA: StringName = &"bases_secretas"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("entradas_bases_secretas")
	Singleton.buscar_evento_accion.connect(_examinar_celda)
	var mapa: MapaConfiguracion = _mapa_padre()
	if mapa != null:
		mapa.mapa_activado.connect(_al_activar)
		if capa_visual != null:
			var celda: Vector2i = mapa.global_to_map_cell(global_position)
			_original = [capa_visual.get_cell_source_id(celda), capa_visual.get_cell_atlas_coords(celda),
				capa_visual.get_cell_alternative_tile(celda)]
		var capas: Array[TileMapLayer] = capas_visuales.duplicate()
		if capa_visual != null and not capas.has(capa_visual):
			capas.append(capa_visual)
		for capa: TileMapLayer in capas:
			var celda: Vector2i = capa.local_to_map(capa.to_local(global_position))
			_originales.append({"capa": capa, "celda": celda,
				"source": capa.get_cell_source_id(celda), "atlas": capa.get_cell_atlas_coords(celda),
				"alternativa": capa.get_cell_alternative_tile(celda)})
		_al_activar(false)


func _al_activar(_por_warp: bool) -> void:
	actualizar_propiedad()


func actualizar_propiedad() -> void:
	_temporal = false
	aplicar_abierta(SistemaGuardado.get_bases_secretas().id_base() == entrada_id)


func aplicar_abierta(abierta: bool) -> void:
	if imagen_abierta == null or _originales.is_empty():
		return
	for original: Dictionary in _originales:
		var capa: TileMapLayer = original["capa"] as TileMapLayer
		if abierta or imagen_cerrada != null:
			capa.erase_cell(original["celda"])
		else:
			_restaurar_capa(original)
	if imagen_cerrada != null:
		imagen_cerrada.visible = not abierta
	imagen_abierta.visible = abierta
	_abierta = abierta
	# Original: 0xC00 sigue bloqueado, incluso abierto. No liberar flags de colisión.


func restaurar_celda_original() -> void:
	for original: Dictionary in _originales:
		_restaurar_capa(original)
	if imagen_cerrada != null:
		imagen_cerrada.hide()
	if imagen_abierta != null:
		imagen_abierta.hide()
	_abierta = false


func _restaurar_capa(original: Dictionary) -> void:
	var capa: TileMapLayer = original["capa"] as TileMapLayer
	if is_instance_valid(capa):
		capa.set_cell(original["celda"], int(original["source"]), original["atlas"], int(original["alternativa"]))


func clave_texto(sufijo: String) -> String:
	return "BASES_%s_%s" % [["CUEVA", "ARBOL", "ARBUSTO"][tipo_entrada], sufijo]


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _operacion_equipo.is_empty() and not _equipo_vigente(_sesion_equipo):
		cancelar_uso_equipo()
	if administrador == null:
		administrador = get_node_or_null("/root/AdministradorMapa") as Node2D
	if administrador == null or administrador.get("mapa_actual") != _mapa_padre():
		return
	if _temporal and not _activa and int(administrador.get("coneccion")) == 0:
		_al_activar(false)  # También revierte una navegación abortada.
	if _abierta and Input.is_action_just_pressed("btn_arriba") and administrador.call("puede_actuar_jugador"):
		_examinar_celda(administrador.call("celda_frente_jugador"), _mapa_padre())


func _examinar_celda(celda: Vector2i, mapa: MapaConfiguracion) -> void:
	if _activa or mapa != _mapa_padre() or mapa.global_to_map_cell(global_position) != celda \
		or Singleton.capa_activa != capa_datos:
		return
	if administrador == null:
		administrador = get_node_or_null("/root/AdministradorMapa") as Node2D
	if administrador == null or administrador.get("dialogo_bases") == null:
		return
	if administrador.get("mapa_actual") != mapa or not administrador.call("puede_actuar_jugador"):
		return
	var jugador: Node2D = administrador.get("jugador") as Node2D
	if jugador == null or jugador.get("facing_direction") != Vector2.UP:
		return
	_ejecutar_examen()


static func conoce_dano_secreto(equipo: Array) -> bool:
	return pokemon_con_dano_secreto(equipo) != null


static func pokemon_con_dano_secreto(equipo: Array) -> BasePokemon:
	for pokemon: Variant in equipo:
		if not pokemon is BasePokemon or pokemon.huevo:
			continue
		for movimiento: Movimiento in pokemon.movimientos:
			if movimiento != null and movimiento.get_nombre_interno() == "DANOSECRETO":
				return pokemon
	return null


func _ejecutar_examen() -> void:
	_activa = true
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var jugador: Node2D = administrador.get("jugador") as Node2D
	jugador.set("no_control", true)
	var sistema: SistemaBasesSecretas = SistemaGuardado.get_bases_secretas()
	var dialogo: Node = administrador.get("dialogo_bases") as Node
	if sistema.id_base() == entrada_id:
		solicitar_entrada(administrador)
	else:
		var pokemon: BasePokemon = pokemon_con_dano_secreto(SistemaGuardado.get_equipo())
		var usar: bool = false
		if pokemon == null or not sistema.es_compatible():
			await dialogo.call("mensaje", DatosCicloBaseSecreta.texto(clave_texto("DESCRIPCION")))
		elif sistema.tiene_base():
			usar = await _preguntar_traslado(sistema, dialogo)
		else:
			usar = await dialogo.call("preguntar", DatosCicloBaseSecreta.texto(clave_texto("USAR")))
		if usar and not sistema.tiene_base():
			await _abrir_con_movimiento(pokemon, dialogo)
	_activa = false
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if int(administrador.get("coneccion")) == 0:
		jugador.set("no_control", false)


func _preguntar_traslado(sistema: SistemaBasesSecretas, dialogo: Node) -> bool:
	var anterior: int = sistema.id_base()
	var origen: Dictionary = DatosBasesSecretas.entrada(anterior)
	var lugar: String = Lugares.nombre_lugar(str(origen["mapa"]).to_upper())
	if not await dialogo.call("preguntar", DatosCicloBaseSecreta.texto("BASES_MUDAR_PREGUNTA").format({"lugar": lugar})):
		return false
	if not await dialogo.call("preguntar", DatosCicloBaseSecreta.texto("BASES_RECOGER_CONFIRMAR")):
		return false
	# AskToMoveSecretBase: desmontar entre fundidos ANTES de la tercera pregunta.
	if not await administrador.call("desmontar_base_para_traslado", self, anterior):
		return false
	return await dialogo.call("preguntar", DatosCicloBaseSecreta.texto("BASES_MUDANZA_TERMINADA"))


func usar_desde_equipo(pokemon: BasePokemon, admin: Node) -> bool:
	if not AccesoDanoSecreto.puede_usar(pokemon, admin) \
		or AccesoDanoSecreto.entrada_frente(admin) != self \
		or admin.get("dialogo_bases") == null or not admin.call("puede_actuar_jugador"):
		return false
	administrador = admin as Node2D
	var jugador: Node2D = admin.get("jugador") as Node2D
	_activa = true
	_sesion_equipo += 1
	var sesion: int = _sesion_equipo
	_operacion_equipo = {"mapa": _mapa_padre(), "jugador": jugador,
		"celda": _mapa_padre().global_to_map_cell(jugador.global_position),
		"sistema": SistemaGuardado.get_bases_secretas(), "pokemon": pokemon, "entrada_id": entrada_id,
		"control_previo": bool(jugador.get("no_control"))}
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	jugador.set("no_control", true)
	if jugador.has_method("_reproducir_mov_campo"):
		_pose_equipo_pendiente = true
		await jugador.call("_reproducir_mov_campo", pokemon, _equipo_vigente.bind(sesion))
		_pose_equipo_pendiente = false
	if _equipo_vigente(sesion):
		await _abrir_con_movimiento(pokemon, admin.get("dialogo_bases"), false, _equipo_vigente.bind(sesion))
	if sesion == _sesion_equipo:
		_finalizar_uso_equipo()
	return true


func _equipo_vigente(sesion: int) -> bool:
	if sesion != _sesion_equipo or not _activa or _operacion_equipo.is_empty() \
		or not is_instance_valid(administrador) or int(administrador.get("coneccion")) != 0:
		return false
	var mapa: MapaConfiguracion = _operacion_equipo["mapa"]
	var jugador: Node2D = _operacion_equipo["jugador"]
	var sistema: SistemaBasesSecretas = _operacion_equipo["sistema"]
	var pokemon: BasePokemon = _operacion_equipo["pokemon"]
	return is_instance_valid(mapa) and is_instance_valid(jugador) \
		and administrador.get("mapa_actual") == mapa and administrador.get("jugador") == jugador \
		and _mapa_padre() == mapa and Singleton.capa_activa == capa_datos \
		and entrada_id == int(_operacion_equipo["entrada_id"]) \
		and mapa.global_to_map_cell(global_position) == (_operacion_equipo["celda"] as Vector2i) + Vector2i.UP \
		and mapa.global_to_map_cell(jugador.global_position) == _operacion_equipo["celda"] \
		and jugador.get("facing_direction") == Vector2.UP \
		and sistema == SistemaGuardado.get_bases_secretas() and sistema.es_compatible() and not sistema.tiene_base() \
		and SistemaGuardado.get_equipo().has(pokemon) \
		and pokemon_con_dano_secreto([pokemon]) == pokemon


func cancelar_uso_equipo() -> void:
	if _operacion_equipo.is_empty():
		return
	_sesion_equipo += 1
	var dialogo: Node = administrador.get("dialogo_bases") if is_instance_valid(administrador) else null
	_finalizar_uso_equipo()
	actualizar_propiedad()
	if is_instance_valid(dialogo) and dialogo.has_method("cancelar"):
		dialogo.call("cancelar")


func _finalizar_uso_equipo() -> void:
	var jugador: Node2D = _operacion_equipo.get("jugador") as Node2D
	if is_instance_valid(jugador) and is_instance_valid(administrador) and int(administrador.get("coneccion")) == 0:
		jugador.set("no_control", bool(_operacion_equipo.get("control_previo", false)))
	if efecto_apertura != null:
		efecto_apertura.stop()
		efecto_apertura.hide()
	_operacion_equipo.clear()
	_activa = false
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if _temporal and is_instance_valid(administrador) and int(administrador.get("coneccion")) == 0:
		actualizar_propiedad()


func _abrir_con_movimiento(pokemon: BasePokemon, dialogo: Node, con_mensaje: bool = true, vigente: Callable = Callable()) -> void:
	var nombre: String = pokemon.mote if not pokemon.mote.is_empty() else pokemon.nombre
	var movimiento: String = "SECRET POWER" if TranslationServer.get_locale().begins_with("en") else "DAÑO SECRETO"
	if con_mensaje:
		await dialogo.call("mensaje", DatosCicloBaseSecreta.texto("BASES_MOVIMIENTO_USADO").format(
			{"nombre": nombre, "movimiento": movimiento}))
	if vigente.is_valid() and not vigente.call():
		return
	if efecto_apertura != null:
		efecto_apertura.show()
		efecto_apertura.play("abrir")
		await get_tree().create_timer(ticks_apertura / 60.0).timeout
		if vigente.is_valid() and not vigente.call():
			return
		aplicar_abierta(true)
		# El task original dura 40 ticks; no depender del reloj de sprites fuera de viewport.
		if ticks_apertura < 40:
			await get_tree().create_timer((40 - ticks_apertura) / 60.0).timeout
			if vigente.is_valid() and not vigente.call():
				return
		efecto_apertura.stop()
		efecto_apertura.hide()
	else:
		aplicar_abierta(true)
	_temporal = true
	await dialogo.call("mensaje", DatosCicloBaseSecreta.texto(clave_texto("DESCUBIERTA")))
	if vigente.is_valid() and not vigente.call():
		return
	if not solicitar_entrada(administrador, true):
		actualizar_propiedad()


func _exit_tree() -> void:
	if not _operacion_equipo.is_empty() and not Engine.is_editor_hint():
		cancelar_uso_equipo()
	if not Engine.is_editor_hint():
		restaurar_celda_original()
	if _activa and not Engine.is_editor_hint():
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)


func solicitar_entrada(administrador: Node, vista_previa: bool = false) -> bool:
	if administrador == null or not administrador.has_method("entrar_base_secreta"):
		return false
	var mapa: MapaConfiguracion = _mapa_padre()
	if mapa == null or administrador.get("mapa_actual") != mapa:
		return false
	var jugador: Node2D = administrador.get("jugador") as Node2D
	if jugador == null:
		return false
	var celda: Vector2i = mapa.global_to_map_cell(jugador.global_position)
	var retorno: Dictionary = {"mapa_actual": mapa.scene_file_path.get_file().get_basename(),
		"cx": celda.x, "cy": celda.y, "capa_datos": Singleton.capa_activa,
		"direccion": [0, 1], "nombre_lugar": mapa.obtener_seccion_efectiva()}
	return bool(administrador.call("entrar_base_secreta", entrada_id, retorno, vista_previa))


func _mapa_padre() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	return null
