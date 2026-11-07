class_name MenuMovimientosConcurso
extends Node2D
## Pantalla de elección de movimiento (Task_ShowMoveSelectScreen /
## Task_HandleMoveSelectInput, src/contest.c). Es la mitad inferior de BG2 desplazada
## 160 px: lista de 4 movimientos a la izquierda (filas 31-37) y, a la derecha, el
## icono de categoría, los corazones de atractivo e interferencia (8 como máximo) y la
## descripción del efecto (PrintContestMoveDescription, contest_2.c:1110-1168).
## Un movimiento que completaría combo se pinta en verde y una repetición en gris.

signal elegido(hueco: int)

const TEXTURA_CATEGORIAS: Texture2D = preload("res://graficos/concurso/categorias_menu.png")
const TEXTURA_CORAZONES: Texture2D = preload("res://graficos/concurso/corazones_menu.png")
## Fotogramas de corazones_menu.png.
const CORAZON_ATRACTIVO_VACIO: int = 0
const CORAZON_ATRACTIVO_LLENO: int = 1
const CORAZON_INTERFERENCIA_LLENO: int = 2
const CORAZON_INTERFERENCIA_VACIO: int = 3
const MAX_CORAZONES: int = 8
const ALTO_FILA: float = 16.0
const COLOR_NORMAL: Color = Color.WHITE
const COLOR_COMBO: Color = Color(0.0, 0.62, 0.25)
const COLOR_REPETIDO: Color = Color(0.58, 0.58, 0.58)

var datos: DatosConcurso
var movimientos: Array[int] = [0, 0, 0, 0]
var hueco: int = 0
var activo: bool = false

@onready var _nombres: Array[Label] = [$Lista/Mov1, $Lista/Mov2, $Lista/Mov3, $Lista/Mov4]
@onready var _cursor: PkSelectorSimple = $Lista/Cursor
@onready var _categoria: Sprite2D = $Categoria
@onready var _corazones_atractivo: Node2D = $CorazonesAtractivo
@onready var _corazones_interferencia: Node2D = $CorazonesInterferencia
@onready var _descripcion: Label = $Descripcion

var _y_primera_fila: float = 0.0


func _ready() -> void:
	_y_primera_fila = _cursor.position.y
	_corazones_atractivo.draw.connect(_dibujar_corazones.bind(_corazones_atractivo, true))
	_corazones_interferencia.draw.connect(_dibujar_corazones.bind(_corazones_interferencia, false))
	visible = false


## Prepara la lista del jugador. `previo` y `atencion` marcan combos y repeticiones.
func abrir(datos_concurso: DatosConcurso, concursante: ConcursanteConcurso) -> void:
	datos = datos_concurso
	movimientos = concursante.movimientos.duplicate()
	for i in _nombres.size():
		var mov: int = movimientos[i]
		_nombres[i].text = datos.nombre_movimiento(mov) if mov != DatosConcurso.MOVIMIENTO_NINGUNO else "-"
		_nombres[i].modulate = _color_movimiento(concursante, mov)
	hueco = clampi(hueco, 0, 3)
	if movimientos[hueco] == DatosConcurso.MOVIMIENTO_NINGUNO:
		hueco = 0
	visible = true
	activo = true
	_actualizar()


func cerrar() -> void:
	activo = false
	visible = false


## Espera la elección del jugador (A sobre un hueco con movimiento).
func elegir(datos_concurso: DatosConcurso, concursante: ConcursanteConcurso) -> int:
	abrir(datos_concurso, concursante)
	var resultado: int = await elegido
	cerrar()
	return resultado


## Contest.c:495-525: verde si completaría combo, gris si repite (salvo los
## movimientos sin aburrimiento).
func _color_movimiento(c: ConcursanteConcurso, mov: int) -> Color:
	if mov == DatosConcurso.MOVIMIENTO_NINGUNO:
		return COLOR_NORMAL
	if c.mov_previo != DatosConcurso.MOVIMIENTO_NINGUNO and c.atencion_juez and c.puede_combo() \
			and datos.son_combo(c.mov_previo, mov) != 0:
		return COLOR_COMBO
	if c.mov_previo == mov and datos.efecto(mov) != EfectosConcurso.Efecto.REPETITION_NOT_BORING:
		return COLOR_REPETIDO
	return COLOR_NORMAL


func mover_cursor(direccion: int) -> void:
	var nuevo: int = hueco
	for _intento in movimientos.size():
		nuevo = posmod(nuevo + direccion, movimientos.size())
		if movimientos[nuevo] != DatosConcurso.MOVIMIENTO_NINGUNO:
			break
	if nuevo != hueco:
		hueco = nuevo
		TiempoConcurso.sonar(self, "SE_SELECT")
		_actualizar()


func aceptar() -> void:
	if not activo or movimientos[hueco] == DatosConcurso.MOVIMIENTO_NINGUNO:
		return
	TiempoConcurso.sonar(self, "SE_SELECT")
	activo = false
	elegido.emit(hueco)


func _unhandled_input(event: InputEvent) -> void:
	if not activo:
		return
	if event.is_action_pressed("btn_arriba"):
		mover_cursor(-1)
	elif event.is_action_pressed("btn_abajo"):
		mover_cursor(1)
	elif event.is_action_pressed("btn_accion"):
		aceptar()
	else:
		return
	get_viewport().set_input_as_handled()


func _actualizar() -> void:
	_cursor.position.y = _y_primera_fila + hueco * ALTO_FILA
	var mov: int = movimientos[hueco]
	_categoria.region_rect = Rect2(0, clampi(datos.categoria(mov), 0, 4) * 16, 40, 16)
	_descripcion.text = datos.descripcion_movimiento(mov)
	_corazones_atractivo.queue_redraw()
	_corazones_interferencia.queue_redraw()


## Corazones llenos de atractivo e interferencia del movimiento bajo el cursor.
func corazones_llenos() -> Vector2i:
	var efecto: int = datos.efecto(movimientos[hueco])
	return Vector2i(_llenos(datos.atractivo_efecto(efecto)), _llenos(datos.interferencia_efecto(efecto)))


static func _llenos(valor: int) -> int:
	return 0 if valor == 0xFF else mini(valor / 10, MAX_CORAZONES)


func _dibujar_corazones(lienzo: Node2D, atractivo: bool) -> void:
	if datos == null:
		return
	var llenos: Vector2i = corazones_llenos()
	var cantidad: int = llenos.x if atractivo else llenos.y
	for i in MAX_CORAZONES:
		var fotograma: int
		if atractivo:
			fotograma = CORAZON_ATRACTIVO_LLENO if i < cantidad else CORAZON_ATRACTIVO_VACIO
		else:
			fotograma = CORAZON_INTERFERENCIA_LLENO if i < cantidad else CORAZON_INTERFERENCIA_VACIO
		lienzo.draw_texture_rect_region(TEXTURA_CORAZONES, Rect2(i * 8, 0, 8, 8), Rect2(fotograma * 8, 0, 8, 8))
