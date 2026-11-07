class_name EfectoNieblaOverworld
extends EfectoClimaBase

## Niebla horizontal (WEATHER_FOG_HORIZONTAL de pokeruby): trama de
## `niebla_buceo.png` (64×64, opaca, en grises) repetida en los dos ejes y anclada
## al mundo. Deriva horizontalmente en valores enteros de píxel.
##
## Mezcla de hardware del GBA con el shader `nube_clima` (el mismo de las nubes):
## min(1, niebla·EVA + fondo·EVB) leyendo lo ya dibujado. La niebla del GBA usa
## BLDALPHA EVA 12 / EVB 8 (Fog1_Main de pokeruby). El fundido de
## entrada y salida lo gestiona el controlador con `factor_mezcla`.
##
## Fog1_Main desplaza la trama 1 px hacia la izquierda cada cuatro frames.

const TEXTURA: Texture2D = preload("res://graficos/climas/niebla_buceo.png")
const SHADER_MEZCLA: Shader = preload("res://UI/shaders/nube_clima.gdshader")
const LADO := 64.0
const TAMANO_REFERENCIA := ConstantesGba.RESOLUCION_LOGICA
const FRAMES_POR_SEGUNDO: float = ConstantesGba.FPS

## Peso de la niebla en la mezcla (EVA del GBA / 16).
@export_range(0.0, 1.0, 0.0625) var eva: float = 12.0 / 16.0:
	set(valor):
		eva = valor
		_actualizar_material()
## Peso del fondo en la mezcla (EVB del GBA / 16).
@export_range(0.0, 1.0, 0.0625) var evb: float = 8.0 / 16.0:
	set(valor):
		evb = valor
		_actualizar_material()
## Frames del GBA (60 fps) que tarda la niebla en derivar 1 px a la izquierda.
@export_range(1, 60, 1) var frames_por_pixel: int = 4

var _frames: float = 0.0
var _material_mezcla: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	_actualizar_material()
	set_process(true)


func _process(delta: float) -> void:
	_avanzar(maxf(0.0, delta) * FRAMES_POR_SEGUNDO)


## Avanza un número exacto de frames del GBA (tests y depuración).
func avanzar_frames(frames: int) -> void:
	_avanzar(float(maxi(frames, 0)))


func _avanzar(frames: float) -> void:
	_frames += frames
	# Acotado: la trama se repite cada LADO píxeles.
	var frames_periodo: float = LADO * float(frames_por_pixel)
	if _frames >= frames_periodo:
		_frames = fmod(_frames, frames_periodo)
	# La cámara también mueve la trama, así que se redibuja siempre.
	queue_redraw()


## Píxeles derivados hacia la izquierda (entero, sin interpolar), módulo LADO.
func obtener_deriva() -> int:
	return floori(_frames / float(frames_por_pixel))


func _actualizar_material() -> void:
	if _material_mezcla == null:
		_material_mezcla = ShaderMaterial.new()
		_material_mezcla.shader = SHADER_MEZCLA
	_material_mezcla.set_shader_parameter(&"eva", eva)
	_material_mezcla.set_shader_parameter(&"evb", evb)
	if material != _material_mezcla:
		material = _material_mezcla
	queue_redraw()


func _draw() -> void:
	if not debe_dibujar():
		return
	var escala := Vector2(size.x / TAMANO_REFERENCIA.x, size.y / TAMANO_REFERENCIA.y)
	draw_set_transform(Vector2.ZERO, 0.0, escala)
	var modulacion := Color(1.0, 1.0, 1.0, factor_mezcla * intensidad)
	var origen := calcular_origen_trama(obtener_posicion_camara(), obtener_deriva())
	for posicion: Vector2 in obtener_teselas_visibles(origen):
		draw_texture_rect(TEXTURA, Rect2(posicion, Vector2(LADO, LADO)), false, modulacion)


func debe_dibujar() -> bool:
	return factor_mezcla > 0.0 and intensidad > 0.0 and size.x > 0.0 and size.y > 0.0


## Origen en pantalla (0..64) de la trama para la cámara `cam` (esquina superior
## izquierda visible, en coordenadas de mundo) y la deriva acumulada.
func calcular_origen_trama(cam: Vector2, deriva: int) -> Vector2:
	return Vector2(fposmod(-cam.x - float(deriva), LADO), fposmod(-cam.y, LADO))


## Posiciones (en el lienzo lógico de 240×160) de las teselas que cubren el área
## visible empezando una tesela antes del origen.
func obtener_teselas_visibles(origen: Vector2) -> Array[Vector2]:
	return TramaClima.obtener_teselas(origen, LADO, TAMANO_REFERENCIA)
