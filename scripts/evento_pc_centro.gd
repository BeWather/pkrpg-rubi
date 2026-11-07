@tool
extends Node2D
class_name EventoPCCentro

# ===================================
# EVENTO PC DEL CENTRO POKÉMON
# ===================================

# Variables exportadas para el editor
@export var coord_tile: Vector2i = Vector2i(10, 1):		# Coordenada en tiles
	set(value):
		coord_tile = value
		if is_inside_tree():
			position = Vector2(value.x * 16 + 8, value.y * 16 + 8)
			update_configuration_warnings()

@export var direccion: Singleton.enum_dir_cartel = Singleton.enum_dir_cartel.TODAS_DIRECCIONES
@export var id_texto: String = "CASA_PC"
@export var usar_transiciones: bool = true
@export var editor_icon: String = "res://graficos/editor/editor_tile_event.png"
## TileAlterno con la pantalla encendida del PC: parpadea al usarlo (DoPCTurnOnEffect
## de Rubí) y queda encendida mientras el PC está abierto.
@export var pantalla: NodePath

## Parpadeos y fotogramas por cambio del encendido (5 y 7 en Rubí).
const PARPADEOS_PANTALLA: int = 5
const FOTOGRAMAS_PARPADEO: int = 7

# Editor
@onready var editor_pc: Sprite2D = Sprite2D.new()

# Variables de estado (solo en juego)
var jugador_en_rango: bool = false
var pc_activo: bool = false
var area_interaccion: Area2D = null

# Referencias a sistemas del juego
var nodo_ui: Node = null
var admin_mapa: Node2D = null
var jugador: Node2D = null
var menu_publico: MenuPCPublico = null
var _control_previo: bool = false
var _sesion: int = 0

func _ready() -> void:
	add_to_group("Cartel")

	if Engine.is_editor_hint():
		_configurar_editor()
	else:
		_configurar_juego()

	print("💻 [PC_CENTRO] Evento PC inicializado en coord_tile:", coord_tile)

## Configuración específica para el editor
func _configurar_editor() -> void:
	set_notify_transform(true)

	# Preparar el icono de editor
	editor_pc.name = "EditorPC"
	editor_pc.position = Vector2.ZERO
	editor_pc.scale = Vector2.ONE
	editor_pc.z_index = 1000
	editor_pc.visible = true

	# Cargar icono o usar fallback
	if FileAccess.file_exists(editor_icon):
		editor_pc.texture = load(editor_icon)
	else:
		# Fallback: crear un rectángulo simple
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.CYAN)
		var texture = ImageTexture.new()
		texture.set_image(image)
		editor_pc.texture = texture

	editor_pc.modulate = Color(1, 1, 1, 0.8)

	if get_node_or_null("EditorPC") == null:
		add_child(editor_pc)

	# set_process(true)

## Configuración específica para el juego
func _configurar_juego() -> void:
	# Liberar el icono si estamos en tiempo de ejecución
	if get_node_or_null("EditorPC"):
		get_node("EditorPC").queue_free()

	# set_process(false)

	# Obtener referencias a sistemas
	_obtener_referencias_sistemas()

## Obtiene referencias a los sistemas principales del juego.
func _obtener_referencias_sistemas() -> void:
	admin_mapa = Singleton.obtener_nodo("Admin")
	jugador = Singleton.obtener_nodo("Jugador")
	nodo_ui = Singleton.obtener_nodo("Menu")

# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		coord_tile = Vector2i(round((position.x - 8) / 16), round((position.y - 8) / 16))
		position = Vector2(coord_tile.x * 16 + 8, coord_tile.y * 16 + 8)

func _process(_delta: float) -> void:
	# Solo en editor: animar modulación del editor_pc para hacerlo más visible
	if not Engine.is_editor_hint():
		return
	var node = get_node_or_null("EditorPC")
	if node:
		# Pulso basado en tiempo para una modulación suave y visible
		var t = Time.get_ticks_msec() / 1000.0
		var alpha = 0.6 + 0.4 * (sin(t * 2.0) * 0.5 + 0.5) # oscila entre 0.6 y 1.0
		node.modulate.a = alpha

# ===================================
# FUNCIÓN PRINCIPAL DEL EVENTO
# ===================================

## Activa el PC con transiciones y diálogo.
func accionar_cartel() -> void:
	if pc_activo or Engine.is_editor_hint():
		return

	print("💻 [PC_CENTRO] Activando sistema de PC...")
	pc_activo = true
	_sesion += 1
	_obtener_referencias_sistemas()
	# El administrador de mapa trata este evento como un cartel y bloquea al jugador
	# (no_control = true) justo antes de llamar aquí. Ese bloqueo es del propio
	# disparo del cartel, no un estado previo que restaurar: capturarlo dejaba al
	# jugador sin control (y el menú de pausa bloqueado) al cerrar el PC.
	_control_previo = false
	Singleton.play_sound.emit("SE_PC_ON")
	# EventScript_PC: el parpadeo corre a la vez que el mensaje de arranque.
	var tile_pantalla: TileAlterno = _pantalla()
	if tile_pantalla != null:
		tile_pantalla.parpadear(PARPADEOS_PANTALLA, FOTOGRAMAS_PARPADEO)

	# Detener al jugador desde el primer momento (pero se cancela en el siguiente frame si se está cerrando un diálogo)
	_pausar_jugador(true)

	# Mostrar diálogo de acceso
	_mostrar_dialogo_acceso()

## Arranque del PC; el sistema de almacenamiento se elige después.
func _mostrar_dialogo_acceso() -> void:
	var clave: String = "CASA_PC" if id_texto in ["ACCESO_PC", "PC_CENTRO_ACCESO"] else id_texto
	var texto_traducido = tr(clave)
	print("💬 [PC_CENTRO] " + texto_traducido)
	# Sin sonido de inicio: el reproductor de efectos es único y cortaría SE_PC_ON.
	Singleton.mostrar_texto(texto_traducido, Callable(self, "_on_dialogo_terminado"), true)


func _pantalla() -> TileAlterno:
	return get_node_or_null(pantalla) as TileAlterno if not pantalla.is_empty() else null

## Se ejecuta cuando termina el diálogo de acceso.
func _on_dialogo_terminado() -> void:
	# El cierre del texto inicial no debe cerrar el nuevo cuadro ni liberar control.
	var sesion: int = _sesion
	await get_tree().process_frame
	if not pc_activo or sesion != _sesion or not is_inside_tree():
		return
	_pausar_jugador(true)
	_cargar_pantalla_pc()

## Todos los eventos existentes comparten el selector de PC público.
func _cargar_pantalla_pc() -> void:
	if not is_instance_valid(nodo_ui):
		_obtener_referencias_sistemas()
	if not is_instance_valid(nodo_ui):
		_on_pc_cerrado()
		return
	menu_publico = preload("res://UI/pc_casa/menu_pc_publico.tscn").instantiate() as MenuPCPublico
	menu_publico.usar_transiciones = usar_transiciones
	menu_publico.cerrado.connect(_on_pc_cerrado)
	nodo_ui.add_child(menu_publico)

## Función que se ejecuta cuando se cierra la pantalla de PC.
func _on_pc_cerrado() -> void:
	if not pc_activo:
		return
	_sesion += 1
	if is_instance_valid(menu_publico):
		menu_publico.cerrado.disconnect(_on_pc_cerrado)
		menu_publico.cerrar()
		menu_publico.queue_free()
	menu_publico = null
	pc_activo = false
	_pausar_jugador(false)
	var tile_pantalla: TileAlterno = _pantalla()
	if tile_pantalla != null:
		tile_pantalla.desactivar()  # DoPCTurnOffEffect
	Singleton.play_sound.emit("SE_PC_OFF")


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and pc_activo:
		_on_pc_cerrado()

## Función para pausar o reanudar el jugador.
func _pausar_jugador(pausar: bool) -> void:
	Singleton.mantener_pausa(&"pc_centro", pausar)
	# El jugador puede no existir aún (o haber sido recreado) cuando se cacheó en _ready
	if not is_instance_valid(jugador):
		jugador = Singleton.obtener_nodo("Jugador")
	if jugador:
		jugador.no_control = true if pausar else _control_previo
	print("🎮 [PC_CENTRO] Jugador %s" % ("pausado" if pausar else "reactivado"))
