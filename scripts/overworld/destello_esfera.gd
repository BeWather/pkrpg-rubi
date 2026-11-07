## destello_esfera.gd
## Destello de la ESFERA al despertar a un legendario (pokeruby field_screen_effect.c: special sub_80818A4 y
## sub_80818FC, tarea sub_80816A8). Lo usan EventoCavernaAbisal y EventoCuevaAncestral.
##
## - lanzar(): con VAR_RESULT el color (0 y 2: rojo 0x001F; 1 y 3: azul 0x7C00, el de MAGNO con la ESFERA AZUL en Rubí) y
##   el centro de la pantalla de GBA ((104,80) con 0 y 1: la casilla a la izquierda del jugador; (120,80) con 2 y 3: el
##   jugador); aquí la cámara no centra igual, así que el evento pasa ese centro ya en píxeles de pantalla. Un círculo de ese color mezclado con la escena (REG_BLDALPHA = 0x070C:
##   eva 12/16, evb 7/16) crece de radio 1 a 160 a 2 px por fotograma (sub_8081534). `expandido` al llegar (el
##   ScriptContext_Enable que espera el `waitstate` del guion).
## - Después la cámara oscila ±4 px en vertical cada 4 fotogramas (SetCameraPanning, caso 4 de la tarea).
## - terminar() (sub_80818FC): deja de oscilar y cada 8 fotogramas baja eva o sube evb, alternando, hasta eva 0 y
##   evb 16 (sub_8081658); entonces se libera.
## Coordenadas de GBA multiplicadas por ESCALA (viewport 720x480 = 240x160 × 3).
extends CanvasLayer
class_name DestelloEsfera

const SHADER := preload("res://scripts/overworld/destello_esfera.gdshader")
const COLOR_ROJO := Color(1.0, 0.0, 0.0)  # BGR555 0x001F
const COLOR_AZUL := Color(0.0, 0.0, 1.0)  # BGR555 0x7C00
const ESCALA: float = 3.0
const CENTRO_GBA := Vector2(104, 80)
const RADIO_INICIAL: int = 1
const RADIO_FINAL: int = 160
const PASO_RADIO: int = 2
const EVA_INICIAL: int = 12
const EVB_INICIAL: int = 7
const FOTOGRAMAS_OSCILACION: int = 4
const AMPLITUD_OSCILACION: float = 4.0
const FOTOGRAMAS_DESVANECIMIENTO: int = 8
const FOTOGRAMA: float = 1.0 / 60.0

signal expandido
signal terminado

var radio: int = RADIO_INICIAL
var eva: int = EVA_INICIAL
var evb: int = EVB_INICIAL
## false: ni círculo animado ni esperas (tests): queda expandido y termina al instante.
var animado: bool = true

var _material: ShaderMaterial
var _camara: Camera2D = null
var _offset_camara: Vector2 = Vector2.ZERO
var _oscilando: bool = false
var _oscilacion_arriba: bool = false


## special sub_80818A4. `camara`: la que oscila mientras dura (puede ser null). `centro`: en píxeles del viewport; el
## círculo se queda fijo en pantalla aunque la cámara oscile.
static func lanzar(padre: Node, azul: bool, camara: Camera2D = null, con_animacion: bool = true, centro: Vector2 = CENTRO_GBA * ESCALA) -> DestelloEsfera:
	var destello := DestelloEsfera.new()
	destello.animado = con_animacion
	destello.layer = 5
	padre.add_child(destello)
	destello._preparar(COLOR_AZUL if azul else COLOR_ROJO, camara, centro)
	destello._expandir()
	return destello


func _preparar(color: Color, camara: Camera2D, centro: Vector2) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("color_esfera", color)
	_material.set_shader_parameter("centro", centro)
	rect.material = _material
	add_child(rect)
	_camara = camara
	if _camara != null:
		_offset_camara = _camara.offset
	_actualizar_material()


func obtener_centro() -> Vector2:
	return _material.get_shader_parameter("centro")


func _actualizar_material() -> void:
	_material.set_shader_parameter("radio", radio * ESCALA)
	_material.set_shader_parameter("eva", eva / 16.0)
	_material.set_shader_parameter("evb", evb / 16.0)


func _expandir() -> void:
	while radio < RADIO_FINAL:
		radio = mini(radio + PASO_RADIO, RADIO_FINAL)
		_actualizar_material()
		if animado:
			await get_tree().create_timer(FOTOGRAMA).timeout
	# Antes del aviso: terminar() puede estar esperándolo y parar la oscilación en el acto.
	_oscilando = animado
	expandido.emit()
	while _oscilando:
		_oscilacion_arriba = not _oscilacion_arriba
		if _camara != null:
			_camara.offset = _offset_camara + Vector2(0, -AMPLITUD_OSCILACION if _oscilacion_arriba else AMPLITUD_OSCILACION)
		await get_tree().create_timer(FOTOGRAMAS_OSCILACION * FOTOGRAMA).timeout


func esta_expandido() -> bool:
	return radio >= RADIO_FINAL


## special sub_80818FC + waitstate: deja de oscilar, se desvanece y se libera.
func terminar() -> void:
	if not esta_expandido():
		await expandido
	_oscilando = false
	if _camara != null:
		_camara.offset = _offset_camara
	var baja_eva := false
	while eva > 0 or evb < 16:
		if animado:
			await get_tree().create_timer(FOTOGRAMAS_DESVANECIMIENTO * FOTOGRAMA).timeout
		baja_eva = not baja_eva
		if baja_eva:
			eva = maxi(eva - 1, 0)
		else:
			evb = mini(evb + 1, 16)
		_actualizar_material()
	terminado.emit()
	queue_free()
