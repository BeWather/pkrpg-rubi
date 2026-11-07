@tool
extends Sprite2D

@export var id_texto: String = "CARTEL_MAPA_REGION_CENTRO_PKM"
const EDITOR_ICON := "res://graficos/editor/editor_tile_cartel.png"
@export var coord_tile: Vector2i = Vector2i.ZERO:		# Coordenada en tiles
	set(value):
		coord_tile = value
		if is_inside_tree():
			position = Vector2(value.x * 16 + 8, value.y * 16 + 8)
			update_configuration_warnings()

@export var direccion: Singleton.enum_dir_cartel = Singleton.enum_dir_cartel.TODAS_DIRECCIONES

var admin: Node2D = null
var jugador: Node2D = null
var nodo_ui: CanvasLayer = null
var mapa_region: Control = null
var activo: bool = false

func _ready() -> void:
	add_to_group("Cartel")

	if Engine.is_editor_hint():
		set_notify_transform(true)
		_preparar_icono_editor()
		# Activar process para actualizar la modulación en el editor
		set_process(true)
	else:
		set_process(false)

# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		coord_tile = Vector2i(round((position.x - 8) / 16), round((position.y - 8) / 16))
		position = Vector2(coord_tile.x * 16 + 8, coord_tile.y * 16 + 8)
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_limpiar_icono_editor()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_preparar_icono_editor()

func _process(_delta: float) -> void:
	# Solo en editor: animar modulación del editor_cartel para hacerlo más visible
	if not Engine.is_editor_hint():
		return
	var t = Time.get_ticks_msec() / 1000.0
	# Pulso suave entre 0.6 y 1.0
	modulate.a = 0.6 + 0.4 * (sin(t * 2.0) * 0.5 + 0.5)

## Icono de editor: el propio nodo es el Sprite2D, así todo su rect de 16x16 es
## clicable en el lienzo (un Sprite2D hijo sin owner lo ignora el editor).
func _preparar_icono_editor() -> void:
	texture = load(EDITOR_ICON)
	centered = true
	z_index = 1000
	modulate = Color(1, 1, 1, 0.8)

## Quita el icono antes de guardar para que no acabe serializado en la escena.
func _limpiar_icono_editor() -> void:
	texture = null
	z_index = 0
	modulate = Color.WHITE

## Función llamada desde el administrador de mapas cuando el jugador interactúa con el cartel
func accionar_cartel() -> void:
	if activo:
		return  # Evitar reentradas si ya está activo
	activo = true
	Singleton.mostrar_texto(tr(id_texto), abrir_mapa_region)

## Función especial para abrir el mapa de región
func abrir_mapa_region() -> void:
	print("📍 [CARTEL MAPA REGION] Abriendo mapa de región...")

	# Obtener referencia al administrador de mapa
	admin = Singleton.obtener_nodo("Admin")
	jugador = Singleton.obtener_nodo("Jugador")
	nodo_ui = Singleton.obtener_nodo("Menu")

	# Cargar la escena del mapa de región
	var mapa_region_scene = preload("res://UI/mapa_region/region_hoenn.tscn")
	mapa_region = mapa_region_scene.instantiate()
	mapa_region.configurar_como_cartel()

	await _transicion_oscurecer()
	_pausar_jugador(true)
	if mapa_region.has_signal("mapa_cerrado"):
		mapa_region.connect("mapa_cerrado", _on_mapa_region_cerrado)

	# Agregar al árbol principal
	nodo_ui.add_child(mapa_region)

	await _transicion_aclarar()
	if is_instance_valid(mapa_region):
		mapa_region.habilitar_input()

## Efecto de oscurecer la pantalla.
func _transicion_oscurecer() -> void:
	print("🌑 [PC_CENTRO] Oscureciendo pantalla...")
	var resultado = await Singleton.transicion("oscurecer")
	if not resultado:
		print("⚠️ [PC_CENTRO] Fallback: usando espera manual")
		await get_tree().create_timer(0.5).timeout

## Efecto de aclarar la pantalla.
func _transicion_aclarar() -> void:
	print("🌅 [PC_CENTRO] Aclarando pantalla...")
	var resultado = await Singleton.transicion("aclarar")
	if not resultado:
		print("⚠️ [PC_CENTRO] Fallback: usando espera manual")
		await get_tree().create_timer(0.5).timeout

## Función para pausar o reanudar el jugador.
func _pausar_jugador(pausar: bool) -> void:
	Singleton.mantener_pausa(&"cartel_mapa", pausar)
	jugador.no_control = pausar
	print("🎮 [PC_CENTRO] Jugador %s" % ("pausado" if pausar else "reactivado"))

## Función que se ejecuta cuando se cierra el mapa de región.
func _on_mapa_region_cerrado() -> void:
	print("🔒 [CARTEL MAPA REGION] Cerrando mapa de región...")

	await _transicion_oscurecer()

	if mapa_region and mapa_region.is_inside_tree():
		if mapa_region.has_signal("mapa_cerrado") and mapa_region.is_connected("mapa_cerrado", _on_mapa_region_cerrado):
			mapa_region.disconnect("mapa_cerrado", _on_mapa_region_cerrado)
		mapa_region.queue_free()
		mapa_region = null

	await _transicion_aclarar()
	_pausar_jugador(false)
	activo = false
	print("✅ [CARTEL MAPA REGION] Mapa de región cerrado, jugador reactivado")
