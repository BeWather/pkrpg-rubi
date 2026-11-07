## reloj_pared.gd
## Reloj de pared del cuarto del jugador (pokeruby src/wallclock.c).
##
## - AJUSTAR (CB2_StartWallClock): empieza a las 10:00 AM; ← → mueven el minutero
##   (acelerando al mantener) y A pregunta si la hora es correcta. Con SÍ se
##   guarda el desfase de la hora del juego (RtcInitLocalTimeOffset).
## - VER (CB2_ViewWallClock): muestra la hora del juego; A o B salen.
##
## Todo avanza a 60 pasos por segundo, como las tareas y sprites de Rubí. Las
## agujas giran sobre el centro del reloj (120,80) y los rótulos AM/PM orbitan a
## 30 px de él por detrás de la esfera, que solo los deja ver por su ventanita.
class_name RelojPared
extends Control

signal terminado

enum Modo { VER, AJUSTAR }

## Task_SetClock2: tMvmtDir.
enum Sentido { NINGUNO, ATRAS, ADELANTE }

const CENTRO := Vector2(120, 80)
## Radio de la órbita de los rótulos AM/PM (sub_810B18C / sub_810B230).
const RADIO_AM_PM: float = 30.0
const PASO: float = 1.0 / 60.0
const TEXTO_VALE: String = "VALE"
const TEXTO_SALIR: String = "SALIR"

## Pregunta "¿Es la hora correcta?" (await, devuelve bool). Sin ella, A confirma.
var preguntar: Callable = Callable()

var modo: Modo = Modo.VER
var hora: int = 10
var minuto: int = 0
## tMinuteHandAngle / tHourHandAngle en grados, 0 = las 12, en sentido horario.
var angulo_minutero: int = 0
var angulo_horario: int = 300
var es_pm: bool = false
var confirmado: bool = false

## Ángulos de órbita (sprite->data[1]): rótulo AM visible a 90°, PM a 90°.
var _angulo_am: int = 90
var _angulo_pm: int = 45
var _direccion: Sentido = Sentido.NINGUNO
var _velocidad: int = 0
var _activo: bool = false
var _preguntando: bool = false
## Tras volver de la pregunta: no leer A hasta soltarla.
var _esperar_soltar: bool = false
var _acumulado: float = 0.0

@onready var _am: Sprite2D = $Am
@onready var _pm: Sprite2D = $Pm
@onready var _base_chica: Sprite2D = $RelojBaseChica
@onready var _base_chico: Sprite2D = $RelojBaseChico
@onready var _cruceta: Sprite2D = $Cruceta
@onready var _vale_salir: Label = $ValeSalir
@onready var _minutero: Sprite2D = $AgujaLarga
@onready var _horario: Sprite2D = $AgujaCorta


## `masculino`: paleta del reloj (gSpecialVar_0x8004 = MALE en la casa de BRUNO).
func configurar(nuevo_modo: Modo, masculino: bool) -> void:
	modo = nuevo_modo
	if modo == Modo.AJUSTAR:
		hora = 10
		minuto = 0
		es_pm = false
		angulo_minutero = 0
		angulo_horario = 300
	else:
		_leer_hora_del_juego()
	# Órbitas iniciales: CB2_StartWallClock (45, 90) y CB2_ViewWallClock.
	_angulo_pm = 90 if es_pm else 45
	_angulo_am = 135 if es_pm else 90
	if is_node_ready():
		_aplicar_aspecto(masculino)
	else:
		ready.connect(_aplicar_aspecto.bind(masculino), CONNECT_ONE_SHOT)


func _aplicar_aspecto(masculino: bool) -> void:
	_base_chico.visible = masculino
	_base_chica.visible = not masculino
	_cruceta.visible = modo == Modo.AJUSTAR
	_vale_salir.text = TEXTO_VALE if modo == Modo.AJUSTAR else TEXTO_SALIR
	_dibujar()


## Task_SetClock1 / Task_ViewClock1: empieza a leer botones (tras el fundido).
func activar() -> void:
	_activo = true
	_esperar_soltar = Input.is_action_pressed(&"btn_accion") or Input.is_action_pressed(&"btn_cancelar")


func _ready() -> void:
	_dibujar()


func _process(delta: float) -> void:
	_acumulado = minf(_acumulado + delta, PASO * 4.0)
	var pulsado_a := Input.is_action_just_pressed(&"btn_accion")
	var pulsado_b := Input.is_action_just_pressed(&"btn_cancelar")
	while _acumulado >= PASO:
		_acumulado -= PASO
		paso(pulsado_a, pulsado_b, _direccion_mantenida())
		pulsado_a = false
		pulsado_b = false
	_dibujar()


func _direccion_mantenida() -> Sentido:
	# Task_SetClock2: con las dos pulsadas gana la derecha.
	if Input.is_action_pressed(&"btn_derecha"):
		return Sentido.ADELANTE
	if Input.is_action_pressed(&"btn_izquierda"):
		return Sentido.ATRAS
	return Sentido.NINGUNO


## Un fotograma de Rubí: la tarea del reloj y los sprites de AM/PM.
func paso(pulsado_a: bool, pulsado_b: bool, mantenida: Sentido) -> void:
	if _esperar_soltar:
		if Input.is_action_pressed(&"btn_accion") or Input.is_action_pressed(&"btn_cancelar"):
			pulsado_a = false
			pulsado_b = false
		else:
			_esperar_soltar = false
	if _activo and not _preguntando:
		if modo == Modo.AJUSTAR:
			_paso_ajustar(pulsado_a, mantenida)
		else:
			_paso_ver(pulsado_a or pulsado_b)
	_paso_am_pm()


## Task_SetClock2.
func _paso_ajustar(pulsado_a: bool, mantenida: Sentido) -> void:
	if angulo_minutero % 6 != 0:
		angulo_minutero = nuevo_angulo_minutero(angulo_minutero, _direccion, _velocidad)
		return
	angulo_minutero = minuto * 6
	angulo_horario = angulo_hora(hora, minuto)
	if pulsado_a:
		_confirmar()
		return
	_direccion = mantenida
	if _direccion == Sentido.NINGUNO:
		_velocidad = 0
		return
	_velocidad = mini(_velocidad + 1, 0xFF)
	angulo_minutero = nuevo_angulo_minutero(angulo_minutero, _direccion, _velocidad)
	avanzar_minuto(_direccion)


## Task_SetClock3..5: "¿Es la hora correcta?"; NO o B vuelven a Task_SetClock2.
func _confirmar() -> void:
	_preguntando = true
	var correcta := true
	if preguntar.is_valid():
		correcta = await preguntar.call()
	if not is_inside_tree():
		return
	_preguntando = false
	if not correcta:
		_esperar_soltar = true
		return
	_activo = false
	confirmado = true
	terminado.emit()


## Task_ViewClock2.
func _paso_ver(pulsado: bool) -> void:
	_leer_hora_del_juego()
	if pulsado:
		_activo = false
		terminado.emit()


## InitClockWithRtc.
func _leer_hora_del_juego() -> void:
	hora = RelojJuego.hora_local()
	minuto = RelojJuego.minuto_local()
	angulo_minutero = minuto * 6
	angulo_horario = angulo_hora(hora, minuto)
	es_pm = hora > 11


## AdvanceClock + UpdateClockPeriod.
func avanzar_minuto(direccion: Sentido) -> void:
	if direccion == Sentido.ATRAS:
		if minuto > 0:
			minuto -= 1
			return
		minuto = 59
		hora = hora - 1 if hora > 0 else 23
		if hora == 11:
			es_pm = false
		elif hora == 23:
			es_pm = true
	elif direccion == Sentido.ADELANTE:
		if minuto < 59:
			minuto += 1
			return
		minuto = 0
		hora = hora + 1 if hora < 23 else 0
		if hora == 0:
			es_pm = false
		elif hora == 12:
			es_pm = true


## sub_810B18C (PM) y sub_810B230 (AM): al cambiar de periodo los rótulos giran
## 15° despacio y luego 30° de 5 en 5; el que llega a 90° queda en la ventanita.
func _paso_am_pm() -> void:
	if es_pm:
		if _angulo_pm >= 60 and _angulo_pm < 90:
			_angulo_pm += 5
		if _angulo_pm < 60:
			_angulo_pm += 1
		if _angulo_am >= 105 and _angulo_am < 135:
			_angulo_am += 5
		if _angulo_am < 105:
			_angulo_am += 1
	else:
		if _angulo_pm > 45 and _angulo_pm <= 75:
			_angulo_pm -= 5
		if _angulo_pm > 75:
			_angulo_pm -= 1
		if _angulo_am > 90 and _angulo_am <= 120:
			_angulo_am -= 5
		if _angulo_am > 120:
			_angulo_am -= 1


func _dibujar() -> void:
	if not is_node_ready():
		return
	_minutero.rotation_degrees = angulo_minutero
	_horario.rotation_degrees = angulo_horario
	_am.position = posicion_rotulo(_angulo_am)
	_pm.position = posicion_rotulo(_angulo_pm)


## Esquina del rótulo de 16x16 cuyo centro orbita en `angulo` (0° = derecha,
## 90° = abajo). Como Rubí: cos·30/4096 truncado hacia cero.
static func posicion_rotulo(angulo: int) -> Vector2:
	var x := int(roundi(cos(deg_to_rad(angulo)) * 4096.0) * RADIO_AM_PM / 4096.0)
	var y := int(roundi(sin(deg_to_rad(angulo)) * 4096.0) * RADIO_AM_PM / 4096.0)
	return CENTRO + Vector2(x, y) - Vector2(8, 8)


@warning_ignore("integer_division")
static func angulo_hora(h: int, m: int) -> int:
	return (h % 12) * 30 + (m / 10) * 5


## CalcMinHandDelta.
static func delta_minutero(velocidad: int) -> int:
	if velocidad > 60:
		return 6
	if velocidad > 30:
		return 3
	if velocidad > 10:
		return 2
	return 1


## CalcNewMinHandAngle.
static func nuevo_angulo_minutero(angulo: int, direccion: Sentido, velocidad: int) -> int:
	var delta := delta_minutero(velocidad)
	match direccion:
		Sentido.ATRAS:
			return angulo - delta if angulo > 0 else 360 - delta
		Sentido.ADELANTE:
			return angulo + delta if angulo < 360 - delta else 0
	return angulo


func angulo_rotulo_am() -> int:
	return _angulo_am


func angulo_rotulo_pm() -> int:
	return _angulo_pm
