@tool
extends EditorProperty

## Vista previa de `estilo_warp` del Warp (warp.gd). Se añade debajo del
## desplegable del enum (add_to_end) y muestra la animación «cerrada» de la escena
## de puerta del estilo; sin ella, el primer cuadro de «abrir_puerta». Solo lee:
## el valor lo sigue editando el desplegable por defecto.

const SingletonScript = preload("res://scripts/singleton.gd")

const ESCALA_MINIATURA := 3
const COLOR_ATENUADO := Color(1, 1, 1, 0.55)
const ANIMACIONES_PREVIA: Array[StringName] = [&"cerrada", &"abrir_puerta", &"default"]

var _miniatura: TextureRect
var _etiqueta: Label


func _init() -> void:
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fila)

	_miniatura = TextureRect.new()
	_miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_miniatura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fila.add_child(_miniatura)

	_etiqueta = Label.new()
	_etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiqueta.modulate = COLOR_ATENUADO
	fila.add_child(_etiqueta)


func _update_property() -> void:
	var objeto := get_edited_object()
	if objeto == null:
		return
	var estilo := int(objeto.get(get_edited_property()))
	# Sin caché: la escena es diminuta y así refleja al momento los cambios en sus SpriteFrames.
	var textura := _leer_textura(_escena_estilo(estilo))
	_miniatura.texture = textura
	_miniatura.visible = textura != null
	if textura != null:
		_miniatura.custom_minimum_size = textura.get_size() * ESCALA_MINIATURA * EditorInterface.get_editor_scale()
	_etiqueta.text = "" if textura != null else "Sin gráfico de puerta"

## Misma correspondencia que Singleton.escena_estilo_warp, sin instancia del autoload.
static func _escena_estilo(estilo: int) -> PackedScene:
	if SingletonScript.SCN_PUERTAS.has(estilo):
		return SingletonScript.SCN_PUERTAS[estilo]
	if estilo in [SingletonScript.EstiloWarp.SERVICIO_COMBATE, SingletonScript.EstiloWarp.SERVICIO_INTERCAMBIO, SingletonScript.EstiloWarp.SERVICIO_RECORDS]:
		return load(SingletonScript.RUTA_PUERTA_SERVICIO)
	return null

static func _leer_textura(escena: PackedScene) -> Texture2D:
	if escena == null:
		return null
	var nodo := escena.instantiate()
	var frames: SpriteFrames = nodo.sprite_frames if nodo is AnimatedSprite2D else null
	nodo.free()
	if frames == null:
		return null
	for anim in ANIMACIONES_PREVIA:
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			return frames.get_frame_texture(anim, 0)
	return null
