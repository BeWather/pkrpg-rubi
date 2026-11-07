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
@onready var lPS_actual: Label = $"LPSActual"
@onready var lPS_total: Label = $"LPSTotal"
@onready var barra_experiencia: ColorRect = $"BarraExperiencia"
var posicion_inicial: Vector2
var _y_reposo: float = 0.0
var _desplazado: bool = false

func _ready():
	posicion_inicial = position

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

func set_salud_max(salud_max: int):
	linea_salud_1.size.x = 48
	linea_salud_2.size.x = 48
	lPS_actual.text = str(salud_max)
	lPS_total.text = str(salud_max)

func set_salud_instantanea(salud_max: int, salud: int) -> void:
	var porcentaje_salud = float(salud) / float(max(salud_max, 1))
	linea_salud_1.size.x = 48 * porcentaje_salud
	linea_salud_2.size.x = 48 * porcentaje_salud
	lPS_actual.text = str(salud)
	lPS_total.text = str(salud_max)

func set_experiencia(experiencia: int, exp_actual_nivel: int, exp_sig_nivel: int):
	set_experiencia_porcentaje(_calcular_porcentaje_experiencia(experiencia, exp_actual_nivel, exp_sig_nivel))

func set_experiencia_porcentaje(porcentaje: float) -> void:
	barra_experiencia.size.x = 48.0 * clamp(porcentaje, 0.0, 1.0)

func animar_experiencia(experiencia: int, exp_actual_nivel: int, exp_sig_nivel: int, duracion: float = 0.8) -> void:
	await animar_experiencia_porcentaje(_calcular_porcentaje_experiencia(experiencia, exp_actual_nivel, exp_sig_nivel), duracion)

func animar_experiencia_porcentaje(porcentaje: float, duracion: float = 0.8) -> void:
	var tween = create_tween()
	tween.tween_property(barra_experiencia, "size", Vector2(48.0 * clamp(porcentaje, 0.0, 1.0), barra_experiencia.size.y), duracion)
	await tween.finished

func _calcular_porcentaje_experiencia(experiencia: int, exp_actual_nivel: int, exp_sig_nivel: int) -> float:
	var experiencia_base = min(exp_actual_nivel, exp_sig_nivel)
	var experiencia_objetivo = max(exp_actual_nivel, exp_sig_nivel)
	var rango_experiencia = max(experiencia_objetivo - experiencia_base, 1)
	return clamp(float(experiencia - experiencia_base) / float(rango_experiencia), 0.0, 1.0)

## Bamboleo del cuadro mientras se elige acción. La base es la Y en reposo
## (no la de la escena): en doble el cuadro descansa en otra posición.
func set_offset_y(oy: int) -> void:
	if not _desplazado:
		_y_reposo = position.y
	position.y = _y_reposo + oy
	_desplazado = oy != 0

func set_salud(salud_max: int, salud: int, tween: Tween):

	tween.tween_property(linea_salud_1, "size", Vector2(48 * float(salud) / float(salud_max), linea_salud_1.size.y), 1)
	tween.parallel().tween_property(linea_salud_2, "size", Vector2(48 * float(salud) / float(salud_max), linea_salud_1.size.y), 1)
	tween.play()
	#linea_salud_1.size.x = 48 * salud / salud_max
	#linea_salud_2.size.x = 48 * salud / salud_max
	lPS_actual.text = str(salud)

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
