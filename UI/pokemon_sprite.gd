extends AnimatedSprite2D
class_name PokemonSprite

## Descripción breve de la clase PokemonSprite:
##
## Controlador ligero para AnimatedSprite2D que delega la carga en PokemonSpriteManager.
## Evita duplicar lógica de rutas, cache y placeholders mientras mantiene la API establecida.

enum TipoSprite {
	FRENTE,
	ESPALDA,
	FRENTE_SHINY,
	ESPALDA_SHINY
}

# Estado
var tipo_sprite_actual: TipoSprite = TipoSprite.FRENTE
var pokemon_nombre_interno: String = ""
## Personalidad del Pokémon mostrado (-1 = sin Pokémon concreto). Decide las
## manchas del frente de SPINDA; el resto de especies la ignora.
var personalidad: int = -1
var sprite_cargado: bool = false

func _ready():
	# Asegurar SpriteFrames
	if sprite_frames == null:
		sprite_frames = SpriteFrames.new()

## Configurar el sprite para un Pokémon específico (API establecida en el proyecto).
## `personalidad_pokemon` (opcional): la del Pokémon concreto, para las manchas
## de SPINDA; -1 muestra el sprite base.
func configurar_pokemon(nombre_interno: String, tipo: TipoSprite = TipoSprite.FRENTE, es_shiny: bool = false, personalidad_pokemon: int = -1):
	pokemon_nombre_interno = nombre_interno.to_upper()
	personalidad = personalidad_pokemon
	# Normalizar tipo final
	if es_shiny:
		tipo_sprite_actual = TipoSprite.FRENTE_SHINY if tipo == TipoSprite.FRENTE else TipoSprite.ESPALDA_SHINY
	else:
		tipo_sprite_actual = tipo
	return _cargar_desde_manager()

## Cargar el sprite usando PokemonSpriteManager y aplicarlo a este AnimatedSprite2D
func _cargar_desde_manager() -> bool:
	if pokemon_nombre_interno.is_empty():
		print("❌ Error: nombre_interno vacío")
		return false

	var base_tipo := _a_tipo_manager_base(tipo_sprite_actual)
	var es_shiny := _es_tipo_shiny(tipo_sprite_actual)
	var tex: Texture2D = PokemonSpriteManager.cargar_sprite_pokemon(pokemon_nombre_interno, base_tipo, es_shiny, personalidad)
	if tex == null:
		# El manager garantiza placeholder, pero por si acaso
		print("⚠️ Manager devolvió textura nula para ", pokemon_nombre_interno)
		return false

	# Aplicar a SpriteFrames como animación de 1 frame
	sprite_frames.clear_all()
	sprite_frames.add_animation("principal")
	sprite_frames.add_frame("principal", tex)
	animation = "principal"
	frame = 0
	sprite_cargado = true
	return true

## Mapeos auxiliares
static func _a_tipo_manager_base(t: TipoSprite) -> int:
	# Devuelve PokemonSpriteManager.SpriteType.FRONT o BACK (sin shiny)
	return PokemonSpriteManager.SpriteType.FRONT if t in [TipoSprite.FRENTE, TipoSprite.FRENTE_SHINY] else PokemonSpriteManager.SpriteType.BACK

static func _es_tipo_shiny(t: TipoSprite) -> bool:
	return t in [TipoSprite.FRENTE_SHINY, TipoSprite.ESPALDA_SHINY]

## Cambiar el tipo de sprite (frente/espalda, normal/shiny)
func cambiar_tipo_sprite(nuevo_tipo: TipoSprite):
	if nuevo_tipo != tipo_sprite_actual:
		tipo_sprite_actual = nuevo_tipo
		_cargar_desde_manager()

## Alternar entre normal y shiny
func alternar_shiny():
	match tipo_sprite_actual:
		TipoSprite.FRENTE:
			cambiar_tipo_sprite(TipoSprite.FRENTE_SHINY)
		TipoSprite.FRENTE_SHINY:
			cambiar_tipo_sprite(TipoSprite.FRENTE)
		TipoSprite.ESPALDA:
			cambiar_tipo_sprite(TipoSprite.ESPALDA_SHINY)
		TipoSprite.ESPALDA_SHINY:
			cambiar_tipo_sprite(TipoSprite.ESPALDA)

## Alternar entre frente y espalda
func alternar_orientacion():
	match tipo_sprite_actual:
		TipoSprite.FRENTE:
			cambiar_tipo_sprite(TipoSprite.ESPALDA)
		TipoSprite.ESPALDA:
			cambiar_tipo_sprite(TipoSprite.FRENTE)
		TipoSprite.FRENTE_SHINY:
			cambiar_tipo_sprite(TipoSprite.ESPALDA_SHINY)
		TipoSprite.ESPALDA_SHINY:
			cambiar_tipo_sprite(TipoSprite.FRENTE_SHINY)

## Función estática para configurar rápidamente un nodo PokemonSprite
static func configurar_desde_pokemon(nodo_sprite: PokemonSprite, pokemon: BasePokemon, tipo: TipoSprite = TipoSprite.FRENTE):
	if pokemon == null:
		print("❌ Error: pokemon es null")
		return false
	var es_shiny: bool = pokemon.es_shiny()
	return nodo_sprite.configurar_pokemon(pokemon.nombre_interno, tipo, es_shiny, pokemon.personalidad)

## Obtener información del estado actual
func obtener_info_estado() -> Dictionary:
	return {
		"pokemon": pokemon_nombre_interno,
		"tipo_sprite": TipoSprite.keys()[tipo_sprite_actual],
		"sprite_cargado": sprite_cargado,
		"ruta_actual": construir_ruta_sprite(),
		"es_shiny": _es_tipo_shiny(tipo_sprite_actual),
		"personalidad": personalidad,
		"es_frente": tipo_sprite_actual in [TipoSprite.FRENTE, TipoSprite.FRENTE_SHINY]
	}

## Debug: imprimir estado actual
func debug_estado():
	var info = obtener_info_estado()
	print("=== Estado PokemonSprite ===")
	for clave in info:
		print(clave, ": ", info[clave])
	print("===========================")

## Mantener compatibilidad: construir la ruta actual usando el Manager
func construir_ruta_sprite() -> String:
	if pokemon_nombre_interno.is_empty():
		return ""
	var base_tipo := _a_tipo_manager_base(tipo_sprite_actual)
	var es_shiny := _es_tipo_shiny(tipo_sprite_actual)
	var tipo_final := base_tipo
	if es_shiny:
		if base_tipo == PokemonSpriteManager.SpriteType.FRONT:
			tipo_final = PokemonSpriteManager.SpriteType.FRONT_SHINY
		else:
			tipo_final = PokemonSpriteManager.SpriteType.BACK_SHINY
	return PokemonSpriteManager.construir_ruta_sprite(pokemon_nombre_interno, tipo_final)
