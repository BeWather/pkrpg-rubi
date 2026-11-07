extends Node2D

## Los mismos colores que la pantalla de equipo (pantalla_equipo_caja.gd).
const COLOR_MACHO := Color(0.188235, 0.74902, 0.937255, 1)
const COLOR_HEMBRA := Color(1, 0.611765, 0.576471, 1)

@onready var lNombre: Label = $"HBoxContainer/LNombre"
@onready var lSexo: Label = $"HBoxContainer/LSexo"
@onready var lNivel: Label = $"LNivel"
@onready var icono: AnimatedSprite2D = $"AnimatedSprite2D"
@onready var linea_salud_1: ColorRect = $"BarraSalud1"
@onready var linea_salud_2: ColorRect = $"BarraSalud2"
## Icono de la POKé BALL "ya capturado" (ball_caught_indicator de Emerald). Ocupa
## el hueco izquierdo del cuadro, el mismo donde se dibuja el icono de estado.
@onready var icono_capturado: Sprite2D = $"IconoCapturado"

## La especie del rival ya está registrada como atrapada en la POKéDEX.
var _capturado: bool = false
## El icono de estado alterado está a la vista (el de captura cede su sitio).
var _estado_visible: bool = false

func set_nombre(nombre: String):
	lNombre.text = nombre

func set_sexo(sexo: String):
	if sexo == "M":
		lSexo.text = "♂"
		lSexo.modulate = COLOR_MACHO
	elif sexo == "F":
		lSexo.text = "♀"
		lSexo.modulate = COLOR_HEMBRA
	else:
		lSexo.text = ""

func set_nivel(nivel: int):
	lNivel.text = str(nivel)

func set_estado(estado: String):
	icono.visible = true
	icono.frame = 0
	match estado:
		"NORMAL":
			icono.visible = false
		"DEBILITADO":
			icono.frame = 0
		"ENVENENADO":
			icono.frame = 1
		"CONGELADO":
			icono.frame = 2
		"QUEMADO":
			icono.frame = 3
		"PARALIZADO":
			icono.frame = 4
		"DORMIDO":
			icono.frame = 5
		_:
			icono.visible = false
	_estado_visible = icono.visible
	_actualizar_icono_capturado()

## Marca si la especie del rival ya está atrapada. El icono solo se ve mientras
## el Pokémon no tiene estado alterado (TryAddPokeballIconToHealthbox de Emerald).
func set_capturado(valor: bool) -> void:
	_capturado = valor
	_actualizar_icono_capturado()

func _actualizar_icono_capturado() -> void:
	# Se consulta `_estado_visible` y no `icono.visible`: antes del primer
	# `set_estado()` el icono de estado conserva la visibilidad de la escena.
	icono_capturado.visible = _capturado and not _estado_visible

func set_salud_max():
	linea_salud_1.size.x = 48
	linea_salud_2.size.x = 48

func set_salud(salud_max: int, salud: int, tween: Tween):

	tween.tween_property(linea_salud_1, "size", Vector2(48 * float(salud) / float(salud_max), linea_salud_1.size.y), 1)
	tween.parallel().tween_property(linea_salud_2, "size", Vector2(48 * float(salud) / float(salud_max), linea_salud_1.size.y), 1)
	tween.play()
	#linea_salud_1.size.x = 48 * salud / salud_max
	#linea_salud_2.size.x = 48 * salud / salud_max

func _on_barra_salud_1_resized() -> void:
	# Umbrales de GetHPBarLevel (battle_interface.c): rojo < 10/48, amarillo < 25/48.
	if linea_salud_1.size.x < 10:
		# color hex a84048 y f85838
		linea_salud_1.color = Color.hex(0xa84048ff)
		linea_salud_2.color = Color.hex(0xfb7f67ff)
	elif linea_salud_1.size.x < 25:
		# color hex c8a808 y f8e038
		linea_salud_1.color = Color.hex(0xc8a808ff)
		linea_salud_2.color = Color.hex(0xf8e038ff)
	else:
		# color hex 58d080 y 70f8a8
		linea_salud_1.color = Color.hex(0x58d080ff)
		linea_salud_2.color = Color.hex(0x70f8a8ff)
