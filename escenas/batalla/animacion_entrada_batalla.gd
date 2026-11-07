class_name AnimacionEntradaBatalla
extends Node

## Animación de la tira de entrada ("frente", BG1) durante la intro del
## combate, como StartBattleIntroAnim(gBattleTerrain) de Rubí
## (src/battle/anim/battle_intro.c). Cada terreno usa una de tres tareas:
##   - BattleIntroTask_ScrollScenery (DESPLAZAR): BG1_X += 6 por cuadro; tras el
##     retardo la tira baja 1 px por cuadro hasta 56 px (HIERBA_LARGA: 2 px hasta
##     80 px).
##   - BattleIntroTask_FadeScenery (FUNDIR): BG1_X += 8 (6 bajo el agua); opaca
##     hasta el retardo y luego EVA baja de 16 a 0, una vez en el primer cuadro y
##     después cada 4. En AGUA la tira además se mece (BG1_Y = Cos2(d6)/512 - 8).
##   - BattleIntroTask_ScrollAndFadeScenery (DESPLAZAR_Y_FUNDIR): BG1_X += 8 con
##     mezcla al 50 % (EVA 8) desde el principio; tras el retardo EVA baja 1 en el
##     primer cuadro y luego cada 6 hasta 0.
## El retardo (tFramesUntilBg1Slide = 32) se cuenta desde el inicio del
## deslizamiento de las plataformas (estado 3) y la tira se borra de golpe al
## terminar ese deslizamiento (CpuFill32 del tilemap de BG1).
##
## `calcular()` es la parte pura (terreno + número de cuadro → estado); el nodo
## la ejecuta a 60 Hz acumulando delta sobre el Node2D de la tira.

signal terminada

enum Familia { DESPLAZAR, FUNDIR, DESPLAZAR_Y_FUNDIR }

const DURACION_CUADRO: float = 1.0 / 60.0
## BG1 se repite cada 256 px en horizontal.
const ANCHO_BG: float = 256.0
## Cuadros de los estados 0-2 (apertura de la ventana) antes del deslizamiento
## de las plataformas en el GBA.
const CUADROS_APERTURA_VENTANA: int = 34
## Estado 3: tBgXOffset baja de DISPLAY_WIDTH (240) a 0 de 2 en 2.
const CUADROS_DESLIZAMIENTO: int = 120
## tFramesUntilBg1Slide.
const CUADROS_RETARDO: int = 32
## DESPLAZAR: tope del descenso (BG1_Y 0xFFC8 / 0xFFB0) y píxeles por cuadro.
const DESCENSO_MAXIMO: int = 56
const DESCENSO_MAXIMO_HIERBA_LARGA: int = 80
const PASO_DESCENSO_HIERBA_LARGA: int = 2
## FUNDIR / DESPLAZAR_Y_FUNDIR: EVA inicial y cuadros entre bajadas de EVA.
const EVA_MAXIMO: int = 16
const EVA_MEZCLA: int = 8
const INTERVALO_FUNDIR: int = 4
const INTERVALO_DESPLAZAR_Y_FUNDIR: int = 6

var _objetivo: Node2D = null
var _terreno: int = EscenarioBatalla.Terreno.LLANURA
var _base: Vector2 = Vector2.ZERO
var _cuadro_inicio_deslizamiento: int = CUADROS_APERTURA_VENTANA
var _cuadros_deslizamiento: int = CUADROS_DESLIZAMIENTO
var _cuadro: int = 0
var _acumulado: float = 0.0


func _ready() -> void:
	set_process(false)


## Familia de tarea de un terreno (sBattleIntroTaskFuncs).
static func familia(terreno: int) -> Familia:
	match terreno:
		EscenarioBatalla.Terreno.ARENA, EscenarioBatalla.Terreno.BAJO_AGUA, EscenarioBatalla.Terreno.AGUA:
			return Familia.FUNDIR
		EscenarioBatalla.Terreno.EDIFICIO, EscenarioBatalla.Terreno.LLANURA:
			return Familia.DESPLAZAR_Y_FUNDIR
		EscenarioBatalla.Terreno.HIERBA_ALTA, EscenarioBatalla.Terreno.HIERBA_LARGA, EscenarioBatalla.Terreno.ESTANQUE, \
				EscenarioBatalla.Terreno.MONTANA, EscenarioBatalla.Terreno.CUEVA:
			return Familia.DESPLAZAR
	return Familia.DESPLAZAR_Y_FUNDIR


## Píxeles que avanza BG1_X por cuadro.
static func velocidad(terreno: int) -> int:
	match familia(terreno):
		Familia.FUNDIR:
			return 6 if terreno == EscenarioBatalla.Terreno.BAJO_AGUA else 8
		Familia.DESPLAZAR_Y_FUNDIR:
			return 8
	return 6


## Estado de la tira tras `cuadro` actualizaciones (cuadro 0 = antes de la
## primera) contadas desde el inicio de la intro. `cuadro_inicio_deslizamiento`:
## actualizaciones antes de que empiece el deslizamiento de las plataformas;
## `cuadros_deslizamiento`: lo que dura. Devuelve {"x", "y", "alpha", "visible"}:
## x es la posición horizontal del nodo (-desplazamiento módulo 256), y el
## descenso respecto a la posición base (positivo = más abajo) y alpha = EVA/16.
static func calcular(terreno: int, cuadro: int, cuadro_inicio_deslizamiento: int = CUADROS_APERTURA_VENTANA, cuadros_deslizamiento: int = CUADROS_DESLIZAMIENTO) -> Dictionary:
	var n := maxi(cuadro, 0)
	var x := -fposmod(float(velocidad(terreno) * n), ANCHO_BG)
	# Cuadros del deslizamiento ya transcurridos y cuadros tras el retardo.
	var en_deslizamiento := n - cuadro_inicio_deslizamiento
	var tras_retardo := en_deslizamiento - CUADROS_RETARDO
	var y := 0.0
	var eva := EVA_MAXIMO
	match familia(terreno):
		Familia.DESPLAZAR:
			if terreno == EscenarioBatalla.Terreno.HIERBA_LARGA:
				y = mini(maxi(tras_retardo, 0) * PASO_DESCENSO_HIERBA_LARGA, DESCENSO_MAXIMO_HIERBA_LARGA)
			else:
				y = mini(maxi(tras_retardo, 0), DESCENSO_MAXIMO)
		Familia.FUNDIR:
			eva = EVA_MAXIMO - _bajadas_eva(tras_retardo, INTERVALO_FUNDIR, EVA_MAXIMO)
			if terreno == EscenarioBatalla.Terreno.AGUA and n > 0:
				# BG1_Y se fija antes de avanzar d6: tras n cuadros vale el de d6
				# después de n - 1 avances. BG1_Y negativo baja el contenido.
				y = -float(balanceo_agua(n - 1))
		Familia.DESPLAZAR_Y_FUNDIR:
			eva = EVA_MEZCLA - _bajadas_eva(tras_retardo, INTERVALO_DESPLAZAR_Y_FUNDIR, EVA_MEZCLA)
	return {
		"x": x,
		"y": y,
		"alpha": float(eva) / float(EVA_MAXIMO),
		"visible": en_deslizamiento < cuadros_deslizamiento,
	}


## BG1_Y del balanceo del agua tras `avances` avances de d6:
## Cos2(d6) / 512 - 8, d6 += 4 mientras d6 < 180 y += 6 después, vuelve a 0 en 360.
static func balanceo_agua(avances: int) -> int:
	# Ciclo: 45 avances de 4 (0..176) y 30 de 6 (180..354).
	var paso := posmod(avances, 75)
	var d6 := paso * 4 if paso < 45 else 180 + (paso - 45) * 6
	@warning_ignore("integer_division")
	return _cos2(d6) / 512 - 8


## Cos2 de trig.c: Sin2(angulo + 90) con gSineDegreeTable (Q4.12).
static func _cos2(angulo: int) -> int:
	var a := angulo + 90
	var valor := roundi(sin(deg_to_rad(float(a % 180))) * 4096.0)
	@warning_ignore("integer_division")
	var negar := ((a / 180) & 1) == 1
	return -valor if negar else valor


## Bajadas de EVA hechas `tras_retardo` cuadros después del retardo: la
## primera en el cuadro 1 y luego una cada `intervalo`, hasta `maximo`.
static func _bajadas_eva(tras_retardo: int, intervalo: int, maximo: int) -> int:
	if tras_retardo <= 0:
		return 0
	@warning_ignore("integer_division")
	return mini(1 + (tras_retardo - 1) / intervalo, maximo)


## Arranca la animación sobre `objetivo` (la tira) en `base` (su posición
## inicial). Los tiempos del deslizamiento de las plataformas van en segundos
## desde el inicio de la intro.
func iniciar(objetivo: Node2D, terreno: int, base: Vector2, inicio_deslizamiento: float, duracion_deslizamiento: float) -> void:
	_objetivo = objetivo
	_terreno = terreno
	_base = base
	_cuadro_inicio_deslizamiento = roundi(inicio_deslizamiento / DURACION_CUADRO)
	_cuadros_deslizamiento = roundi(duracion_deslizamiento / DURACION_CUADRO)
	_cuadro = 0
	_acumulado = 0.0
	set_process(true)
	_aplicar()


## Detiene la animación sin tocar la tira.
func detener() -> void:
	set_process(false)
	_objetivo = null


func esta_activa() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	if not is_instance_valid(_objetivo):
		detener()
		return
	_acumulado += delta
	var avanzo := false
	while _acumulado >= DURACION_CUADRO:
		_acumulado -= DURACION_CUADRO
		_cuadro += 1
		avanzo = true
	if avanzo:
		_aplicar()


func _aplicar() -> void:
	var estado := calcular(_terreno, _cuadro, _cuadro_inicio_deslizamiento, _cuadros_deslizamiento)
	_objetivo.position = _base + Vector2(float(estado.x), float(estado.y))
	_objetivo.modulate.a = float(estado.alpha)
	if not bool(estado.visible):
		_objetivo.visible = false
		detener()
		terminada.emit()
