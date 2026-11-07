class_name EfectoBurbujasOverworld
extends EfectoClimaBase

## Burbujas submarinas (WEATHER_BUBBLES de pokeruby, field_weather_effects.c:
## Bubbles_InitVars / Bubbles_Main / Bubbles_Finish, sub_8080588 y unc_0807DAB4).
## Se compone de dos capas sobre una pantalla lógica de 240×160 escalada al área
## visible y simulada en frames del GBA (60 fps):
##
## - Una capa Fog1 (`Niebla`, la escena `niebla.tscn` reutilizada): la trama
##   `niebla_buceo.png` (= graphics/weather/fog1.png) anclada al mundo que deriva
##   1 px a la izquierda cada 4 frames. En WEATHER_BUBBLES Fog1_Main fija
##   Weather_SetTargetBlendCoeffs(4, 16, 0): EVA 4/16 y EVB 16/16, que la escena
##   declara como overrides de `eva`/`evb`. Se dibuja detrás de este nodo
##   (show_behind_parent) porque sus sprites tienen prioridad 2 y las burbujas 1.
## - Las burbujas (bubble.png, 8×16 = 2 frames de 8×8, paleta del tag 0x1200),
##   que dibuja este nodo. Cada frame avanza un contador; cuando supera
##   INTERVALOS_APARICION[idx] aparece una burbuja en POSICIONES_APARICION[pos]
##   y los dos índices avanzan cíclicamente.
##
## Anclaje (coordOffsetEnabled = TRUE): en el GBA la pantalla de un sprite es
## pos1 + pos2 + centerToCornerVec + gSpriteCoordOffset, y gSpriteCoordOffset es
## la cámara cambiada de signo. sub_8080588 resta gSpriteCoordOffsetY a la y, así
## que la burbuja nace a la altura de pantalla de la tabla y desde ahí queda
## anclada al mundo; la x no se compensa, así que la tabla es una posición de
## mundo que se repite cada 512 px (la x del OAM tiene 9 bits). Al cargar el
## mapa gTotalCameraPixelOffset vale 0 (overworld.c), así que la tabla son
## posiciones de pantalla respecto a la cámara de ese momento: aquí
## gSpriteCoordOffset = -(cámara - cámara al empezar el clima), con la cámara
## como esquina superior izquierda visible en píxeles de mundo (= píxeles GBA).
## La y del OAM tiene 8 bits: una burbuja que sale por arriba reaparece por
## abajo, igual que en el GBA.

const TEXTURA: Texture2D = preload("res://graficos/climas/burbuja.png")
const TAMANO_REFERENCIA := ConstantesGba.RESOLUCION_LOGICA
const FRAMES_POR_SEGUNDO: float = ConstantesGba.FPS
## Máximo de frames simulados en un solo _process (evita espirales tras un tirón).
const MAX_FRAMES_POR_PROCESO := 8

## gUnknown_0839AC68: frames entre apariciones (el contador debe superarlos).
const INTERVALOS_APARICION: Array[int] = [40, 90, 60, 90, 2, 60, 40, 30]
## gUnknown_0839AC78: centro de cada burbuja al nacer, en coordenadas GBA.
const POSICIONES_APARICION: Array[Vector2i] = [
	Vector2i(120, 160), Vector2i(376, 160),
	Vector2i(40, 140), Vector2i(296, 140),
	Vector2i(180, 130), Vector2i(436, 130),
	Vector2i(60, 160), Vector2i(436, 160),
	Vector2i(220, 180), Vector2i(476, 180),
	Vector2i(10, 90), Vector2i(266, 90),
	Vector2i(256, 160),
]
const LADO_BURBUJA := 8
## centerToCornerVec de un sprite de 8×8.
const CENTRO_A_ESQUINA := Vector2i(-4, -4)
## unc_0807DAB4: pos1.y -= 3 por frame.
const SUBIDA_POR_FRAME := 3
## Se destruye cuando data[2] supera 0x77, es decir, en su actualización 120.
const VIDA_FRAMES := 120
## gSpriteAnim_839ACAC: frame 0 durante 16 frames, luego frame 1 hasta el final.
const FRAMES_PRIMER_CUADRO := 16
## Rango del contador del vaivén (data[0] > 8) y amplitud (pos2.x > 4 invierte).
const LIMITE_CONTADOR_VAIVEN := 8
const MAXIMO_VAIVEN := 4
## Periodo de la x (9 bits) y de la y (8 bits) del OAM.
const PERIODO_OAM := Vector2i(512, 256)
## Bubbles_InitAll repite Bubbles_Main hasta weatherGfxLoaded: 1 llamada para
## crear la niebla y 7 de Weather_UpdateBlend hasta pasar EVA de 0 a 4 (sube en
## las actualizaciones impares, sin retardo). Durante ese bucle no corren los
## callbacks de los sprites.
const FRAMES_INICIALIZACION := 8


class Burbuja extends RefCounted:
	## pos1 del sprite (centro, con gSpriteCoordOffset ya descontado: mundo).
	var posicion: Vector2i = Vector2i.ZERO
	## pos2.x: vaivén horizontal.
	var vaiven: int = 0
	## data[0]: contador del vaivén (se incrementa dos veces por frame).
	var contador_vaiven: int = 0
	## data[1]: 0 = el vaivén crece, 1 = decrece.
	var vaiven_decrece: bool = false
	## data[2]: actualizaciones recibidas (también los pasos de la animación).
	var edad: int = 0
	var viva: bool = true

	## Frame de bubble.png que muestra ahora.
	func obtener_frame() -> int:
		return 0 if edad <= FRAMES_PRIMER_CUADRO else 1


@onready var _niebla: EfectoNieblaOverworld = $Niebla

var _burbujas: Array[Burbuja] = []
## unknown_726 (contador), unknown_728 (índice de intervalo), unknown_72A
## (índice de posición) de Bubbles_InitVars.
var _contador_aparicion: int = INTERVALOS_APARICION[0]
var _indice_intervalo: int = 0
var _indice_posicion: int = 0
var _acumulador_frames: float = 0.0
var _simulacion_iniciada: bool = false
var _saliendo: bool = false
## Cámara al empezar la simulación (gTotalCameraPixelOffset = 0).
var _camara_referencia: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	# La niebla avanza al ritmo de este nodo (frames enteros del GBA).
	_niebla.set_process(false)
	_sincronizar_niebla()
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


func configurar(nueva_intensidad: float, nueva_area_visible: Rect2) -> void:
	super.configurar(nueva_intensidad, nueva_area_visible)
	_sincronizar_niebla()


func actualizar_area_visible(nueva_area_visible: Rect2) -> void:
	super.actualizar_area_visible(nueva_area_visible)
	_sincronizar_niebla()


func set_factor_mezcla(nuevo_factor: float) -> void:
	var previo: float = factor_mezcla
	super.set_factor_mezcla(nuevo_factor)
	if _niebla != null:
		_niebla.set_factor_mezcla(factor_mezcla)
	if not _simulacion_iniciada:
		# Antes del primer frame: factor 1 = aplicar_inmediato (Bubbles_InitAll);
		# factor menor = comienzo de una transición (InitVars y Main frame a frame).
		_saliendo = false
		if factor_mezcla >= 1.0:
			inicializar_todo()
		return
	if factor_mezcla < previo:
		# Bubbles_Finish: ya no corre Bubbles_Main (no nacen burbujas), pero las
		# vivas siguen subiendo hasta que se destruyen con la niebla.
		_saliendo = true
	elif factor_mezcla > previo:
		_saliendo = false


func detener() -> void:
	super.detener()
	if _niebla != null:
		_niebla.detener()


## Bubbles_InitAll: Bubbles_Main sin callbacks de sprites hasta cargar el clima.
func inicializar_todo() -> void:
	if _simulacion_iniciada:
		return
	_iniciar_simulacion()
	var camara: Vector2 = obtener_camara_relativa()
	for _frame: int in range(FRAMES_INICIALIZACION):
		_avanzar_niebla()
		_actualizar_aparicion(camara)


## Simula un frame del GBA: Bubbles_Main (niebla y aparición) en RunTasks y
## después los callbacks de las burbujas en AnimateSprites (también el de una
## burbuja recién creada).
func avanzar_frame() -> void:
	if not _simulacion_iniciada:
		_iniciar_simulacion()
	var camara: Vector2 = obtener_camara_relativa()
	_avanzar_niebla()
	if not _saliendo:
		_actualizar_aparicion(camara)
	for burbuja: Burbuja in _burbujas:
		actualizar_burbuja(burbuja)
	_burbujas = _burbujas.filter(func(b: Burbuja) -> bool: return b.viva)


## Avanza `frames` frames del GBA (tests y depuración).
func avanzar_frames(frames: int) -> void:
	for _frame: int in range(maxi(frames, 0)):
		avanzar_frame()


func obtener_burbujas() -> Array[Burbuja]:
	return _burbujas


func obtener_indice_intervalo() -> int:
	return _indice_intervalo


func obtener_indice_posicion() -> int:
	return _indice_posicion


func obtener_contador_aparicion() -> int:
	return _contador_aparicion


func esta_saliendo() -> bool:
	return _saliendo


func obtener_niebla() -> EfectoNieblaOverworld:
	return _niebla


## -gSpriteCoordOffset: desplazamiento de la cámara desde que empezó el clima.
func obtener_camara_relativa() -> Vector2:
	return obtener_posicion_camara() - _camara_referencia


func _iniciar_simulacion() -> void:
	_simulacion_iniciada = true
	_camara_referencia = obtener_posicion_camara()


## unc_0807DAB4: vaivén de 0 a 5 px (cambia cada 5 frames), sube 3 px por frame
## y muere en su actualización número VIDA_FRAMES.
static func actualizar_burbuja(burbuja: Burbuja) -> void:
	burbuja.contador_vaiven += 2
	if burbuja.contador_vaiven > LIMITE_CONTADOR_VAIVEN:
		burbuja.contador_vaiven = 0
		if not burbuja.vaiven_decrece:
			burbuja.vaiven += 1
			if burbuja.vaiven > MAXIMO_VAIVEN:
				burbuja.vaiven_decrece = true
		else:
			burbuja.vaiven -= 1
			if burbuja.vaiven <= 0:
				burbuja.vaiven_decrece = false
	burbuja.posicion.y -= SUBIDA_POR_FRAME
	burbuja.edad += 1
	if burbuja.edad >= VIDA_FRAMES:
		burbuja.viva = false


## Esquina superior izquierda de la burbuja en la pantalla lógica para la cámara
## relativa `camara` (= -gSpriteCoordOffset), con el ajuste del OAM (x de 9
## bits, y de 8 bits).
static func posicion_en_pantalla(burbuja: Burbuja, camara: Vector2) -> Vector2i:
	var esquina := Vector2i(
		burbuja.posicion.x + burbuja.vaiven + CENTRO_A_ESQUINA.x - roundi(camara.x),
		burbuja.posicion.y + CENTRO_A_ESQUINA.y - roundi(camara.y))
	return Vector2i(_ajustar_oam(esquina.x, PERIODO_OAM.x), _ajustar_oam(esquina.y, PERIODO_OAM.y))


## Coordenada del OAM: se reduce al periodo del registro y, si el sprite cruza
## el borde, se expresa como negativa (se ve recortado por el lado opuesto).
static func _ajustar_oam(valor: int, periodo: int) -> int:
	var resultado: int = posmod(valor, periodo)
	if resultado > periodo - LADO_BURBUJA:
		resultado -= periodo
	return resultado


## Bubbles_Main: el contador avanza y, cuando supera el intervalo vigente, se
## reinicia, el índice de intervalo avanza (0..7) y nace una burbuja en la
## posición vigente, cuyo índice avanza después (0..12).
func _actualizar_aparicion(camara: Vector2) -> void:
	_contador_aparicion += 1
	if _contador_aparicion <= INTERVALOS_APARICION[_indice_intervalo]:
		return
	_contador_aparicion = 0
	_indice_intervalo = (_indice_intervalo + 1) % INTERVALOS_APARICION.size()
	_crear_burbuja(_indice_posicion, camara)
	_indice_posicion = (_indice_posicion + 1) % POSICIONES_APARICION.size()


## sub_8080588: y = tabla - gSpriteCoordOffsetY = tabla + cámara.y; x = tabla.
func _crear_burbuja(indice: int, camara: Vector2) -> void:
	var burbuja := Burbuja.new()
	var origen: Vector2i = POSICIONES_APARICION[indice]
	burbuja.posicion = Vector2i(origen.x, origen.y + roundi(camara.y))
	_burbujas.append(burbuja)


func _avanzar_niebla() -> void:
	if _niebla != null:
		_niebla.posicion_camara_override = posicion_camara_override
		_niebla.avanzar_frames(1)


func _sincronizar_niebla() -> void:
	if _niebla == null:
		return
	_niebla.posicion_camara_override = posicion_camara_override
	_niebla.configurar(intensidad, Rect2(Vector2.ZERO, size))
	_niebla.set_factor_mezcla(factor_mezcla)


func debe_dibujar() -> bool:
	return factor_mezcla > 0.0 and intensidad > 0.0 and size.x > 0.0 and size.y > 0.0


func _draw() -> void:
	if not debe_dibujar():
		return
	var escala := Vector2(size.x / TAMANO_REFERENCIA.x, size.y / TAMANO_REFERENCIA.y)
	draw_set_transform(Vector2.ZERO, 0.0, escala)
	var camara: Vector2 = obtener_camara_relativa()
	var lado := Vector2(LADO_BURBUJA, LADO_BURBUJA)
	for burbuja: Burbuja in _burbujas:
		var esquina := Vector2(posicion_en_pantalla(burbuja, camara))
		if esquina.x >= TAMANO_REFERENCIA.x or esquina.y >= TAMANO_REFERENCIA.y:
			continue
		var region := Rect2(0.0, float(burbuja.obtener_frame() * LADO_BURBUJA), lado.x, lado.y)
		draw_texture_rect_region(TEXTURA, Rect2(esquina, lado), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
