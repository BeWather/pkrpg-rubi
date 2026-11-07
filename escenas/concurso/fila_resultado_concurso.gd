class_name FilaResultadoConcurso
extends Node2D
## Una fila de la pantalla de resultados (src/contest_link_util.c), 24 px de alto desde
## la fila de tiles 4 + 3 × concursante:
## - icono del Pokémon en la columna 3 (sub_80C3024: 32×24, sin la primera fila de tiles);
## - mote y «/ENTRENADOR» en la columna 7 (sub_80C226C);
## - número de puesto 2×2 en la columna 1, fila +1 (sub_80C3A5C);
## - 10 marcas por ronda desde la columna 19, filas +1 y +2 (sub_80C40D4);
## - barra de 88 px (11 tiles) en la columna 7, fila +2 (sub_80C42C0).

const TEXTURA_BARRA: Texture2D = preload("res://graficos/concurso/resultados_barra.png")
const TEXTURA_MARCAS: Texture2D = preload("res://graficos/concurso/resultados_marcas.png")
const RUTA_ICONOS: String = "res://graficos/Icons/icon%03d.png"
const MARCAS_POR_RONDA: int = 10
const ANCHO_BARRA: int = 88
## Fotogramas de resultados_marcas.png.
const MARCA_R1_VACIA: int = 0
const MARCA_R1_LLENA: int = 1
const MARCA_R2_VACIA: int = 3
const MARCA_R2_POSITIVA: int = 4
const MARCA_R2_NEGATIVA: int = 6

var escala_tiempo: float = 1.0
## Ancho de la barra (eContestLink80C2020Struct2018000.unk_0c[i]).
var ancho_barra: int = 0
## Marcas encendidas por ronda (las de la ronda 2 negativas si `ronda2_negativa`).
var marcas_ronda1: int = 0
var marcas_ronda2: int = 0
var ronda2_negativa: bool = false
## Segmentos de cada ronda (sub_80C3990 / sub_80C39E4): las marcas encendidas son las
## últimas `marcas_rondaN` de las `segmentos_rondaN` primeras columnas.
var segmentos_ronda1: int = 0
var segmentos_ronda2: int = 0
var puesto: int = -1
var animando_barra: bool = false

var _icono_frame: int = 0
var _tween_ganador: Tween

@onready var _icono: Sprite2D = $Icono
@onready var _mote: Label = $Mote
@onready var _entrenador: Label = $Entrenador
@onready var _puesto: Sprite2D = $Puesto
@onready var _marcas: Node2D = $Marcas
@onready var _barra: Node2D = $Barra
@onready var _resalte: ColorRect = $Resalte


func _ready() -> void:
	_marcas.draw.connect(_dibujar_marcas)
	_barra.draw.connect(_dibujar_barra)
	_puesto.visible = false
	_resalte.color.a = 0.0


func configurar(c: ConcursanteConcurso, numero_nacional: int) -> void:
	_mote.text = c.mote
	_entrenador.text = "/" + c.entrenador
	var ruta: String = RUTA_ICONOS % numero_nacional
	if numero_nacional > 0 and ResourceLoader.exists(ruta):
		_icono.texture = load(ruta)
	_fijar_fotograma_icono(0)


func _fijar_fotograma_icono(fotograma: int) -> void:
	_icono_frame = fotograma
	_icono.region_rect = Rect2(fotograma * 32, 8, 32, 24)


## Una marca más de la ronda 1 (se encienden de derecha a izquierda).
func encender_marca_ronda1() -> void:
	marcas_ronda1 += 1
	_marcas.queue_redraw()


func encender_marca_ronda2(negativa: bool) -> void:
	marcas_ronda2 += 1
	ronda2_negativa = negativa
	_marcas.queue_redraw()


## sub_80C42C0: la barra avanza 1 px por frame hacia `destino` (0..88).
func animar_barra(destino: int) -> void:
	destino = clampi(destino, 0, ANCHO_BARRA)
	animando_barra = true
	while ancho_barra != destino:
		ancho_barra += 1 if destino > ancho_barra else -1
		_barra.queue_redraw()
		await TiempoConcurso.esperar(self, 1.0, escala_tiempo)
	animando_barra = false


func mostrar_puesto(nuevo: int) -> void:
	puesto = nuevo
	_puesto.frame = clampi(nuevo, 0, 3)
	_puesto.visible = true


## sub_80C3B30/sub_80C3BD8 (la fila del ganador destella) y sub_80C3E60 (el icono
## alterna sus dos fotogramas cada 14 frames).
func resaltar_ganador() -> void:
	if _tween_ganador != null:
		_tween_ganador.kill()
	_tween_ganador = create_tween().set_loops()
	_tween_ganador.tween_property(_resalte, "color:a", 0.45, 0.5)
	_tween_ganador.tween_property(_resalte, "color:a", 0.0, 0.5)
	_animar_icono()


func _animar_icono() -> void:
	while is_inside_tree() and _tween_ganador != null and _tween_ganador.is_valid():
		await TiempoConcurso.esperar(self, 14.0, maxf(escala_tiempo, 1.0))
		if not is_inside_tree():
			return
		_fijar_fotograma_icono(_icono_frame ^ 1)


func _dibujar_marcas() -> void:
	for k in MARCAS_POR_RONDA:
		var x: float = k * 8.0
		# Paso n: columna 19 + segmentos − 1 − n (se encienden de derecha a izquierda).
		var r1: int = MARCA_R1_LLENA if _encendida(k, segmentos_ronda1, marcas_ronda1) else MARCA_R1_VACIA
		var r2: int = MARCA_R2_VACIA
		if _encendida(k, segmentos_ronda2, marcas_ronda2):
			r2 = MARCA_R2_NEGATIVA if ronda2_negativa else MARCA_R2_POSITIVA
		_marcas.draw_texture_rect_region(TEXTURA_MARCAS, Rect2(x, 0, 8, 8), Rect2(r1 * 8, 0, 8, 8))
		_marcas.draw_texture_rect_region(TEXTURA_MARCAS, Rect2(x, 8, 8, 8), Rect2(r2 * 8, 0, 8, 8))


static func _encendida(columna: int, segmentos: int, encendidas: int) -> bool:
	return columna < segmentos and columna >= segmentos - encendidas


func _dibujar_barra() -> void:
	for i in ANCHO_BARRA / 8:
		var relleno: int = clampi(ancho_barra - i * 8, 0, 8)
		if relleno == 0:
			continue
		_barra.draw_texture_rect_region(TEXTURA_BARRA, Rect2(i * 8, 0, 8, 8), Rect2(relleno * 8, 0, 8, 8))
