@tool
extends Control

signal nombre_confirmado(nombre: String)
signal cancelado
signal entrada_invalida

enum TipoObjetivo {
	CHICO,
	CHICA,
	POKEMON,
}

enum SexoPokemon {
	NO_TIENE,
	MACHO,
	HEMBRA,
}

const FILAS := 4
## HandleDpadMovement (naming_screen.c, COLUMN_COUNT 9): columnas 0-7 del
## teclado y la 8 para los botones (cambio de página, BORRA, FIN).
const COLUMNA_BOTONES := 8
## Fila de teclado → fila de botón al entrar, y botón → fila al salir.
const FILA_A_BOTON: Array[int] = [0, 1, 1, 2]
const BOTON_A_FILA: Array[int] = [0, 0, 3, 0]
const POSICION_PRIMER_CARACTER := Vector2(80, 43)
const PASO_CARACTER := 8
const RETARDO_INICIAL_NAVEGACION := 0.35
const INTERVALO_REPETICION_NAVEGACION := 0.08
const ESCALA_OBJETIVO_PERSONAJE := Vector2(1.0, 1.0)
# Resolver al mostrar el objetivo evita cargar personaje/NPC/batalla/nombres
# de forma circular mientras el editor importa las clases.
const ESCENA_CHICO: String = "res://escenas/character/boy.tscn"
const ESCENA_CHICA: String = "res://escenas/character/girl.tscn"
const ICONO_POKEMON: Texture2D = preload("res://graficos/Icons/icon001.png")
const RUTA_ICONO_POKEMON := "res://graficos/Icons/icon%03d.png"

const TECLADOS: Array = [
	[
		["A", "B", "C", "D", "E", "F", " ", "."],
		["G", "H", "I", "J", "K", "L", " ", ","],
		["M", "N", "O", "P", "Q", "R", "S", " "],
		["T", "U", "V", "W", "X", "Y", "Z", " "],
	],
	[
		["a", "b", "c", "d", "e", "f", " ", "."],
		["g", "h", "i", "j", "k", "l", " ", ","],
		["m", "n", "o", "p", "q", "r", "s", " "],
		["t", "u", "v", "w", "x", "y", "z", " "],
	],
	[
		["0", "1", "2", "3", "4", " "],
		["5", "6", "7", "8", "9", " "],
		["!", "?", "♂", "♀", "/", "-"],
		[".", "“", "”", "‘", "’", " "],
	]
]

const TECLADO_COORDS: Array = [
	[	# Teclado mayúsculas y minúsculas
		[	# Eje X
			[27, 43, 59, 83, 99, 115, 131, 155]
		],
		[	# Eje Y
			[72, 88, 104, 120]
		]
	],
	[   # Teclado de números y símbolos
		[	# Eje X
			[27, 51, 75, 99, 123, 147]
		],
		[	# Eje Y
			[72, 88, 104, 120]
		]
	]
]

const COORDS_BOTONES_MENU: Array = [
	Vector2(188, 69),	# Botón SELECT, cambie de teclado 'mayúsculas', 'minúsculas' y 'otros'
	Vector2(188, 98),	# Botón CANCELAR, borra el último caracter
	Vector2(188, 120)   # Botón START, confirma el nombre y sale del menú
]

@export_category("Configuracion")
@export var titulo: String = "¿CÓMO TE LLAMAS?":
	set(value):
		titulo = value
		_solicitar_refresco()

@export_range(4, 16, 1) var max_caracteres: int = 10:
	set(value):
		max_caracteres = clampi(value, 4, 16)
		_solicitar_refresco()

@export var nombre_obligatorio: bool = false:
	set(value):
		nombre_obligatorio = value
		_solicitar_refresco()

@export var tipo_objetivo: TipoObjetivo = TipoObjetivo.CHICO:
	set(value):
		tipo_objetivo = value
		_solicitar_refresco()

@export_enum("No tiene", "Macho", "Hembra") var sexo_pokemon: int = SexoPokemon.NO_TIENE:
	set(value):
		sexo_pokemon = clampi(value, SexoPokemon.NO_TIENE, SexoPokemon.HEMBRA)
		_solicitar_refresco()

@export_range(1, 999, 1) var numero_pokemon: int = 1:
	set(value):
		numero_pokemon = clampi(value, 1, 999)
		_solicitar_refresco()

var nombre: String = ""
var teclado_actual: int = 0
var fila_actual: int = 0
var columna_actual: int = 0
var menu_actual: int = 0
## tKbFunctionKey: fila a la que vuelve el cursor al salir de BORRA.
var tecla_funcion: int = 0
var en_menu: bool = false
var _refresco_pendiente: bool = false
var _timer_repeticion_navegacion: Timer = null
var _direccion_presionada: Vector2i = Vector2i.ZERO

@onready var etiqueta_titulo: Label = $Titulo
@onready var cursor_caracter: Sprite2D = $CursorCaracter
@onready var cursor_letra: AnimatedSprite2D = $CursorLetra
@onready var cursor_menu: Sprite2D = $CursorMenu
@onready var objetivo: AnimatedSprite2D = $Objetivo
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_player_cursores: AnimationPlayer = $AnimationPlayerCursores
var etiqueta_sexo: Label = null

func _ready() -> void:
	_timer_repeticion_navegacion = Timer.new()
	_timer_repeticion_navegacion.one_shot = true
	_timer_repeticion_navegacion.timeout.connect(_repetir_navegacion)
	add_child(_timer_repeticion_navegacion)
	_refrescar_configuracion()

func configurar(
	nuevo_titulo: String,
	nuevo_max_caracteres: int,
	nuevo_nombre_obligatorio: bool,
	nuevo_tipo_objetivo: TipoObjetivo = TipoObjetivo.CHICO,
	nuevo_numero_pokemon: int = 1
) -> void:
	titulo = nuevo_titulo
	max_caracteres = nuevo_max_caracteres
	nombre_obligatorio = nuevo_nombre_obligatorio
	tipo_objetivo = nuevo_tipo_objetivo
	numero_pokemon = nuevo_numero_pokemon
	reiniciar()

func reiniciar() -> void:
	nombre = ""
	teclado_actual = 0
	fila_actual = 0
	columna_actual = 0
	menu_actual = 0
	tecla_funcion = 0
	en_menu = false
	_refrescar_configuracion()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.is_editor_hint() or event.is_echo():
		return

	if event.is_action_pressed("btn_arriba"):
		_iniciar_navegacion(Vector2i.UP)
	elif event.is_action_pressed("btn_abajo"):
		_iniciar_navegacion(Vector2i.DOWN)
	elif event.is_action_pressed("btn_izquierda"):
		_iniciar_navegacion(Vector2i.LEFT)
	elif event.is_action_pressed("btn_derecha"):
		_iniciar_navegacion(Vector2i.RIGHT)
	elif event.is_action_released("btn_arriba") and _direccion_presionada == Vector2i.UP:
		_detener_navegacion()
	elif event.is_action_released("btn_abajo") and _direccion_presionada == Vector2i.DOWN:
		_detener_navegacion()
	elif event.is_action_released("btn_izquierda") and _direccion_presionada == Vector2i.LEFT:
		_detener_navegacion()
	elif event.is_action_released("btn_derecha") and _direccion_presionada == Vector2i.RIGHT:
		_detener_navegacion()
	else:
		# HandleKeyboardEvent: SELECT cambia de página y B borra estén donde
		# estén el cursor; START lleva el cursor a FIN.
		if event.is_action_pressed("btn_select"):
			_cambiar_teclado()
			_actualizar_cursor_caracter()
			_reiniciar_repeticion_navegacion()
		elif event.is_action_pressed("btn_cancelar"):
			_borrar_caracter()
			_reiniciar_repeticion_navegacion()
		elif event.is_action_pressed("btn_menu"):
			_ir_a_fin()
			_reiniciar_repeticion_navegacion()
		elif event.is_action_pressed("btn_accion"):
			_seleccionar()
			_reiniciar_repeticion_navegacion()
		else:
			return
	get_viewport().set_input_as_handled()

func _iniciar_navegacion(direccion: Vector2i) -> void:
	if _direccion_presionada != direccion:
		_direccion_presionada = direccion
		_mover(direccion)
	_timer_repeticion_navegacion.wait_time = RETARDO_INICIAL_NAVEGACION
	_timer_repeticion_navegacion.start()

func _detener_navegacion() -> void:
	_direccion_presionada = Vector2i.ZERO
	_timer_repeticion_navegacion.stop()

func _reiniciar_repeticion_navegacion() -> void:
	if _direccion_presionada == Vector2i.ZERO:
		return
	_timer_repeticion_navegacion.wait_time = RETARDO_INICIAL_NAVEGACION
	_timer_repeticion_navegacion.start()

func _repetir_navegacion() -> void:
	if _direccion_presionada == Vector2i.ZERO:
		return
	_mover(_direccion_presionada)
	_timer_repeticion_navegacion.wait_time = INTERVALO_REPETICION_NAVEGACION
	_timer_repeticion_navegacion.start()


func _solicitar_refresco() -> void:
	if not is_inside_tree() or _refresco_pendiente:
		return
	_refresco_pendiente = true
	call_deferred("_refrescar_configuracion")

func _refrescar_configuracion() -> void:
	_refresco_pendiente = false
	if not is_inside_tree():
		return
	if nombre.length() > max_caracteres:
		nombre = nombre.substr(0, max_caracteres)
	if etiqueta_titulo:
		etiqueta_titulo.text = titulo
	_actualizar_teclado()
	_actualizar_objetivo()
	_actualizar_cursor_caracter()
	_actualizar_cursores_letra()
	_actualizar_caracteres()
	_actualizar_cursor_menu()

## Port de HandleDpadMovement: los bordes horizontales enlazan teclado y botones
## (izquierda desde la columna 0 va a los botones; derecha desde ellos, a la 0).
func _mover(direccion: Vector2i) -> void:
	var x: int = COLUMNA_BOTONES if en_menu else columna_actual
	var y: int = menu_actual if en_menu else fila_actual
	var x_previa: int = x
	x += direccion.x
	y += direccion.y
	if x < 0:
		x = COLUMNA_BOTONES
	if x > COLUMNA_BOTONES:
		x = 0
	if direccion.x != 0:
		# La página OTROS solo tiene 6 columnas.
		if x >= _columnas_teclado_actual() and x < COLUMNA_BOTONES:
			x = COLUMNA_BOTONES if direccion.x > 0 else _columnas_teclado_actual() - 1
		if x == COLUMNA_BOTONES:
			tecla_funcion = y
			y = FILA_A_BOTON[y]
		elif x_previa == COLUMNA_BOTONES:
			y = tecla_funcion if y == 1 else BOTON_A_FILA[y]
	if x == COLUMNA_BOTONES:
		y = posmod(y, COORDS_BOTONES_MENU.size())
		if y == 0:
			tecla_funcion = 1
		elif y == 2:
			tecla_funcion = 2
		en_menu = true
		menu_actual = y
	else:
		en_menu = false
		columna_actual = x
		fila_actual = posmod(y, FILAS)
	_actualizar_cursor_menu()
	_actualizar_cursor_caracter()

## MoveCursorToOKButton
func _ir_a_fin() -> void:
	en_menu = true
	menu_actual = 2
	_actualizar_cursor_menu()
	_actualizar_cursor_caracter()

func _seleccionar() -> void:
	if en_menu:
		match menu_actual:
			0:
				_cambiar_teclado()
			1:
				_borrar_caracter()
			2:
				_confirmar()
		# El cursor se queda en el botón pulsado (KeyboardKeyHandler_*).
		return

	var tecla := _tecla_actual(fila_actual, columna_actual)
	if not _celda_activa(fila_actual, columna_actual) or nombre.length() >= max_caracteres:
		return
	nombre += tecla
	_actualizar_cursores_letra()
	_actualizar_caracteres()
	# sub_80B7004: al escribir el último carácter el cursor salta a FIN.
	if nombre.length() == max_caracteres:
		_ir_a_fin()

func _borrar_caracter() -> void:
	if nombre.is_empty():
		return
	nombre = nombre.substr(0, nombre.length() - 1)
	_actualizar_cursores_letra()
	_actualizar_caracteres()

func _confirmar() -> void:
	if nombre.is_empty():
		if nombre_obligatorio:
			entrada_invalida.emit()
		else:
			cancelado.emit()
		return
	nombre_confirmado.emit(nombre)

func _tecla_actual(fila: int, columna: int) -> String:
	return TECLADOS[teclado_actual][fila][columna]

## Todas las posiciones declaradas por el teclado son navegables, incluidos los espacios.
func _celda_activa(fila: int, columna: int) -> bool:
	return fila >= 0 and fila < FILAS and columna >= 0 and columna < _columnas_teclado_actual()

## Los teclados 0 y 1 comparten coordenadas; el 2 tiene su propia rejilla.
func _indice_coords_teclado() -> int:
	return 0 if teclado_actual < 2 else 1

func _columnas_teclado_actual() -> int:
	return (TECLADO_COORDS[_indice_coords_teclado()][0][0] as Array).size()

func _posicion_tecla(fila: int, columna: int) -> Vector2:
	var ejes: Array = TECLADO_COORDS[_indice_coords_teclado()]
	var posiciones_x: Array = ejes[0][0]
	var posiciones_y: Array = ejes[1][0]
	return Vector2(posiciones_x[columna], posiciones_y[fila])

## Tras cambiar de teclado conserva la posición si sigue siendo válida.
func _normalizar_posicion() -> void:
	columna_actual = clampi(columna_actual, 0, _columnas_teclado_actual() - 1)
	if _celda_activa(fila_actual, columna_actual):
		return
	columna_actual = 0
	if not _celda_activa(fila_actual, columna_actual):
		fila_actual = 0

func _cambiar_teclado() -> void:
	teclado_actual = posmod(teclado_actual + 1, TECLADOS.size())
	_normalizar_posicion()
	_actualizar_teclado(true)

func _actualizar_teclado(animar: bool = false) -> void:
	# El botón SELECT muestra la página siguiente (gUnknown_083CE2CA):
	# en MAYÚS dice "minús", en minúsculas "otros" y en OTROS "MAYÚS".
	$BotonMinus.visible = teclado_actual == 0
	$BotonOtros.visible = teclado_actual == 1
	$BotonMayus.visible = teclado_actual == 2
	if animar and animation_player and animation_player.has_animation(_animacion_teclado_actual()):
		animation_player.play(_animacion_teclado_actual())
		return
	$TecladoMayus.visible = teclado_actual == 0
	$TecladoMinus.visible = teclado_actual == 1
	$TecladoOtros.visible = teclado_actual == 2

func _animacion_teclado_actual() -> StringName:
	match teclado_actual:
		0:
			return &"Teclado Mayúsculas"
		1:
			return &"Teclado Minúsculas"
		2:
			return &"Teclado Numérico"
	return &""

func _actualizar_cursor_caracter() -> void:
	cursor_caracter.visible = not en_menu
	var posicion_anterior := cursor_caracter.position
	if not en_menu:
		cursor_caracter.position = _posicion_tecla(fila_actual, columna_actual)
	_actualizar_animacion_cursor()
	# Como sub_80B6998: al moverse, el parpadeo vuelve a empezar desde el color base.
	if not en_menu and cursor_caracter.position != posicion_anterior and animation_player_cursores:
		animation_player_cursores.seek(0.0, true)

func _actualizar_cursor_menu() -> void:
	cursor_menu.visible = en_menu
	var posicion_anterior := cursor_menu.position
	if en_menu:
		cursor_menu.position = COORDS_BOTONES_MENU[menu_actual]
	_actualizar_animacion_cursor()
	# Como sub_80B65D4: al cambiar de botón, el parpadeo vuelve a empezar (paso 15).
	if en_menu and cursor_menu.position != posicion_anterior and animation_player_cursores:
		animation_player_cursores.seek(0.0, true)

func _actualizar_animacion_cursor() -> void:
	if not animation_player_cursores:
		return
	# Nombre sin tilde: así se llama la animación en entrada_nombre.tscn.
	var animacion := &"Cursor Menu" if en_menu else &"Cursor Caracter"
	if animation_player_cursores.current_animation != animacion or not animation_player_cursores.is_playing():
		animation_player_cursores.play(animacion)

func _actualizar_cursores_letra() -> void:
	if not cursor_letra:
		return
	for child in get_children():
		if child.name.begins_with("CursorLetraSlot") and (Engine.is_editor_hint() or int(child.name.trim_prefix("CursorLetraSlot")) >= max_caracteres):
			child.free()
	if Engine.is_editor_hint():
		cursor_letra.position = POSICION_PRIMER_CARACTER
		cursor_letra.visible = true
		cursor_letra.play("activo")
		return
	var cursores: Array[CanvasItem] = [cursor_letra]
	cursor_letra.position = POSICION_PRIMER_CARACTER
	for indice in range(1, max_caracteres):
		var cursor := get_node_or_null("CursorLetraSlot%d" % indice) as AnimatedSprite2D
		if cursor == null:
			cursor = cursor_letra.duplicate() as AnimatedSprite2D
			cursor.name = "CursorLetraSlot%d" % indice
			add_child(cursor)
			_registrar_nodo_en_escena_editada(cursor)
		cursor.position = POSICION_PRIMER_CARACTER + Vector2(indice * PASO_CARACTER, 0)
		cursores.append(cursor)
	for indice in cursores.size():
		var cursor := cursores[indice]
		cursor.visible = indice >= nombre.length() and indice < max_caracteres
		cursor.play("activo" if indice == nombre.length() else "default")

func _actualizar_caracteres() -> void:
	for child in get_children():
		if child.name.begins_with("CaracterNombre") or child.name == "SexoPokemon":
			child.free()
	if Engine.is_editor_hint():
		etiqueta_sexo = null
		return
	if not etiqueta_titulo:
		return
	for indice in nombre.length():
		var etiqueta := Label.new()
		etiqueta.name = "CaracterNombre%d" % indice
		etiqueta.position = POSICION_PRIMER_CARACTER + Vector2(indice * PASO_CARACTER, -21)
		etiqueta.size = Vector2(PASO_CARACTER, 16)
		etiqueta.text = nombre[indice]
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		etiqueta.label_settings = etiqueta_titulo.label_settings
		add_child(etiqueta)
		_registrar_nodo_en_escena_editada(etiqueta)
	_actualizar_etiqueta_sexo()

func _actualizar_etiqueta_sexo() -> void:
	if sexo_pokemon == SexoPokemon.NO_TIENE:
		if etiqueta_sexo:
			etiqueta_sexo.visible = false
		return
	if etiqueta_sexo == null:
		etiqueta_sexo = Label.new()
		etiqueta_sexo.name = "SexoPokemon"
		etiqueta_sexo.size = Vector2(PASO_CARACTER, 16)
		etiqueta_sexo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta_sexo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		etiqueta_sexo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(etiqueta_sexo)
		_registrar_nodo_en_escena_editada(etiqueta_sexo)
	var indice_referencia := max_caracteres - 1
	etiqueta_sexo.position = POSICION_PRIMER_CARACTER + Vector2((indice_referencia + 2) * PASO_CARACTER, -21)
	etiqueta_sexo.text = "♂" if sexo_pokemon == SexoPokemon.MACHO else "♀"
	var configuracion_sexo := etiqueta_titulo.label_settings.duplicate() as LabelSettings
	configuracion_sexo.font_color = Color.RED if sexo_pokemon == SexoPokemon.MACHO else Color.BLUE
	etiqueta_sexo.label_settings = configuracion_sexo
	etiqueta_sexo.visible = true

func _registrar_nodo_en_escena_editada(nodo: Node) -> void:
	if Engine.is_editor_hint():
		nodo.owner = get_tree().edited_scene_root

func _actualizar_objetivo() -> void:
	if not objetivo:
		return
	objetivo.centered = false
	# objetivo.position = Vector2(47, 23)
	match tipo_objetivo:
		TipoObjetivo.CHICO:
			objetivo.sprite_frames = _obtener_frames_personaje(load(ESCENA_CHICO))
			# objetivo.scale = ESCALA_OBJETIVO_PERSONAJE
			objetivo.scale = Vector2.ONE
			objetivo.play("camina_abajo_1")
			objetivo.position = Vector2(40, 8)
		TipoObjetivo.CHICA:
			objetivo.sprite_frames = _obtener_frames_personaje(load(ESCENA_CHICA))
			# objetivo.scale = ESCALA_OBJETIVO_PERSONAJE
			objetivo.scale = Vector2.ONE
			objetivo.play("camina_abajo_1")
			objetivo.position = Vector2(48, 16)
		TipoObjetivo.POKEMON:
			objetivo.sprite_frames = _crear_frames_icono_pokemon()
			objetivo.scale = Vector2.ONE
			objetivo.play("pokemon")
			objetivo.position = Vector2(38, 14)

func _obtener_frames_personaje(escena: PackedScene) -> SpriteFrames:
	var personaje := escena.instantiate()
	var sprite := personaje.get_node_or_null("basico") as AnimatedSprite2D
	var frames: SpriteFrames = sprite.sprite_frames if sprite else null
	personaje.free()
	return frames

func _crear_frames_icono_pokemon() -> SpriteFrames:
	var ruta_icono := RUTA_ICONO_POKEMON % numero_pokemon
	var textura_completa := load(ruta_icono) as Texture2D if ResourceLoader.exists(ruta_icono) else null
	if textura_completa == null:
		textura_completa = ICONO_POKEMON

	var frames := SpriteFrames.new()
	frames.add_animation("pokemon")
	frames.set_animation_loop("pokemon", true)

	# Los iconos normales contienen dos frames de 32x32 colocados horizontalmente.
	var cantidad_frames := 2 if textura_completa.get_width() >= 64 and textura_completa.get_height() >= 32 else 1
	for indice in range(cantidad_frames):
		var atlas := AtlasTexture.new()
		atlas.atlas = textura_completa
		atlas.region = Rect2(indice * 32, 0, 32, 32)
		atlas.filter_clip = true
		frames.add_frame("pokemon", atlas)

	frames.set_animation_speed("pokemon", 2.0)
	return frames
