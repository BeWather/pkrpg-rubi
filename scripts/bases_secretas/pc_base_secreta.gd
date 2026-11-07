@tool
extends Marker2D
class_name PCBaseSecreta

## Interacción en el marcador original, sin crear árboles UI.
signal operacion_solicitada(operacion: StringName)
@export var editor: Node
var administrador: Node2D
var activa: bool = false
var ultima_operacion: StringName = &""
var _jugador: Node2D
var _dialogo: Node
var _control_previo: bool = false
var _originales: Array[Dictionary] = []
var _sesion: int = 0
var _mensaje_listo: bool = false
const PAUSA: StringName = &"pc_base_secreta"
const PRINCIPAL: Array[String] = ["BASES_PC_DECORACION", "BASES_PC_RECOGER", "BASES_PC_SALIR"]
const DECORACION: Array[String] = ["BASES_PC_DECORAR", "BASES_PC_GUARDAR", "BASES_PC_TIRAR", "BASES_PC_SALIR_DECORACION"]
const AYUDAS: Array[String] = ["BASES_PC_AYUDA_DECORAR", "BASES_PC_AYUDA_GUARDAR", "BASES_PC_AYUDA_TIRAR", "BASES_PC_AYUDA_SALIR"]


func _ready() -> void:
	if not Engine.is_editor_hint():
		Singleton.buscar_evento_accion.connect(_examinar)


func _interior() -> InteriorBaseSecreta:
	return get_parent() as InteriorBaseSecreta


func _vigente() -> bool:
	var interior: InteriorBaseSecreta = _interior()
	if not is_instance_valid(administrador) or interior == null or administrador.get("mapa_actual") != interior \
		or int(administrador.get("coneccion")) != 0 or interior.es_vista_previa() or interior._preview_activa \
		or interior.obtener_contexto().is_empty() or interior.sistema == null:
		return false
	return interior.sistema.es_compatible() and interior.sistema.tiene_base() \
		and interior.sistema.id_base() == int(interior.obtener_contexto()["entrada_id"])


func _examinar(celda: Vector2i, mapa: MapaConfiguracion) -> void:
	if Engine.is_editor_hint() or activa or mapa != _interior() or Singleton.capa_activa != 0 \
		or mapa.global_to_map_cell(global_position) != celda:
		return
	if administrador == null:
		administrador = get_node_or_null("/root/AdministradorMapa") as Node2D
	if not _vigente() or not administrador.call("puede_actuar_jugador"):
		return
	var jugador: Node2D = administrador.get("jugador") as Node2D
	if jugador == null or jugador.get("facing_direction") != Vector2.UP \
		or administrador.call("celda_frente_jugador") != celda:
		return
	abrir()


func abrir() -> bool:
	if activa or not _vigente() or not administrador.call("puede_actuar_jugador"):
		return false
	_dialogo = administrador.get("dialogo_bases") as Node
	_jugador = administrador.get("jugador") as Node2D
	if _dialogo == null or _jugador == null or not _dialogo.has_method("seleccionar_pc"):
		return false
	activa = true
	_sesion += 1
	var sesion: int = _sesion
	_control_previo = bool(_jugador.get("no_control"))
	_jugador.set("no_control", true)
	Singleton.mantener_pausa(PAUSA, true)
	_capturar()
	Singleton.play_sound.emit("SE_PC_LOGIN")
	var nombre: String = str(_interior().sistema.obtener_base().get("propietario", {}).get("nombre", ""))
	_mensaje_listo = false
	_mostrar_inicio(sesion, nombre)  # Texto y parpadeo simultáneos, como el script original.
	# fldeff_secret_base_pc.c: ON 4/12/20, OFF 8/16 (ticks de 60 Hz).
	for id: int in [0x224, 0x220, 0x224, 0x220, 0x224]:
		await get_tree().create_timer(4.0 / 60.0).timeout
		if sesion != _sesion:
			return false
		if not activa or not _vigente():
			cancelar()
			return false
		_dibujar(id)
	while _actual(sesion) and not _mensaje_listo:
		await get_tree().process_frame
	while _actual(sesion):
		var opcion: int = await _dialogo.call("seleccionar_pc", PRINCIPAL, [] as Array[String])
		if not _actual(sesion):
			break
		if opcion == 0:
			await _decoracion(sesion)
		elif opcion == 1:
			var recogida: bool = await _interior().solicitar_recogida(administrador)
			if sesion != _sesion:
				return false
			if recogida:
				_finalizar()
				return true
		else:
			break  # SALIR/B, nunca registro de bases ajenas.
	if sesion != _sesion:
		return false
	_finalizar()
	return true


func _actual(sesion: int) -> bool:
	return activa and sesion == _sesion and _vigente()


func _mostrar_inicio(sesion: int, nombre: String) -> void:
	await _dialogo.call("mensaje", DatosPCBase.texto("BASES_PC_INICIO").format({"nombre": nombre}))
	if sesion == _sesion:
		_mensaje_listo = true


func _decoracion(sesion: int) -> void:
	while _actual(sesion):
		var opcion: int = await _dialogo.call("seleccionar_pc", DECORACION, AYUDAS)
		if not _actual(sesion) or opcion < 0 or opcion >= 3:
			return
		ultima_operacion = [&"decorar", &"guardar", &"tirar"][opcion]
		operacion_solicitada.emit(ultima_operacion)
		if not is_instance_valid(editor):
			editor = _dialogo.get_node_or_null("EditorDecoracion")
		if is_instance_valid(editor) and editor.has_method("abrir_operacion"):
			await editor.call("abrir_operacion", ultima_operacion, _interior(), administrador)
		else:
			# Adaptador ausente (tests/UI incompleta): no simular operaciones.
			return


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and activa and not _vigente():
		cancelar()


func cancelar() -> void:
	if not activa:
		return
	# Inactivar antes de señales: un await reanudado no debe volver a abrir menús.
	activa = false
	_sesion += 1
	if is_instance_valid(editor) and editor.has_method("cancelar"):
		editor.call("cancelar")
	if is_instance_valid(_dialogo) and _dialogo.has_method("cancelar"):
		_dialogo.call("cancelar")
	_finalizar()


func _finalizar() -> void:
	activa = false
	_restaurar()
	Singleton.mantener_pausa(PAUSA, false)
	if is_instance_valid(_jugador) and is_instance_valid(administrador) and int(administrador.get("coneccion")) == 0:
		_jugador.set("no_control", _control_previo)
	_dialogo = null
	_jugador = null


func _capturar() -> void:
	_originales.clear()
	var compositor: MapaDecoracion = _interior().mapa_decoracion
	var celda: Vector2i = _interior().global_to_map_cell(global_position)
	for capa: TileMapLayer in [compositor.capa_fondo, compositor.capa_suelo, compositor.capa_superior]:
		_originales.append({"capa": capa, "celda": celda, "fuente": capa.get_cell_source_id(celda),
			"atlas": capa.get_cell_atlas_coords(celda), "alternativa": capa.get_cell_alternative_tile(celda)})


func _dibujar(id: int) -> void:
	for i: int in _originales.size():
		var original: Dictionary = _originales[i]
		(original["capa"] as TileMapLayer).set_cell(original["celda"], i, DatosInterioresBases.atlas_metatile(id))


func _restaurar() -> void:
	if not _originales.is_empty():
		Singleton.play_sound.emit("SE_PC_OFF")
	for original: Dictionary in _originales:
		if is_instance_valid(original["capa"]):
			(original["capa"] as TileMapLayer).set_cell(original["celda"], original["fuente"], original["atlas"], original["alternativa"])
	_originales.clear()  # Solo gráficos; flags/estado/superficies nunca se cambiaron.


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		cancelar()
