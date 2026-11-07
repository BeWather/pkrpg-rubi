@tool
class_name MenuBoxManager
extends Resource

## Gestor de texturas para NinePatchRect de menús
## Maneja la carga dinámica de texturas menu_box_1.png a menu_box_20.png

# Cache de texturas cargadas para evitar cargas repetidas
static var _texture_cache: Dictionary = {}

## Obtiene la textura correspondiente al tipo de imagen especificado
static func get_menu_box_texture(image_type: int) -> Texture2D:
	# Asegurar que el tipo está en rango válido
	image_type = clamp(image_type, 1, 20)
	
	# Verificar si ya está en cache
	if _texture_cache.has(image_type):
		return _texture_cache[image_type]
	
	# Cargar textura desde archivo
	var texture_path = "res://UI/menu_box_%d.png" % image_type
	var texture = load(texture_path) as Texture2D
	
	if texture:
		_texture_cache[image_type] = texture
		print("[MENU BOX MANAGER] Textura cargada: %s" % texture_path)
	else:
		print("[MENU BOX MANAGER] Error: No se pudo cargar %s, usando menu_box_1.png como fallback" % texture_path)
		# Fallback a menu_box_1.png
		if not _texture_cache.has(1):
			_texture_cache[1] = load("res://UI/menu_box_1.png") as Texture2D
		texture = _texture_cache[1]
	
	return texture

## Aplica la textura a un NinePatchRect específico
static func apply_texture_to_ninepatch(ninepatch: NinePatchRect, image_type: int) -> void:
	if not ninepatch:
		print("[MENU BOX MANAGER] Error: NinePatchRect es null")
		return
	
	var texture = get_menu_box_texture(image_type)
	ninepatch.texture = texture
	print("[MENU BOX MANAGER] Textura aplicada a %s: menu_box_%d.png" % [ninepatch.name, image_type])

## Limpia el cache de texturas (útil para liberar memoria)
static func clear_cache() -> void:
	_texture_cache.clear()
	print("[MENU BOX MANAGER] Cache de texturas limpiado")

## Precarga todas las texturas del 1 al 20 (opcional, para mejor rendimiento)
static func preload_all_textures() -> void:
	print("[MENU BOX MANAGER] Precargando todas las texturas...")
	for i in range(1, 21):
		get_menu_box_texture(i)
	print("[MENU BOX MANAGER] Precarga completa: %d texturas en cache" % _texture_cache.size())
