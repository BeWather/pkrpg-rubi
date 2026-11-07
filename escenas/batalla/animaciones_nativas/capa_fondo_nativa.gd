extends Sprite2D
class_name CapaFondoNativa
## Capa de fondo de las animaciones nativas (§22 de documentacion/piloto_animaciones_nativas.md):
## el equivalente de un fondo BG1/BG2/BG3 del original, como una textura importada con parámetros
## legibles y el shader capa_fondo.gdshader. No emula registros: cada propiedad describe lo que se
## ve.
##
## - `desplazamiento`: scroll del contenido (en la posición p de la capa se ve p + desplazamiento
##   de la textura) con repetición; `fotograma` elige una franja de una hoja vertical (`fotogramas`),
##   p. ej. los 11 pasos ya horneados del ciclo de paleta del fondo psíquico.
## - `mezcla_gba` con `eva`/`evb`: mezcla con lo de debajo como REG_BLDALPHA (capa * eva + debajo *
##   evb); si no, `opacidad` normal.
## - ondulación por fila (`onda_*`): lo que el original hace por scanline con HOFS.
## - `fijar_ventana(sprite)`: la capa solo se ve dentro de la silueta del battler (ventana OBJ).
##
## Se usa de dos formas: como plantilla oculta de la escena (nodo con la textura, editable en el
## editor) que EfectoFondoNativo duplica y coloca, o creada por código para copiar un battler
## (monbg) con `repetir = false`.

const SHADER: Shader = preload("res://escenas/batalla/animaciones_nativas/capa_fondo.gdshader")

## Fotogramas de la hoja: franjas verticales de alto `texture.height / fotogramas` (no se usa
## `vframes`, que con `region_enabled` dividiría el rectángulo dibujado).
@export var fotogramas: int = 1:
	set(valor):
		fotogramas = maxi(1, valor)
		_actualizar()
## Fotograma de la hoja que se ve.
@export var fotograma: int = 0:
	set(valor):
		fotograma = valor
		_actualizar()
@export var desplazamiento: Vector2 = Vector2.ZERO:
	set(valor):
		desplazamiento = valor
		_actualizar()
@export var repetir: bool = true:
	set(valor):
		repetir = valor
		_actualizar()
@export var mezcla_gba: bool = false:
	set(valor):
		mezcla_gba = valor
		_actualizar()
@export_range(0.0, 1.0) var eva: float = 1.0:
	set(valor):
		eva = valor
		_actualizar()
@export_range(0.0, 1.0) var evb: float = 0.0:
	set(valor):
		evb = valor
		_actualizar()
@export_range(0.0, 1.0) var opacidad: float = 1.0:
	set(valor):
		opacidad = valor
		_actualizar()
@export var onda_amplitud: float = 0.0:
	set(valor):
		onda_amplitud = valor
		_actualizar()
@export var onda_periodo: float = 32.0:
	set(valor):
		onda_periodo = valor
		_actualizar()
@export var onda_fase: float = 0.0:
	set(valor):
		onda_fase = valor
		_actualizar()
## Mezcla de paleta hacia `tinte_color` (0..1, BlendPalette del original).
@export var tinte_color: Color = Color.BLACK:
	set(valor):
		tinte_color = valor
		_actualizar()
@export_range(0.0, 1.0) var tinte_cantidad: float = 0.0:
	set(valor):
		tinte_cantidad = valor
		_actualizar()
## Píxeles que se suman a la ondulación en el sentido de su signo (vaivén de Paranormal).
@export var onda_extra: float = 0.0:
	set(valor):
		onda_extra = valor
		_actualizar()
## Filas (locales) en las que se aplica la ondulación, ambas incluidas.
@export var onda_filas: Vector2 = Vector2(-100000, 100000):
	set(valor):
		onda_filas = valor
		_actualizar()

var _material: ShaderMaterial
var _ventana: Sprite2D
## Rect del fotograma de la textura (si la capa es la copia de un battler).
var _rect_fuente: Rect2 = Rect2()


## Prepara la capa para dibujarse como un rectángulo de `tamano` píxeles en su posición (el campo
## entero para un fondo). Llamar antes de mostrarla.
func preparar(tamano: Vector2) -> void:
	centered = false
	offset = Vector2.ZERO
	region_enabled = true
	region_rect = Rect2(Vector2.ZERO, tamano)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	_actualizar()


## Copia el fotograma visible de un battler (monbg): la capa se coloca y se transforma como él cada
## frame, sin repetición, con `margen` píxeles libres a cada lado para la ondulación.
func copiar_sprite(sprite: Sprite2D, margen: int = 0) -> void:
	texture = sprite.texture
	flip_h = sprite.flip_h
	_rect_fuente = rect_fuente(sprite)
	preparar(_rect_fuente.size + Vector2(2 * margen, 0))
	repetir = false
	desplazamiento = Vector2(-margen, 0)
	_seguir(sprite, margen)


## Deja de seguir al battler copiado: la copia se queda donde está (instantánea para estelas).
func fijar_en_sitio() -> void:
	_copiado = null


## Solo se ve dentro de la silueta de `sprite` (null la quita).
func fijar_ventana(sprite: Sprite2D) -> void:
	_ventana = sprite
	_actualizar()


func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_antes_de_dibujar)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_antes_de_dibujar):
		RenderingServer.frame_pre_draw.disconnect(_antes_de_dibujar)


## La ventana y la copia siguen al battler: se actualizan justo antes de dibujar, después de que
## las animaciones y los Tweens lo hayan movido en este frame.
func _antes_de_dibujar() -> void:
	if _ventana != null and not is_instance_valid(_ventana):
		_ventana = null
	if _ventana != null:
		_actualizar_ventana()
	if _copiado != null:
		if is_instance_valid(_copiado):
			_seguir(_copiado, _margen_copia)
		else:
			_copiado = null


var _copiado: Sprite2D
var _margen_copia: int = 0
## Escala de la copia de un battler alrededor de su centro (1 = como el original).
var escala_copia: Vector2 = Vector2.ONE


func _seguir(sprite: Sprite2D, margen: int) -> void:
	_copiado = sprite
	_margen_copia = margen
	var rect: Rect2 = sprite.get_rect()
	var centro: Vector2 = rect.get_center()
	var escala: Transform2D = Transform2D(0.0, centro) * Transform2D.IDENTITY.scaled(escala_copia) * Transform2D(0.0, -centro)
	global_transform = sprite.get_global_transform() * escala * Transform2D(0.0, rect.position - Vector2(margen, 0))


## Rect (píxeles de la textura) del fotograma que dibuja un Sprite2D.
static func rect_fuente(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2()
	if sprite.region_enabled:
		return sprite.region_rect
	var tamano: Vector2 = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	return Rect2(Vector2(sprite.frame_coords) * tamano, tamano)


func _actualizar() -> void:
	if _material == null:
		return
	var tamano: Vector2 = texture.get_size() if texture != null else Vector2(1, 1)
	var rect: Rect2 = _rect_fuente
	if rect.size == Vector2.ZERO:
		var alto: float = tamano.y / fotogramas
		rect = Rect2(0.0, alto * clampi(fotograma, 0, fotogramas - 1), tamano.x, alto)
	_material.set_shader_parameter(&"tamano_textura", tamano)
	_material.set_shader_parameter(&"fotograma", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_material.set_shader_parameter(&"desplazamiento", desplazamiento.floor())
	_material.set_shader_parameter(&"repetir", repetir)
	_material.set_shader_parameter(&"espejo", flip_h and _rect_fuente.size != Vector2.ZERO)
	_material.set_shader_parameter(&"mezcla_gba", mezcla_gba)
	_material.set_shader_parameter(&"eva", eva)
	_material.set_shader_parameter(&"evb", evb)
	_material.set_shader_parameter(&"opacidad", opacidad)
	_material.set_shader_parameter(&"onda_amplitud", onda_amplitud)
	_material.set_shader_parameter(&"onda_periodo", onda_periodo)
	_material.set_shader_parameter(&"onda_fase", onda_fase)
	_material.set_shader_parameter(&"onda_extra", onda_extra)
	_material.set_shader_parameter(&"tinte_color", tinte_color)
	_material.set_shader_parameter(&"tinte_cantidad", tinte_cantidad)
	_material.set_shader_parameter(&"onda_filas", onda_filas)
	_material.set_shader_parameter(&"con_ventana", _ventana != null)
	if _ventana != null:
		_actualizar_ventana()


func _actualizar_ventana() -> void:
	var inversa: Transform2D = _ventana.get_global_transform().affine_inverse()
	var origen: Vector2 = _ventana.get_rect().position
	# píxel local = inversa * mundo - origen del rect dibujado
	_material.set_shader_parameter(&"ventana", _ventana.texture)
	_material.set_shader_parameter(&"ventana_x", Vector3(inversa.x.x, inversa.y.x, inversa.origin.x - origen.x))
	_material.set_shader_parameter(&"ventana_y", Vector3(inversa.x.y, inversa.y.y, inversa.origin.y - origen.y))
	var rect: Rect2 = rect_fuente(_ventana)
	_material.set_shader_parameter(&"ventana_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_material.set_shader_parameter(&"ventana_tamano", _ventana.texture.get_size() if _ventana.texture != null else Vector2.ONE)
	_material.set_shader_parameter(&"ventana_espejo", _ventana.flip_h)
