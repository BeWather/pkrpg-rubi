class_name CajaConcursante
extends Node2D
## Caja de un concursante en la columna derecha de la pantalla de concurso (BG2 de
## pokeruby, 96×40 en (144, posición × 40)). Las posiciones internas salen de
## src/contest_2.c:
## - mote en x = 5 y «/ENTRENADOR» en la columna 25 (PrintContestant*NameWithColor);
## - estrellas de condición en la columna 19, filas 2-4 (DrawConditionStars);
## - icono de estado 2×2 en la columna 20, fila 2 (DrawStatusSymbol);
## - corazones de la apelación desde la columna 22, 8 por fila y hasta 16
##   (Task_UpdateAppealHearts, uno cada 15 frames);
## - corazón deslizante centrado en (36 + desplazamiento, 36), desplazamiento =
##   puntos / 10 × 2 hasta 56, 1 px por frame (sub_80AFE78);
## - indicador «siguiente turno» de 64×8 en (34, 32) con el número en los tiles 5-6
##   (CreateNextTurnSprites, ShowHideNextTurnGfx).

const TEXTURA_RIVAL: Texture2D = preload("res://graficos/concurso/caja_rival.png")
const TEXTURA_JUGADOR: Texture2D = preload("res://graficos/concurso/caja_jugador.png")
const TEXTURA_CORAZONES: Texture2D = preload("res://graficos/concurso/corazones.png")
## Fotogramas de iconos_estado.png (EventoConcurso.Icono más el de sobresaltado).
const ICONO_SOBRESALTADO: int = 3
const MAX_CORAZONES: int = 16
const CORAZONES_POR_FILA: int = 8
const FRAMES_POR_CORAZON: float = 15.0
const DESLIZADOR_MAXIMO: int = 56
const X_DESLIZADOR: float = 36.0

## Escala de las esperas (TiempoConcurso); la fija la escena.
var escala_tiempo: float = 1.0
var es_jugador: bool = false
## Corazones a la vista: positivos de atractivo, negativos de interferencia.
var corazones: int = 0:
	set(valor):
		corazones = clampi(valor, -MAX_CORAZONES, MAX_CORAZONES)
		if is_node_ready():
			_corazones.queue_redraw()
var estrellas: int = 0
var icono: int = EventoConcurso.Icono.NINGUNO
var desplazamiento_deslizador: int = 0
var tiene_atencion: bool = false
## sliderUpdating: el corazón deslizante aún se está moviendo.
var deslizando: bool = false

var _tween_atencion: Tween

@onready var _fondo: Sprite2D = $Fondo
@onready var _brillo: Sprite2D = $Fondo/Brillo
@onready var _mote: Label = $Mote
@onready var _entrenador: Label = $Entrenador
@onready var _estrellas: Array[Sprite2D] = [$Estrella1, $Estrella2, $Estrella3]
@onready var _icono: Sprite2D = $Icono
@onready var _corazones: Node2D = $Corazones
@onready var _deslizador: Sprite2D = $Deslizador
@onready var _siguiente_turno: Sprite2D = $SiguienteTurno
@onready var _numero_turno: Sprite2D = $SiguienteTurno/Numero
@onready var _turno_aleatorio: Sprite2D = $SiguienteTurno/Aleatorio


func _ready() -> void:
	_corazones.draw.connect(_dibujar_corazones)
	reiniciar()


## Datos fijos del concursante: color de la caja y nombres.
func configurar(concursante: ConcursanteConcurso) -> void:
	es_jugador = concursante.es_jugador
	_fondo.texture = TEXTURA_JUGADOR if es_jugador else TEXTURA_RIVAL
	_brillo.texture = _fondo.texture
	_mote.text = concursante.mote
	_entrenador.text = "/" + concursante.entrenador
	_corazones.queue_redraw()


## Estado visual al empezar el concurso.
func reiniciar() -> void:
	corazones = 0
	fijar_estrellas(0)
	fijar_icono(EventoConcurso.Icono.NINGUNO)
	mostrar_siguiente_turno(0, 0)
	fijar_atencion(false)
	desplazamiento_deslizador = 0
	_deslizador.position.x = X_DESLIZADOR


static func corazones_de(puntos: int) -> int:
	# GetNumHeartsFromAppealPoints: división truncada y tope ±16.
	return clampi(int(puntos / 10.0), -MAX_CORAZONES, MAX_CORAZONES)


## UpdateAppealHearts: de `desde` a `desde + delta` puntos, un corazón cada 15 frames.
func animar_corazones(desde: int, delta: int) -> void:
	corazones = corazones_de(desde)
	var destino: int = corazones_de(desde + delta)
	while corazones != destino:
		await TiempoConcurso.esperar(self, FRAMES_POR_CORAZON, escala_tiempo)
		var paso: int = 1 if destino > corazones else -1
		corazones += paso
		if delta > 0:
			# SE_CONTEST_HEART sube un semitono por corazón.
			TiempoConcurso.sonar(self, "SE_CONTEST_HEART", pow(2.0, (absi(corazones) - 1) / 12.0))
	await TiempoConcurso.esperar(self, FRAMES_POR_CORAZON, escala_tiempo)


## DrawConditionStars: condición / 10 estrellas (0-3).
func fijar_estrellas(condicion: int) -> void:
	estrellas = clampi(condicion / 10, 0, _estrellas.size())
	for k in _estrellas.size():
		_estrellas[k].visible = k < estrellas


## DrawStatusSymbol (o el de sobresaltado de DrawUnnervedSymbols).
func fijar_icono(nuevo: int) -> void:
	icono = nuevo
	_icono.visible = nuevo >= 0
	if nuevo >= 0:
		_icono.frame = nuevo


## ShowHideNextTurnGfx: `modo` = turnOrderMod (0 oculto, 1 número, 2 «?»).
func mostrar_siguiente_turno(modo: int, orden: int) -> void:
	_siguiente_turno.visible = modo != 0
	_numero_turno.visible = modo == 1
	_turno_aleatorio.visible = modo == 2
	if modo == 1:
		_numero_turno.frame = clampi(orden, 0, 3)


## Ojo de atención del juez: la caja late mientras el concursante la tiene
## (sub_80B0458 mezcla la paleta de la caja con RGB(31, 31, 18)).
func fijar_atencion(activa: bool) -> void:
	if activa == tiene_atencion and (_tween_atencion != null) == activa:
		return
	tiene_atencion = activa
	if _tween_atencion != null:
		_tween_atencion.kill()
		_tween_atencion = null
	_brillo.modulate.a = 0.0
	if activa:
		_tween_atencion = create_tween().set_loops()
		_tween_atencion.tween_property(_brillo, "modulate:a", 0.6, 0.5)
		_tween_atencion.tween_property(_brillo, "modulate:a", 0.0, 0.5)


## Parpadeo de la caja al empezar el turno del concursante (contest_2.c:2781-2875).
func parpadear() -> void:
	for _vez in 2:
		_brillo.modulate.a = 0.8
		await TiempoConcurso.esperar(self, 8.0, escala_tiempo)
		_brillo.modulate.a = 0.0
		await TiempoConcurso.esperar(self, 8.0, escala_tiempo)
	if tiene_atencion:
		_tween_atencion = null
		tiene_atencion = false
		fijar_atencion(true)


## sub_80AFE78: lleva el corazón deslizante a puntos / 10 × 2 (0..56), 1 px por frame.
func mover_deslizador(puntos_totales: int) -> void:
	var destino: int = clampi(int(puntos_totales / 10.0) * 2, 0, DESLIZADOR_MAXIMO)
	deslizando = true
	while desplazamiento_deslizador != destino:
		desplazamiento_deslizador += 1 if destino > desplazamiento_deslizador else -1
		_deslizador.position.x = X_DESLIZADOR + desplazamiento_deslizador
		await TiempoConcurso.esperar(self, 1.0, escala_tiempo)
	deslizando = false


## Coloca el corazón deslizante sin animación (cajas redibujadas entre apelaciones).
func fijar_deslizador(puntos_totales: int) -> void:
	desplazamiento_deslizador = clampi(int(puntos_totales / 10.0) * 2, 0, DESLIZADOR_MAXIMO)
	_deslizador.position.x = X_DESLIZADOR + desplazamiento_deslizador


func _dibujar_corazones() -> void:
	var x_textura: int = 16 if es_jugador else 0
	if corazones < 0:
		x_textura += 8
	for k in absi(corazones):
		var origen := Vector2((k % CORAZONES_POR_FILA) * 8, (k / CORAZONES_POR_FILA) * 8)
		_corazones.draw_texture_rect_region(TEXTURA_CORAZONES, Rect2(origen, Vector2(8, 8)),
			Rect2(x_textura, 0, 8, 8))
