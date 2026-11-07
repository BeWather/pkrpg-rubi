class_name PuertaGiratoria
extends Node2D

## Puerta giratoria de una prueba de la CASA TRETA (acertijo 6) o del GIMNASIO de
## CIUDAD ARBORADA: pokeruby src/rotating_gate.c (RotatingGate_*).
##
## GEOMETRÍA (verificada contra las tablas de empuje de Rubí). El eje de giro es
## la ESQUINA superior izquierda de la celda `celda` (la `x, y` de
## sRotatingGate_*PuzzleConfig), no el centro de una celda. Los brazos son
## segmentos pegados a las ARISTAS entre celdas, que salen de ese eje hacia
## N / E / S / O, de 1 celda (corto) o 2 (largo):
##
##            celda.x-1 | celda.x
##    brazo N:   (x-1, y-k) | (x, y-k)       k = 1 (corto), 2 (largo)
##    brazo S:   (x-1, y+k-1) | (x, y+k-1)
##    brazo E:   (x+k-1, y-1) / (x+k-1, y)   (arista horizontal)
##    brazo O:   (x-k, y-1) / (x-k, y)
##
## El brazo no ocupa celdas: se cruza al pasar de una celda a la contigua. Un
## paso que atraviesa la arista de un brazo lo EMPUJA: lo hace girar 90° en el
## sentido en que lo empuja, si ningún brazo choca con una celda bloqueada en su
## recorrido (RotatingGate_CanRotate); si no puede girar, el brazo bloquea.
## El estado (orientación) es solo de ejecución: al cargar vuelve al de fábrica.
##
## La textura (graficos/puertas_giratorias/<forma>.png, 32x32 las formas de brazos
## cortos y 64x64 las demás) está centrada en el eje.

## Formas (GATE_SHAPE_*). L = dos brazos (N, E); T = tres (N, E, S) en
## orientación 0. «Largo» = el brazo mide 2 celdas.
enum Forma {
	L1,  ## N corto + E corto
	L2,  ## N largo + E corto
	L3,  ## N corto + E largo
	L4,  ## N largo + E largo
	T1,  ## N, E, S cortos
	T2,  ## N largo, E, S cortos
	T3,  ## N, E largo, S
	T4,  ## N, E, S largo
}

## ROTATE_NONE / ROTATE_ANTICLOCKWISE / ROTATE_CLOCKWISE.
enum Sentido { NINGUNO, ANTIHORARIO, HORARIO }

## Direcciones del mundo y de los brazos: GATE_ARM_NORTH..WEST.
enum Brazo { NORTE, ESTE, SUR, OESTE }

const TILE: int = 16
## GATE_ARM_MAX_LENGTH.
const LARGO_MAXIMO: int = 2
## SE_ROTATING_GATE (id 48 de songs.h), registrado en `Singleton.se`.
const SONIDO_GIRO: String = "SE_ROTATING_GATE"
## Fotogramas de la animación (60 por segundo): -4/256 de vuelta por fotograma
## durante 16 (normal) u -8/256 durante 8 (si el jugador no va andando).
const DURACION_GIRO: float = 16.0 / 60.0
const DURACION_GIRO_RAPIDO: float = 8.0 / 60.0

## sRotatingGate_ArmLayout: por forma, [corto N, largo N, corto E, largo E,
## corto S, largo S, corto O, largo O] con la puerta en orientación 0.
const DISPOSICION: Array = [
	[1, 0, 1, 0, 0, 0, 0, 0],  # L1
	[1, 1, 1, 0, 0, 0, 0, 0],  # L2
	[1, 0, 1, 1, 0, 0, 0, 0],  # L3
	[1, 1, 1, 1, 0, 0, 0, 0],  # L4
	[1, 0, 1, 0, 1, 0, 0, 0],  # T1
	[1, 1, 1, 0, 1, 0, 0, 0],  # T2
	[1, 0, 1, 1, 1, 0, 0, 0],  # T3
	[1, 0, 1, 0, 1, 1, 0, 0],  # T4
]

## sRotatingGate_RotationInfo{North,South,West,East}: cuadrícula 4x4 centrada en
## el eje (columna = x - celda.x + 2, fila = y - celda.y + 2) de la CELDA DE
## DESTINO del paso. Cada valor es GATE_ROT(sentido, brazo, largo):
## (sentido << 4) | (brazo << 1) | largo; 255 = no toca ningún brazo.
const SIN_EMPUJE: int = 255
const EMPUJE_NORTE: Array[int] = [
	255, 255, 255, 255,
	39, 38, 18, 19,    # CW(O,1) CW(O,0) ACW(E,0) ACW(E,1)
	255, 255, 255, 255,
	255, 255, 255, 255,
]
const EMPUJE_SUR: Array[int] = [
	255, 255, 255, 255,
	255, 255, 255, 255,
	23, 22, 34, 35,    # ACW(O,1) ACW(O,0) CW(E,0) CW(E,1)
	255, 255, 255, 255,
]
const EMPUJE_OESTE: Array[int] = [
	255, 17, 255, 255,  # ACW(N,1)
	255, 16, 255, 255,  # ACW(N,0)
	255, 36, 255, 255,  # CW(S,0)
	255, 37, 255, 255,  # CW(S,1)
]
const EMPUJE_ESTE: Array[int] = [
	255, 255, 33, 255,  # CW(N,1)
	255, 255, 32, 255,  # CW(N,0)
	255, 255, 20, 255,  # ACW(S,0)
	255, 255, 21, 255,  # ACW(S,1)
]

## sRotatingGate_ArmPositions*Rotation: por dirección ACTUAL de cada brazo
## (N, E, S, O) y tramo (corto, largo), la celda (relativa a `celda`) que barre
## al girar. Si alguna está bloqueada en el mapa la puerta no gira.
const BARRIDO_HORARIO: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -2),   # N
	Vector2i(0, 0), Vector2i(1, 0),     # E
	Vector2i(-1, 0), Vector2i(-1, 1),   # S
	Vector2i(-1, -1), Vector2i(-2, -1), # O
]
const BARRIDO_ANTIHORARIO: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(-1, -2), # N
	Vector2i(0, -1), Vector2i(1, -1),   # E
	Vector2i(0, 0), Vector2i(0, 1),     # S
	Vector2i(-1, 0), Vector2i(-2, 0),   # O
]

const TEXTURAS: Array[Texture2D] = [
	preload("res://graficos/puertas_giratorias/forma_0.png"),
	preload("res://graficos/puertas_giratorias/forma_1.png"),
	preload("res://graficos/puertas_giratorias/forma_2.png"),
	preload("res://graficos/puertas_giratorias/forma_3.png"),
	preload("res://graficos/puertas_giratorias/forma_4.png"),
	preload("res://graficos/puertas_giratorias/forma_5.png"),
	preload("res://graficos/puertas_giratorias/forma_6.png"),
	preload("res://graficos/puertas_giratorias/forma_7.png"),
]

## Celda cuya esquina superior izquierda es el eje (x, y de la configuración de Rubí).
@export var celda: Vector2i = Vector2i.ZERO
@export var forma: Forma = Forma.T1
## Giro horario de fábrica en cuartos de vuelta (0, 90, 180, 270 grados = 0..3).
@export_range(0, 3) var orientacion_inicial: int = 0

## Orientación actual (0..3, cuartos de vuelta horarios).
var orientacion: int = 0
var _sprite: Sprite2D = null
## Ángulo visual acumulado (radianes): evita el salto de 270° a 0° al animar.
var _angulo: float = 0.0
var _tween: Tween = null
## Sustituye al sonido real (tests).
var con_sonido: bool = true


func _ready() -> void:
	orientacion = posmod(orientacion_inicial, 4)
	position = Vector2(celda * TILE)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = TEXTURAS[forma]
	add_child(_sprite)
	_angulo = orientacion * PI / 2.0
	_sprite.rotation = _angulo


## ¿Existe el segmento (`largo` = el segundo tramo) del brazo que mira hacia
## `direccion_mundo` (Brazo) con la puerta en `orient_actual`? RotatingGate_HasArm.
static func hay_brazo(forma_puerta: int, orient_actual: int, direccion_mundo: int, largo: bool) -> bool:
	var original := posmod(direccion_mundo - orient_actual, 4)
	return DISPOSICION[forma_puerta][original * 2 + (1 if largo else 0)] == 1


## RotatingGate_GetRotationInfo: valor de la tabla para `direccion` (la del paso)
## en la celda (columna, fila) de la cuadrícula 4x4.
static func info_empuje(direccion: Vector2i, columna: int, fila: int) -> int:
	var tabla: Array[int]
	match direccion:
		Vector2i.UP:
			tabla = EMPUJE_NORTE
		Vector2i.DOWN:
			tabla = EMPUJE_SUR
		Vector2i.LEFT:
			tabla = EMPUJE_OESTE
		Vector2i.RIGHT:
			tabla = EMPUJE_ESTE
		_:
			return SIN_EMPUJE
	return tabla[fila * 4 + columna]


## Sentido (Sentido.*) en que un paso hacia `destino` en `direccion` empuja a un
## brazo de una puerta con el eje en `eje`; NINGUNO si ese paso no toca ninguno.
## No comprueba si puede girar. Es estática para poder simular sin nodos (tests).
static func sentido_en(eje: Vector2i, forma_puerta: int, orient_actual: int, destino: Vector2i, direccion: Vector2i) -> int:
	var columna := destino.x - eje.x + 2
	var fila := destino.y - eje.y + 2
	if columna < 0 or columna > 3 or fila < 0 or fila > 3:
		return Sentido.NINGUNO
	var info := info_empuje(direccion, columna, fila)
	if info == SIN_EMPUJE:
		return Sentido.NINGUNO
	var datos_brazo := info & 0xF
	var brazo := datos_brazo >> 1
	var largo := (datos_brazo & 1) == 1
	if not hay_brazo(forma_puerta, orient_actual, brazo, largo):
		return Sentido.NINGUNO
	return (info & 0xF0) >> 4


## RotatingGate_CanRotate: ningún tramo de ningún brazo puede barrer una celda
## bloqueada. `bloqueada(celda: Vector2i) -> bool` es la capa de colisiones del mapa.
static func barrido_libre(eje: Vector2i, forma_puerta: int, orient_actual: int, sentido: int, bloqueada: Callable) -> bool:
	var barrido: Array[Vector2i]
	if sentido == Sentido.ANTIHORARIO:
		barrido = BARRIDO_ANTIHORARIO
	elif sentido == Sentido.HORARIO:
		barrido = BARRIDO_HORARIO
	else:
		return false
	for original in 4:
		for tramo in LARGO_MAXIMO:
			if DISPOSICION[forma_puerta][original * 2 + tramo] != 1:
				continue
			var actual := (orient_actual + original) % 4
			if bloqueada.call(eje + barrido[actual * 2 + tramo]):
				return false
	return true


## Sentido en que un paso empuja a esta puerta (ver `sentido_en`).
func sentido_de_empuje(destino: Vector2i, direccion: Vector2i) -> int:
	return sentido_en(celda, forma, orientacion, destino, direccion)


## ¿Puede girar en `sentido` sin chocar con una celda con BLOQUEO de `datos`?
func puede_girar(datos: TPTileDataMap, sentido: int) -> bool:
	var bloqueada := func(c: Vector2i) -> bool:
		return datos != null and datos.has_flag(Vector2(c), TPTileDataMap.Flags.BLOQUEO)
	return barrido_libre(celda, forma, orientacion, sentido, bloqueada)


## Gira 90° en `sentido`: RotatingGate_RotateInDirection + animación y sonido
## (SpriteCallback_RotatingGate). `rapido` = el jugador no iba andando.
func girar(sentido: int, rapido: bool = false) -> void:
	if sentido == Sentido.ANTIHORARIO:
		orientacion = (orientacion + 3) % 4
		_angulo -= PI / 2.0
	elif sentido == Sentido.HORARIO:
		orientacion = (orientacion + 1) % 4
		_angulo += PI / 2.0
	else:
		return
	if con_sonido and is_inside_tree():
		Singleton.play_sound.emit(SONIDO_GIRO)
	_animar(DURACION_GIRO_RAPIDO if rapido else DURACION_GIRO)


## Vuelve a la orientación de fábrica (RotatingGate_ResetAllGateOrientations).
func restaurar() -> void:
	orientacion = posmod(orientacion_inicial, 4)
	_angulo = orientacion * PI / 2.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if _sprite != null:
		_sprite.rotation = _angulo


## Aristas que hoy cierran los brazos: lista de [celda_a, celda_b] (las dos
## celdas separadas por el segmento). Sirve para dibujar, depurar y para los
## tests de alcanzabilidad.
func aristas() -> Array:
	var lista: Array = []
	for original in 4:
		var mundo := (orientacion + original) % 4
		for tramo in LARGO_MAXIMO:
			if DISPOSICION[forma][original * 2 + tramo] != 1:
				continue
			var k := tramo + 1
			match mundo:
				Brazo.NORTE:
					lista.append([celda + Vector2i(-1, -k), celda + Vector2i(0, -k)])
				Brazo.SUR:
					lista.append([celda + Vector2i(-1, k - 1), celda + Vector2i(0, k - 1)])
				Brazo.ESTE:
					lista.append([celda + Vector2i(k - 1, -1), celda + Vector2i(k - 1, 0)])
				Brazo.OESTE:
					lista.append([celda + Vector2i(-k, -1), celda + Vector2i(-k, 0)])
	return lista


func _animar(duracion: float) -> void:
	if _sprite == null:
		return
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		_sprite.rotation = _angulo
		return
	_tween = create_tween()
	_tween.tween_property(_sprite, "rotation", _angulo, duracion)
