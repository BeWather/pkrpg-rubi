@tool
class_name EventoPCCasa
extends Node2D

@export var capa_datos: int = -1
@export var coord_tile: Vector2i = Vector2i.ZERO:
	set(value):
		coord_tile = value
		if is_inside_tree():
			position = Vector2(value.x * 16 + 8, value.y * 16 + 8)
			update_configuration_warnings()
@export var direccion: Singleton.enum_dir_cartel = Singleton.enum_dir_cartel.TODAS_DIRECCIONES
@export var id_texto: String = "CASA_PC"
## TileAlterno con la pantalla encendida del PC: parpadea al usarlo (BlinkPCScreen
## de Rubí) y queda encendida mientras el PC está abierto.
@export var pantalla: NodePath

## Parpadeos y fotogramas por cambio del encendido (5 y 7 en Rubí).
const PARPADEOS_PANTALLA: int = 5
const FOTOGRAMAS_PARPADEO: int = 7

var _activo: bool = false
var _menu_pc: MenuPCCasa = null
var _jugador: Node2D = null
var administrador: Node2D
var _control_previo: bool = false
var _sesion: int = 0


func _ready() -> void:
	add_to_group("Cartel")
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_crear_icono_editor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		coord_tile = Vector2i(round((position.x - 8) / 16), round((position.y - 8) / 16))
		position = Vector2(coord_tile.x * 16 + 8, coord_tile.y * 16 + 8)


func accionar_cartel() -> void:
	if _activo or Engine.is_editor_hint():
		return
	if not is_instance_valid(administrador):
		administrador = get_tree().root.get_node_or_null("AdministradorMapa") as Node2D
	if not _vigente():
		return
	_sesion += 1
	var sesion: int = _sesion
	_activo = true
	_jugador = administrador.get("jugador") as Node2D
	_control_previo = bool(_jugador.get("no_control")) if _jugador != null else false
	Singleton.mantener_pausa(&"pc_casa", true)
	# SE_PC_ON de Rubí: no hay audio con ese nombre en el proyecto; el más cercano es
	# "pc_abrir" (computeropen.wav). El apagado lo pone el menú ("pc_cerrar").
	Singleton.play_sound.emit("pc_abrir")
	if _jugador:
		_jugador.no_control = true
	var tile_pantalla: TileAlterno = _pantalla()
	if tile_pantalla != null:
		await tile_pantalla.parpadear(PARPADEOS_PANTALLA, FOTOGRAMAS_PARPADEO)
		if not _activo or sesion != _sesion:
			return  # el PC se cerró durante el encendido
	_mensaje_inicio(sesion)


func _pantalla() -> TileAlterno:
	return get_node_or_null(pantalla) as TileAlterno if not pantalla.is_empty() else null


func _vigente() -> bool:
	var habitacion: HabitacionJugador = get_parent().get_parent() as HabitacionJugador
	return habitacion != null and habitacion._preparada \
		and habitacion.casa == HistoriaVillaRaiz.casa_jugador() \
		and habitacion.sistema != null and habitacion.sistema.es_compatible() \
		and is_instance_valid(administrador) and administrador.get("mapa_actual") == habitacion \
		and int(administrador.get("coneccion")) == 0


func _mensaje_inicio(sesion: int) -> void:
	var dialogo: DialogoBaseSecreta = administrador.get("dialogo_bases") as DialogoBaseSecreta
	if dialogo == null:
		_cerrar_pc()
		return
	await dialogo.mensaje(tr(id_texto))
	if _activo and sesion == _sesion:
		_abrir_menu(sesion)


func _abrir_menu(sesion: int) -> void:
	# El callback del texto inicial ocurre justo antes de que ese diálogo se
	# cierre. Esperar un instante evita que dicho cierre afecte al texto del menú.
	await get_tree().create_timer(0.02).timeout
	if not _activo or not is_inside_tree() or sesion != _sesion:
		return
	if not _vigente():
		_cerrar_pc()
		return
	var capa_ui: Node = administrador.get_node_or_null("Menu")
	var dialogo: DialogoBaseSecreta = administrador.get("dialogo_bases") as DialogoBaseSecreta
	var cuadro_dialogo: NinePatchRect = dialogo.cuadro if dialogo != null else null
	if not capa_ui or not cuadro_dialogo:
		_cerrar_pc()
		return

	_menu_pc = preload("res://UI/pc_casa/menu_pc_casa.tscn").instantiate() as MenuPCCasa
	if not _menu_pc:
		_cerrar_pc()
		return
	_menu_pc.configurar_cuadro_dialogo(cuadro_dialogo)
	_menu_pc.habitacion = get_parent().get_parent() as HabitacionJugador
	if not is_instance_valid(administrador):
		administrador = get_tree().root.get_node_or_null("AdministradorMapa") as Node2D
	_menu_pc.administrador = administrador
	capa_ui.add_child(_menu_pc)
	_menu_pc.cerrado.connect(_cerrar_pc)
	if _jugador:
		_jugador.no_control = true


func _cerrar_pc() -> void:
	var abierta: bool = _activo
	# Con el menú abierto es él quien suena al cerrarse ("pc_cerrar").
	var sono_el_menu: bool = _menu_pc != null
	_sesion += 1
	if abierta:
		var tile_pantalla: TileAlterno = _pantalla()
		if tile_pantalla != null:
			tile_pantalla.desactivar()
		if not sono_el_menu:
			Singleton.play_sound.emit("SE_PC_OFF")
	if _menu_pc and is_instance_valid(_menu_pc):
		if _menu_pc.cerrado.is_connected(_cerrar_pc):
			_menu_pc.cerrado.disconnect(_cerrar_pc)
		_menu_pc._cerrar()
		_menu_pc.queue_free()
	_menu_pc = null
	_activo = false
	if abierta and is_instance_valid(administrador):
		var dialogo: DialogoBaseSecreta = administrador.get("dialogo_bases") as DialogoBaseSecreta
		if dialogo != null:
			dialogo.cancelar()
	Singleton.mantener_pausa(&"pc_casa", false)
	if is_instance_valid(_jugador) and is_instance_valid(administrador) and int(administrador.get("coneccion")) == 0:
		_jugador.no_control = _control_previo


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and _activo and not _vigente():
		_cerrar_pc()


func _exit_tree() -> void:
	if Engine.is_editor_hint() or not _activo:
		return
	_cerrar_pc()


func _crear_icono_editor() -> void:
	if get_node_or_null("EditorPC"):
		return
	var icono := Sprite2D.new()
	icono.name = "EditorPC"
	icono.texture = load("res://graficos/editor/editor_tile_cartel.png")
	icono.z_index = 1000
	icono.modulate = Color(1, 1, 1, 0.8)
	add_child(icono)
