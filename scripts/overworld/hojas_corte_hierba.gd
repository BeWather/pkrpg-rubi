class_name HojasCorteHierba
extends Node2D

## FLDEFF_CUT_GRASS de pokeruby: las 8 hojas que salen girando del jugador al usar
## CORTE sobre la hierba alta (FldEff_CutGrass, CutGrassSpriteCallback1/2/End de
## src/fldeff_cut.c; imagen graphics/field_effect_objects/pics/cut_grass.png, 8x8,
## con la paleta 06 de los efectos de campo).
##
## Cada hoja arranca en el ángulo 32 * i (de 0 a 255) y radio 8. Un fotograma
## después de crearse (Callback1) empiezan a moverse (Callback2): cada fotograma
## x2 = Sin(ángulo, radio) e y2 = Cos(ángulo, radio), ángulo += 8 y
## radio += (contador >> 2) + 1, durante 29 fotogramas; el siguiente (CallbackEnd)
## destruye las hojas y libera al jugador. Todo a 60 fotogramas por segundo.

## Emitida al acabar (CallbackEnd): quien lanza el efecto vuelve a dar el control.
signal terminado

const CANTIDAD: int = 8
const FOTOGRAMAS_MOVIMIENTO: int = 29
## Fotograma en el que corre CallbackEnd: 1 de Callback1 + 29 de Callback2.
const FOTOGRAMA_FINAL: int = 30
const SEGUNDOS_POR_FOTOGRAMA: float = 1.0 / 60.0
const RADIO_INICIAL: int = 8
const GIRO_POR_FOTOGRAMA: int = 8
const SEPARACION_ANGULAR: int = 32
## Las hojas van por encima del jugador y de la copa de los árboles.
const CAPA_Z: int = 3
## Imagen de 8x8 (índices de paleta: 0 transparente, 1 claro, 2 medio, 3 oscuro).
const PIXELES: Array[String] = [
	"00000000",
	"03000300",
	"31303130",
	"32232230",
	"03232300",
	"03323300",
	"22333220",
	"02232200",
]

static var _textura: ImageTexture = null

var _fotograma: int = 0
var _acumulado: float = 0.0
var _hojas: Array[Sprite2D] = []
var _acabado: bool = false


func _ready() -> void:
	z_index = CAPA_Z
	var textura := textura_hoja()
	for _i in CANTIDAD:
		var hoja := Sprite2D.new()
		hoja.texture = textura
		hoja.centered = true
		add_child(hoja)
		_hojas.append(hoja)


func _exit_tree() -> void:
	# Si el mapa se libera a medias, quien espera el efecto no se queda colgado.
	if not _acabado:
		_acabado = true
		terminado.emit()


func _process(delta: float) -> void:
	_acumulado += delta
	while _acumulado >= SEGUNDOS_POR_FOTOGRAMA and not _acabado:
		_acumulado -= SEGUNDOS_POR_FOTOGRAMA
		avanzar_fotograma()


## Un fotograma de 1/60 s. El 0 deja las hojas en el origen (Callback1); del 1 al
## 29 se mueven y en el 30 acaba.
func avanzar_fotograma() -> void:
	if _acabado:
		return
	_fotograma += 1
	if _fotograma >= FOTOGRAMA_FINAL:
		_acabado = true
		# DestroySprite de las 8 hojas y FieldEffectStop; después se libera al jugador.
		queue_free()
		terminado.emit()
		return
	for i in _hojas.size():
		_hojas[i].position = Vector2(posicion_hoja(i, _fotograma - 1))


func fotograma_actual() -> int:
	return _fotograma


func ha_terminado() -> bool:
	return _acabado


# ──────────────────────────────────────────────────────────────────────────────
# REGLAS (puras)
# ──────────────────────────────────────────────────────────────────────────────

## Radio de las hojas en el `paso`-ésimo fotograma de movimiento (0 a 28), antes
## de actualizarlo: 8, 9, 10, 11, 12, 14, 16, 18, 20, 23...
static func radio_en(paso: int) -> int:
	var radio := RADIO_INICIAL
	for k in paso:
		radio += (k >> 2) + 1
	return radio


## gSineTable[índice]: 256 * sin(índice * (π / 128)) truncado hacia cero (Q8.8).
static func seno_q8(indice: int) -> int:
	return int(256.0 * sin(TAU * float(indice & 0xFF) / 256.0))


## Sin(ángulo, radio) y Cos(ángulo, radio) de trig.c: (amplitud * tabla) >> 8.
static func desplazamiento(angulo: int, radio: int) -> Vector2i:
	var x := (radio * seno_q8(angulo)) >> 8
	var y := (radio * seno_q8(angulo + 64)) >> 8
	return Vector2i(x, y)


## Desplazamiento de la hoja `indice` en el fotograma de movimiento `paso`.
static func posicion_hoja(indice: int, paso: int) -> Vector2i:
	var angulo := (SEPARACION_ANGULAR * indice + GIRO_POR_FOTOGRAMA * paso) & 0xFF
	return desplazamiento(angulo, radio_en(paso))


## Textura 8x8 de la hoja, la misma para todas.
static func textura_hoja() -> ImageTexture:
	if _textura != null:
		return _textura
	# Paleta 06 de los efectos de campo de pokeruby (06.pal): índices 1 a 3.
	var paleta: Array[Color] = [
		Color(0, 0, 0, 0),
		Color.from_rgba8(180, 255, 82),
		Color.from_rgba8(98, 205, 8),
		Color.from_rgba8(41, 115, 0),
	]
	var imagen := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			imagen.set_pixel(x, y, paleta[int(PIXELES[y][x])])
	_textura = ImageTexture.create_from_image(imagen)
	return _textura
