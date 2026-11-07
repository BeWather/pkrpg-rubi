class_name MenuBoxComponent
extends Node

## Componente que hace que un NinePatchRect se actualice automáticamente
## cuando cambia la configuración de imagen_tipo en las opciones

@export var auto_update_on_options_change: bool = true
@export var manual_image_type: int = 0  # Si > 0, usa este valor en lugar de leer de opciones

var target_ninepatch: NinePatchRect
var current_image_type: int = 1

func _ready() -> void:
	# Buscar el NinePatchRect padre o hermano
	target_ninepatch = get_parent() as NinePatchRect
	if not target_ninepatch:
		# Buscar en hermanos
		for sibling in get_parent().get_children():
			if sibling is NinePatchRect:
				target_ninepatch = sibling
				break
	
	if not target_ninepatch:
		print("[MENU BOX COMPONENT] Error: No se encontró NinePatchRect objetivo para %s" % get_parent().name)
		return
	
	# Conectar a señales de opciones si está habilitado auto-update
	if auto_update_on_options_change:
		# Conectar a la señal cuando las opciones cambien
		var singleton = get_tree().root.get_node_or_null("Singleton")
		if singleton and singleton.has_signal("opciones_cambiadas"):
			singleton.connect("opciones_cambiadas", _on_opciones_changed)
	
	# Aplicar textura inicial
	_update_texture()

func _update_texture() -> void:
	if not target_ninepatch:
		return
	
	var image_type = _get_current_image_type()
	if current_image_type != image_type:
		current_image_type = image_type
		# Cargar la clase MenuBoxManager
		var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
		menu_box_manager.apply_texture_to_ninepatch(target_ninepatch, image_type)

func _get_current_image_type() -> int:
	# Si hay tipo manual configurado, usarlo
	if manual_image_type > 0:
		return manual_image_type
	
	# Leer de las opciones guardadas
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	
	# Fallback a imagen_tipo 1
	return 1

func _on_opciones_changed() -> void:
	print("[MENU BOX COMPONENT] Opciones cambiaron, actualizando textura...")
	_update_texture()

## Fuerza la actualización de la textura
func force_update() -> void:
	current_image_type = 0  # Forzar cambio
	_update_texture()

## Establece un tipo de imagen específico (anula auto-update temporalmente)
func set_image_type(image_type: int) -> void:
	manual_image_type = image_type
	_update_texture()

## Restaura el comportamiento auto-update desde opciones
func restore_auto_update() -> void:
	manual_image_type = 0
	_update_texture()
