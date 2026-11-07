extends Control
class_name SlotPokemon

# ========================================
# SLOT INDIVIDUAL PARA POKÉMON EN CAJAS PC
# ========================================

# Señales para comunicación con el controlador principal
signal slot_seleccionado(slot_pokemon: SlotPokemon)
signal slot_hover_iniciado(slot_pokemon: SlotPokemon)
signal slot_hover_terminado(slot_pokemon: SlotPokemon)

# Referencias a nodos (se configurarán en _ready)
@onready var fondo_slot: NinePatchRect = $FondoSlot
@onready var icono_pokemon: TextureRect = $IconoPokemon
@onready var indicador_estado: TextureRect = $IndicadorEstado
@onready var marco_seleccion: NinePatchRect = $MarcoSeleccion

# Estados visuales del slot
enum EstadoVisual {
	VACIO,           # Slot sin Pokémon
	OCUPADO,         # Slot con Pokémon
	SELECCIONADO,    # Slot actualmente seleccionado por el cursor
	MARCADO,         # Slot marcado para intercambio
	HOVER            # Mouse sobre el slot (para futuro)
}

# Variables del slot
var estado_actual: EstadoVisual = EstadoVisual.VACIO
var pokemon_asignado: BasePokemon = null
var posicion_caja: int = -1      # Qué caja (0-15)
var posicion_slot: int = -1      # Qué slot en la caja (0-29)
var indice_grilla: Vector2i      # Posición en la grilla (x: 0-5, y: 0-4)

# Configuración visual
const TAMAÑO_SLOT: Vector2 = Vector2(24, 24)
const COLOR_VACIO: Color = Color(0.8, 0.8, 0.8, 0.3)
const COLOR_OCUPADO: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_SELECCIONADO: Color = Color(1.0, 1.0, 0.0, 1.0)
const COLOR_MARCADO: Color = Color(0.0, 1.0, 0.0, 0.8)

# Recursos de iconos
var carpeta_iconos: String = "res://graficos/Icons/"
var icono_cargado: Texture2D = null

# Cache estático de iconos para optimización (compartido entre todos los slots)
static var cache_iconos: Dictionary = {}  # [numero_nacional] -> AtlasTexture

func _ready() -> void:
	# Configurar tamaño del slot
	custom_minimum_size = TAMAÑO_SLOT
	size = TAMAÑO_SLOT
	
	# Inicializar estado visual
	_aplicar_estado_visual()
	
	# Conectar señales si existen los nodos
	_conectar_señales_interaccion()

## Conecta las señales de interacción del mouse (DESHABILITADO).
func _conectar_señales_interaccion() -> void:
	# Las señales del mouse están deshabilitadas para usar solo navegación por teclado
	# El mouse_filter ya está configurado como MOUSE_FILTER_IGNORE en pantalla_cajas_pc.gd
	pass

# ===================================
# API PRINCIPAL - GESTIÓN DEL POKÉMON
# ===================================

## Configura la información básica del slot.
func configurar_slot(caja: int, slot: int, pos_grilla: Vector2i) -> void:
	posicion_caja = caja
	posicion_slot = slot
	indice_grilla = pos_grilla
	
	# print("🔧 [SLOT] Configurado: Caja %d, Slot %d, Grilla (%d,%d)" % [
	# 	caja, slot, pos_grilla.x, pos_grilla.y
	# ])

## Asigna un Pokémon al slot y actualiza la visualización.
func asignar_pokemon(pokemon: BasePokemon) -> void:
	pokemon_asignado = pokemon
	
	if pokemon:
		estado_actual = EstadoVisual.OCUPADO
		_cargar_datos_pokemon(pokemon)
		# print("🐾 [SLOT] Pokémon asignado: %s Nv.%d" % [pokemon.nombre_interno, pokemon.nivel])
	else:
		estado_actual = EstadoVisual.VACIO
		_limpiar_datos_pokemon()
		# print("🔧 [SLOT] Slot vaciado")
	
	_aplicar_estado_visual()

## Devuelve el Pokémon asignado al slot.
func obtener_pokemon() -> BasePokemon:
	return pokemon_asignado

## Verifica si el slot está vacío.
func esta_vacio() -> bool:
	return pokemon_asignado == null

## Devuelve la posición del slot (caja, slot).
func obtener_posicion() -> Vector2i:
	return Vector2i(posicion_caja, posicion_slot)

## Devuelve la posición en la grilla (x, y).
func obtener_posicion_grilla() -> Vector2i:
	return indice_grilla

# ===================================
# ESTADOS VISUALES
# ===================================

## Cambia el estado visual del slot.
func establecer_estado(nuevo_estado: EstadoVisual) -> void:
	if estado_actual != nuevo_estado:
		estado_actual = nuevo_estado
		_aplicar_estado_visual()

## Aplica el estado visual actual a todos los elementos.
func _aplicar_estado_visual() -> void:
	if not fondo_slot:
		return
	
	match estado_actual:
		EstadoVisual.VACIO:
			_aplicar_estilo_vacio()
		EstadoVisual.OCUPADO:
			_aplicar_estilo_ocupado()
		EstadoVisual.SELECCIONADO:
			_aplicar_estilo_seleccionado()
		EstadoVisual.MARCADO:
			_aplicar_estilo_marcado()
		EstadoVisual.HOVER:
			_aplicar_estilo_hover()

## Aplica el estilo visual para slot vacío.
func _aplicar_estilo_vacio() -> void:
	fondo_slot.modulate = COLOR_VACIO
	icono_pokemon.visible = false
	indicador_estado.visible = false
	marco_seleccion.visible = false

## Aplica el estilo visual para slot ocupado.
func _aplicar_estilo_ocupado() -> void:
	fondo_slot.modulate = COLOR_OCUPADO
	icono_pokemon.visible = true
	indicador_estado.visible = pokemon_asignado and pokemon_asignado.estado != -1
	marco_seleccion.visible = false

## Aplica el estilo visual para slot seleccionado.
func _aplicar_estilo_seleccionado() -> void:
	fondo_slot.modulate = COLOR_SELECCIONADO
	marco_seleccion.visible = true
	marco_seleccion.modulate = COLOR_SELECCIONADO
	
	# Mantener visibilidad de elementos si hay Pokémon
	if pokemon_asignado:
		icono_pokemon.visible = true
		indicador_estado.visible = pokemon_asignado.estado != -1

## Aplica el estilo visual para slot marcado para intercambio.
func _aplicar_estilo_marcado() -> void:
	fondo_slot.modulate = COLOR_MARCADO
	marco_seleccion.visible = true
	marco_seleccion.modulate = COLOR_MARCADO
	
	# Mantener visibilidad de elementos si hay Pokémon
	if pokemon_asignado:
		icono_pokemon.visible = true

## Aplica el estilo visual para hover del mouse.
func _aplicar_estilo_hover() -> void:
	fondo_slot.modulate = Color(1.2, 1.2, 1.0, 1.0)  # Ligeramente más brillante

# ===================================
# CARGA DE DATOS DEL POKÉMON
# ===================================

## Carga y muestra los datos del Pokémon en el slot.
func _cargar_datos_pokemon(pokemon: BasePokemon) -> void:
	if not pokemon:
		return
	
	# Cargar icono del Pokémon
	_cargar_icono_pokemon(pokemon.numero_nacional)
	
	# Mostrar indicador de estado (envenenado, paralizado, etc.)
	_actualizar_indicador_estado(pokemon.estado)

## Carga el icono del Pokémon desde los recursos de graficos/Icons/.
func _cargar_icono_pokemon(numero_nacional: int) -> void:
	if not icono_pokemon:
		return
	
	# Verificar cache primero para optimización
	var cache_key = "pokemon_%d" % numero_nacional
	if cache_key in cache_iconos:
		icono_pokemon.texture = cache_iconos[cache_key]
		icono_cargado = cache_iconos[cache_key]
		# print("📋 [SLOT] Icono desde cache: Pokémon %03d" % numero_nacional)
		return
	
	# Manejar caso especial de huevo Pokémon (número 0)
	if numero_nacional == 0:
		_cargar_icono_huevo()
		return
	
	# Construir ruta del icono con formato icon000.png
	var ruta_icono = "%sicon%03d.png" % [carpeta_iconos, numero_nacional]
	
	# Intentar cargar el icono
	if ResourceLoader.exists(ruta_icono):
		var texture_completa = load(ruta_icono) as Texture2D
		
		# Crear AtlasTexture para extraer solo el primer frame (32x32)
		var atlas = AtlasTexture.new()
		atlas.atlas = texture_completa
		atlas.region = Rect2(0, 0, 32, 32)  # Solo el primer frame de 64x32
		
		# Asignar y cachear
		icono_pokemon.texture = atlas
		icono_cargado = atlas
		cache_iconos[cache_key] = atlas  # Guardar en cache para futuros usos
		
		# print("🖼️ [SLOT] Icono cargado y cacheado: %s (frame 1)" % ruta_icono)
	else:
		# Usar icono por defecto si no existe
		_usar_icono_por_defecto()
		print("⚠️ [SLOT] Icono no encontrado: %s, usando por defecto" % ruta_icono)

## Usa un icono por defecto cuando no se encuentra el específico.
func _usar_icono_por_defecto() -> void:
	var cache_key = "default"
	
	# Verificar cache para icono por defecto
	if cache_key in cache_iconos:
		icono_pokemon.texture = cache_iconos[cache_key]
		icono_cargado = cache_iconos[cache_key]
		print("📋 [SLOT] Icono por defecto desde cache")
		return
	
	var ruta_default = "res://graficos/Icons/icon000.png"  # Icono de Pokémon desconocido/MissingNo
	if ResourceLoader.exists(ruta_default):
		var texture_completa = load(ruta_default) as Texture2D
		
		# Crear AtlasTexture para el primer frame
		var atlas = AtlasTexture.new()
		atlas.atlas = texture_completa
		atlas.region = Rect2(0, 0, 32, 32)
		
		icono_pokemon.texture = atlas
		icono_cargado = atlas
		cache_iconos[cache_key] = atlas  # Cachear icono por defecto
		
		print("🔧 [SLOT] Icono por defecto cargado y cacheado: %s" % ruta_default)
	else:
		# Si ni siquiera existe el icono por defecto, usar textura vacía
		icono_pokemon.texture = null
		icono_cargado = null

## Carga el icono especial para huevos Pokémon.
func _cargar_icono_huevo() -> void:
	var cache_key = "egg"
	
	# Verificar cache para huevo
	if cache_key in cache_iconos:
		icono_pokemon.texture = cache_iconos[cache_key]
		icono_cargado = cache_iconos[cache_key]
		print("📋 [SLOT] Icono de huevo desde cache")
		return
	
	var ruta_huevo = "res://graficos/Icons/iconEgg.png"
	if ResourceLoader.exists(ruta_huevo):
		var texture_completa = load(ruta_huevo) as Texture2D
		
		# Para el huevo, usar la textura completa o solo el primer frame según el diseño
		var atlas = AtlasTexture.new()
		atlas.atlas = texture_completa
		atlas.region = Rect2(0, 0, 32, 32)
		
		icono_pokemon.texture = atlas
		icono_cargado = atlas
		cache_iconos[cache_key] = atlas  # Cachear icono de huevo
		
		print("🥚 [SLOT] Icono de huevo cargado y cacheado: %s" % ruta_huevo)
	else:
		_usar_icono_por_defecto()

## Actualiza el indicador visual del estado del Pokémon.
func _actualizar_indicador_estado(estado: int) -> void:
	if not indicador_estado:
		return
	
	# -1 = Normal (sin estado), otros valores = estados especiales
	if estado == -1:
		indicador_estado.visible = false
	else:
		indicador_estado.visible = true
		# TODO: Cargar sprite específico según el estado
		# Por ejemplo: paralizado, envenenado, quemado, etc.

## Limpia todos los datos visuales del Pokémon.
func _limpiar_datos_pokemon() -> void:
	if icono_pokemon:
		icono_pokemon.texture = null
	if indicador_estado:
		indicador_estado.visible = false
	
	icono_cargado = null

# ===================================
# GESTIÓN DE CACHE DE ICONOS
# ===================================

## Limpia el cache de iconos para liberar memoria.
static func limpiar_cache_iconos() -> void:
	cache_iconos.clear()
	print("🗑️ [SLOT] Cache de iconos limpiado")

## Devuelve el tamaño actual del cache de iconos.
static func obtener_tamaño_cache() -> int:
	return cache_iconos.size()

## Precarga iconos comunes para mejorar rendimiento.
static func precargar_iconos_comunes() -> void:
	# Lista de Pokémon más comunes para precargar
	var pokemon_comunes = [1, 4, 7, 25, 133, 134, 135, 136, 150, 151]  # Bulbasaur, Charmander, Squirtle, Pikachu, Eevees, etc.
	
	for numero in pokemon_comunes:
		var cache_key = "pokemon_%d" % numero
		if not cache_key in cache_iconos:
			var ruta_icono = "res://graficos/Icons/icon%03d.png" % numero
			if ResourceLoader.exists(ruta_icono):
				var texture_completa = load(ruta_icono) as Texture2D
				var atlas = AtlasTexture.new()
				atlas.atlas = texture_completa
				atlas.region = Rect2(0, 0, 32, 32)
				cache_iconos[cache_key] = atlas
	
	print("⚡ [SLOT] %d iconos comunes precargados" % pokemon_comunes.size())

# ===================================
# UTILIDADES Y DEBUG
# ===================================

## Devuelve información de debug del slot.
func obtener_info_debug() -> String:
	var info = []
	info.append("=== SLOT DEBUG ===")
	info.append("Posición: Caja %d, Slot %d" % [posicion_caja, posicion_slot])
	info.append("Grilla: (%d, %d)" % [indice_grilla.x, indice_grilla.y])
	info.append("Estado: %s" % EstadoVisual.keys()[estado_actual])
	
	if pokemon_asignado:
		info.append("Pokémon: %s Nv.%d" % [pokemon_asignado.nombre_interno, pokemon_asignado.nivel])
	else:
		info.append("Pokémon: [VACÍO]")
	
	return "\n".join(info)

## Verifica si el slot tiene una posición válida asignada.
func es_posicion_valida() -> bool:
	return posicion_caja >= 0 and posicion_slot >= 0
