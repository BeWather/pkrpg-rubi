extends Node2D
class_name DockCajaController

# ===================================
# CONTROLADOR DE DOCK CAJA INDIVIDUAL
# ===================================
# Este script maneja las funcionalidades específicas de cada instancia de dock_caja.tscn
# Evita referencias nulas y centraliza la lógica de cada caja.

# Referencias locales a nodos hijos de esta instancia
@onready var titulo_caja: Node2D = $titulo_caja
@onready var label_nombre_caja: Label = $titulo_caja/lb_nombre
@onready var flecha_izquierda: AnimatedSprite2D = $"flecha-izquierda"
@onready var flecha_derecha: AnimatedSprite2D = $"flecha-derecha"
@onready var sombra_mano: Sprite2D = $SombraMano
@onready var fondo_caja: Sprite2D = $"fondo-grilla"

# Variables de estado de esta caja
var numero_caja: int = 0
var es_caja_activa: bool = false
var slots_pokemon: Array[Node] = []

# Señales para comunicación con el controlador principal
# signal caja_activada(numero_caja: int)
# signal flecha_pulsada(direccion: int)

func _ready():
	# Configurar estado inicial de la caja
	_inicializar_caja()

## Inicializa el estado de la caja.
func _inicializar_caja() -> void:
	# Hacer la sombra de la mano invisible por defecto
	if sombra_mano:
		sombra_mano.visible = false
	
	# Configurar flechas en estado inactivo
	configurar_flechas_inactivas()

## Configura el número de esta caja y actualiza el nombre.
func configurar_caja(numero: int, nombre_caja: String = "") -> void:
	numero_caja = numero
	
	# Actualizar nombre si se proporciona, sino usar formato por defecto
	var nombre_final = nombre_caja if nombre_caja != "" else "Caja %d" % (numero + 1)
	
	if label_nombre_caja:
		label_nombre_caja.text = nombre_final
		print("📝 [DOCK CAJA] Caja %d configurada con nombre: %s" % [numero, nombre_final])

## Activa esta caja (la marca como caja actual).
func activar_caja() -> void:
	es_caja_activa = true
	
	# Configurar flechas activas
	# configurar_flechas_activas()
	
	# Hacer visible la sombra de la mano si existe
	# if sombra_mano:
	# 	sombra_mano.visible = true
	
	print("✅ [DOCK CAJA] Caja %d activada" % numero_caja)
	
	# Emitir señal para notificar al controlador principal
	# caja_activada.emit(numero_caja)

## Desactiva esta caja.
func desactivar_caja() -> void:
	es_caja_activa = false
	
	# Configurar flechas inactivas
	# _configurar_flechas_inactivas()
	
	# # Ocultar la sombra de la mano
	# if sombra_mano:
	# 	sombra_mano.visible = false
	
	# print("💤 [DOCK CAJA] Caja %d desactivada" % numero_caja)

## Configura las flechas en estado activo (con animación).
func configurar_flechas_activas() -> void:
	if flecha_izquierda and is_instance_valid(flecha_izquierda):
		flecha_izquierda.play()
	
	if flecha_derecha and is_instance_valid(flecha_derecha):
		flecha_derecha.play()

## Configura las flechas en estado inactivo (sin animación).
func configurar_flechas_inactivas() -> void:
	if flecha_izquierda and is_instance_valid(flecha_izquierda):
		# print("🛑 [DOCK CAJA] Deteniendo animación flecha izquierda")
		flecha_izquierda.stop()
		flecha_izquierda.frame = 0
	
	if flecha_derecha and is_instance_valid(flecha_derecha):
		# print("🛑 [DOCK CAJA] Deteniendo animación flecha derecha")
		flecha_derecha.stop()
		flecha_derecha.frame = 0

## Actualiza la posición de la sombra de la mano.
func actualizar_posicion_sombra(posicion: Vector2) -> void:
	if sombra_mano and is_instance_valid(sombra_mano):
		sombra_mano.position = posicion

## Muestra u oculta la sombra de la mano.
func configurar_visibilidad_sombra(es_visible: bool) -> void:
	if sombra_mano and is_instance_valid(sombra_mano):
		sombra_mano.visible = es_visible and es_caja_activa

## Obtiene la referencia a la sombra de la mano.
func obtener_sombra() -> Sprite2D:
	return sombra_mano

## Obtiene la referencia al label del nombre.
func obtener_label_nombre() -> Label:
	return label_nombre_caja

## Obtiene la referencia a las flechas.
func obtener_flecha_izquierda() -> AnimatedSprite2D:
	return flecha_izquierda

func obtener_flecha_derecha() -> AnimatedSprite2D:
	return flecha_derecha

## Obtiene todas las referencias importantes de esta caja.
func obtener_referencias() -> Dictionary:
	return {
		"numero_caja": numero_caja,
		"label_nombre": label_nombre_caja,
		"flecha_izquierda": flecha_izquierda,
		"flecha_derecha": flecha_derecha,
		"sombra_mano": sombra_mano,
		"fondo_caja": fondo_caja,
		"es_activa": es_caja_activa
	}

## Agrega un slot de Pokémon a esta caja.
func agregar_slot_pokemon(slot: Node) -> void:
	slots_pokemon.append(slot)

## Limpia todos los slots de esta caja.
func limpiar_slots_pokemon() -> void:
	for slot in slots_pokemon:
		if is_instance_valid(slot):
			if slot.has_method("limpiar"):
				slot.limpiar()
			slot.queue_free()
	slots_pokemon.clear()

## Obtiene los slots de Pokémon de esta caja.
func obtener_slots_pokemon() -> Array[Node]:
	return slots_pokemon

## Busca un slot por coordenadas de grilla.
func buscar_slot_por_coordenadas(x: int, y: int) -> Node:
	var nombre_slot = "slot_%d_%d" % [x, y]
	return get_node_or_null(nombre_slot)

## Busca un slot por índice lineal.
func buscar_slot_por_indice(indice: int) -> Node:
	# Convertir índice lineal a coordenadas de grilla (6 columnas)
	var x = indice % 6
	var y = int(indice / 6.0)  # División entera explícita
	return buscar_slot_por_coordenadas(x, y)

## Método de limpieza al destruir la caja.
func limpiar() -> void:
	print("🧹 [DOCK CAJA] Limpiando caja %d" % numero_caja)
	limpiar_slots_pokemon()
	
	# Limpiar referencias
	label_nombre_caja = null
	flecha_izquierda = null
	flecha_derecha = null
	sombra_mano = null
	fondo_caja = null
