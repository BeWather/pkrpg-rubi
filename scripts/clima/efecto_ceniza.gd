class_name EfectoCenizaOverworld
extends EfectoClimaBase

## Ceniza volcánica (WEATHER_VOLCANIC_ASH de Emerald): trama de `ceniza.png`
## (2 frames de 64×64) repetida en los dos ejes y anclada al mundo. Cae 1 px cada
## 0,1 s y alterna de frame cada segundo, sin interpolación. El fundido de entrada
## y salida lo gestiona el controlador con `factor_mezcla`.

const TEXTURA: Texture2D = preload("res://graficos/climas/ceniza.png")
const LADO := 64.0
const TAMANO_REFERENCIA := ConstantesGba.RESOLUCION_LOGICA
const SEGUNDOS_POR_PIXEL := 0.1
const SEGUNDOS_POR_FRAME := 1.0
const FRAMES := 2

var _tiempo: float = 0.0


func _ready() -> void:
	super._ready()
	set_process(true)


func _process(delta: float) -> void:
	_tiempo += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	if not debe_dibujar():
		return
	var escala := Vector2(size.x / TAMANO_REFERENCIA.x, size.y / TAMANO_REFERENCIA.y)
	draw_set_transform(Vector2.ZERO, 0.0, escala)
	var modulacion := Color(1.0, 1.0, 1.0, factor_mezcla * intensidad)
	var region := Rect2(obtener_frame() * LADO, 0.0, LADO, LADO)
	var origen := calcular_origen_trama(obtener_posicion_camara(), obtener_caida())
	for posicion: Vector2 in obtener_teselas_visibles(origen):
		draw_texture_rect_region(TEXTURA, Rect2(posicion, Vector2(LADO, LADO)), region, modulacion)


func debe_dibujar() -> bool:
	return factor_mezcla > 0.0 and intensidad > 0.0 and size.x > 0.0 and size.y > 0.0


func obtener_frame() -> int:
	return int(floor(_tiempo / SEGUNDOS_POR_FRAME)) % FRAMES


## Píxeles caídos desde que se creó el efecto (entero, sin interpolar).
func obtener_caida() -> int:
	return int(floor(_tiempo / SEGUNDOS_POR_PIXEL))


## Origen en pantalla (0..64) de la trama para la cámara `cam` (esquina superior
## izquierda visible, en coordenadas de mundo) y la caída acumulada.
func calcular_origen_trama(cam: Vector2, caida: int) -> Vector2:
	return Vector2(fposmod(-cam.x, LADO), fposmod(float(caida) - cam.y, LADO))


## Posiciones (en el lienzo lógico de 240×160) de las teselas que cubren el área
## visible empezando una tesela antes del origen.
func obtener_teselas_visibles(origen: Vector2) -> Array[Vector2]:
	return TramaClima.obtener_teselas(origen, LADO, TAMANO_REFERENCIA)
