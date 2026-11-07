class_name PokemonBattleShaderController
extends Node

## Controlador de efectos shader para sprites de Pokémon en batalla
## Permite activar/desactivar múltiples efectos de forma modular

var sprite_node: Sprite2D
var shader_material: ShaderMaterial
var shader_resource: Shader

## Efectos disponibles
enum EfectoPokemon {
	SILUETA,
	PARPADEO,
	BRILLO,
	DESVANECIMIENTO,
	CONTORNO,
	MONOCROMO
}

## Presets de efectos comunes
enum PresetEfecto {
	NORMAL,
	APARICION,
	DEBILITADO,
	CRITICO,
	ESTADO_ALTERADO,
	SHINY
}

func _init(sprite: Sprite2D):
	sprite_node = sprite
	_inicializar_shader()

## Inicializa el shader en el sprite
func _inicializar_shader():
	if not sprite_node:
		print("❌ [POKEMON_SHADER] Error: Sprite node es null")
		return
	
	# Reutilizar el material definido en la escena de batalla para que sus
	# parámetros sean visibles y editables desde el inspector.
	shader_material = sprite_node.material as ShaderMaterial

	# Mantener un fallback para sprites creados por código o escenas antiguas
	# que todavía no tengan un ShaderMaterial asignado.
	if shader_material == null:
		shader_resource = load("res://escenas/batalla/pokemon_battle.gdshader") as Shader
		if not shader_resource:
			print("❌ [POKEMON_SHADER] Error: No se pudo cargar pokemon_battle.gdshader")
			return

		shader_material = ShaderMaterial.new()
		shader_material.resource_local_to_scene = true
		shader_material.shader = shader_resource
		sprite_node.material = shader_material
	else:
		shader_resource = shader_material.shader

	if shader_resource == null:
		print("❌ [POKEMON_SHADER] Error: El ShaderMaterial no tiene shader asignado")
		return
	
	# Configurar valores por defecto (todos los efectos desactivados)
	_resetear_efectos()
	
	print("✅ [POKEMON_SHADER] Shader inicializado en %s" % sprite_node.name)

## Resetea todos los efectos a sus valores por defecto
func _resetear_efectos():
	if not shader_material:
		return
	
	# Desactivar todos los efectos
	shader_material.set_shader_parameter("efecto_silueta", false)
	shader_material.set_shader_parameter("efecto_parpadeo", false)
	shader_material.set_shader_parameter("efecto_brillo", false)
	shader_material.set_shader_parameter("efecto_desvanecimiento", false)
	shader_material.set_shader_parameter("efecto_contorno", false)
	shader_material.set_shader_parameter("efecto_monocromo", false)
	
	# Valores por defecto
	shader_material.set_shader_parameter("alpha_desvanecimiento", 1.0)
	shader_material.set_shader_parameter("progreso_silueta", 1.0)

	print("🧼 [POKEMON_SHADER] Efectos reseteados a valores por defecto")

## Activa un efecto específico con parámetros opcionales
func activar_efecto(efecto: EfectoPokemon, parametros: Dictionary = {}):
	if not shader_material:
		print("❌ [POKEMON_SHADER] Material no inicializado")
		return
	
	match efecto:
		EfectoPokemon.SILUETA:
			shader_material.set_shader_parameter("efecto_silueta", true)
			shader_material.set_shader_parameter("color_silueta", parametros.get("color", Color("#ffb5f7")))
			shader_material.set_shader_parameter("intensidad_silueta", parametros.get("intensidad", 1.0))
			shader_material.set_shader_parameter("progreso_silueta", parametros.get("progreso", 0.0))
			
		EfectoPokemon.PARPADEO:
			shader_material.set_shader_parameter("efecto_parpadeo", true)
			shader_material.set_shader_parameter("velocidad_parpadeo", parametros.get("velocidad", 4.0))
			shader_material.set_shader_parameter("color_parpadeo", parametros.get("color", Color.WHITE))
			
		EfectoPokemon.BRILLO:
			shader_material.set_shader_parameter("efecto_brillo", true)
			shader_material.set_shader_parameter("intensidad_brillo", parametros.get("intensidad", 1.8))
			shader_material.set_shader_parameter("color_brillo", parametros.get("color", Color("#fff8dc")))
			
		EfectoPokemon.DESVANECIMIENTO:
			shader_material.set_shader_parameter("efecto_desvanecimiento", true)
			shader_material.set_shader_parameter("alpha_desvanecimiento", parametros.get("alpha", 0.5))
			
		EfectoPokemon.CONTORNO:
			shader_material.set_shader_parameter("efecto_contorno", true)
			shader_material.set_shader_parameter("color_contorno", parametros.get("color", Color.WHITE))
			shader_material.set_shader_parameter("grosor_contorno", parametros.get("grosor", 1.5))
			
		EfectoPokemon.MONOCROMO:
			shader_material.set_shader_parameter("efecto_monocromo", true)
			shader_material.set_shader_parameter("intensidad_monocromo", parametros.get("intensidad", 1.0))
			shader_material.set_shader_parameter("tinte_monocromo", parametros.get("tinte", Color.WHITE))
	
	print("✨ [POKEMON_SHADER] Efecto activado: %s | parametros=%s" % [EfectoPokemon.keys()[efecto], parametros])

## Desactiva un efecto específico
func desactivar_efecto(efecto: EfectoPokemon):
	if not shader_material:
		return
	
	match efecto:
		EfectoPokemon.SILUETA:
			shader_material.set_shader_parameter("efecto_silueta", false)
			shader_material.set_shader_parameter("progreso_silueta", 1.0)
		EfectoPokemon.PARPADEO:
			shader_material.set_shader_parameter("efecto_parpadeo", false)
		EfectoPokemon.BRILLO:
			shader_material.set_shader_parameter("efecto_brillo", false)
		EfectoPokemon.DESVANECIMIENTO:
			shader_material.set_shader_parameter("efecto_desvanecimiento", false)
			shader_material.set_shader_parameter("alpha_desvanecimiento", 1.0)
		EfectoPokemon.CONTORNO:
			shader_material.set_shader_parameter("efecto_contorno", false)
		EfectoPokemon.MONOCROMO:
			shader_material.set_shader_parameter("efecto_monocromo", false)
	
	print("🔕 [POKEMON_SHADER] Efecto desactivado: %s" % EfectoPokemon.keys()[efecto])

## Aplica un preset de efectos predefinido
func aplicar_preset(preset: PresetEfecto):
	# Resetear primero
	_resetear_efectos()
	print("🎛️ [POKEMON_SHADER] Aplicando preset %s" % PresetEfecto.keys()[preset])
	
	match preset:
		PresetEfecto.NORMAL:
			# Sin efectos
			pass
			
		PresetEfecto.APARICION:
			activar_efecto(EfectoPokemon.SILUETA, {"color": Color("#ffb5f7"), "intensidad": 1.0})
			activar_efecto(EfectoPokemon.BRILLO, {"intensidad": 2.0})
			activar_efecto(EfectoPokemon.CONTORNO, {"color": Color("#ffffff"), "grosor": 2.0})
			
		PresetEfecto.DEBILITADO:
			activar_efecto(EfectoPokemon.MONOCROMO, {"intensidad": 0.8, "tinte": Color.GRAY})
			activar_efecto(EfectoPokemon.DESVANECIMIENTO, {"alpha": 0.6})
			
		PresetEfecto.CRITICO:
			activar_efecto(EfectoPokemon.PARPADEO, {"velocidad": 8.0, "color": Color("#ff6b6b")})
			activar_efecto(EfectoPokemon.BRILLO, {"intensidad": 2.5, "color": Color("#ffff88")})
			activar_efecto(EfectoPokemon.CONTORNO, {"color": Color("#ff0000"), "grosor": 2.5})
			
		PresetEfecto.ESTADO_ALTERADO:
			activar_efecto(EfectoPokemon.PARPADEO, {"velocidad": 3.0, "color": Color("#9b59b6")})
			activar_efecto(EfectoPokemon.CONTORNO, {"color": Color("#8e44ad"), "grosor": 1.5})
			
		PresetEfecto.SHINY:
			activar_efecto(EfectoPokemon.BRILLO, {"intensidad": 1.5, "color": Color("#ffd700")})
			activar_efecto(EfectoPokemon.PARPADEO, {"velocidad": 2.0, "color": Color("#ffffff")})
			activar_efecto(EfectoPokemon.CONTORNO, {"color": Color("#ffd700"), "grosor": 1.0})
	
	print("🎨 [POKEMON_SHADER] Preset aplicado: %s" % PresetEfecto.keys()[preset])

## Anima un parámetro específico
func animar_parametro(parametro: String, valor_inicial: float, valor_final: float, duracion: float, callback: Callable = Callable()):
	if not shader_material:
		print("❌ [POKEMON_SHADER] No se puede animar: material no inicializado")
		return

	print("🎚️ [POKEMON_SHADER] Animando parámetro %s de %.3f a %.3f en %.3fs" % [parametro, valor_inicial, valor_final, duracion])
	
	var tween = sprite_node.create_tween()
	tween.tween_method(func(valor): _actualizar_parametro(parametro, valor), valor_inicial, valor_final, duracion)

	await tween.finished
	print("✅ [POKEMON_SHADER] Animación completada para parámetro %s" % parametro)

	if callback.is_valid():
		callback.call()
		print("🔁 [POKEMON_SHADER] Callback post-animación ejecutado para %s" % parametro)

## Actualiza un parámetro específico (usado por tween)
func _actualizar_parametro(parametro: String, valor: float):
	if shader_material:
		shader_material.set_shader_parameter(parametro, valor)

## Establece directamente el valor de un parámetro del shader
func set_parametro(parametro: String, valor) -> void:
	if not shader_material:
		print("❌ [POKEMON_SHADER] No se puede establecer %s: material no inicializado" % parametro)
		return

	shader_material.set_shader_parameter(parametro, valor)
	print("📝 [POKEMON_SHADER] Parámetro %s establecido en %s" % [parametro, valor])

## Imprime el estado actual de los parámetros clave del shader
func debug_estado(etiqueta: String = "") -> void:
	if not shader_material:
		print("❌ [POKEMON_SHADER] No se puede obtener estado: material no inicializado")
		return

	var estado = {
		"efecto_silueta": shader_material.get_shader_parameter("efecto_silueta"),
		"intensidad_silueta": shader_material.get_shader_parameter("intensidad_silueta"),
		"progreso_silueta": shader_material.get_shader_parameter("progreso_silueta"),
		"efecto_parpadeo": shader_material.get_shader_parameter("efecto_parpadeo"),
		"efecto_brillo": shader_material.get_shader_parameter("efecto_brillo"),
		"efecto_contorno": shader_material.get_shader_parameter("efecto_contorno"),
		"efecto_monocromo": shader_material.get_shader_parameter("efecto_monocromo"),
		"alpha_desvanecimiento": shader_material.get_shader_parameter("alpha_desvanecimiento")
	}

	var prefijo = etiqueta if etiqueta != "" else "Estado"
	print("🔍 [POKEMON_SHADER] %s => %s" % [prefijo, estado])

## Elimina el shader del sprite
func limpiar_shader():
	if sprite_node:
		sprite_node.material = null
	shader_material = null
	print("🧹 [POKEMON_SHADER] Shader removido de %s" % sprite_node.name if sprite_node else "sprite")
