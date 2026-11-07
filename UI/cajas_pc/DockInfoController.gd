extends Sprite2D
class_name DockInfoController

## Controlador para el Dock de Información de Pokémon
## 
## Este controlador maneja todo el estado, navegación, animación e input 
## del dock de información, incluyendo:
## - Mostrar/ocultar información de Pokémon
## - Actualizar datos (mote, especie, nivel, sexo, etc.)
## - Gestión de marcas y estados especiales
## - Animaciones del panel de información
## 
## Sigue el patrón de controladores independientes para evitar 
## dependencias y gestionar referencias dinámicamente.

# Referencias a nodos de información
var info_container: Node2D = null
var label_mote: Label = null
var label_especie: Label = null
var label_nivel: Label = null
var label_sexo: Label = null
var label_variocolor: Label = null
var label_objeto: Label = null

# Referencias a marcas
var label_marca_circulo: Label = null
var label_marca_cuadrado: Label = null
var label_marca_triangulo: Label = null
var label_marca_corazon: Label = null

# Referencias a componentes de visualización
var info_anim: AnimatedSprite2D = null  # Animación del panel de información
var pokemon_sprite: AnimatedSprite2D = null  # Sprite del Pokémon
var controlador_principal = null  # Referencia al controlador principal para transiciones

# Variables de estado
var info_visible: bool = false
var pokemon_actual: BasePokemon = null
var tween_animacion: Tween = null

# Señales para comunicación con el controlador principal
signal info_mostrada(pokemon: BasePokemon)
signal info_ocultada()
signal pokemon_actualizado(pokemon: BasePokemon)

func _ready():
	# Inicializar estado del dock
	_inicializar_dock()

## Inicializa el estado del dock de información.
func _inicializar_dock() -> void:
	# Obtener referencias a nodos
	_obtener_referencias()
	
	# Configurar estado inicial
	_ocultar_info()
	
	print("📋 [DOCK INFO] Controlador inicializado")

## Establece la referencia al controlador principal para usar transiciones.
func establecer_controlador_principal(controlador) -> void:
	controlador_principal = controlador
	print("📋 [DOCK INFO] Controlador principal establecido para transiciones")

## Obtiene las referencias a todos los nodos del dock de información.
func _obtener_referencias() -> void:
	# Contenedor principal de información
	info_container = get_node("info")
	
	# Componentes de visualización
	info_anim = get_node("info_anim")
	pokemon_sprite = get_node("PokemonSprite")
	
	# Labels de información básica
	if info_container:
		label_mote = info_container.get_node("mote")
		label_especie = info_container.get_node("nombre_interno")
		label_nivel = info_container.get_node("nivel")
		label_sexo = info_container.get_node("sexo")
		label_variocolor = info_container.get_node("variocolor")
		label_objeto = info_container.get_node("objeto")
		
		# Labels de marcas
		label_marca_circulo = info_container.get_node("marca_circulo")
		label_marca_cuadrado = info_container.get_node("marca_cuadrado")
		label_marca_triangulo = info_container.get_node("marca_triangulo")
		label_marca_corazon = info_container.get_node("marca_corazon")
	
	print("📋 [DOCK INFO] Referencias obtenidas")

## Muestra la información del Pokémon especificado.
func mostrar_info(pokemon: BasePokemon) -> void:
	if not pokemon:
		_ocultar_info()
		return
	
	# Actualizar referencias si es necesario
	if not info_container:
		_obtener_referencias()
	
	# Guardar referencia al Pokémon actual
	pokemon_actual = pokemon
	
	# Hacer visible el dock de información
	if info_container:
		info_container.visible = true
		info_visible = true
	
	# Actualizar PokemonSprite con transiciones si está disponible el controlador principal
	if controlador_principal and controlador_principal.has_method("_mostrar_sprite_pokemon"):
		# Usar el sistema de transiciones del controlador principal
		controlador_principal._mostrar_sprite_pokemon(pokemon)
		print("🎬 [DOCK INFO] Usando transiciones del controlador principal")
	else:
		# Fallback: configuración directa sin transiciones
		configurar_sprite_pokemon(pokemon)
		mostrar_sprite_pokemon()
		print("⚠️ [DOCK INFO] Sin transiciones: usando configuración directa")
	
	# Actualizar todos los datos
	_actualizar_datos_pokemon(pokemon)
	
	# Actualizar animación del info a "encendido"
	activar_animacion_info("encendido")
	
	# Emitir señal
	info_mostrada.emit(pokemon)
	
	print("📋 [DOCK INFO] Mostrando información: %s Nv.%d" % [pokemon.nombre_interno, pokemon.nivel])

## Oculta la información del Pokémon.
func _ocultar_info() -> void:
	if info_container:
		info_container.visible = false
		info_visible = false
	
	# Ocultar sprite del Pokémon con transiciones si está disponible
	if controlador_principal and controlador_principal.has_method("_ocultar_sprite_pokemon"):
		# Usar el sistema de transiciones del controlador principal
		controlador_principal._ocultar_sprite_pokemon()
		print("🎬 [DOCK INFO] Ocultando con transiciones del controlador principal")
	else:
		# Fallback: ocultación directa
		ocultar_sprite_pokemon()
		print("⚠️ [DOCK INFO] Sin transiciones: ocultación directa")
	
	# Cambiar animación a default
	activar_animacion_info("default")
	
	pokemon_actual = null
	
	# Emitir señal
	info_ocultada.emit()
	
	print("📋 [DOCK INFO] Información ocultada")

## Oculta la información (función pública).
func ocultar_info() -> void:
	_ocultar_info()

## Actualiza todos los datos del Pokémon en la interfaz.
func _actualizar_datos_pokemon(pokemon: BasePokemon) -> void:
	# Actualizar mote (apodo) y especie
	if label_mote:
		label_mote.text = pokemon.mote if pokemon.mote != "" else pokemon.nombre
	
	if label_especie:
		label_especie.text = "/" + pokemon.nombre
	
	# Actualizar nivel
	if label_nivel:
		label_nivel.text = "Nv%d" % pokemon.nivel
	
	# Actualizar sexo
	_actualizar_sexo(pokemon)
	
	# Actualizar objeto equipado
	_actualizar_objeto(pokemon)
	
	# Actualizar variocolor (shiny)
	_actualizar_variocolor(pokemon)
	
	# Actualizar marcas
	_actualizar_marcas(pokemon)

## Actualiza la información de sexo del Pokémon.
func _actualizar_sexo(pokemon: BasePokemon) -> void:
	if not label_sexo:
		return
	
	var sexo_texto = ""
	var sexo = pokemon.sexo
	if sexo == "M" or sexo == "macho":
		sexo_texto = "♂"
		label_sexo.modulate = Color(0.175, 0.68, 0.84, 1) # Azul
	elif sexo == "F" or sexo == "hembra":
		sexo_texto = "♀"
		label_sexo.modulate = Color(1, 0.611765, 0.576471, 1) # Rosa

	label_sexo.text = sexo_texto
	label_sexo.visible = sexo_texto != ""

## Actualiza la información del objeto equipado.
func _actualizar_objeto(pokemon: BasePokemon) -> void:
	if not label_objeto:
		return
	
	var objeto_texto: String = ObjetosLlevados.nombre_objeto(pokemon.objeto) if pokemon.objeto != "" and pokemon.objeto != "NONE" else ""

	label_objeto.text = objeto_texto
	label_objeto.visible = objeto_texto != ""

## Actualiza el indicador de variocolor (shiny).
func _actualizar_variocolor(pokemon: BasePokemon) -> void:
	if not label_variocolor:
		return
	
	var es_shiny = false
	if pokemon.has_method("es_shiny"):
		es_shiny = pokemon.es_shiny()
	
	label_variocolor.visible = es_shiny
	print("✨ [DOCK INFO] Variocolor visible: %s" % label_variocolor.visible)

## Actualiza la visibilidad de las marcas del Pokémon.
func _actualizar_marcas(pokemon: BasePokemon) -> void:
	# Leer marcas directamente desde la propiedad del Pokémon
	var marcas_pokemon = pokemon.marcas
	
	# Actualizar visibilidad de cada marca individual
	if label_marca_circulo:
		label_marca_circulo.visible = marcas_pokemon.get("circulo", false)
	if label_marca_cuadrado:
		label_marca_cuadrado.visible = marcas_pokemon.get("cuadrado", false)
	if label_marca_triangulo:
		label_marca_triangulo.visible = marcas_pokemon.get("triangulo", false)
	if label_marca_corazon:
		label_marca_corazon.visible = marcas_pokemon.get("corazon", false)
	
	print("🏷️ [DOCK INFO] Marcas activas: %s" % str(marcas_pokemon))

## Actualiza la información con un nuevo Pokémon (si ya está visible).
func actualizar_pokemon(pokemon: BasePokemon) -> void:
	if info_visible and pokemon:
		pokemon_actual = pokemon
		_actualizar_datos_pokemon(pokemon)
		pokemon_actualizado.emit(pokemon)
		print("📋 [DOCK INFO] Información actualizada: %s" % pokemon.nombre_interno)

## Verifica si la información está actualmente visible.
func esta_visible() -> bool:
	return info_visible

## Obtiene el Pokémon actualmente mostrado.
func obtener_pokemon_actual() -> BasePokemon:
	return pokemon_actual

## Anima la aparición del dock (para futuras mejoras).
func animar_mostrar() -> void:
	if tween_animacion:
		tween_animacion.kill()
	
	# Crear animación de aparición
	tween_animacion = create_tween()
	tween_animacion.set_ease(Tween.EASE_OUT)
	tween_animacion.set_trans(Tween.TRANS_BACK)
	
	# Animar desde transparente a opaco
	if info_container:
		info_container.modulate.a = 0.0
		tween_animacion.tween_property(info_container, "modulate:a", 1.0, 0.3)

## Anima la desaparición del dock (para futuras mejoras).
func animar_ocultar() -> void:
	if tween_animacion:
		tween_animacion.kill()
	
	# Crear animación de desaparición
	tween_animacion = create_tween()
	tween_animacion.set_ease(Tween.EASE_IN)
	tween_animacion.set_trans(Tween.TRANS_QUART)
	
	# Animar de opaco a transparente
	if info_container:
		tween_animacion.tween_property(info_container, "modulate:a", 0.0, 0.2)
		tween_animacion.tween_callback(_finalizar_ocultacion)

## Finaliza la animación de ocultación.
func _finalizar_ocultacion() -> void:
	_ocultar_info()

## Limpia recursos del tween al salir.
func _exit_tree() -> void:
	if tween_animacion and tween_animacion.is_valid():
		tween_animacion.kill()
		tween_animacion = null

## === GESTIÓN DEL SPRITE POKÉMON ===

## Configura el sprite del Pokémon.
func configurar_sprite_pokemon(pokemon_info) -> void:
	if not pokemon_sprite:
		print("❌ [DOCK INFO] PokemonSprite no encontrado")
		return
	
	var nombre_pokemon: String
	# Personalidad del Pokémon concreto (manchas de SPINDA); -1 si solo hay nombre.
	var personalidad: int = -1
	var es_shiny: bool = false

	# Determinar el nombre según el tipo de parámetro
	if pokemon_info is BasePokemon:
		nombre_pokemon = pokemon_info.nombre_interno
		personalidad = pokemon_info.personalidad
		es_shiny = pokemon_info.es_shiny()
	elif pokemon_info is String:
		nombre_pokemon = pokemon_info
	else:
		print("⚠️ [DOCK INFO] Tipo de parámetro no válido para configurar sprite")
		return

	# Configurar el Pokémon usando el método apropiado
	if pokemon_sprite.has_method("configurar_pokemon"):
		pokemon_sprite.configurar_pokemon(nombre_pokemon, PokemonSprite.TipoSprite.FRENTE, es_shiny, personalidad)
		print("🎯 [DOCK INFO] Sprite configurado: %s" % nombre_pokemon)
	elif pokemon_sprite.has_method("set_pokemon"):
		# Si recibimos un BasePokemon, usarlo directamente; si no, crear uno temporal
		var pokemon_para_sprite = pokemon_info if pokemon_info is BasePokemon else BasePokemon.new()
		if not pokemon_info is BasePokemon:
			pokemon_para_sprite.nombre_interno = nombre_pokemon
		pokemon_sprite.set_pokemon(pokemon_para_sprite)
		print("🎯 [DOCK INFO] Sprite configurado (método alternativo): %s" % nombre_pokemon)
	else:
		print("⚠️ [DOCK INFO] No se encontró método para configurar sprite")

## Oculta el sprite del Pokémon.
func ocultar_sprite_pokemon() -> void:
	if pokemon_sprite:
		pokemon_sprite.visible = false
		print("👻 [DOCK INFO] Sprite Pokémon ocultado")

## Muestra el sprite del Pokémon.
func mostrar_sprite_pokemon() -> void:
	if pokemon_sprite:
		pokemon_sprite.visible = true
		print("👁️ [DOCK INFO] Sprite Pokémon mostrado")

## Aplica material shader al sprite del Pokémon.
func aplicar_material_sprite(shader_material: Material) -> void:
	if pokemon_sprite:
		pokemon_sprite.material = shader_material
		print("🎨 [DOCK INFO] Material aplicado al sprite")

## === GESTIÓN DE ANIMACIONES INFO ===

## Activa una animación específica en el info_anim.
func activar_animacion_info(nombre_animacion: String) -> void:
	if not info_anim:
		print("⚠️ [DOCK INFO] Nodo info_anim no encontrado")
		return
	
	# Verificar si la animación existe y reproducirla
	if info_anim.sprite_frames and info_anim.sprite_frames.has_animation(nombre_animacion):
		info_anim.play(nombre_animacion)
		print("🎬 [DOCK INFO] Animación reproducida: %s" % nombre_animacion)
	else:
		print("❌ [DOCK INFO] Animación '%s' no encontrada" % nombre_animacion)

## Configura la animación por defecto.
func configurar_animacion_por_defecto() -> void:
	if info_anim and is_instance_valid(info_anim):
		info_anim.play("default")
		print("🎬 [DOCK INFO] Animación configurada a 'default'")

## Obtiene el nodo PokemonSprite para uso externo si es necesario.
func obtener_pokemon_sprite() -> AnimatedSprite2D:
	return pokemon_sprite

## Obtiene el nodo info_anim para uso externo si es necesario.
func obtener_info_anim() -> AnimatedSprite2D:
	return info_anim
