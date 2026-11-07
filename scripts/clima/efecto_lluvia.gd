class_name EfectoLluviaOverworld
extends EfectoClimaBase

## Lluvia ligera fiel a WEATHER_RAIN_LIGHT de pokeruby (field_weather_effects.c,
## sub_807E4EC / sub_807E5C0 / sub_807E6F0 / sub_807E8E8). Todo se simula en
## frames del GBA (60 fps) sobre una pantalla lógica de 240×160 que se escala al
## área visible.
##
## - Pool fijo de 24 gotas; solo las `max_gotas` primeras llegan a activarse, una
##   cada `frames_por_gota` frames al entrar y una cada `frames_por_gota` al salir.
## - Cada gota cae 18 frames en espacio de PANTALLA hacia su celda de aterrizaje
##   (rejilla de 8 px elegida con el LCG del juego) y luego muestra una salpicadura
##   de 7 frames ANCLADA AL MUNDO (no se mueve con la pantalla si la cámara se
##   desplaza). Ciclo completo: 25 frames.
## - `aplicar_inmediato` del controlador (factor 1 antes del primer frame) activa
##   todas las gotas de golpe, como LightRain_InitAll. Una transición (factor que
##   sube desde 0) las activa de forma progresiva; cuando el factor baja (fundido
##   de salida) se desactivan de forma progresiva hasta 0.

const TEXTURA: Texture2D = preload("res://graficos/climas/lluvia_gota.png")
const TAMANO_REFERENCIA := ConstantesGba.RESOLUCION_LOGICA
const TAMANO_FRAME := Vector2(16.0, 32.0)
const FRAMES_POR_SEGUNDO: float = ConstantesGba.FPS
## Máximo de frames simulados en un solo _process (evita espirales tras un tirón).
const MAX_FRAMES_POR_PROCESO := 8

const TOTAL_GOTAS := 24
## Velocidad de caída en 1/16 de píxel por frame (gUnknown_0839AABC[0]).
const VELOCIDAD_SUBPIXEL := Vector2i(-104, 208)
## gUnknown_0839AAC4[0]: frames de caída y de salpicadura.
const FRAMES_CAIDA := 18
const FRAMES_SALPICADURA := 7
const FRAMES_CICLO := FRAMES_CAIDA + FRAMES_SALPICADURA
const SEMILLA_CERO := 361
const CELDAS_ATERRIZAJE := 600
const COLUMNAS_ATERRIZAJE := 30
const LADO_CELDA_ATERRIZAJE := 8
## Límites de visibilidad durante la caída (centro del sprite, en pantalla lógica):
## x en [-8, 248] e y en [-16, 176], ambos incluidos.
const LIMITE_VISIBLE := Rect2i(-8, -16, 257, 193)

enum EstadoGota {
	ESPERANDO,
	CAYENDO,
	SALPICANDO,
}

class Gota extends RefCounted:
	var semilla: int = 0
	var estado: EstadoGota = EstadoGota.CAYENDO
	## Frames de caída restantes (CAYENDO) o de espera inicial (ESPERANDO).
	var contador: int = 0
	## Posición del centro en 1/16 px de pantalla lógica.
	var posicion_subpixel: Vector2i = Vector2i.ZERO
	## Posición del centro en píxeles de pantalla lógica (a_pixeles(posicion_subpixel)).
	var posicion_pantalla: Vector2i = Vector2i.ZERO
	## Centro de la salpicadura en coordenadas de mundo (fijado al aterrizar).
	var posicion_mundo: Vector2 = Vector2.ZERO
	var frames_salpicadura: int = 0
	var activa: bool = false
	var visible: bool = false


## Gotas que se activan con intensidad 1 (lluvia ligera: 10).
@export_range(0, 24, 1) var max_gotas: int = 10
## Frames entre activaciones/desactivaciones sucesivas (lluvia ligera: 9).
@export_range(1, 60, 1) var frames_por_gota: int = 9

var _gotas: Array[Gota] = []
var _gotas_activas: int = 0
var _contador_activacion: int = 0
var _acumulador_frames: float = 0.0
var _simulacion_iniciada: bool = false
var _saliendo: bool = false


func _init() -> void:
	_inicializar_gotas()


func _ready() -> void:
	super._ready()
	set_process(true)


func _process(delta: float) -> void:
	_acumulador_frames += maxf(0.0, delta) * FRAMES_POR_SEGUNDO
	var pasos: int = 0
	while _acumulador_frames >= 1.0 and pasos < MAX_FRAMES_POR_PROCESO:
		_acumulador_frames -= 1.0
		avanzar_frame()
		pasos += 1
	if _acumulador_frames >= 1.0:
		_acumulador_frames = fmod(_acumulador_frames, 1.0)
	queue_redraw()


func set_factor_mezcla(nuevo_factor: float) -> void:
	var previo: float = factor_mezcla
	super.set_factor_mezcla(nuevo_factor)
	if not _simulacion_iniciada:
		# Antes del primer frame: factor 1 = aplicar_inmediato (todo activo de
		# golpe); factor menor = comienzo de una transición de entrada.
		_saliendo = false
		if factor_mezcla >= 1.0:
			activar_todas_inmediato()
		return
	if factor_mezcla < previo:
		_saliendo = true
	elif factor_mezcla > previo:
		_saliendo = false


## Simula un frame del GBA: activación/desactivación progresiva y movimiento de
## las 24 gotas (también las inactivas, que siguen su ciclo invisibles).
func avanzar_frame() -> void:
	_simulacion_iniciada = true
	_actualizar_activacion()
	var camara: Vector2 = obtener_posicion_camara()
	for gota: Gota in _gotas:
		_avanzar_gota(gota, camara)


## Activa de golpe tantas gotas como pide el objetivo actual (LightRain_InitAll).
func activar_todas_inmediato() -> void:
	var objetivo: int = obtener_objetivo_gotas()
	while _gotas_activas < objetivo:
		_gotas[_gotas_activas].activa = true
		_gotas_activas += 1
	while _gotas_activas > objetivo:
		_desactivar_ultima()
	_contador_activacion = 0


func obtener_objetivo_gotas() -> int:
	if _saliendo or factor_mezcla <= 0.0 or intensidad <= 0.0:
		return 0
	return clampi(roundi(float(max_gotas) * intensidad), 0, TOTAL_GOTAS)


func obtener_gotas_activas() -> int:
	return _gotas_activas


func esta_saliendo() -> bool:
	return _saliendo


func obtener_gota(indice: int) -> Gota:
	return _gotas[indice]


## Número de gotas que se dibujarían ahora mismo.
func contar_gotas_visibles() -> int:
	var total: int = 0
	for gota: Gota in _gotas:
		if gota.visible and gota.estado != EstadoGota.ESPERANDO:
			total += 1
	return total


## Siguiente semilla del LCG de sub_807E4EC (0 se sustituye por 361).
static func siguiente_semilla(semilla: int) -> int:
	var base: int = SEMILLA_CERO if semilla == 0 else semilla
	var aleatorio: int = (base * 1103515245 + 12345) & 0xFFFFFFFF
	return ((aleatorio & 0x7FFF0000) >> 16) % CELDAS_ATERRIZAJE


## Centro de aterrizaje, en píxeles de pantalla lógica, para una semilla.
static func posicion_aterrizaje(semilla: int) -> Vector2i:
	var columna: int = semilla % COLUMNAS_ATERRIZAJE
	var fila: int = floori(float(semilla) / float(COLUMNAS_ATERRIZAJE))
	return Vector2i(columna, fila) * LADO_CELDA_ATERRIZAJE


## `subpixel >> 4` del GBA (desplazamiento aritmético = división por defecto). En
## GDScript `>>` no admite operandos negativos.
static func a_pixeles(subpixel: Vector2i) -> Vector2i:
	return Vector2i(floori(float(subpixel.x) / 16.0), floori(float(subpixel.y) / 16.0))


## Frame del spritesheet (0 = gota; 1..5 = salpicaduras) de una salpicadura que
## lleva `frames` frames mostrándose: frames 1, 4 y 5 durante 3, 2 y 2 frames.
static func frame_salpicadura(frames: int) -> int:
	if frames < 3:
		return 1
	if frames < 5:
		return 4
	return 5


func _draw() -> void:
	if factor_mezcla <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var escala := Vector2(size.x / TAMANO_REFERENCIA.x, size.y / TAMANO_REFERENCIA.y)
	draw_set_transform(Vector2.ZERO, 0.0, escala)
	var camara: Vector2 = obtener_posicion_camara()
	for gota: Gota in _gotas:
		if not gota.visible:
			continue
		var centro: Vector2
		var frame: int
		match gota.estado:
			EstadoGota.CAYENDO:
				centro = Vector2(gota.posicion_pantalla)
				frame = 0
			EstadoGota.SALPICANDO:
				centro = gota.posicion_mundo - camara
				frame = frame_salpicadura(gota.frames_salpicadura)
			_:
				continue
		var destino := Rect2(centro - TAMANO_FRAME * 0.5, TAMANO_FRAME)
		var region := Rect2(0.0, float(frame) * TAMANO_FRAME.y, TAMANO_FRAME.x, TAMANO_FRAME.y)
		draw_texture_rect_region(TEXTURA, destino, region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## CreateRainSprite + sub_807E6F0: semilla `slot*145 % 600`, un ciclo inicial y
## `slot*9 / 25` ciclos más; luego `slot*9 % 25` frames de desfase (en caída) o de
## espera invisible (si caen en la parte de salpicadura).
func _inicializar_gotas() -> void:
	_gotas.clear()
	for indice: int in range(TOTAL_GOTAS):
		var gota := Gota.new()
		gota.semilla = (indice * 145) % CELDAS_ATERRIZAJE
		_reiniciar_ciclo(gota)
		var desfase: int = indice * 9
		var ciclos_extra: int = floori(float(desfase) / float(FRAMES_CICLO))
		var resto: int = desfase % FRAMES_CICLO
		for _ciclo: int in range(ciclos_extra):
			_reiniciar_ciclo(gota)
		if resto < FRAMES_CAIDA:
			for _frame: int in range(resto):
				_mover_gota(gota, Vector2.ZERO)
		else:
			gota.estado = EstadoGota.ESPERANDO
			gota.contador = resto - FRAMES_CAIDA
			gota.visible = false
		_gotas.append(gota)


## sub_807E8E8: una gota más (o menos) cada `frames_por_gota` frames hasta
## alcanzar el objetivo, siempre en orden de slot.
func _actualizar_activacion() -> void:
	var objetivo: int = obtener_objetivo_gotas()
	if _gotas_activas == objetivo:
		return
	_contador_activacion += 1
	if _contador_activacion < frames_por_gota:
		return
	_contador_activacion = 0
	if _gotas_activas < objetivo:
		_gotas[_gotas_activas].activa = true
		_gotas_activas += 1
	else:
		_desactivar_ultima()


func _desactivar_ultima() -> void:
	_gotas_activas -= 1
	var gota: Gota = _gotas[_gotas_activas]
	gota.activa = false
	gota.visible = false


func _avanzar_gota(gota: Gota, camara: Vector2) -> void:
	match gota.estado:
		EstadoGota.ESPERANDO:
			# sub_807E6C4
			if gota.contador == 0:
				_reiniciar_ciclo(gota)
			else:
				gota.contador -= 1
		EstadoGota.CAYENDO:
			_mover_gota(gota, camara)
		EstadoGota.SALPICANDO:
			gota.frames_salpicadura += 1
			if gota.frames_salpicadura >= FRAMES_SALPICADURA:
				gota.visible = false
				_reiniciar_ciclo(gota)


## sub_807E4EC: nueva celda de aterrizaje y posición inicial "rebobinada" 18
## frames de caída. La gota queda invisible hasta su primer movimiento.
func _reiniciar_ciclo(gota: Gota) -> void:
	gota.semilla = siguiente_semilla(gota.semilla)
	var aterrizaje: Vector2i = posicion_aterrizaje(gota.semilla)
	gota.posicion_subpixel = aterrizaje * 16 - VELOCIDAD_SUBPIXEL * FRAMES_CAIDA
	gota.posicion_pantalla = a_pixeles(gota.posicion_subpixel)
	gota.estado = EstadoGota.CAYENDO
	gota.contador = FRAMES_CAIDA
	gota.frames_salpicadura = 0


## sub_807E5C0 (rama de caída). Al agotar la caída la salpicadura se ancla al
## mundo con la cámara de ese instante.
func _mover_gota(gota: Gota, camara: Vector2) -> void:
	gota.posicion_subpixel += VELOCIDAD_SUBPIXEL
	gota.posicion_pantalla = a_pixeles(gota.posicion_subpixel)
	gota.visible = gota.activa and LIMITE_VISIBLE.has_point(gota.posicion_pantalla)
	gota.contador -= 1
	if gota.contador == 0:
		gota.estado = EstadoGota.SALPICANDO
		gota.frames_salpicadura = 0
		gota.posicion_mundo = Vector2(gota.posicion_pantalla) + camara
