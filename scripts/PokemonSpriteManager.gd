@tool
# SpriteManager para Batalla Pokémon
# Sistema robusto de carga de sprites con manejo de errores y placeholders

extends RefCounted
class_name PokemonSpriteManager

# Rutas base para los sprites
const SPRITE_BASE_PATH = "res://graficos/pokemon/"
const FRONT_PATH = SPRITE_BASE_PATH + "front/"
const BACK_PATH = SPRITE_BASE_PATH + "back/"
const FRONT_SHINY_PATH = SPRITE_BASE_PATH + "front-shiny/"
const BACK_SHINY_PATH = SPRITE_BASE_PATH + "back-shiny/"

# Placeholder para sprites faltantes
const PLACEHOLDER_PATH = "res://graficos/pokemon/placeholder.png"

# Enumeración para tipos de sprite
enum SpriteType {
	FRONT,
	BACK,
	FRONT_SHINY,
	BACK_SHINY
}

# Cache de sprites cargados para optimización
static var sprite_cache: Dictionary = {}

## Variantes con manchas de SPINDA, por especie + tipo + personalidad. Va aparte
## de `sprite_cache` (que solo guarda las texturas base) y se vacía al llegar a
## MAX_CACHE_MANCHAS para no crecer sin límite con muchos SPINDA distintos.
static var cache_manchas: Dictionary = {}
const MAX_CACHE_MANCHAS: int = 64

# Contador de sprites faltantes para logging
static var missing_sprites: Dictionary = {}

# Función principal para cargar sprite de Pokémon.
# `personalidad` (opcional, -1 = sin Pokémon concreto) es el valor de
# personalidad del Pokémon: en el frente de SPINDA decide sus manchas
# (ManchasSpinda). El resto de especies y la espalda la ignoran.
static func cargar_sprite_pokemon(nombre_interno: String, tipo: SpriteType, es_shiny: bool = false, personalidad: int = -1) -> Texture2D:
	# Normalizar nombre a mayúsculas (como están los archivos)
	var nombre_sprite = nombre_interno.to_upper()
	
	# Determinar tipo final basado en shiny
	var tipo_final = tipo
	if es_shiny:
		if tipo == SpriteType.FRONT:
			tipo_final = SpriteType.FRONT_SHINY
		elif tipo == SpriteType.BACK:
			tipo_final = SpriteType.BACK_SHINY
	
	# Crear clave de cache
	var cache_key = nombre_sprite + "_" + str(tipo_final)
	
	# Verificar cache primero
	var texture: Texture2D = null
	if sprite_cache.has(cache_key):
		texture = sprite_cache[cache_key]
	else:
		# Construir ruta del sprite
		var sprite_path = construir_ruta_sprite(nombre_sprite, tipo_final)

		# Intentar cargar el sprite
		texture = cargar_texture_seguro(sprite_path, nombre_sprite, tipo_final)

		# Guardar en cache
		sprite_cache[cache_key] = texture

	if personalidad >= 0 and ManchasSpinda.aplica_a(nombre_sprite) \
			and tipo_final in [SpriteType.FRONT, SpriteType.FRONT_SHINY]:
		return _variante_con_manchas(texture, cache_key, personalidad, tipo_final == SpriteType.FRONT_SHINY)

	return texture

## Frente de SPINDA con las manchas de `personalidad`, cacheado aparte para
## que dos SPINDA distintos no compartan textura (la base no se modifica).
static func _variante_con_manchas(base: Texture2D, cache_key: String, personalidad: int, es_shiny: bool) -> Texture2D:
	var clave: String = "%s_%d" % [cache_key, personalidad & 0xFFFFFFFF]
	if cache_manchas.has(clave):
		return cache_manchas[clave]
	if cache_manchas.size() >= MAX_CACHE_MANCHAS:
		cache_manchas.clear()
	var variante: Texture2D = ManchasSpinda.textura_con_manchas(base, personalidad, es_shiny)
	cache_manchas[clave] = variante
	return variante

# Construir la ruta completa del sprite
static func construir_ruta_sprite(nombre_sprite: String, tipo: SpriteType) -> String:
	var base_path = ""
	
	match tipo:
		SpriteType.FRONT:
			base_path = FRONT_PATH
		SpriteType.BACK:
			base_path = BACK_PATH
		SpriteType.FRONT_SHINY:
			base_path = FRONT_SHINY_PATH
		SpriteType.BACK_SHINY:
			base_path = BACK_SHINY_PATH
	
	return base_path + nombre_sprite + ".png"

# Cargar texture con manejo de errores
static func cargar_texture_seguro(ruta: String, nombre: String, tipo: SpriteType) -> Texture2D:
	# Verificar si el archivo existe
	if ResourceLoader.exists(ruta):
		var texture = load(ruta) as Texture2D
		if texture != null:
			print("✅ Sprite cargado: ", nombre, " (", get_tipo_string(tipo), ")")
			return texture
		else:
			print("⚠️ Error al cargar sprite: ", ruta)
	else:
		print("⚠️ Sprite no encontrado: ", ruta)
	
	# Registrar sprite faltante
	registrar_sprite_faltante(nombre, tipo)
	
	# Intentar cargar placeholder
	return cargar_placeholder(nombre, tipo)

# Cargar placeholder o crear texture temporal
static func cargar_placeholder(nombre: String, tipo: SpriteType) -> Texture2D:
	# Intentar cargar placeholder oficial si existe
	if ResourceLoader.exists(PLACEHOLDER_PATH):
		var placeholder = load(PLACEHOLDER_PATH) as Texture2D
		if placeholder != null:
			print("🔄 Usando placeholder para: ", nombre)
			return placeholder
	
	# Crear texture básico como último recurso
	print("🆘 Creando texture temporal para: ", nombre)
	return crear_texture_temporal(tipo)

# Crear texture temporal básico
static func crear_texture_temporal(tipo: SpriteType) -> Texture2D:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	# Colorear según tipo
	var color = Color.MAGENTA  # Color llamativo para indicar error
	match tipo:
		SpriteType.FRONT, SpriteType.FRONT_SHINY:
			color = Color.CYAN
		SpriteType.BACK, SpriteType.BACK_SHINY:
			color = Color.YELLOW
	
	image.fill(color)
	
	var texture = ImageTexture.create_from_image(image)
	
	return texture

# Registrar sprites faltantes para logging
static func registrar_sprite_faltante(nombre: String, tipo: SpriteType):
	var key = nombre + "_" + get_tipo_string(tipo)
	if not missing_sprites.has(key):
		missing_sprites[key] = 1
	else:
		missing_sprites[key] += 1

# Obtener string descriptivo del tipo
static func get_tipo_string(tipo: SpriteType) -> String:
	match tipo:
		SpriteType.FRONT:
			return "frente"
		SpriteType.BACK:
			return "espalda"
		SpriteType.FRONT_SHINY:
			return "frente_shiny"
		SpriteType.BACK_SHINY:
			return "espalda_shiny"
		_:
			return "desconocido"

# Funciones de conveniencia para la batalla
## `personalidad` (opcional): la del Pokémon concreto, para las manchas de SPINDA.
static func cargar_sprite_frente(nombre_interno: String, es_shiny: bool = false, personalidad: int = -1) -> Texture2D:
	return cargar_sprite_pokemon(nombre_interno, SpriteType.FRONT, es_shiny, personalidad)

## Frente de un Pokémon concreto: especie, variocolor y personalidad (manchas de
## SPINDA) salen del propio Pokémon.
static func cargar_sprite_frente_de(pokemon: BasePokemon) -> Texture2D:
	if pokemon == null:
		return null
	return cargar_sprite_pokemon(pokemon.nombre_interno, SpriteType.FRONT, pokemon.es_shiny(), pokemon.personalidad)

static func cargar_sprite_espalda(nombre_interno: String, es_shiny: bool = false) -> Texture2D:
	return cargar_sprite_pokemon(nombre_interno, SpriteType.BACK, es_shiny)

# Aplicar sprite a un nodo Sprite2D con logging
static func aplicar_sprite_a_nodo(nodo: Sprite2D, nombre_interno: String, tipo: SpriteType, es_shiny: bool = false, personalidad: int = -1):
	if nodo == null:
		print("❌ Error: nodo Sprite2D es null")
		return

	var texture = cargar_sprite_pokemon(nombre_interno, tipo, es_shiny, personalidad)
	nodo.texture = texture
	
	print("🎨 Sprite aplicado a nodo: ", nombre_interno, " (", get_tipo_string(tipo), ")")

# Limpiar cache (útil para debugging)
static func limpiar_cache():
	sprite_cache.clear()
	cache_manchas.clear()
	print("🧹 Cache de sprites limpiado")

# Obtener estadísticas de sprites faltantes
static func obtener_estadisticas_faltantes() -> Dictionary:
	return missing_sprites.duplicate()

# Imprimir reporte de sprites faltantes
static func imprimir_reporte_faltantes():
	if missing_sprites.size() == 0:
		print("✅ No hay sprites faltantes registrados")
		return
	
	print("\n📊 REPORTE DE SPRITES FALTANTES:")
	print("========================================")  # 40 caracteres
	
	for sprite_key in missing_sprites.keys():
		var count = missing_sprites[sprite_key]
		print("⚠️  %s: %d intentos fallidos" % [sprite_key, count])
	
	print("========================================")  # 40 caracteres
	print("Total sprites faltantes: ", missing_sprites.size())

# Precargar sprites comunes para optimización
static func precargar_sprites_basicos():
	var pokemon_comunes = [
		"PIKACHU", "CHARIZARD", "BLASTOISE", "VENUSAUR",
		"MEWTWO", "MEW", "RHYDON", "GYARADOS",
		"DRAGONITE", "GROUDON", "KYOGRE", "RAYQUAZA"
	]
	
	print("🔄 Precargando sprites básicos...")
	
	for pokemon in pokemon_comunes:
		cargar_sprite_frente(pokemon)
		cargar_sprite_espalda(pokemon)
	
	print("✅ Sprites básicos precargados")

# Validar integridad de sprites (herramienta de desarrollo)
static func validar_sprites_pokemon(lista_pokemon: Array) -> Dictionary:
	var resultado = {
		"total": 0,
		"encontrados": 0,
		"faltantes": []
	}
	
	for pokemon in lista_pokemon:
		var nombre = ""
		if typeof(pokemon) == TYPE_STRING:
			nombre = pokemon
		elif pokemon.has("nombre_interno"):
			nombre = pokemon.nombre_interno
		else:
			continue
		
		resultado.total += 1
		
		var ruta_frente = construir_ruta_sprite(nombre.to_upper(), SpriteType.FRONT)
		var ruta_espalda = construir_ruta_sprite(nombre.to_upper(), SpriteType.BACK)
		
		if ResourceLoader.exists(ruta_frente) and ResourceLoader.exists(ruta_espalda):
			resultado.encontrados += 1
		else:
			resultado.faltantes.append(nombre)
	
	return resultado
