extends Node2D
class_name FondoMovimientoNativo
## Capa de fondo de las animaciones nativas: fadetobg/restorebg y mezclas de
## paleta del fondo del original. `EfectoMovimientoNativo.configurar()` la
## coloca por encima del fondo y el suelo de la batalla y por debajo de los
## battlers. `Imagen` es el fondo propio del movimiento (oculto = se ve el de
## la batalla) y `Velo` el color hacia el que se funde todo lo de debajo.
## Con `fijar_imagen()` (§22) el fondo propio es una CapaFondoNativa creada al vuelo
## (hoja con fotogramas, scroll repetido y ondulación por fila); `Imagen` queda para
## las escenas que la tienen con su textura en la .tscn.

@export var mostrar_imagen: bool = false:
	set(valor):
		mostrar_imagen = valor
		if is_node_ready():
			imagen.visible = valor and capa_imagen == null
			if capa_imagen != null:
				capa_imagen.visible = valor
## Proporción de la mezcla hacia `color_velo` (16avos del original / 16).
@export_range(0.0, 1.0) var velo: float = 0.0:
	set(valor):
		velo = valor
		_aplicar_velo()
@export var color_velo: Color = Color.BLACK:
	set(valor):
		color_velo = valor
		_aplicar_velo()
## Scroll del fondo (gBattle_BG3_X/Y): mueve el contenido hacia -desplazamiento.
@export var desplazamiento: Vector2 = Vector2.ZERO:
	set(valor):
		desplazamiento = valor
		if is_node_ready():
			imagen.region_rect.position = valor
			if capa_imagen != null:
				capa_imagen.desplazamiento = valor
## Fotograma de la hoja del fondo propio (fijar_imagen), p. ej. el paso del ciclo de paleta.
@export var fotograma: int = 0:
	set(valor):
		fotograma = valor
		if capa_imagen != null:
			capa_imagen.fotograma = valor

@onready var imagen: Sprite2D = $Imagen
@onready var velo_rect: ColorRect = $Velo
## Fondo propio puesto con fijar_imagen() (null = se usa `Imagen`).
var capa_imagen: CapaFondoNativa
var _tamano: Vector2 = Vector2(240, 160)
## §37: capa que invierte solo el fondo (fijar_inversion), creada la primera vez; va después del velo.
var _inversion: Array[CanvasItem] = []

const SHADER_INVERSION: Shader = preload("res://escenas/batalla/animaciones_nativas/inversion_campo.gdshader")


func _ready() -> void:
	imagen.visible = mostrar_imagen
	imagen.region_rect.position = desplazamiento
	_aplicar_velo()


func colocar(z: int, tamano: Vector2) -> void:
	z_as_relative = false
	z_index = z
	_tamano = tamano
	imagen.region_rect = Rect2(desplazamiento, tamano)
	velo_rect.size = tamano


## Pone como fondo propio la textura de `plantilla` (un Sprite2D o CapaFondoNativa oculto de la
## escena; su `vframes` = fotogramas de la hoja) o lo quita con null. No lo muestra: eso lo decide
## `mostrar_imagen` (los fundidos de fadetobg lo cambian en el negro).
func fijar_imagen(plantilla: Sprite2D) -> void:
	if plantilla == null:
		if capa_imagen != null:
			capa_imagen.queue_free()
			capa_imagen = null
		imagen.visible = false
		return
	if capa_imagen == null:
		capa_imagen = CapaFondoNativa.new()
		capa_imagen.name = &"ImagenMovimiento"
		add_child(capa_imagen)
		move_child(capa_imagen, velo_rect.get_index())
	capa_imagen.texture = plantilla.texture
	capa_imagen.fotogramas = plantilla.vframes
	capa_imagen.preparar(_tamano)
	capa_imagen.fotograma = fotograma
	capa_imagen.desplazamiento = desplazamiento
	capa_imagen.visible = mostrar_imagen
	imagen.visible = false


## §37: inversión de colores solo del fondo (lo dibujado hasta esta capa: el fondo de la batalla, el propio del
## movimiento y su velo). La usa EfectoParticulasNativo cuando la inversión del fondo y la de los battlers van
## desfasadas (en el original, un fundido de paleta del fondo en marcha reescribe su paleta y pierde la inversión).
func fijar_inversion(activa: bool) -> void:
	if _inversion.is_empty():
		if not activa:
			return
		var previa: BackBufferCopy = BackBufferCopy.new()
		previa.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		var capa: ColorRect = ColorRect.new()
		capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.size = _tamano
		var material_capa: ShaderMaterial = ShaderMaterial.new()
		material_capa.shader = SHADER_INVERSION
		capa.material = material_capa
		var posterior: BackBufferCopy = BackBufferCopy.new()
		posterior.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_inversion = [previa, capa, posterior]
		for nodo: CanvasItem in _inversion:
			add_child(nodo)
	for nodo: CanvasItem in _inversion:
		nodo.visible = activa


func fijar_velo(color: Color, cantidad: float) -> void:
	color_velo = color
	velo = cantidad


func _aplicar_velo() -> void:
	if is_node_ready():
		velo_rect.color = Color(color_velo, velo)
		velo_rect.visible = velo > 0.0
