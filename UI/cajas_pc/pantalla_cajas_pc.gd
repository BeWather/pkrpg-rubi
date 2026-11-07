extends Control
class_name PantallaCajasPC

# ===================================
# SISTEMA DE CAJAS DEL PC - CONTROLADOR PRINCIPAL
# ===================================
#
# TECLAS DE DEBUG (solo en debug builds):
# F1 - Mostrar información detallada de todas las cajas
# F2 - Mostrar información de la caja actual
# F3 - Verificar especies duplicadas
# F4 - Estadísticas rápidas del sistema
#

# Señales para comunicación con el exterior
signal caja_cerrada
signal pokemon_intercambiado(origen_caja: int, origen_slot: int, destino_caja: int, destino_slot: int)
signal pokemon_depositado(equipo_index: int, caja: int, slot: int)
signal pokemon_retirado(caja: int, slot: int, equipo_index: int)

# Referencias a nodos de la escena
@onready var mano: AnimatedSprite2D = $mano
@onready var eje_cajas: Node2D = $EjeCajas  # Contenedor principal de todas las cajas
@onready var dock_equipo_controller: Node = $"Dock-equipo"  # Controlador del dock del equipo Pokémon

# Referencias a nodos de UI adicionales (actualizadas dinámicamente)
var dock_caja_actual: DockCajaController = null  # Controlador de la caja actualmente activa
var sombra: Sprite2D = null  # Referencia dinámica a la sombra de la caja actual
var flecha_izquierda: AnimatedSprite2D = null  # Referencia dinámica a flecha izquierda
var flecha_derecha: AnimatedSprite2D = null  # Referencia dinámica a flecha derecha
var label_nombre_caja: Label = null  # Referencia dinámica al label del nombre
@onready var dock_info_controller: Node = $"DockInfo"  # Controlador del dock de información
@onready var boton_cerrar: AnimatedSprite2D = $"bt-cerrar"

# Menú emergente para opciones
@onready var menu_pc: Control = $MenuPC

# Configuración de la grilla
const SLOTS_HORIZONTAL: int = 6
const SLOTS_VERTICAL: int = 5
const SLOTS_TOTAL: int = SLOTS_HORIZONTAL * SLOTS_VERTICAL  # 30 slots

# Posiciones base para la navegación (basado en tu configuración)
const POSICION_BASE_MANO: Vector2 = Vector2(100, 32)
const POSICION_BASE_SOMBRA: Vector2 = Vector2(91, 48)
const ESPACIADO_SLOT: Vector2 = Vector2(24, 24)  # Espaciado entre slots
const POSICION_BASE_GRILLA: Vector2 = Vector2(88, 36)  # Donde empieza la grilla

# Posiciones especiales de la UI para navegación avanzada
const POSICION_NOMBRE_CAJA: Vector2 = Vector2(162, 12)     # Posición sobre el nombre de la caja
const POSICION_BOTON_EQUIPO: Vector2 = Vector2(120, 14)    # Posición sobre botón equipo Pokémon
const POSICION_BOTON_CERRAR: Vector2 = Vector2(208, 14)    # Posición sobre botón cerrar

# Constantes para animación de cambio de caja (código legacy - a eliminar)
const DISTANCIA_ENTRE_CAJAS: int = 192  # 156 (ancho) + 32 (espacio) + 4 (margen)
const POSICION_CAJA_ACTUAL: Vector2 = Vector2(0, 0)  # Posición de la caja actual
const POSICION_CAJA_DERECHA: Vector2 = Vector2(DISTANCIA_ENTRE_CAJAS, 0)  # Caja derecha
const POSICION_CAJA_IZQUIERDA: Vector2 = Vector2(-DISTANCIA_ENTRE_CAJAS, 0)  # Caja izquierda

# Posiciones del cursor en el equipo Pokémon
# const POSICION_EQUIPO_SLOT1: Vector2 = Vector2(105, 52)
# const POSICION_EQUIPO_SLOT2: Vector2 = Vector2(152, 4)
# const POSICION_EQUIPO_SLOT3: Vector2 = Vector2(152, 28)
# const POSICION_EQUIPO_SLOT4: Vector2 = Vector2(152, 52)
# const POSICION_EQUIPO_SLOT5: Vector2 = Vector2(152, 76)
# const POSICION_EQUIPO_SLOT6: Vector2 = Vector2(152, 100)
# const POSICION_EQUIPO_SALIR: Vector2 = Vector2(152, 132)

# Grilla de slots (array bidimensional para fácil acceso)
var grilla_slots: Array[Array] = []  # [fila][columna] -> SlotPokemon
var slots_lista: Array[SlotPokemon] = []  # Lista lineal de todos los slots (0-29)

# Variables de estado del cursor
var cursor_x: int = 0  # Posición X en la grilla (0-5)
var cursor_y: int = 0  # Posición Y en la grilla (0-4)
var cursor_activo: bool = false

# Estados de navegación avanzada
enum ModoNavegacion {
	GRILLA,          # Navegando en la grilla de slots (0-29)
	NOMBRE_CAJA,     # Cursor sobre nombre de caja
	BOTON_EQUIPO,    # Cursor sobre botón de equipo
	BOTON_CERRAR,    # Cursor sobre botón de cerrar
	EQUIPO_POKEMON   # Navegando en el equipo Pokémon
}

var modo_navegacion: ModoNavegacion = ModoNavegacion.GRILLA
var columna_guardada: int = 0  # Para recordar la columna al volver de elementos UI

# Variables del equipo Pokémon - Ahora manejadas por DockEquipoController
# Las variables de estado del equipo están en el controlador

# Variables del sistema de cajas
var caja_actual: int = 0  # Caja actualmente visible (0-13)
var pokemon_seleccionado: BasePokemon = null
var slot_seleccionado: Vector2i = Vector2i(-1, -1)  # -1,-1 significa ninguno seleccionado
var modo_intercambio: bool = false

# Variables para el modo MOVER
## SELECT: A ejecuta directamente la primera opción del menú (pokeruby
## gUnknown_020384E9); empieza desactivado cada vez que se abre la pantalla.
var movimiento_rapido: bool = false
var modo_mover_activo: bool = false  # Indica si la mano lleva un Pokémon
## Pokémon que lleva la mano: la MISMA instancia (se mueve, no se copia). Mientras
## lo lleva no está ni en el equipo ni en ninguna caja.
var modo_mover_basepokemon: BasePokemon = null
var modo_mover_sprite = null  # Sprite del Pokémon que sigue la mano
var mostrando_mensaje_pokemon: bool = false  # Indica si se está mostrando mensaje "¡Tienes un POKéMON!"

# Referencia al gestor de cajas PC
var gestor_cajas: CajasPC = null

# Equipo Pokémon (6 slots)
var equipo_pokemon: Array[BasePokemon] = []

# Variables para animaciones
var tween_cursor: Tween
var animacion_activa: bool = false

# Variables para transición de sprite Pokémon
var tween_sprite: Tween
var sprite_animacion_activa: bool = false
var sprite_pokemon_actual: String = ""  # Para evitar transiciones innecesarias
var sprite_material_shader: ShaderMaterial = null  # Material con shader para transición
var noise_texture: ImageTexture = null  # Textura de ruido generada

# Variables para animación de cambio de caja con desplazamiento
var tween_cambio_caja: Tween
var animacion_cambio_caja_activa: bool = false
const DISTANCIA_DESPLAZAMIENTO: int = 192  # Distancia de animación entre cajas
const DURACION_ANIMACION_CAJA: float = 0.3  # Duración de la animación
const POSICION_CAJA_CENTRO: Vector2 = Vector2(0, 0)  # Posición central de la caja visible

# Sistema de múltiples cajas instanciadas
var instancias_cajas: Array[Node2D] = []  # Array con todas las instancias de DockCaja
## Total de cajas: pokeruby TOTAL_BOXES_COUNT (= SistemaGuardado.TOTAL_CAJAS_PC
## = CajasPC.MAX_CAJAS). Ni la navegación ni DEJAR pueden ir más allá.
const TOTAL_CAJAS: int = 14
var escena_dock_caja: PackedScene = null  # Escena a instanciar

# Operación con la que se abrió la pantalla (menú del PC de Ruby).
const OPERACION_SACAR: int = 0  # WITHDRAW
const OPERACION_DEJAR: int = 1  # DEPOSIT
const OPERACION_MOVER: int = 2  # MOVE
var operacion: int = OPERACION_MOVER

# Textos oficiales de la ROM española (AXVS), pokemon_storage_system de Ruby.
const TEXTO_SALIR_CAJA: String = "Salir de la CAJA."
const TEXTO_MAS_CAMBIOS: String = "¿Hacer más cambios?"
const OPCIONES_MOVIMIENTO_RAPIDO: Array[String] = ["DEJAR", "SACAR", "MOVER", "CAMBIO", "COLOCAR"]
const TEXTURA_MANO: Texture2D = preload("res://UI/cajas_pc/mano.png")
const TEXTURA_MANO_RAPIDA: Texture2D = preload("res://UI/cajas_pc/mano_rapida.png")
const TEXTO_DEJAR_EN_CAJA: String = "¿Dejar en qué CAJA?"
const TEXTO_CAJA_LLENA: String = "La CAJA está llena."
const TEXTO_ULTIMO_POKEMON: String = "¡Ése es tu último POKéMON!"
const TEXTO_EQUIPO_COMPLETO: String = "¡Tu equipo está completo!"
const TEXTO_LLEVAS_POKEMON: String = "¡Llevas un POKéMON!"
const TEXTO_CUAL_ELEGIR: String = "¿Cuál vas a elegir?"
const SONIDO_FALLO: String = "SE_FAILURE"

## Secuencias encadenadas (SACAR, CAMBIO...): bloquean el input de principio a fin.
var secuencia_activa: bool = false
## Origen del Pokémon que lleva la mano, para devolverlo si la pantalla se
## cierra a la fuerza: {"caja": int, "slot": int} o {"equipo": int}.
var origen_pokemon_sostenido: Dictionary = {}
## Caja en la que empieza "¿Dejar en qué CAJA?": la 0 la primera vez y luego
## la última elegida en esta sesión (aunque estuviera llena).
var caja_selector_dejar: int = 0
## Qué pregunta SÍ/NO está pendiente: "salir" o "mas_cambios".
var confirmacion_pendiente: String = ""
## Aviso que solo se cierra con A/B (no con la cruceta).
var mensaje_solo_ab: bool = false
## Acción a ejecutar al cerrar el aviso actual.
var al_cerrar_mensaje: Callable = Callable()
## Evita emitir `caja_cerrada` dos veces.
var cajas_cerradas: bool = false

# Variables para navegación continua
var navegacion_timer: Timer
var tecla_presionada: String = ""

# Variables para animación de "MOVER"
var tween_mano_mover: Tween
var animacion_mover_activa: bool = false

# Variables para animación de "COLOCAR"
var tween_mano_colocar: Tween
var animacion_colocar_activa: bool = false

# Variables para animación del dock del equipo
var animacion_dock_equipo_activa: bool = false

# Variables para animación de reorganización de iconos del equipo
var tween_reorganizacion_equipo: Tween
var animacion_reorganizacion_activa: bool = false
const DURACION_ANIMACION_REORGANIZACION: float = 2.3

var navegacion_inicial_delay: float = 0.5  # Delay inicial antes de repetir
var navegacion_repeat_delay: float = 0.1   # Delay entre repeticiones

# Variables para cooldown de input al cerrar menús
var input_cooldown_activo: bool = false
var tecla_cancelar_presionada: bool = false
var tecla_accion_presionada: bool = false

# Variables para pantalla_info
var pantalla_info_activa: PantallaInfoPokemon = null
var pantalla_info_indice_inicial: int = -1  # Slot inicial a mostrar en pantalla_info

func _ready() -> void:
	print("🖥️ [CAJAS PC] Inicializando pantalla de cajas...")
	_aplicar_textura_mano()

	# Cargar la escena de dock_caja
	escena_dock_caja = preload("res://UI/cajas_pc/dock_caja.tscn")

	# Inicializar todas las instancias de cajas
	_inicializar_instancias_cajas()

	# Inicializar sprites como ocultos - Delegado al controlador
	if dock_info_controller:
		dock_info_controller.ocultar_sprite_pokemon()
		sprite_pokemon_actual = ""

	# Generar textura de ruido para transiciones
	_generar_textura_ruido()

	# Crear material con shader para transiciones
	_inicializar_shader_transicion()

	# Inicializar el gestor de cajas PC
	_inicializar_gestor_cajas()

	# Conectar señales del controlador de equipo
	_conectar_senales_equipo()

	# Conectar señales del menú PC
	_conectar_senales_menu_pc()

	# Establecer referencia para transiciones en DockInfoController
	if dock_info_controller and dock_info_controller.has_method("establecer_controlador_principal"):
		dock_info_controller.establecer_controlador_principal(self)
		print("✅ [CAJAS PC] Referencia establecida en DockInfoController para transiciones")

	# Crear la grilla de slots
	_crear_grilla_slots()

	# Configurar posición inicial del cursor
	_configurar_cursor_inicial()

	# Conectar señales si es necesario
	_conectar_señales()

	# Crear timer para navegación continua
	_crear_timer_navegacion()

	# Cargar datos en todas las cajas
	_cargar_todas_las_cajas()

	# Actualizar referencias de la caja actual
	_actualizar_referencias_slots_caja_actual()

	# Actualizar visualización de slots del equipo
	# _actualizar_slots_equipo()

	# Validar nodos de sprite
	_validar_nodos_sprite()

	# Actualizar sprite inicial después de cargar datos
	_actualizar_sprite_pokemon()

	# Configurar el nombre de la caja inicial
	_configurar_nombre_caja_inicial()

	# Debug: verificar estado del sistema
	# _debug_verificar_estado_cajas()

	print("✅ [CAJAS PC] Pantalla inicializada correctamente")

## Configura el nombre inicial de la primera caja
func _configurar_nombre_caja_inicial() -> void:
	if not gestor_cajas or not dock_caja_actual:
		return

	# Obtener y configurar el nombre de la caja inicial
	var nombre_caja = gestor_cajas.obtener_nombre_caja(caja_actual)
	label_nombre_caja.text = nombre_caja

## Limpia recursos al salir del árbol de nodos.
func _exit_tree() -> void:
	print("🧹 [CAJAS PC] Limpiando recursos...")

	# Si la pantalla se libera con un Pokémon en la mano (p. ej. el PC se cierra
	# desde fuera sin pasar por cerrar_caja), devolverlo antes de que se pierda.
	if esta_en_modo_mover():
		_devolver_pokemon_sostenido()
		_sincronizar_con_sistema_guardado()

	# Detener tweens activos
	if tween_cambio_caja and tween_cambio_caja.is_valid():
		tween_cambio_caja.kill()
		tween_cambio_caja = null

	if tween_cursor and tween_cursor.is_valid():
		tween_cursor.kill()
		tween_cursor = null

	if tween_sprite and tween_sprite.is_valid():
		tween_sprite.kill()
		tween_sprite = null

	if tween_mano_mover and tween_mano_mover.is_valid():
		tween_mano_mover.kill()
		tween_mano_mover = null

	if tween_mano_colocar and tween_mano_colocar.is_valid():
		tween_mano_colocar.kill()
		tween_mano_colocar = null

	# El tween del equipo ahora es manejado por DockEquipoController

	# Limpiar timer de navegación
	if navegacion_timer and is_instance_valid(navegacion_timer):
		navegacion_timer.queue_free()
		navegacion_timer = null

	# Limpiar sprite del Pokémon en modo MOVER
	if modo_mover_sprite and is_instance_valid(modo_mover_sprite):
		modo_mover_sprite.queue_free()
		modo_mover_sprite = null

	# Limpiar pantalla de información activa
	if pantalla_info_activa and is_instance_valid(pantalla_info_activa):
		if pantalla_info_activa.pantalla_cerrada.is_connected(_on_pantalla_info_cerrada):
			pantalla_info_activa.pantalla_cerrada.disconnect(_on_pantalla_info_cerrada)
		pantalla_info_activa.queue_free()
		pantalla_info_activa = null

	print("✅ [CAJAS PC] Recursos limpiados")

## Conecta las señales del controlador de equipo.
func _conectar_senales_equipo() -> void:
	if dock_equipo_controller:
		# Conectar señal para saltar a la grilla
		# dock_equipo_controller.saltar_a_grilla.connect(_manejar_salto_a_grilla)
		# Conectar señal para cuando el equipo se ha cerrado completamente
		dock_equipo_controller.equipo_cerrado.connect(_on_equipo_cerrado)
		# Conectar señal para cuando cambia el slot del equipo
		dock_equipo_controller.slot_cambiado.connect(_on_slot_equipo_cambiado)
		# Conectar señales de animación para bloqueo de input
		dock_equipo_controller.animacion_iniciada.connect(_on_animacion_equipo_iniciada)
		dock_equipo_controller.animacion_terminada.connect(_on_animacion_equipo_terminada)
		print("✅ [EQUIPO] Señales del controlador conectadas")

	# Conectar señales del controlador de información
	if dock_info_controller:
		# Las señales del dock info se pueden usar para futuras funcionalidades
		print("✅ [INFO] Controlador de información conectado")

## Conecta las señales del controlador de menú PC.
func _conectar_senales_menu_pc() -> void:
	if menu_pc and menu_pc.has_signal("opcion_seleccionada"):
		menu_pc.opcion_seleccionada.connect(_on_menu_pc_opcion_seleccionada)
		menu_pc.confirmacion_respondida.connect(_on_confirmacion_respondida)
		menu_pc.caja_elegida.connect(_on_caja_elegida)
		print("✅ [MENU PC] Señal opcion_seleccionada conectada")
	else:
		print("⚠️ [MENU PC] No se pudo conectar la señal - menu_pc no encontrado o señal inexistente")

## Maneja el salto desde el equipo a la grilla.
func _manejar_salto_a_grilla() -> void:
	print("🔄 [EQUIPO → GRILLA] Saltando desde equipo a grilla (0,0)")

	# Cambiar modo de navegación
	modo_navegacion = ModoNavegacion.GRILLA
	cursor_x = 0
	cursor_y = 0

	# Actualizar cursor y sprite
	_actualizar_posicion_cursor()
	_actualizar_sprite_pokemon()

## Inicializa el gestor de cajas PC con datos del sistema de guardado.
func _inicializar_gestor_cajas() -> void:
	# Crear instancia del gestor de cajas
	gestor_cajas = CajasPC.new()

	# Cargar datos desde el sistema de guardado
	_cargar_datos_desde_sistema_guardado()

	# DEBUG: Verificar que el equipo se cargó correctamente
	var equipo_actual = dock_equipo_controller.obtener_equipo_completo()
	print("🔍 [DEBUG] Después de cargar equipo - Size: %d" % equipo_actual.size())
	for i in range(equipo_actual.size()):
		if equipo_actual[i]:
			print("🔍 [DEBUG]   equipo_pokemon[%d]: %s" % [i, equipo_actual[i].nombre_interno])
		else:
			print("🔍 [DEBUG]   equipo_pokemon[%d]: null" % i)

	# Actualizar visualización de slots del equipo
	_actualizar_slots_equipo()
	# Array legacy usado por DATOS en el equipo.
	_sincronizar_equipo_desde_controlador()

	print("📦 [CAJAS PC] Gestor de cajas inicializado")

## Carga datos desde el sistema de guardado real.
func _cargar_datos_desde_sistema_guardado() -> void:
	print("💾 [CAJAS PC] Cargando datos desde sistema de guardado...")

	# Verificar si existe el sistema de guardado
	var sistema_guardado = _obtener_sistema_guardado()
	if not sistema_guardado:
		print("⚠️ [CAJAS PC] Sistema de guardado no disponible, generando datos de prueba...")
		# _generar_datos_iniciales_prueba()
		return

	# Inicializar cajas PC en el sistema de guardado si no existen
	sistema_guardado.inicializar_cajas_pc()

	# Cargar datos desde el sistema de guardado
	# El sistema de guardado ya se encarga de generar datos si están vacíos
	print("� [CAJAS PC] Cargando datos desde sistema de guardado...")
	_cargar_datos_existentes(sistema_guardado)

## Obtiene referencia al sistema de guardado.
func _obtener_sistema_guardado():
	# Primero intentar el nodo en el árbol
	if is_inside_tree():
		var sistema_guardado = get_tree().root.get_node_or_null("SistemaGuardado")
		if sistema_guardado:
			return sistema_guardado

	# Fallback: variable global
	if typeof(SistemaGuardado) != TYPE_NIL:
		return SistemaGuardado

	return null

## Genera datos iniciales de prueba y los guarda.
# func _generar_datos_iniciales_con_guardado(sistema_guardado) -> void:
# 	print("🎲 [CAJAS PC] Generando datos iniciales con guardado...")

# 	# Generar equipo Pokémon de prueba
# 	_generar_equipo_inicial(sistema_guardado)

# 	# Generar datos de cajas PC
# 	sistema_guardado.generar_datos_prueba_cajas_pc()

# 	# Cargar datos en el gestor de cajas
# 	var cajas_datos = sistema_guardado.obtener_cajas_pc()
# 	gestor_cajas.cargar_cajas_desde_datos(cajas_datos)

# 	# Cargar equipo en el controlador del dock
# 	var equipo_datos = sistema_guardado.datos_vivos.equipo_pokemon
# 	# Convertir Array genérico a Array[BasePokemon] para cumplir con el tipo esperado
# 	var equipo_tipado: Array[BasePokemon] = []
# 	for pokemon in equipo_datos:
# 		if pokemon is BasePokemon:
# 			equipo_tipado.append(pokemon)
# 	dock_equipo_controller.actualizar_slots(equipo_tipado)

# 	# Guardar inmediatamente
# 	sistema_guardado.guardar_partida()
# 	print("💾 [CAJAS PC] Datos iniciales guardados")

## Carga datos existentes desde el sistema de guardado.
func _cargar_datos_existentes(sistema_guardado) -> void:
	print("📖 [CAJAS PC] Cargando datos existentes...")

	# Lee las cajas PC del sistema de guardado y las guarda en el gestor
	var cajas_datos = sistema_guardado.obtener_cajas_pc()
	gestor_cajas.cargar_cajas_desde_datos(cajas_datos)

	# Cargar equipo
	var bp_equipo: Array[BasePokemon] = sistema_guardado.datos_vivos.equipo_pokemon
	# Convertir Array genérico a Array[BasePokemon] para cumplir con el tipo esperado
	# var equipo_tipado: Array[BasePokemon] = []
	# for pokemon in equipo_datos:
	# 	if pokemon is BasePokemon:
	# 		equipo_tipado.append(pokemon)
	dock_equipo_controller.cargar_equipo_pokemon(bp_equipo)
	# dock_equipo_controller.actualizar_slots(bp_equipo)

	print("✅ [CAJAS PC] Datos existentes cargados")

## Genera datos de prueba como fallback.
# func _generar_datos_iniciales_prueba() -> void:
# 	print("🎲 [CAJAS PC] Generando datos de prueba (fallback)...")

# 	# Usar el método legacy
# 	gestor_cajas.generar_datos_prueba()
# 	_generar_equipo_prueba()

## Genera un equipo inicial para el jugador.
# func _generar_equipo_inicial(sistema_guardado) -> void:
# 	print("👥 [CAJAS PC] Generando equipo inicial...")

# 	# Limpiar equipo existente
# 	sistema_guardado.datos_vivos.equipo_pokemon.clear()

# 	# Números nacionales para el equipo inicial
# 	var numeros_equipo = [278, 296, 263, 258, 220, 244]  # WINGULL, MAKUHITA, ZIGZAGOON, MUDKIP, SWINUB, ENTEI

# 	for i in range(6):
# 		var numero_pokemon = numeros_equipo[i]
# 		var pokemon = sistema_guardado._crear_pokemon_de_prueba(numero_pokemon)

# 		if pokemon:
# 			pokemon.nivel = 55 + (i * 5)  # Niveles 55, 60, 65, 70, 75, 80
# 			# Obtener datos de la especie para el ratio de crecimiento
# 			var datos_especie = DatabaseManager.obtener_pokemon_por_numero(numero_pokemon)
# 			var ratio_crecimiento = datos_especie.get("ratio_crecimiento", "NORMAL")
# 			pokemon.experiencia = pokemon.get_exp_nivel(pokemon.nivel, ratio_crecimiento)
# 			sistema_guardado.datos_vivos.equipo_pokemon.append(pokemon)
# 			print("👥 [CAJAS PC] ✅ Equipo slot %d: %s Nv.%d" % [i, pokemon.nombre_interno, pokemon.nivel])

# 	print("✅ [CAJAS PC] Equipo inicial generado con %d Pokémon" % sistema_guardado.datos_vivos.equipo_pokemon.size())

## Sincroniza los datos actuales con el sistema de guardado.
func _sincronizar_con_sistema_guardado() -> void:
	var sistema_guardado = _obtener_sistema_guardado()
	if not sistema_guardado:
		print("⚠️ [CAJAS PC] No se puede sincronizar: sistema de guardado no disponible")
		return

	print("💾 [CAJAS PC] Sincronizando datos en memoria volátil...")

	# Sincronizar equipo Pokémon en memoria
	var equipo_actual: Array[BasePokemon] = []
	for pokemon in dock_equipo_controller.obtener_equipo_completo():
		if pokemon != null:
			equipo_actual.append(pokemon)
	sistema_guardado.datos_vivos.equipo_pokemon = equipo_actual

	# Sincronizar cajas PC en memoria: exactamente las 14 cajas de Ruby, cada
	# una con sus 30 slots (null = vacío), igual que inicializar_cajas_pc().
	var cajas_pc: Array = sistema_guardado.datos_vivos.cajas_pc
	cajas_pc.clear()
	for caja_index in range(TOTAL_CAJAS):
		var caja_data: Array = []
		caja_data.assign(gestor_cajas.obtener_pokemon_en_caja(caja_index))
		caja_data.resize(SLOTS_TOTAL)
		cajas_pc.append(caja_data)
	# Pokémon de partidas antiguas que no cupieron en las 14 cajas: se siguen
	# guardando aparte (en cajas extra) para no perderlos nunca.
	var sin_hueco: Array[BasePokemon] = gestor_cajas.pokemon_sin_hueco
	for inicio in range(0, sin_hueco.size(), SLOTS_TOTAL):
		var caja_extra: Array = []
		caja_extra.assign(sin_hueco.slice(inicio, inicio + SLOTS_TOTAL))
		caja_extra.resize(SLOTS_TOTAL)
		cajas_pc.append(caja_extra)
	# Ruby recuerda la caja en la que se salió (gPokemonStorage.currentBox).
	sistema_guardado.datos_vivos.indice_caja_activa = caja_actual

	# NOTA: No se guarda en disco aquí, solo se actualiza la memoria volátil
	# El guardado real se hace desde el menú cuando el jugador lo solicita
	print("💾 [CAJAS PC] Datos sincronizados en memoria (no guardado en disco)")

## Configura la posición inicial del cursor y sus elementos visuales.
func _configurar_cursor_inicial() -> void:
	cursor_x = 0
	cursor_y = 0
	cursor_activo = true
	modo_navegacion = ModoNavegacion.GRILLA
	columna_guardada = 0

	# Posicionar mano y sombra en la posición inicial
	_actualizar_posicion_cursor()

	# Iniciar animación de la mano
	if mano:
		mano.play("idle")  # Asegurar que la mano esté animada

	print("👆 [CAJAS PC] Cursor configurado en posición inicial (0,0) - Modo GRILLA")

## Conecta las señales necesarias para el funcionamiento.
func _conectar_señales() -> void:
	# Aquí podemos conectar señales futuras si es necesario
	pass

## Crea el timer para navegación continua.
func _crear_timer_navegacion() -> void:
	navegacion_timer = Timer.new()
	navegacion_timer.wait_time = navegacion_inicial_delay
	navegacion_timer.one_shot = true
	navegacion_timer.timeout.connect(_on_navegacion_timer_timeout)
	add_child(navegacion_timer)
	print("⏱️ [CAJAS PC] Timer de navegación continua creado")

## Carga los datos de la caja actual y actualiza la visualización.
func _cargar_caja_actual() -> void:
	print("📋 [CAJAS PC] Cargando caja %d..." % caja_actual)

	# Obtener los Pokémon de la caja actual desde el gestor
	var pokemones_caja = gestor_cajas.obtener_pokemon_en_caja(caja_actual)

	# Actualizar cada slot de la grilla
	for i in range(SLOTS_TOTAL):
		if i < slots_lista.size() and i < pokemones_caja.size():
			var pokemon = pokemones_caja[i]
			slots_lista[i].asignar_pokemon(pokemon)
		elif i < slots_lista.size():
			slots_lista[i].asignar_pokemon(null)

	print("✅ [CAJAS PC] Caja %d cargada con %d Pokémon" % [caja_actual, _contar_pokemon_en_caja()])

## Carga los datos de todas las cajas y actualiza la visualización.
func _cargar_todas_las_cajas() -> void:
	print("📋 [CAJAS PC] Cargando datos para todas las cajas...")

	if not gestor_cajas:
		print("⚠️ [CAJAS PC] Error: gestor_cajas no está inicializado")
		return

	# Cargar datos para cada caja
	for caja_index in range(instancias_cajas.size()):
		var caja_instance = instancias_cajas[caja_index]
		var pokemones_caja = gestor_cajas.obtener_pokemon_en_caja(caja_index)

		# Obtener slots de esta caja
		var slots_caja = []
		for hijo in caja_instance.get_children():
			if hijo is SlotPokemon:
				slots_caja.append(hijo)

		# Ordenar slots por posición
		slots_caja.sort_custom(func(a, b): return a.indice_grilla.y * SLOTS_HORIZONTAL + a.indice_grilla.x < b.indice_grilla.y * SLOTS_HORIZONTAL + b.indice_grilla.x)

		# Asignar Pokémon a slots
		for i in range(SLOTS_TOTAL):
			if i < slots_caja.size():
				if i < pokemones_caja.size():
					slots_caja[i].asignar_pokemon(pokemones_caja[i])
				else:
					slots_caja[i].asignar_pokemon(null)

		var pokemon_count = pokemones_caja.size()
		print("📦 [CAJAS PC] Caja %d: %d Pokémon cargados" % [caja_index, pokemon_count])

	print("✅ [CAJAS PC] Todas las cajas cargadas")

## Función de debug para verificar el estado del sistema de cajas.
func _debug_verificar_estado_cajas() -> void:
	print("🔍 [DEBUG] ======= ESTADO DEL SISTEMA DE CAJAS =======")
	print("  - Total instancias: %d" % instancias_cajas.size())
	print("  - Caja actual: %d" % caja_actual)
	print("  - Dock actual válido: %s" % str(dock_caja_actual != null))
	print("  - Slots en grilla actual: %d" % slots_lista.size())

	if not gestor_cajas:
		print("❌ [DEBUG] Gestor de cajas no disponible")
		return

	# Mostrar información detallada de cada caja
	print("\n📦 [DEBUG] CONTENIDO DETALLADO DE CAJAS:")

	var total_pokemon_sistema = 0
	var total_cajas_con_pokemon = 0

	for caja_num in range(TOTAL_CAJAS):
		var pokemon_en_caja = 0
		var slots_vacios = 0

		print("\n🗂️ [CAJA %d] %s" % [caja_num, gestor_cajas.obtener_nombre_caja(caja_num)])

		# Verificar cada slot de la caja
		for slot in range(gestor_cajas.POKEMON_POR_CAJA):
			var pokemon = gestor_cajas.obtener_pokemon(caja_num, slot)
			if pokemon:
				pokemon_en_caja += 1
				var nombre_especie = _pad_string_to_length(pokemon.nombre_interno.substr(0, 12), 12)

				var info_pokemon = "  [%02d] #%03d %s Nv.%d" % [
					slot,
					pokemon.numero_nacional,
					nombre_especie,
					pokemon.nivel
				]

				# Agregar información adicional
				var extras = []
				if pokemon.shiny:
					extras.append("⭐")
				if pokemon.sexo == "F":
					extras.append("♀")
				elif pokemon.sexo == "M":
					extras.append("♂")

				# Verificar si tiene marcas
				var tiene_marcas = false
				for marca in ["circulo", "cuadrado", "triangulo", "corazon"]:
					if pokemon.marcas.get(marca, false):
						tiene_marcas = true
						break
				if tiene_marcas:
					extras.append("🏷️")

				if extras.size() > 0:
					info_pokemon += " " + " ".join(extras)

				print(info_pokemon)
			else:
				slots_vacios += 1

		if pokemon_en_caja > 0:
			total_cajas_con_pokemon += 1
			total_pokemon_sistema += pokemon_en_caja

		# Resumen de la caja
		if pokemon_en_caja > 0 or slots_vacios < gestor_cajas.POKEMON_POR_CAJA:
			print("  ➤ Pokémon: %d | Vacíos: %d | Total: %d" % [pokemon_en_caja, slots_vacios, gestor_cajas.POKEMON_POR_CAJA])
		else:
			print("  ➤ CAJA VACÍA")

	# Resumen general
	print("\n📊 [DEBUG] ======= RESUMEN GENERAL =======")
	print("  🎯 Total Pokémon en sistema: %d" % total_pokemon_sistema)
	print("  📦 Cajas con Pokémon: %d/%d" % [total_cajas_con_pokemon, TOTAL_CAJAS])
	print("  📈 Promedio por caja activa: %.1f" % (float(total_pokemon_sistema) / max(total_cajas_con_pokemon, 1)))

	# Verificar especies únicas
	_debug_verificar_especies_unicas()

## Verifica que no haya especies duplicadas en el sistema.
func _debug_verificar_especies_unicas() -> void:
	if not gestor_cajas:
		return

	print("\n🔬 [DEBUG] VERIFICACIÓN DE ESPECIES ÚNICAS:")

	var especies_encontradas = {}
	var duplicados_encontrados = []

	for caja_num in range(TOTAL_CAJAS):
		for slot in range(gestor_cajas.POKEMON_POR_CAJA):
			var pokemon = gestor_cajas.obtener_pokemon(caja_num, slot)
			if pokemon:
				var clave_especie = pokemon.numero_nacional
				var ubicacion = "Caja%d-Slot%d" % [caja_num, slot]

				if especies_encontradas.has(clave_especie):
					# Duplicado encontrado
					duplicados_encontrados.append({
						"nombre_interno": pokemon.nombre_interno,
						"numero": pokemon.numero_nacional,
						"ubicacion1": especies_encontradas[clave_especie],
						"ubicacion2": ubicacion
					})
				else:
					especies_encontradas[clave_especie] = ubicacion

	if duplicados_encontrados.size() > 0:
		print("  ⚠️ ESPECIES DUPLICADAS ENCONTRADAS:")
		for duplicado in duplicados_encontrados:
			print("    - #%03d %s: %s y %s" % [
				duplicado.numero,
				duplicado.nombre_interno,
				duplicado.ubicacion1,
				duplicado.ubicacion2
			])
	else:
		print("  ✅ No se encontraron especies duplicadas")

	print("  📊 Total especies únicas: %d" % especies_encontradas.size())

# ===================================
# CREACIÓN Y GESTIÓN DE LA GRILLA
# ===================================

## Inicializa todas las instancias de cajas y las configura.
func _inicializar_instancias_cajas() -> void:
	print("📦 [CAJAS PC] Inicializando %d instancias de cajas..." % TOTAL_CAJAS)

	if not eje_cajas:
		print("⚠️ [CAJAS PC] Error: EjeCajas no encontrado")
		return

	# Limpiar array de instancias
	instancias_cajas.clear()

	# La primera caja ya existe en la escena
	var primera_caja = eje_cajas.get_child(0)
	if primera_caja:
		instancias_cajas.append(primera_caja)
		primera_caja.visible = true  # La caja actual es visible
		dock_caja_actual = primera_caja

		# Actualizar referencias a elementos de la primera caja
		_actualizar_referencias_caja_actual()

		print("📦 [CAJAS PC] Caja 0 configurada (ya existente)")

	# Crear las instancias restantes (cajas 1-13)
	for i in range(1, TOTAL_CAJAS):
		var nueva_caja = escena_dock_caja.instantiate()
		nueva_caja.name = "DockCaja" + str(i+1)
		nueva_caja.visible = false  # Ocultar por defecto
		eje_cajas.add_child(nueva_caja)
		instancias_cajas.append(nueva_caja)

		print("📦 [CAJAS PC] Caja %d instanciada y ocultada" % i)

	print("✅ [CAJAS PC] %d instancias de cajas inicializadas" % instancias_cajas.size())

## Actualiza las referencias a los elementos de la caja actual.
func _actualizar_referencias_caja_actual() -> void:
	if not dock_caja_actual:
		return

	# Si dock_caja_actual es un DockCajaController, usar sus métodos
	sombra = dock_caja_actual.obtener_sombra()
	flecha_izquierda = dock_caja_actual.obtener_flecha_izquierda()
	flecha_derecha = dock_caja_actual.obtener_flecha_derecha()
	label_nombre_caja = dock_caja_actual.obtener_label_nombre()

	print("🔄 [CAJAS PC] Referencias actualizadas para caja actual")

## Activa una caja usando su DockCajaController.
func _activar_caja_controller(numero_caja: int) -> void:
	# Desactivar todas las cajas primero
	for i in range(instancias_cajas.size()):
		var caja = instancias_cajas[i]
		if caja and caja.has_method("desactivar_caja"):
			caja.desactivar_caja()

	# Activar la caja específica
	if numero_caja >= 0 and numero_caja < instancias_cajas.size():
		var caja_objetivo = instancias_cajas[numero_caja]
		if caja_objetivo and caja_objetivo.has_method("activar_caja"):
			caja_objetivo.activar_caja()
			caja_objetivo.configurar_caja(numero_caja)

			# Actualizar referencias del controlador principal
			dock_caja_actual = caja_objetivo
			_actualizar_referencias_caja_actual()

			print("✅ [CAJAS PC] Caja %d activada mediante controller" % numero_caja)

## Crea toda la grilla de slots de 6x5 para todas las cajas.
func _crear_grilla_slots() -> void:
	print("🔧 [CAJAS PC] Creando grillas de slots para todas las cajas...")

	# Cargar la escena del slot
	var escena_slot = preload("res://UI/cajas_pc/slot_pokemon.tscn")

	# Inicializar arrays para la caja actual
	grilla_slots = []
	slots_lista = []

	# Crear slots para cada instancia de caja
	for caja_index in range(instancias_cajas.size()):
		var caja_instance = instancias_cajas[caja_index]

		print("🔧 [CAJAS PC] Creando slots para caja %d..." % caja_index)

		# Si es la caja actual, usar los arrays principales
		var grilla_caja: Array[Array] = []
		var slots_caja: Array[SlotPokemon] = []

		# Crear grilla bidimensional para esta caja
		for fila in range(SLOTS_VERTICAL):
			var fila_slots: Array[SlotPokemon] = []

			for columna in range(SLOTS_HORIZONTAL):
				# Crear instancia del slot
				var slot = escena_slot.instantiate() as SlotPokemon

				# Calcular posición en pantalla
				var pos_x = POSICION_BASE_GRILLA.x + (columna * ESPACIADO_SLOT.x)
				var pos_y = POSICION_BASE_GRILLA.y + (fila * ESPACIADO_SLOT.y)
				slot.position = Vector2(pos_x, pos_y)

				# Configurar el slot
				var indice_lineal = fila * SLOTS_HORIZONTAL + columna
				slot.configurar_slot(caja_index, indice_lineal, Vector2i(columna, fila))

				# DESHABILITAR CONTROLES DEL MOUSE - Solo navegación por teclado
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

				# Agregar a la instancia de caja
				caja_instance.add_child(slot)
				fila_slots.append(slot)
				slots_caja.append(slot)

			grilla_caja.append(fila_slots)

		# Si es la caja actual, asignar a los arrays principales
		if caja_index == caja_actual:
			grilla_slots = grilla_caja
			slots_lista = slots_caja

		print("✅ [CAJAS PC] Caja %d: %d slots creados" % [caja_index, slots_caja.size()])

	print("✅ [CAJAS PC] Todas las grillas creadas. Caja actual: %d slots" % slots_lista.size())

## Actualiza la configuración de todos los slots para la caja actual.
func _actualizar_configuracion_slots() -> void:
	for i in range(slots_lista.size()):
		var slot = slots_lista[i]
		var fila = int(float(i) / SLOTS_HORIZONTAL)  # División entera
		var columna = i % SLOTS_HORIZONTAL
		slot.configurar_slot(caja_actual, i, Vector2i(columna, fila))

## Actualiza la selección visual de todos los slots.
func _actualizar_seleccion_visual() -> void:
	# Primero, resetear todos los slots a su estado normal
	for slot in slots_lista:
		if slot.esta_vacio():
			slot.establecer_estado(SlotPokemon.EstadoVisual.VACIO)
		else:
			slot.establecer_estado(SlotPokemon.EstadoVisual.OCUPADO)

	# Luego, marcar el slot actual como seleccionado
	var slot_actual = _obtener_slot_actual()
	if slot_actual:
		slot_actual.establecer_estado(SlotPokemon.EstadoVisual.SELECCIONADO)

	# Actualizar sprite del Pokémon y animación según el slot actual
	_actualizar_sprite_pokemon()

## Obtiene el slot en una posición específica de la grilla.
func _obtener_slot_en_posicion(x: int, y: int) -> SlotPokemon:
	# Validar que no haya animación activa para evitar errores de "previously freed"
	if animacion_cambio_caja_activa:
		print("⚠️ [CAJAS PC] Evitando acceso a slot durante animación de cambio de caja")
		return null

	if x >= 0 and x < SLOTS_HORIZONTAL and y >= 0 and y < SLOTS_VERTICAL:
		var slot = grilla_slots[y][x]
		if slot and is_instance_valid(slot):
			return slot
		else:
			print("⚠️ [CAJAS PC] Slot no válido en posición (%d, %d)" % [x, y])
			return null
	return null

## Obtiene el slot actualmente seleccionado por el cursor.
func _obtener_slot_actual() -> SlotPokemon:
	if modo_navegacion == ModoNavegacion.GRILLA:
		return _obtener_slot_en_posicion(cursor_x, cursor_y)
	return null

## Cuenta cuántos Pokémon hay en la caja actual.
func _contar_pokemon_en_caja() -> int:
	var contador = 0
	for slot in slots_lista:
		if not slot.esta_vacio():
			contador += 1
	return contador

## Actualiza el sprite del Pokémon según el modo de navegación actual.
func _actualizar_sprite_pokemon() -> void:
	# Si estamos en modo MOVER, mostrar siempre el Pokémon temporal
	if modo_mover_activo and modo_mover_basepokemon:
		# _mostrar_sprite_pokemon(modo_mover_basepokemon)
		# _mostrar_info_pokemon(modo_mover_basepokemon)
		# _activar_animacion_info("encendido")
		# print("🖼️ [MODO MOVER] Mostrando Pokémon temporal: %s" % modo_mover_basepokemon.nombre_interno)
		return

	match modo_navegacion:
		ModoNavegacion.GRILLA:
			_actualizar_sprite_pokemon_grilla()
		ModoNavegacion.EQUIPO_POKEMON:
			# El equipo maneja su propio DockInfo a través de señales
			pass
		_:
			# Para otros modos de navegación, ocultar sprite e info
			_ocultar_sprite_pokemon()
			_ocultar_info_pokemon()

## Actualiza el sprite específicamente para el modo grilla.
func _actualizar_sprite_pokemon_grilla() -> void:
	var slot_actual = _obtener_slot_actual()
	var pokemon_actual = slot_actual.obtener_pokemon() if slot_actual else null

	if pokemon_actual:
		# Mostrar sprite del Pokémon y activar animación "encendido"
		_mostrar_sprite_pokemon(pokemon_actual)
		_mostrar_info_pokemon(pokemon_actual)
		_activar_animacion_info("encendido")
		print("🖼️ [GRILLA] Mostrando sprite e info de %s" % pokemon_actual.nombre_interno)
	else:
		# Ocultar sprite y poner animación "default"
		_ocultar_sprite_pokemon()
		_ocultar_info_pokemon()
		_activar_animacion_info("default")
		print("🖼️ [GRILLA] Ocultando sprite e info - slot vacío")

## Actualiza el sprite específicamente para el modo equipo.
# func _actualizar_sprite_pokemon_equipo() -> void:
# 	# En modo equipo, la actualización se maneja a través de señales (slot_cambiado)
# 	# Esta función existe para casos especiales donde se necesite forzar una actualización
# 	var pokemon_actual = dock_equipo_controller.obtener_pokemon_actual()

# 	if pokemon_actual:
# 		# Usar el mismo sistema de transiciones que el modo grilla
# 		_mostrar_sprite_pokemon(pokemon_actual)
# 		_mostrar_info_pokemon(pokemon_actual)
# 		_activar_animacion_info("encendido")
# 		print("🖼️ [EQUIPO] Mostrando sprite e info de %s con transiciones" % pokemon_actual.nombre_interno)
# 	else:
# 		# Usar el mismo sistema que el modo grilla para ocultar
# 		_ocultar_sprite_pokemon()
# 		_ocultar_info_pokemon()
# 		_activar_animacion_info("default")
# 		print("🖼️ [EQUIPO] Ocultando sprite e info - slot vacío o salir")

## Muestra el sprite del Pokémon en el nodo PokemonSprite con transición animada.
func _mostrar_sprite_pokemon(pokemon: BasePokemon) -> void:
	print("🖼️ [SPRITE] === MOSTRAR SPRITE POKEMON ===")
	print("🖼️ [SPRITE] Pokémon solicitado: %s" % pokemon.nombre_interno)
	print("🖼️ [SPRITE] Pokémon actual: %s" % sprite_pokemon_actual)
	print("🖼️ [SPRITE] Animación activa: %s" % sprite_animacion_activa)

	if not dock_info_controller:
		print("❌ [CAJAS PC] Controlador DockInfo no encontrado")
		return

	# Si ya está mostrando el mismo Pokémon y no hay animación, no hacer nada
	if sprite_pokemon_actual == _clave_sprite_pokemon(pokemon) and not sprite_animacion_activa:
		print("⏭️ [SPRITE] Ya mostrando el mismo Pokémon sin animación, omitiendo")
		return

	# Lógica de interrupción: si hay una transición activa, reiniciarla
	if sprite_animacion_activa:
		# Cancelar la transición actual y reiniciar con el nuevo Pokémon
		print("🔄 [CAJAS PC] Interrumpiendo transición para cambiar a: %s" % pokemon.nombre_interno)
		_cancelar_transicion_sprite()

	# Iniciar nueva transición
	print("🚀 [SPRITE] Iniciando nueva transición...")
	_iniciar_transicion_sprite(pokemon.nombre_interno, pokemon)

## Clave del sprite mostrado: la especie, si es variocolor y además la
## personalidad en SPINDA (sus manchas cambian de un individuo a otro aunque la
## especie sea la misma).
static func _clave_sprite_pokemon(pokemon: BasePokemon) -> String:
	var clave: String = pokemon.nombre_interno + ("_shiny" if pokemon.es_shiny() else "")
	if ManchasSpinda.aplica_a(pokemon.nombre_interno):
		return "%s_%d" % [clave, pokemon.personalidad]
	return clave

## Oculta el sprite del Pokémon con transición.
func _ocultar_sprite_pokemon() -> void:
	if not dock_info_controller:
		print("❌ [CAJAS PC] Controlador DockInfo no encontrado")
		return

	# Cancelar cualquier animación en curso
	_cancelar_transicion_sprite()

	# Ocultar sprite a través del controller
	dock_info_controller.ocultar_sprite_pokemon()
	sprite_pokemon_actual = ""

## Activa la animación del botón cerrar.
func _activar_animacion_boton_cerrar() -> void:
	if boton_cerrar:
		boton_cerrar.play()
		print("🎬 [BOTÓN] Activando animación botón cerrar")

## Detiene la animación del botón cerrar y lo deja en frame 0.
func _detener_animacion_boton_cerrar() -> void:
	if boton_cerrar:
		boton_cerrar.stop()
		boton_cerrar.frame = 0
		print("⏹️ [BOTÓN] Deteniendo animación botón cerrar")

## Muestra la información del Pokémon usando el controlador.
func _mostrar_info_pokemon(pokemon: BasePokemon) -> void:
	if not dock_info_controller:
		print("❌ [INFO] Controlador dock_info no encontrado")
		return

	# Delegar al controlador
	dock_info_controller.mostrar_info(pokemon)

## Oculta la información del Pokémon usando el controlador.
func _ocultar_info_pokemon() -> void:
	if dock_info_controller:
		dock_info_controller.ocultar_info()

## LEGACY: Función de marcas - ahora manejada por el controlador.
func _actualizar_marcas_pokemon(_pokemon: BasePokemon) -> void:
	# Esta función ahora es manejada por DockInfoController
	print("⚠️ [LEGACY] _actualizar_marcas_pokemon() ahora es manejada por DockInfoController")

## Activa una animación específica en el nodo info_anim.
func _activar_animacion_info(nombre_animacion: String) -> void:
	if not dock_info_controller:
		print("❌ [CAJAS PC] Controlador DockInfo no encontrado")
		return

	# Delegar al controller
	dock_info_controller.activar_animacion_info(nombre_animacion)
	print("🎬 [CAJAS PC] Delegando animación al controller: %s" % nombre_animacion)

# ===================================
# SEÑALES DE LOS SLOTS (DESHABILITADAS)
# ===================================

# Las señales del mouse están deshabilitadas para usar solo navegación por teclado

# ===================================
# NAVEGACIÓN DEL CURSOR MEJORADA
# ===================================

## Maneja la entrada del usuario para navegación y acciones.
func _input(event: InputEvent) -> void:
	if not cursor_activo or animacion_activa or animacion_dock_equipo_activa or animacion_reorganizacion_activa:
		return
	# Secuencias (SACAR...) y cambio de caja: la caja/slot de destino aún no es
	# definitiva, así que ninguna acción puede colarse.
	if secuencia_activa or animacion_cambio_caja_activa:
		return

	# MANEJO DEL COOLDOWN: Detectar cuando se sueltan las teclas
	if input_cooldown_activo:
		if tecla_cancelar_presionada and not Input.is_action_pressed("btn_cancelar"):
			tecla_cancelar_presionada = false
			print("🔓 [COOLDOWN] Tecla cancelar liberada")
		if tecla_accion_presionada and not Input.is_action_pressed("btn_accion"):
			tecla_accion_presionada = false
			print("🔓 [COOLDOWN] Tecla acción liberada")
		if not tecla_cancelar_presionada and not tecla_accion_presionada:
			_desactivar_cooldown_input()

	# PRIORIDAD 1: Si hay menú, el controlador lo maneja automáticamente
	if menu_pc.hay_menu_activo():
		return

	# PRIORIDAD 2: Si hay cooldown activo, ignorar input de ambas teclas
	if input_cooldown_activo:
		if event.is_action_pressed("btn_cancelar"):
			print("⏳ [COOLDOWN] Input de cancelar ignorado - Cooldown activo")
			return
		if event.is_action_pressed("btn_accion"):
			print("⏳ [COOLDOWN] Input de acción ignorado - Cooldown activo")
			return

	# PRIORIDAD 3: Si estamos mostrando mensaje del Pokémon, cerrar con cualquier tecla
	if mostrando_mensaje_pokemon:
		var con_ab: bool = event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar")
		var con_cruceta: bool = event.is_action_pressed("btn_izquierda") or event.is_action_pressed("btn_derecha") or \
		   event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo")
		if con_ab or (con_cruceta and not mensaje_solo_ab):
			_cerrar_mensaje_pokemon()
		# Con un aviso en pantalla no se navega ni se actúa.
		return

	# Navegación con D-pad/joystick - manejar press y release
	if event.is_action_pressed("btn_izquierda"):
		_iniciar_navegacion("btn_izquierda", -1, 0)
	elif event.is_action_released("btn_izquierda"):
		_detener_navegacion("btn_izquierda")
	elif event.is_action_pressed("btn_derecha"):
		_iniciar_navegacion("btn_derecha", 1, 0)
	elif event.is_action_released("btn_derecha"):
		_detener_navegacion("btn_derecha")
	elif event.is_action_pressed("btn_arriba"):
		_iniciar_navegacion("btn_arriba", 0, -1)
	elif event.is_action_released("btn_arriba"):
		_detener_navegacion("btn_arriba")
	elif event.is_action_pressed("btn_abajo"):
		_iniciar_navegacion("btn_abajo", 0, 1)
	elif event.is_action_released("btn_abajo"):
		_detener_navegacion("btn_abajo")

	# Cambio rápido de caja con L/R
	# elif event.is_action_pressed("shoulder_left"):
	# 	_cambiar_caja(-1)
	# elif event.is_action_pressed("shoulder_right"):
	# 	_cambiar_caja(1)

	# Acciones principales
	elif event.is_action_pressed("btn_accion"):  # A - Seleccionar
		_accion_seleccionar()
	elif event.is_action_pressed("btn_cancelar"):  # B - Cancelar/Salir
		_accion_cancelar()
	elif event.is_action_pressed("btn_select"):  # SELECT - Movimiento rápido
		_alternar_movimiento_rapido()
	# elif event.is_action_pressed("action_x"):  # X - Opciones del Pokémon
	# 	_accion_opciones_pokemon()
	# elif event.is_action_pressed("action_y"):  # Y - Opciones de la caja
	# 	_accion_opciones_caja()

	# Teclas de debug (solo en debug builds)
	elif OS.is_debug_build():
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_F1:  # F1 - Mostrar info detallada del sistema
					_debug_verificar_estado_cajas()
				KEY_F2:  # F2 - Mostrar info de la caja actual
					_debug_info_caja_actual()
				KEY_F3:  # F3 - Buscar especies duplicadas
					_debug_verificar_especies_unicas()
				KEY_F4:  # F4 - Estadísticas rápidas
					_debug_estadisticas_rapidas()

## Inicia la navegación continua en una dirección.
func _iniciar_navegacion(accion: String, delta_x: int, delta_y: int) -> void:
	# Ejecutar movimiento inmediato
	_mover_cursor_mejorado(delta_x, delta_y)

	# Configurar para repetición continua
	tecla_presionada = accion
	navegacion_timer.wait_time = navegacion_inicial_delay
	navegacion_timer.start()

## Detiene la navegación continua.
func _detener_navegacion(accion: String) -> void:
	if tecla_presionada == accion:
		tecla_presionada = ""
		navegacion_timer.stop()

## Callback del timer para navegación continua.
func _on_navegacion_timer_timeout() -> void:
	if tecla_presionada != "" and Input.is_action_pressed(tecla_presionada):
		# Continuar navegación según la tecla presionada
		match tecla_presionada:
			"btn_izquierda":
				_mover_cursor_mejorado(-1, 0)
			"btn_derecha":
				_mover_cursor_mejorado(1, 0)
			"btn_arriba":
				_mover_cursor_mejorado(0, -1)
			"btn_abajo":
				_mover_cursor_mejorado(0, 1)

		# Configurar timer para siguiente repetición (más rápido)
		navegacion_timer.wait_time = navegacion_repeat_delay
		navegacion_timer.start()
	else:
		# Detener si la tecla ya no está presionada
		tecla_presionada = ""

## Sistema de navegación con modos para manejar diferentes áreas.
func _mover_cursor_mejorado(delta_x: int, delta_y: int) -> void:
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			_navegar_en_grilla(delta_x, delta_y)
		ModoNavegacion.NOMBRE_CAJA:
			_navegar_en_nombre_caja(delta_x, delta_y)
		ModoNavegacion.BOTON_EQUIPO:
			_navegar_en_boton_equipo(delta_x, delta_y)
		ModoNavegacion.BOTON_CERRAR:
			_navegar_en_boton_cerrar(delta_x, delta_y)
		ModoNavegacion.EQUIPO_POKEMON:
			_navegar_en_equipo_pokemon(delta_x, delta_y)

## Navegación dentro de la grilla de slots.
func _navegar_en_grilla(delta_x: int, delta_y: int) -> void:
	if delta_y == -1 and cursor_y == 0:
		# Arriba desde fila 1: guardar columna y saltar a nombre de caja

		# Salir del modo grilla
		columna_guardada = cursor_x
		dock_caja_actual.sombra_mano.visible = false

		# Ir a modo nombre de caja
		modo_navegacion = ModoNavegacion.NOMBRE_CAJA
		_actualizar_posicion_cursor_ui()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a nombre de caja, columna guardada: %d" % columna_guardada)
		return

	if delta_y == 1 and cursor_y == SLOTS_VERTICAL - 1:
		# Abajo desde última fila: saltar a botones según columna
		columna_guardada = cursor_x
		if cursor_x <= 2:
			# Columnas 0-2: ir al botón de equipo
			modo_navegacion = ModoNavegacion.BOTON_EQUIPO
			_actualizar_posicion_cursor_ui()
			_reproducir_sonido_navegacion()
			print("🎯 [CAJAS PC] Saltando a botón de equipo desde columna %d" % cursor_x)
		else:
			# Columnas 3-5: ir al botón de cerrar
			modo_navegacion = ModoNavegacion.BOTON_CERRAR
			_actualizar_posicion_cursor_ui()
			_reproducir_sonido_navegacion()
			print("🎯 [CAJAS PC] Saltando a botón de cerrar desde columna %d" % cursor_x)
		return

	if delta_x != 0:
		# Navegación horizontal con wrap
		var nuevo_x = cursor_x + delta_x

		if nuevo_x < 0:
			nuevo_x = SLOTS_HORIZONTAL - 1  # Wrap a la derecha
		elif nuevo_x >= SLOTS_HORIZONTAL:
			nuevo_x = 0  # Wrap a la izquierda

		cursor_x = nuevo_x

	if delta_y != 0:
		# Navegación vertical normal
		var nuevo_y = cursor_y + delta_y

		if nuevo_y >= 0 and nuevo_y < SLOTS_VERTICAL:
			cursor_y = nuevo_y

	_animar_movimiento_cursor()
	_actualizar_seleccion_visual()
	_reproducir_sonido_navegacion()

	print("👆 [CAJAS PC] Cursor movido a (%d, %d)" % [cursor_x, cursor_y])

## Navegación en el área del nombre de caja.
func _navegar_en_nombre_caja(delta_x: int, delta_y: int) -> void:
	if delta_y == -1:
		# Arriba: siempre al botón de equipo (pokeruby sub_809C85C: área 3,
		# posición 0); a CERRAR CAJA se llega con Derecha desde ahí.
		dock_caja_actual.configurar_flechas_inactivas()
		modo_navegacion = ModoNavegacion.BOTON_EQUIPO
		_actualizar_posicion_cursor_ui()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a botón de equipo desde nombre de caja")
	elif delta_y == 1:
		# Abajo: volver a grilla en columna guardada
		cursor_x = columna_guardada
		cursor_y = 0
		modo_navegacion = ModoNavegacion.GRILLA
		dock_caja_actual.configurar_flechas_inactivas()
		var nueva_pos_sombra = POSICION_BASE_SOMBRA + Vector2(cursor_x * ESPACIADO_SLOT.x, cursor_y * ESPACIADO_SLOT.y)
		dock_caja_actual.sombra_mano.position = nueva_pos_sombra
		_animar_movimiento_cursor()
		_actualizar_seleccion_visual()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Volviendo a grilla en columna %d" % columna_guardada)
	elif delta_x != 0:
		# Izquierda/Derecha: cambiar caja
		_cambiar_caja(delta_x)

## Navegación en el botón de equipo.
func _navegar_en_boton_equipo(delta_x: int, delta_y: int) -> void:
	if delta_y == -1:
		# Arriba: ir a fila inferior de la grilla (fila 4)
		# Columnas 0-2, simétrico al botón de cerrar (que fuerza 3-5).
		columna_guardada = mini(columna_guardada, 2)
		cursor_x = columna_guardada
		cursor_y = SLOTS_VERTICAL - 1  # Última fila
		modo_navegacion = ModoNavegacion.GRILLA
		_animar_movimiento_cursor()
		_actualizar_seleccion_visual()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a fila inferior de grilla desde botón equipo")
	elif delta_y == 1:
		# Abajo: ir a nombre de caja
		modo_navegacion = ModoNavegacion.NOMBRE_CAJA
		_actualizar_posicion_cursor_ui()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a nombre de caja desde botón equipo")
	elif delta_x != 0:
		# Izquierda/Derecha: ir a botón de cerrar
		modo_navegacion = ModoNavegacion.BOTON_CERRAR
		_actualizar_posicion_cursor_ui()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a botón de cerrar")

## Navegación en el botón de cerrar.
func _navegar_en_boton_cerrar(delta_x: int, delta_y: int) -> void:
	if delta_y == -1:
		# Arriba: ir a fila inferior de la grilla (fila 4)
		if columna_guardada < 3:
			columna_guardada = 3
		cursor_x = columna_guardada  # Posición centrada en las últimas columnas
		cursor_y = SLOTS_VERTICAL - 1  # Última fila
		modo_navegacion = ModoNavegacion.GRILLA
		_animar_movimiento_cursor()
		_actualizar_seleccion_visual()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a fila inferior de grilla desde botón cerrar")
	elif delta_y == 1:
		# Abajo: ir a nombre de caja
		modo_navegacion = ModoNavegacion.NOMBRE_CAJA
		_actualizar_posicion_cursor_ui()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a nombre de caja desde botón cerrar")
	elif delta_x != 0:
		# Izquierda/Derecha: ir a botón de equipo
		modo_navegacion = ModoNavegacion.BOTON_EQUIPO
		_actualizar_posicion_cursor_ui()
		_reproducir_sonido_navegacion()
		print("🎯 [CAJAS PC] Saltando a botón de equipo")

## Navegación dentro del equipo Pokémon.
func _navegar_en_equipo_pokemon(delta_x: int, delta_y: int) -> void:
	# Delegar navegación al controlador del equipo. En DEJAR el cursor no sale
	# del panel (pokeruby: modo depósito sin acceso a la caja).
	dock_equipo_controller.navegar_equipo(Vector2i(delta_x, delta_y), operacion != OPERACION_DEJAR)

	# Actualizar cursor en pantalla principal
	_actualizar_posicion_cursor()
	_reproducir_sonido_navegacion()

## Obtiene la posición del cursor para un slot específico del equipo.
func _obtener_posicion_equipo_slot(slot: int) -> Vector2:
	# Delegar al controlador del equipo
	return dock_equipo_controller.obtener_posicion_slot(slot)

## Actualiza la posición del cursor para elementos de la UI.
func _actualizar_posicion_cursor_ui() -> void:
	var nueva_pos_mano: Vector2
	var flip_vertical: bool = false

	# Detener animación del botón cerrar por defecto
	_detener_animacion_boton_cerrar()

	match modo_navegacion:
		ModoNavegacion.NOMBRE_CAJA:
			nueva_pos_mano = POSICION_NOMBRE_CAJA
			flip_vertical = false
			# Activar animaciones de las flechas cuando estamos sobre el nombre de la caja
			dock_caja_actual.configurar_flechas_activas()
		ModoNavegacion.BOTON_EQUIPO:
			nueva_pos_mano = POSICION_BOTON_EQUIPO
			if modo_mover_activo:
				nueva_pos_mano += Vector2(0, -6)  # Ajuste extra hacia arriba si estamos en modo mover
			else:
				flip_vertical = true  # Flip vertical para botones
		ModoNavegacion.BOTON_CERRAR:
			nueva_pos_mano = POSICION_BOTON_CERRAR
			if modo_mover_activo:
				nueva_pos_mano += Vector2(0, -6)  # Ajuste extra hacia arriba si estamos en modo mover
			else:
				flip_vertical = true  # Flip vertical para botones
			# Activar animación del botón cerrar cuando estamos sobre él
			_activar_animacion_boton_cerrar()
		ModoNavegacion.EQUIPO_POKEMON:
			nueva_pos_mano = _obtener_posicion_equipo_slot(dock_equipo_controller.obtener_slot_actual())
			# nueva_pos_sombra = nueva_pos_mano + Vector2(-9, 16)
			flip_vertical = false  # Sin flip para equipo
		_:
			return

	# Configurar flip vertical de la mano
	if mano:
		mano.flip_v = flip_vertical

	# Ocultar sombra cuando no estamos en la grilla
	if sombra:
		sombra.visible = false

	# Actualizar sprite del Pokémon cuando salimos de la grilla
	_actualizar_sprite_pokemon()

	# Animar el movimiento
	if tween_cursor:
		tween_cursor.kill()

	tween_cursor = create_tween()
	tween_cursor.set_parallel(true)
	tween_cursor.tween_property(mano, "position", nueva_pos_mano, 0.1)

## Anima el movimiento suave del cursor a su nueva posición.
func _animar_movimiento_cursor() -> void:
	if tween_cursor:
		tween_cursor.kill()

	tween_cursor = create_tween()
	tween_cursor.set_parallel(true)

	if modo_navegacion == ModoNavegacion.GRILLA:
		# Calcular nueva posición basada en la grilla
		var nueva_pos_mano = POSICION_BASE_MANO + Vector2(cursor_x * ESPACIADO_SLOT.x, cursor_y * ESPACIADO_SLOT.y)
		var nueva_pos_sombra = POSICION_BASE_SOMBRA + Vector2(cursor_x * ESPACIADO_SLOT.x, cursor_y * ESPACIADO_SLOT.y)

		# Asegurar que no tenga flip vertical en la grilla
		if mano:
			mano.flip_v = false

		# Mostrar sombra en la grilla
		if sombra:
			sombra.visible = true

		# Animar ambos elementos
		tween_cursor.tween_property(mano, "position", nueva_pos_mano, 0.1)
		tween_cursor.tween_property(sombra, "position", nueva_pos_sombra, 0.1)

	await tween_cursor.finished

## Actualiza inmediatamente la posición del cursor sin animación.
func _actualizar_posicion_cursor() -> void:
	if modo_navegacion == ModoNavegacion.GRILLA:
		var pos_mano = POSICION_BASE_MANO + Vector2(cursor_x * ESPACIADO_SLOT.x, cursor_y * ESPACIADO_SLOT.y)
		var pos_sombra = POSICION_BASE_SOMBRA + Vector2(cursor_x * ESPACIADO_SLOT.x, cursor_y * ESPACIADO_SLOT.y)

		# Asegurar que no tenga flip vertical en la grilla
		if mano:
			mano.flip_v = false

		# Mostrar sombra en la grilla
		if sombra:
			sombra.visible = true

		# Crear tween para animación suave
		if tween_cursor and tween_cursor.is_valid():
			tween_cursor.kill()

		tween_cursor = create_tween()
		tween_cursor.set_parallel(true)  # Permitir animaciones paralelas
		tween_cursor.tween_property(mano, "position", pos_mano, 0.15)
		tween_cursor.tween_property(sombra, "position", pos_sombra, 0.15)
		_actualizar_sprite_pokemon()
	else:
		# Para elementos de UI, usar _actualizar_posicion_cursor_ui()
		_actualizar_posicion_cursor_ui()

# ===================================
# NAVEGACIÓN ENTRE CAJAS
# ===================================

## Cambia a la caja anterior o siguiente con animación.
func _cambiar_caja(direccion: int) -> void:
	# Prevenir cambios durante animación
	if animacion_cambio_caja_activa:
		print("⚠️ [CAJAS PC] Cambio de caja bloqueado: animación en curso")
		return

	# 14 cajas (0-13) dando la vuelta, como en Ruby.
	var nueva_caja: int = posmod(caja_actual + direccion, TOTAL_CAJAS)

	# Cambiar a la nueva caja usando el sistema de instancias
	_cambiar_a_caja_instancia(nueva_caja)

## Cambia a una caja específica usando el sistema de instancias con animación.
func _cambiar_a_caja_instancia(numero_caja: int) -> void:
	if numero_caja < 0 or numero_caja >= instancias_cajas.size():
		print("⚠️ [CAJAS PC] Error: número de caja inválido: %d" % numero_caja)
		return

	if numero_caja == caja_actual:
		return

	if animacion_cambio_caja_activa:
		print("⚠️ [CAJAS PC] Cambio de caja bloqueado: animación en curso")
		return

	print("📦 [CAJAS PC] Cambiando de caja %d a caja %d" % [caja_actual, numero_caja])

	# Determinar dirección de la animación considerando wraparound
	var direccion = _calcular_direccion_animacion(caja_actual, numero_caja)

	# Iniciar animación de desplazamiento
	_animar_cambio_caja_con_desplazamiento(numero_caja, direccion)

## Calcula la dirección correcta de animación considerando wraparound.
func _calcular_direccion_animacion(caja_origen: int, caja_destino: int) -> int:
	# Casos especiales de wraparound:
	# Caja 0 -> última caja (izquierda): la última debe entrar desde la izquierda
	# Última caja -> Caja 0 (derecha): la caja 0 debe entrar desde la derecha
	var ultima: int = TOTAL_CAJAS - 1

	if caja_origen == 0 and caja_destino == ultima:
		# Navegación hacia atrás (izquierda): la última caja entra desde la izquierda
		return -1
	elif caja_origen == ultima and caja_destino == 0:
		# Navegación hacia adelante (derecha): caja 0 entra desde la derecha
		return 1
	else:
		# Navegación normal: usar comparación simple
		return 1 if caja_destino > caja_origen else -1

## Anima el cambio de caja con desplazamiento horizontal.
func _animar_cambio_caja_con_desplazamiento(nueva_caja: int, direccion: int) -> void:
	animacion_cambio_caja_activa = true

	var caja_actual_nodo = instancias_cajas[caja_actual]
	var caja_nueva_nodo = instancias_cajas[nueva_caja]

	# Configurar posiciones iniciales
	caja_actual_nodo.position = POSICION_CAJA_CENTRO
	caja_nueva_nodo.position = Vector2(direccion * DISTANCIA_DESPLAZAMIENTO, 0)

	# Hacer visible la nueva caja
	caja_nueva_nodo.visible = true
	caja_nueva_nodo.configurar_flechas_activas()

	# Crear tween para la animación
	if tween_cambio_caja:
		tween_cambio_caja.kill()
	tween_cambio_caja = create_tween()
	tween_cambio_caja.set_parallel(true)  # Permitir animaciones paralelas

	# Animar caja actual saliendo
	tween_cambio_caja.tween_property(caja_actual_nodo, "position",
		Vector2(-direccion * DISTANCIA_DESPLAZAMIENTO, 0), DURACION_ANIMACION_CAJA)

	# Animar nueva caja entrando
	tween_cambio_caja.tween_property(caja_nueva_nodo, "position",
		POSICION_CAJA_CENTRO, DURACION_ANIMACION_CAJA)

	# Al finalizar la animación
	await tween_cambio_caja.finished

	# Ocultar caja anterior y finalizar cambio
	caja_actual_nodo.visible = false
	caja_actual_nodo.position = POSICION_CAJA_CENTRO  # Resetear posición

	# Actualizar referencias
	dock_caja_actual = caja_nueva_nodo
	caja_actual = nueva_caja

	# Actualizar referencias de UI
	_actualizar_referencias_caja_actual()
	_actualizar_referencias_slots_caja_actual()

	# Realizar inicializaciones necesarias para la nueva caja
	_inicializar_estado_nueva_caja()

	# Actualizar nombre de la caja
	var nombre_caja = gestor_cajas.obtener_nombre_caja(caja_actual) if gestor_cajas else "Caja %d" % (caja_actual + 1)
	if label_nombre_caja and is_instance_valid(label_nombre_caja):
		label_nombre_caja.text = nombre_caja

	# Actualizar sprite del Pokémon seleccionado
	_actualizar_sprite_pokemon()

	animacion_cambio_caja_activa = false
	print("✅ [CAJAS PC] Cambio de caja con animación completado")

## Realiza las inicializaciones necesarias al cambiar a una nueva caja.
func _inicializar_estado_nueva_caja() -> void:
	print("🔧 [CAJAS PC] Inicializando estado de nueva caja...")

	# 1. Configurar info_anim para animación 'default' a través del controller
	if dock_info_controller:
		dock_info_controller.activar_animacion_info("default")
		print("🎬 [CAJAS PC] info_anim configurado a 'default' vía controller")

	# 2. Activar la nueva caja usando el controller
	_activar_caja_controller(caja_actual)

	# 3. Usar la función helper para configurar el modo actual correctamente
	_cambiar_modo_navegacion(modo_navegacion)

## Configura las flechas de navegación según el modo de navegación actual.
func _configurar_flechas_segun_modo() -> void:
	match modo_navegacion:
		ModoNavegacion.NOMBRE_CAJA:
			# Cuando el cursor está sobre el nombre de la caja, las flechas deben animarse
			dock_caja_actual.configurar_flechas_activas()
		_:
			# En otros modos, detener las flechas
			dock_caja_actual.configurar_flechas_inactivas()

## Configura la sombra de la mano según el modo de navegación actual.
func _configurar_sombra_segun_modo() -> void:
	# Usar el controller para configurar la sombra si está disponible
	if dock_caja_actual and dock_caja_actual.has_method("configurar_visibilidad_sombra"):
		match modo_navegacion:
			ModoNavegacion.GRILLA:
				dock_caja_actual.configurar_visibilidad_sombra(true)
				print("👤 [CAJAS PC] Sombra de mano visible (modo GRILLA)")
			_:
				dock_caja_actual.configurar_visibilidad_sombra(false)
				print("👻 [CAJAS PC] Sombra de mano oculta")

## Cambia el modo de navegación y configura automáticamente los elementos UI.
func _cambiar_modo_navegacion(nuevo_modo: ModoNavegacion) -> void:
	if modo_navegacion == nuevo_modo:
		return

	print("🔄 [NAVEGACIÓN] Cambiando modo: %s -> %s" % [
		_obtener_nombre_modo(modo_navegacion),
		_obtener_nombre_modo(nuevo_modo)
	])

	modo_navegacion = nuevo_modo

	# Configurar elementos según el nuevo modo
	_configurar_flechas_segun_modo()
	_configurar_sombra_segun_modo()

## Obtiene el nombre del modo para debugging.
func _obtener_nombre_modo(modo: ModoNavegacion) -> String:
	match modo:
		ModoNavegacion.GRILLA: return "GRILLA"
		ModoNavegacion.NOMBRE_CAJA: return "NOMBRE_CAJA"
		ModoNavegacion.BOTON_EQUIPO: return "BOTON_EQUIPO"
		ModoNavegacion.BOTON_CERRAR: return "BOTON_CERRAR"
		ModoNavegacion.EQUIPO_POKEMON: return "EQUIPO_POKEMON"
		_: return "DESCONOCIDO"

## Actualiza las referencias a los slots de la caja actual.
func _actualizar_referencias_slots_caja_actual() -> void:
	if not dock_caja_actual:
		print("⚠️ [CAJAS PC] Error: dock_caja_actual no está definido")
		return

	# Obtener todos los slots de la caja actual
	var slots_hijos = []
	var grilla_nueva: Array[Array] = []
	var slots_lista_nueva: Array[SlotPokemon] = []

	# Buscar slots en los hijos de la caja actual
	for hijo in dock_caja_actual.get_children():
		if hijo is SlotPokemon:
			slots_hijos.append(hijo)

	# Ordenar slots por posición para mantener el orden correcto
	slots_hijos.sort_custom(func(a, b): return a.indice_grilla.y * SLOTS_HORIZONTAL + a.indice_grilla.x < b.indice_grilla.y * SLOTS_HORIZONTAL + b.indice_grilla.x)

	# Reconstruir grilla bidimensional
	for fila in range(SLOTS_VERTICAL):
		var fila_slots: Array[SlotPokemon] = []
		for columna in range(SLOTS_HORIZONTAL):
			var indice = fila * SLOTS_HORIZONTAL + columna
			if indice < slots_hijos.size():
				var slot = slots_hijos[indice] as SlotPokemon
				fila_slots.append(slot)
				slots_lista_nueva.append(slot)
		grilla_nueva.append(fila_slots)

	# Actualizar referencias globales
	grilla_slots = grilla_nueva
	slots_lista = slots_lista_nueva

	print("🔄 [CAJAS PC] Referencias de slots actualizadas: %d slots encontrados" % slots_lista.size())

## Cambia a una caja específica.
func _ir_a_caja(numero_caja: int) -> void:
	if numero_caja == caja_actual:
		return

	# Usar el nuevo sistema de instancias
	_cambiar_a_caja_instancia(numero_caja)

	# Reproducir sonido de cambio de caja
	_reproducir_sonido_cambio_caja()

	# Emitir señal de cambio de caja
	# TODO: Implementar señal cuando sea necesario

# ===================================
# ACCIONES DEL USUARIO
# ===================================

## Maneja la acción de seleccionar (botón A).
func _accion_seleccionar() -> void:
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			_accion_seleccionar_slot()
		ModoNavegacion.NOMBRE_CAJA:
			_accion_seleccionar_nombre_caja()
		ModoNavegacion.BOTON_EQUIPO:
			_accion_seleccionar_boton_equipo()
		ModoNavegacion.BOTON_CERRAR:
			_accion_seleccionar_boton_cerrar()
		ModoNavegacion.EQUIPO_POKEMON:
			_accion_seleccionar_equipo_slot()

	_reproducir_sonido_seleccion()

## Maneja la selección de un slot en la grilla.
func _accion_seleccionar_slot() -> void:
	var slot_actual = _obtener_slot_actual()
	var _slot_index = _obtener_indice_slot_actual()
	var pokemon_en_slot: BasePokemon = slot_actual.obtener_pokemon() if slot_actual else null
	# var _slot_info = {
	# 	"es_equipo": false
	# }

	# Si estamos en modo MOVER, intentar colocar el Pokémon aquí
	if modo_mover_activo and modo_mover_basepokemon:
		var nombre = modo_mover_basepokemon.mote if modo_mover_basepokemon.mote != "" else modo_mover_basepokemon.nombre
		var del_equipo = false
		var el_primero = false
		_abrir_menu_pokemon(nombre, del_equipo, el_primero, pokemon_en_slot != null)
		# _colocar_pokemon_modo_mover(slot_actual)
		return

	if modo_intercambio:
		# _procesar_intercambio(slot_index)
		pass
	elif pokemon_en_slot:
		var nombre = pokemon_en_slot.mote if pokemon_en_slot.mote != "" else pokemon_en_slot.nombre
		var del_equipo = false
		var el_primero = true
		_abrir_menu_pokemon(nombre, del_equipo, el_primero, true)
	else:
		# _accion_slot_vacio(slot_index)
		pass

## Maneja la selección del nombre de caja.
func _accion_seleccionar_nombre_caja() -> void:
	print("📝 [CAJAS PC] Acción: Editar nombre de caja")
	# TODO: Abrir diálogo para editar nombre de caja

## Maneja la selección del botón de equipo.
func _accion_seleccionar_boton_equipo() -> void:
	# En SACAR el equipo solo se abre para recibir al Pokémon sacado.
	if operacion == OPERACION_SACAR:
		_mensaje_operacion(TEXTO_CUAL_ELEGIR)
		return
	print("👥 [CAJAS PC] Acción: Abrir pantalla de equipo")
	_abrir_equipo_pokemon()

## Maneja la selección del botón de cerrar.
func _accion_seleccionar_boton_cerrar() -> void:
	print("🚪 [CAJAS PC] Acción: Cerrar cajas PC")
	_preguntar_salir()

## Maneja la selección de un slot en el equipo Pokémon.
func _accion_seleccionar_equipo_slot() -> void:
	if dock_equipo_controller.obtener_slot_actual() == 6:
		# Slot 6 es "salir": en DEJAR sale de la CAJA; en MOVER cierra el panel.
		if operacion == OPERACION_DEJAR:
			_preguntar_salir()
			return
		print("🚪 [EQUIPO] Cerrando equipo Pokémon")
		_cerrar_equipo_pokemon()
	else:
		# Slots 0-5 son Pokémon del equipo
		var slot_index = dock_equipo_controller.obtener_slot_actual()
		print("👥 [EQUIPO] Seleccionando slot %d del equipo" % (slot_index + 1))

		# Obtener el Pokémon del slot actual
		var pokemon_en_equipo: BasePokemon = dock_equipo_controller.obtener_pokemon_actual()

		# Si estamos en modo MOVER, abrir menú con opciones específicas para modo MOVER
		if modo_mover_activo and modo_mover_basepokemon:
			var nombre = modo_mover_basepokemon.mote if modo_mover_basepokemon.mote != "" else modo_mover_basepokemon.nombre
			var del_equipo = true
			var el_primero = false
			_abrir_menu_pokemon(nombre, del_equipo, el_primero, pokemon_en_equipo != null)
			return

		# Si hay un Pokémon en el slot, abrir menú de opciones
		if pokemon_en_equipo:
			var nombre = pokemon_en_equipo.mote if pokemon_en_equipo.mote != "" else pokemon_en_equipo.nombre
			var del_equipo = true
			var el_primero = true
			var tiene_pokemon = true
			_abrir_menu_pokemon(nombre, del_equipo, el_primero, tiene_pokemon)
		else:
			print("ℹ️ [EQUIPO] Slot %d está vacío - sin opciones disponibles" % (slot_index + 1))

## Abre el equipo Pokémon usando el controlador.
func _abrir_equipo_pokemon() -> void:
	if dock_equipo_controller.esta_visible():
		return  # Ya está abierto

	# Bloquear input durante la animación de apertura
	animacion_dock_equipo_activa = true
	print("🔒 [EQUIPO] Bloqueando input durante animación de apertura")

	# SINCRONIZAR: Asegurar que el controlador tenga los datos actuales del equipo
	# Convertir Array genérico a Array[BasePokemon] para cumplir con el tipo esperado
	# var equipo_tipado: Array[BasePokemon] = []
	# for pokemon in equipo_pokemon:
	# 	if pokemon is BasePokemon:
	# 		equipo_tipado.append(pokemon)
	# dock_equipo_controller.actualizar_slots(equipo_tipado)
	print("🔄 [EQUIPO] Datos sincronizados al abrir equipo: %d Pokémon" % equipo_pokemon.size())

	# Conectar la señal equipo_abierto si no está conectada
	if not dock_equipo_controller.equipo_abierto.is_connected(_on_equipo_abierto):
		dock_equipo_controller.equipo_abierto.connect(_on_equipo_abierto)

	# Usar el controlador para abrir el equipo
	dock_equipo_controller.abrir_equipo()

	# Cambiar a modo equipo
	modo_navegacion = ModoNavegacion.EQUIPO_POKEMON

	# NOTA: _actualizar_posicion_cursor() se llama en _on_equipo_abierto()
	# después de que la animación de apertura haya terminado

## Cierra el equipo Pokémon usando el controlador.
func _cerrar_equipo_pokemon() -> void:
	if not dock_equipo_controller.esta_visible():
		return  # Ya está cerrado

	# Bloquear input durante la animación de cierre
	animacion_dock_equipo_activa = true
	print("🔒 [EQUIPO] Bloqueando input durante animación de cierre")

	print("👥 [EQUIPO] Cerrando equipo Pokémon...")

	# Usar el controlador para cerrar el equipo
	# La finalización del cierre se maneja en _on_equipo_cerrado()
	dock_equipo_controller.cerrar_equipo()

## Finaliza el cierre del equipo y restaura el estado anterior.
func _finalizar_cierre_equipo() -> void:
	# Volver al modo anterior (botón equipo)
	modo_navegacion = ModoNavegacion.GRILLA
	cursor_x = columna_guardada if columna_guardada != -1 else 0
	_actualizar_posicion_cursor()
	# _actualizar_posicion_cursor_ui()

## Callback cuando el equipo se ha abierto completamente.
func _on_equipo_abierto() -> void:
	print("👥 [EQUIPO] Equipo abierto - actualizando posición del cursor")

	# Desbloquear input ahora que la animación terminó
	animacion_dock_equipo_activa = false
	print("🔓 [EQUIPO] Desbloqueando input - animación de apertura terminada")

	# Ahora que la animación terminó, actualizar la posición del cursor
	_actualizar_posicion_cursor()

	if dock_info_controller and !modo_mover_activo:
		# Actualizar el DockInfo con el Pokémon del slot inicial
		var slot_actual = dock_equipo_controller.obtener_slot_actual()
		var pokemon_inicial = dock_equipo_controller.obtener_pokemon_actual()

		print("🔍 [DEBUG] Slot actual: %d, Pokémon: %s" % [slot_actual, "null" if not pokemon_inicial else pokemon_inicial.nombre_interno])

		if pokemon_inicial:
			dock_info_controller.mostrar_info(pokemon_inicial)
			print("🔍 [INFO] Mostrando información inicial de %s" % pokemon_inicial.nombre_interno)
		else:
			print("🔍 [INFO] No hay Pokémon en el slot inicial o está vacío")

	# Desconectar la señal para evitar callbacks múltiples
	if dock_equipo_controller.equipo_abierto.is_connected(_on_equipo_abierto):
		dock_equipo_controller.equipo_abierto.disconnect(_on_equipo_abierto)

## Callback cuando el equipo se ha cerrado completamente.
func _on_equipo_cerrado() -> void:
	print("👥 [EQUIPO] Equipo cerrado - finalizando cierre")

	# Desbloquear input ahora que la animación terminó
	animacion_dock_equipo_activa = false
	print("🔓 [EQUIPO] Desbloqueando input - animación de cierre terminada")

	# Ahora que la animación de cierre terminó, finalizar el cierre
	_finalizar_cierre_equipo()

## Callback cuando cambia el slot seleccionado en el equipo.
func _on_slot_equipo_cambiado(slot_index: int) -> void:
	print("👥 [EQUIPO] Slot cambiado a: %d" % slot_index)

	# DEBUG: Verificar estado del equipo usando el controlador
	var equipo_actual = dock_equipo_controller.obtener_equipo_completo()
	print("🔍 [DEBUG] Tamaño del equipo_pokemon: %d" % equipo_actual.size())
	if slot_index < equipo_actual.size() and equipo_actual[slot_index]:
		print("🔍 [DEBUG] Pokémon en array[%d]: %s" % [slot_index, equipo_actual[slot_index].nombre_interno])
	else:
		print("🔍 [DEBUG] No hay Pokémon en array[%d] o está fuera de rango" % slot_index)

	# Obtener el Pokémon del slot actual
	var pokemon_actual = dock_equipo_controller.obtener_pokemon_actual()
	print("🔍 [DEBUG] obtener_pokemon_actual() devuelve: %s" % ("null" if not pokemon_actual else pokemon_actual.nombre_interno))

	# Actualizar el DockInfo con el Pokémon seleccionado usando transiciones
	if dock_info_controller and !modo_mover_activo:
		if pokemon_actual:
			# Usar el sistema completo de transiciones como en modo grilla
			_mostrar_sprite_pokemon(pokemon_actual)
			_mostrar_info_pokemon(pokemon_actual)
			_activar_animacion_info("encendido")
			print("🔍 [INFO] Mostrando información de %s con transiciones" % pokemon_actual.nombre_interno)
		else:
			# Usar el sistema completo para ocultar como en modo grilla
			_ocultar_sprite_pokemon()
			_ocultar_info_pokemon()
			_activar_animacion_info("default")
			print("🔍 [INFO] Ocultando información (slot vacío o salir)")

## Callback cuando inicia una animación en el equipo (bloquear input).
func _on_animacion_equipo_iniciada() -> void:
	animacion_reorganizacion_activa = true
	print("🔒 [ANIMACION EQUIPO] Input bloqueado - animación de reorganización iniciada")

## Callback cuando termina una animación en el equipo (desbloquear input).
func _on_animacion_equipo_terminada() -> void:
	animacion_reorganizacion_activa = false

	# SINCRONIZAR: Asegurar que el array legacy esté actualizado después de cualquier animación
	_sincronizar_equipo_desde_controlador()

	print("🔓 [ANIMACION EQUIPO] Input desbloqueado - animación de reorganización terminada")

## Maneja la selección de opciones del menú PC.
func _on_menu_pc_opcion_seleccionada(opcion: String, _contexto: Dictionary) -> void:
	print("🎯 [MENU PC] Opción seleccionada: %s" % opcion)

	# Manejar cada opción específica
	match opcion:
		"MOVER":
			_mover_pokemon()
		"COLOCAR":
			_colocar_pokemon_modo_mover()   # Usado en el modo MOVER para colocar el Pokémon
		"CAMBIO":
			_intercambiar_pokemon_sostenido()
		"DEJAR":
			_dejar_pokemon_en_caja()
		"SACAR":
			_sacar_pokemon_al_equipo()
		"MARCAR", "SOLTAR":
			pass  # No implementados en este proyecto.
		"DATOS":
			_mostrar_pantalla_info_pokemon()
		"SALIR":
			print("🚪 [MENU PC] Opción SALIR seleccionada - Activando cooldown de input")
			_activar_cooldown_input()
		_:
			print("⚠️ [MENU PC] Opción no implementada: %s" % opcion)


## Muestra un aviso en la ventana inferior hasta que se pulse A/B (o la cruceta,
## salvo con `solo_ab`). `sonido_fallo` reproduce SE_FAILURE como Ruby en las
## acciones rechazadas; `al_cerrar` se ejecuta al cerrar el aviso.
func _mensaje_operacion(texto: String, sonido_fallo: bool = false, solo_ab: bool = false, al_cerrar: Callable = Callable()) -> void:
	if sonido_fallo:
		Singleton.play_sound.emit(SONIDO_FALLO)
	menu_pc.mostrar_solo_mensaje(texto)
	mostrando_mensaje_pokemon = true
	mensaje_solo_ab = solo_ab
	al_cerrar_mensaje = al_cerrar
	_activar_cooldown_input()


## true si en el equipo queda algún Pokémon útil (no HUEVO y con PS) además del
## slot `excluir` (pokeruby CanMovePartyMon).
func _hay_otro_pokemon_util(excluir: int) -> bool:
	var equipo: Array = dock_equipo_controller.obtener_equipo_completo()
	for i in equipo.size():
		var pokemon: BasePokemon = equipo[i]
		if i != excluir and pokemon != null and not pokemon.huevo and pokemon.estad_ps_actual > 0:
			return true
	return false


## MOVER: agarra el Pokémon bajo el cursor. Del equipo solo si no es el último
## Pokémon útil.
func _mover_pokemon() -> void:
	if esta_en_modo_mover() or secuencia_activa:
		return
	if modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		if dock_equipo_controller.obtener_pokemon_actual() == null:
			return
		if not _hay_otro_pokemon_util(dock_equipo_controller.obtener_slot_actual()):
			_mensaje_operacion(TEXTO_ULTIMO_POKEMON, true)
			return
	_iniciar_animacion_mover()


## SACAR (modo SACAR y SACAR de MOVER), como Ruby: la mano agarra el Pokémon de
## la caja (si no lleva ya uno), se abre el equipo, la mano va al primer hueco
## y lo suelta allí, el equipo se cierra y el cursor vuelve al slot de origen.
## Sin mensaje final. El input queda bloqueado durante toda la secuencia.
func _sacar_pokemon_al_equipo() -> void:
	if secuencia_activa:
		return
	var sosteniendo: bool = esta_en_modo_mover()
	if not sosteniendo:
		if modo_navegacion != ModoNavegacion.GRILLA:
			return
		if gestor_cajas.obtener_pokemon(caja_actual, _obtener_indice_slot_actual()) == null:
			return
	if _contar_pokemon_equipo() >= SistemaGuardado.MAX_POKEMON_EQUIPO:
		_mensaje_operacion(TEXTO_EQUIPO_COMPLETO)
		return

	secuencia_activa = true
	var cursor_origen := Vector2i(cursor_x, cursor_y)
	var modo_origen: ModoNavegacion = modo_navegacion

	if not sosteniendo:
		if not await _animar_agarrar():
			return
	if not esta_en_modo_mover():
		secuencia_activa = false
		return
	var origen: Dictionary = origen_pokemon_sostenido.duplicate()

	if not dock_equipo_controller.esta_visible():
		columna_guardada = cursor_origen.x
		_abrir_equipo_pokemon()
		if not await _esperar_mientras(func() -> bool: return animacion_dock_equipo_activa):
			return

	# La mano va al primer hueco del equipo: min(nº de Pokémon, 5).
	var destino: int = mini(_contar_pokemon_equipo(), SistemaGuardado.MAX_POKEMON_EQUIPO - 1)
	modo_navegacion = ModoNavegacion.EQUIPO_POKEMON
	dock_equipo_controller.configurar_slot_actual(destino)
	_actualizar_posicion_cursor()
	if not await _esperar_tween(tween_cursor):
		return
	if not await _animar_soltar():
		return
	if not esta_en_modo_mover():
		pokemon_retirado.emit(int(origen.get("caja", -1)), int(origen.get("slot", -1)), destino)

	if modo_origen != ModoNavegacion.EQUIPO_POKEMON:
		_cerrar_equipo_pokemon()
		if not await _esperar_mientras(func() -> bool: return animacion_dock_equipo_activa):
			return
		modo_navegacion = ModoNavegacion.GRILLA
		cursor_x = cursor_origen.x
		cursor_y = cursor_origen.y
		_actualizar_posicion_cursor()
		_actualizar_seleccion_visual()
	secuencia_activa = false


## DEJAR (modo DEJAR y DEJAR de MOVER): "¿Dejar en qué CAJA?" con la ventana de
## elección de caja. Sin animación de mano, como en Ruby. Si la mano lleva un
## Pokémon se deja ese; si no, el del slot del equipo bajo el cursor (salvo que
## sea el último Pokémon útil).
func _dejar_pokemon_en_caja() -> void:
	if secuencia_activa:
		return
	if not esta_en_modo_mover():
		if modo_navegacion != ModoNavegacion.EQUIPO_POKEMON:
			return
		if dock_equipo_controller.obtener_pokemon_actual() == null:
			return
		if not _hay_otro_pokemon_util(dock_equipo_controller.obtener_slot_actual()):
			_mensaje_operacion(TEXTO_ULTIMO_POKEMON, true)
			return
	_mostrar_selector_dejar()


## Abre (o reabre) la ventana de elección de caja con su pregunta.
func _mostrar_selector_dejar() -> void:
	var nombres: Array[String] = []
	var conteos: Array[int] = []
	for i in TOTAL_CAJAS:
		nombres.append(gestor_cajas.obtener_nombre_caja(i))
		conteos.append(gestor_cajas.contar_pokemon_en_caja(i))
	menu_pc.mostrar_selector_caja(caja_selector_dejar, nombres, conteos)
	menu_pc.mostrar_mensaje(TEXTO_DEJAR_EN_CAJA)


## Respuesta de la ventana "¿Dejar en qué CAJA?" (-1 = cancelada con B).
func _on_caja_elegida(indice: int) -> void:
	_activar_cooldown_input()
	if indice < 0:
		menu_pc.ocultar_mensaje()
		return
	indice = clampi(indice, 0, TOTAL_CAJAS - 1)
	caja_selector_dejar = indice
	if gestor_cajas.primer_slot_libre(indice) < 0:
		# La ventana sigue en pantalla; tras A/B se vuelve a preguntar.
		_mensaje_operacion(TEXTO_CAJA_LLENA, false, true, _reabrir_selector_dejar)
		return
	menu_pc.ocultar_selector_caja()
	menu_pc.ocultar_mensaje()
	_depositar_en_caja(indice)


func _reabrir_selector_dejar() -> void:
	if menu_pc.selector_caja_visible():
		menu_pc.reactivar_selector_caja()
		menu_pc.mostrar_mensaje(TEXTO_DEJAR_EN_CAJA)
	else:
		_mostrar_selector_dejar()


## Deja en el primer hueco de `caja` el Pokémon de la mano o, si no lleva
## ninguno, el del slot del equipo bajo el cursor: su icono desaparece al
## momento y el equipo se compacta (el cursor se queda en el mismo índice).
func _depositar_en_caja(caja: int) -> bool:
	var slot: int = gestor_cajas.primer_slot_libre(caja)
	if slot < 0:
		return false
	var pokemon: BasePokemon = null
	var indice_equipo: int = -1
	if esta_en_modo_mover():
		pokemon = modo_mover_basepokemon
		_soltar_pokemon_de_la_mano()
		if mano:
			mano.play("idle")
	else:
		indice_equipo = dock_equipo_controller.obtener_slot_actual()
		pokemon = dock_equipo_controller.remover_pokemon_de_slot(indice_equipo)
		if pokemon == null:
			return false
		_sincronizar_equipo_desde_controlador()
	_escribir_en_caja(caja, slot, pokemon)
	_sincronizar_con_sistema_guardado()
	pokemon_depositado.emit(indice_equipo, caja, slot)
	_refrescar_info_tras_cambio()
	return true


## CAMBIO: deja el Pokémon de la mano en el slot bajo el cursor y agarra el que
## había, sin compactar el equipo. En el equipo no se permite si así no quedaría
## ningún Pokémon útil (el de la mano es HUEVO o está debilitado).
func _intercambiar_pokemon_sostenido() -> void:
	if not esta_en_modo_mover() or secuencia_activa or not mano:
		return
	var otro: BasePokemon = null
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			otro = gestor_cajas.obtener_pokemon(caja_actual, _obtener_indice_slot_actual())
		ModoNavegacion.EQUIPO_POKEMON:
			otro = dock_equipo_controller.obtener_pokemon_actual()
			var sostenido_inutil: bool = modo_mover_basepokemon.huevo or modo_mover_basepokemon.estad_ps_actual <= 0
			if otro != null and sostenido_inutil and not _hay_otro_pokemon_util(dock_equipo_controller.obtener_slot_actual()):
				_mensaje_operacion(TEXTO_ULTIMO_POKEMON, true)
				return
	if otro == null:
		return

	# Animación breve: la mano baja, cambia los Pokémon y vuelve a subir.
	secuencia_activa = true
	var posicion_inicial: Vector2 = mano.position
	mano.frame = 2
	var tween: Tween = create_tween()
	tween.tween_property(mano, "position", posicion_inicial + Vector2(0, 8), 0.15)
	tween.tween_callback(_ejecutar_intercambio)
	tween.tween_callback(func() -> void: mano.frame = 3)
	tween.tween_property(mano, "position", posicion_inicial, 0.15)
	if not await _esperar_tween(tween):
		return
	secuencia_activa = false


## Ejecuta el intercambio de datos del CAMBIO (llamado desde su animación).
func _ejecutar_intercambio() -> void:
	if not esta_en_modo_mover():
		return
	var dejado: BasePokemon = modo_mover_basepokemon
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			var indice: int = _obtener_indice_slot_actual()
			var otro: BasePokemon = gestor_cajas.obtener_pokemon(caja_actual, indice)
			if otro == null:
				return
			var slot: SlotPokemon = _obtener_slot_visual(caja_actual, indice)
			var icono: CanvasItem = slot.icono_pokemon.duplicate() if slot else null
			_escribir_en_caja(caja_actual, indice, dejado)
			_tomar_en_mano(otro, icono, {"caja": caja_actual, "slot": indice})
		ModoNavegacion.EQUIPO_POKEMON:
			var indice_equipo: int = dock_equipo_controller.obtener_slot_actual()
			var icono_equipo: Sprite2D = dock_equipo_controller.obtener_icono_pokemon_actual()
			var icono: CanvasItem = icono_equipo.duplicate() if icono_equipo else null
			var otro: BasePokemon = dock_equipo_controller.intercambiar_pokemon_en_slot(indice_equipo, dejado)
			if otro == null:
				if icono:
					icono.free()
				return
			_sincronizar_equipo_desde_controlador()
			_tomar_en_mano(otro, icono, {"equipo": indice_equipo})
		_:
			return
	_sincronizar_con_sistema_guardado()
	_refrescar_info_tras_cambio()

## Activa el cooldown de input para evitar cierre inmediato del PC.
func _activar_cooldown_input() -> void:
	input_cooldown_activo = true
	tecla_cancelar_presionada = true
	tecla_accion_presionada = true
	print("⏳ [COOLDOWN] Input cooldown activado - Esperando release de ambas teclas (cancelar y acción)")

## Desactiva el cooldown de input cuando se sueltan ambas teclas.
func _desactivar_cooldown_input() -> void:
	if input_cooldown_activo and not tecla_cancelar_presionada and not tecla_accion_presionada:
		input_cooldown_activo = false
		print("✅ [COOLDOWN] Input cooldown desactivado - Ambas teclas liberadas")

## Inicia la animación de "MOVER": baja la mano, abre, cierra y levanta el Pokémon.
func _iniciar_animacion_mover() -> void:
	if animacion_mover_activa or not mano:
		return

	print("✋ [ANIMACION MOVER] Iniciando secuencia de animación de mover")
	animacion_mover_activa = true
	animacion_activa = true  # Bloquear input

	# Detener tween anterior si existe
	if tween_mano_mover and tween_mano_mover.is_valid():
		tween_mano_mover.kill()

	# Crear nuevo tween
	tween_mano_mover = create_tween()

	# Obtener posición actual de la mano
	var posicion_inicial = mano.position
	var posicion_bajada = Vector2(posicion_inicial.x, posicion_inicial.y + 8)

	# Secuencia de animación:
	# 1. Bajar la mano 8 píxeles con frame 2 (mano abierta)
	mano.play("default")
	mano.stop()
	mano.frame = 2  # Frame 2: mano abierta
	tween_mano_mover.tween_property(mano, "position", posicion_bajada, 0.15)

	# 2. Esperar un momento y cerrar la mano (frame 3)
	# tween_mano_mover.tween_callback(_anima_mover_cerrar_mano.bind(3)).set_delay(0.1)
	tween_mano_mover.tween_callback(_anima_mover_cerrar_mano.bind(3))

	# 3. Levantar el Pokémon (volver a posición inicial)
	# tween_mano_mover.tween_property(mano, "position", posicion_inicial, 0.3).set_delay(0.2)
	tween_mano_mover.tween_property(mano, "position", posicion_inicial, 0.15)

	# 4. Al finalizar, restablecer estado
	tween_mano_mover.tween_callback(_finalizar_animacion_mover)

	print("🎬 [ANIMACION MOVER] Secuencia iniciada: bajar → abrir → cerrar → levantar")

## Cambia el frame de la animación de la mano.
func _anima_mover_cerrar_mano(frame: int) -> void:
	if mano and mano.sprite_frames:
		mano.frame = frame
		print("🖐️ [ANIMACION MOVER] Frame cambiado a: %d" % frame)

	# Iniciar modo MOVER: copiar el Pokémon a variable temporal
	_iniciar_modo_mover()

## Finaliza la animación de mover y restaura el estado normal.
func _finalizar_animacion_mover() -> void:
	print("✅ [ANIMACION MOVER] Secuencia completada")
	animacion_mover_activa = false
	animacion_activa = false  # Desbloquea input

## Inicia la animación de "COLOCAR": baja la mano, abre, coloca el Pokémon, sube la mano.
func _iniciar_animacion_colocar() -> void:
	if animacion_colocar_activa or not mano:
		return

	print("🎯 [ANIMACION COLOCAR] Iniciando secuencia de animación de colocar")
	animacion_colocar_activa = true
	animacion_activa = true  # Bloquear input

	# Detener tween anterior si existe
	if tween_mano_colocar and tween_mano_colocar.is_valid():
		tween_mano_colocar.kill()

	# Crear nuevo tween
	tween_mano_colocar = create_tween()

	# Obtener posición actual de la mano
	var posicion_inicial = mano.position
	var posicion_bajada = Vector2(posicion_inicial.x, posicion_inicial.y + 8)

	# Secuencia de animación:
	# 1. Bajar la mano 8 píxeles con frame 3 (mano cerrada con Pokémon)
	# mano.play("default")
	# mano.stop()
	mano.frame = 3  # Frame 3: mano cerrada
	tween_mano_colocar.tween_property(mano, "position", posicion_bajada, 0.15)

	# 2. Abrir la mano (frame 2) y ejecutar colocación
	tween_mano_colocar.tween_callback(_anima_colocar_abrir_mano.bind(2))   # Mano abierto y ejecutar colocación

	# 3. Levantar la mano (volver a posición inicial)
	tween_mano_colocar.tween_property(mano, "position", posicion_inicial, 0.15)

	# 4. Al finalizar, restablecer estado
	tween_mano_colocar.tween_callback(_finalizar_animacion_colocar)

	print("🎬 [ANIMACION COLOCAR] Secuencia iniciada: bajar → abrir → colocar → levantar")

## Cambia el frame de la animación de la mano y ejecuta la colocación.
func _anima_colocar_abrir_mano(frame: int) -> void:
	if mano:
		mano.frame = frame
		print("🖐️ [ANIMACION COLOCAR] Frame cambiado a: %d" % frame)

	# Ejecutar la colocación real del Pokémon
	_ejecutar_colocacion_pokemon()

## Finaliza la animación de colocar y restaura el estado normal.
func _finalizar_animacion_colocar() -> void:
	print("✅ [ANIMACION COLOCAR] Secuencia completada")
	animacion_colocar_activa = false
	animacion_activa = false  # Desbloquea input

	# Si la colocación no se pudo hacer, la mano sigue cerrada con su Pokémon;
	# si se hizo, vuelve a la animación idle.
	if mano:
		if esta_en_modo_mover():
			mano.frame = 3
		else:
			mano.play("idle")

## Ejecuta la colocación real del Pokémon (llamada desde la animación): lo
## escribe en el gestor de cajas o en el equipo (nunca solo en el slot visual) y
## sincroniza con SistemaGuardado. Si el destino está ocupado no hace nada y la
## mano conserva el Pokémon.
func _ejecutar_colocacion_pokemon() -> void:
	if not esta_en_modo_mover():
		print("❌ [COLOCACION] Error: no hay Pokémon temporal para colocar")
		return

	var pokemon: BasePokemon = modo_mover_basepokemon
	if modo_navegacion == ModoNavegacion.GRILLA:
		var indice: int = _obtener_indice_slot_actual()
		if not gestor_cajas.esta_slot_vacio(caja_actual, indice):
			print("❌ [COLOCACION] Slot %d de la caja %d ocupado" % [indice, caja_actual])
			return
		print("✅ [COLOCACION] Colocando %s en caja %d, slot %d" % [pokemon.get_nombre_mostrar(), caja_actual, indice])
		_soltar_pokemon_de_la_mano()
		_escribir_en_caja(caja_actual, indice, pokemon)
	elif modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		# Se escribe en el slot del cursor y el equipo se compacta (si queda
		# detrás del último Pokémon, su icono se desliza hasta el hueco).
		var indice_equipo: int = dock_equipo_controller.obtener_slot_actual()
		if not dock_equipo_controller.colocar_pokemon_en_slot(indice_equipo, pokemon):
			print("❌ [COLOCACION] No se pudo colocar en el slot %d del equipo" % indice_equipo)
			return
		print("✅ [COLOCACION] Colocando %s en equipo, posición %d" % [pokemon.get_nombre_mostrar(), indice_equipo])
		_soltar_pokemon_de_la_mano()
		_sincronizar_equipo_desde_controlador()
	else:
		print("❌ [COLOCACION] Error: Modo de navegación no soportado")
		return

	# Sincronizar cambios con el sistema de guardado
	_sincronizar_con_sistema_guardado()
	_refrescar_info_tras_cambio()

# ===================================
# FUNCIONES DEL MODO MOVER
# ===================================

## Inicia el modo MOVER: la mano toma el Pokémon bajo el cursor (la misma
## instancia, no una copia) y lo quita de su ubicación original.
func _iniciar_modo_mover() -> void:
	var pokemon: BasePokemon = _obtener_pokemon_actual()
	if not pokemon:
		print("❌ [MODO MOVER] Error al obtener el Pokémon actual")
		return
	print("🚀 [MODO MOVER] Iniciando modo MOVER con: %s" % pokemon.get_nombre_mostrar())

	var icono: CanvasItem = null
	var origen: Dictionary = {}
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			var indice: int = _obtener_indice_slot_actual()
			var slot: SlotPokemon = _obtener_slot_visual(caja_actual, indice)
			if slot:
				icono = slot.icono_pokemon.duplicate()
			origen = {"caja": caja_actual, "slot": indice}
		ModoNavegacion.EQUIPO_POKEMON:
			var icono_equipo: Sprite2D = dock_equipo_controller.obtener_icono_pokemon_actual()
			if icono_equipo:
				icono = icono_equipo.duplicate()
			origen = {"equipo": dock_equipo_controller.obtener_slot_actual()}

	_tomar_en_mano(pokemon, icono, origen)

	# REMOVER el Pokémon de su ubicación original
	_remover_pokemon_de_origen()


## Pokémon bajo el cursor, en el equipo o en la grilla de la caja actual.
func _obtener_pokemon_actual() -> BasePokemon:
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			return gestor_cajas.obtener_pokemon(caja_actual, _obtener_indice_slot_actual())
		ModoNavegacion.EQUIPO_POKEMON:
			return dock_equipo_controller.obtener_pokemon_actual()
		_:
			return null

## Remueve el Pokémon de su ubicación original según el modo de navegación.
func _remover_pokemon_de_origen() -> void:
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			_remover_pokemon_de_grilla()
		ModoNavegacion.EQUIPO_POKEMON:
			_remover_pokemon_de_equipo()
		_:
			print("⚠️ [MODO MOVER] Modo de navegación no soportado para remoción")

## Remueve el Pokémon de un slot de la grilla (lo deja vacío).
func _remover_pokemon_de_grilla() -> void:
	_quitar_de_caja(caja_actual, _obtener_indice_slot_actual())
	print("📤 [MODO MOVER] Pokémon removido de slot (%d,%d) en caja %d" % [cursor_x, cursor_y, caja_actual])

	# Sincronizar cambios con el sistema de guardado
	_sincronizar_con_sistema_guardado()

## Remueve el Pokémon del equipo (los siguientes se mueven hacia arriba).
func _remover_pokemon_de_equipo() -> void:
	if not dock_equipo_controller:
		print("⚠️ [MODO MOVER] Error: dock_equipo_controller no disponible")
		return

	var slot_actual = dock_equipo_controller.obtener_slot_actual()

	# Remover el Pokémon del equipo usando el controlador
	var pokemon_removido = dock_equipo_controller.remover_pokemon_de_slot(slot_actual)

	if pokemon_removido:
		print("📤 [MODO MOVER] Pokémon %s removido del equipo slot %d" % [pokemon_removido.get_nombre_mostrar(), slot_actual])

		# SINCRONIZAR: Actualizar el array legacy del controlador principal
		_sincronizar_equipo_desde_controlador()

		# Sincronizar cambios con el sistema de guardado
		_sincronizar_con_sistema_guardado()
	else:
		print("⚠️ [MODO MOVER] No había Pokémon en el slot %d para remover" % slot_actual)

## La mano pasa a llevar `pokemon` (que debe haber salido ya, o salir justo
## después, de su ubicación) con `icono` colgando de ella. `origen` sirve para
## devolverlo si la pantalla se cierra a la fuerza.
func _tomar_en_mano(pokemon: BasePokemon, icono: CanvasItem, origen: Dictionary) -> void:
	modo_mover_activo = true
	modo_mover_basepokemon = pokemon
	origen_pokemon_sostenido = origen
	if modo_mover_sprite and is_instance_valid(modo_mover_sprite):
		modo_mover_sprite.queue_free()
	modo_mover_sprite = icono
	if icono and mano:
		icono.visible = true
		icono.z_index = -1
		mano.add_child(icono)
		icono.position = Vector2(-16, -12)

## La mano deja de llevar Pokémon (el que llevaba ya se escribió en otro sitio).
func _soltar_pokemon_de_la_mano() -> void:
	modo_mover_activo = false
	modo_mover_basepokemon = null
	origen_pokemon_sostenido = {}
	if modo_mover_sprite and is_instance_valid(modo_mover_sprite):
		modo_mover_sprite.queue_free()
	modo_mover_sprite = null

## Devuelve el Pokémon de la mano para que no se pierda si la pantalla se cierra
## a la fuerza: a su slot de origen de la caja si sigue libre; si no, al primer
## hueco del equipo y, si está lleno, al primer hueco de las cajas. Sin ningún
## hueco en todo el PC se conserva en `pokemon_sin_hueco` (se guarda aparte).
func _devolver_pokemon_sostenido() -> void:
	if not esta_en_modo_mover():
		return
	var pokemon: BasePokemon = modo_mover_basepokemon
	var origen: Dictionary = origen_pokemon_sostenido.duplicate()
	_soltar_pokemon_de_la_mano()
	print("↩️ [MODO MOVER] Devolviendo %s antes de cerrar" % pokemon.get_nombre_mostrar())

	if origen.has("caja") and gestor_cajas.esta_slot_vacio(int(origen.caja), int(origen.slot)):
		_escribir_en_caja(int(origen.caja), int(origen.slot), pokemon)
		return
	var cantidad_equipo: int = _contar_pokemon_equipo()
	if cantidad_equipo < SistemaGuardado.MAX_POKEMON_EQUIPO and dock_equipo_controller.colocar_pokemon_en_slot(cantidad_equipo, pokemon):
		_sincronizar_equipo_desde_controlador()
		return
	var hueco: Vector2i = gestor_cajas.encontrar_primer_slot_vacio()
	if hueco.x >= 0:
		_escribir_en_caja(hueco.x, hueco.y, pokemon)
		return
	gestor_cajas.pokemon_sin_hueco.append(pokemon)

## Escribe un Pokémon en el gestor de cajas y en el slot visual de esa caja.
## Al entrar en una caja se restauran PP, PS y estado (pokeruby
## BoxMonRestorePP / SendMonToPC).
func _escribir_en_caja(caja: int, slot: int, pokemon: BasePokemon) -> void:
	SistemaGuardado._preparar_pokemon_para_caja(pokemon)
	gestor_cajas.colocar_pokemon(caja, slot, pokemon)
	var visual: SlotPokemon = _obtener_slot_visual(caja, slot)
	if visual:
		visual.asignar_pokemon(pokemon)

## Quita un Pokémon del gestor de cajas y de su slot visual.
func _quitar_de_caja(caja: int, slot: int) -> BasePokemon:
	var pokemon: BasePokemon = gestor_cajas.quitar_pokemon(caja, slot)
	var visual: SlotPokemon = _obtener_slot_visual(caja, slot)
	if visual:
		visual.asignar_pokemon(null)
	return pokemon

## Slot visual (SlotPokemon) de cualquier caja, aunque no sea la visible.
func _obtener_slot_visual(caja: int, slot: int) -> SlotPokemon:
	if caja < 0 or caja >= instancias_cajas.size():
		return null
	for hijo in instancias_cajas[caja].get_children():
		if hijo is SlotPokemon and hijo.indice_grilla.y * SLOTS_HORIZONTAL + hijo.indice_grilla.x == slot:
			return hijo
	return null

## Refresca el DockInfo/selección tras escribir datos bajo el cursor.
func _refrescar_info_tras_cambio() -> void:
	if modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		_on_slot_equipo_cambiado(dock_equipo_controller.obtener_slot_actual())
	elif modo_navegacion == ModoNavegacion.GRILLA:
		_actualizar_seleccion_visual()

## Muestra "¡Llevas un POKéMON!" (con sonido de fallo) al intentar salir con
## un Pokémon en la mano; la mano lo conserva.
func _mensaje_moviendo() -> void:
	if not esta_en_modo_mover():
		return
	print("❌ [MODO MOVER] Intento de salir llevando un Pokémon")
	_mensaje_operacion(TEXTO_LLEVAS_POKEMON, true)

## Cierra el aviso de la ventana inferior y ejecuta su acción pendiente.
func _cerrar_mensaje_pokemon() -> void:
	if not mostrando_mensaje_pokemon:
		return

	# Ocultar el mensaje
	mostrando_mensaje_pokemon = false
	mensaje_solo_ab = false
	menu_pc.ocultar_mensaje()

	# Activar cooldown breve para evitar input inmediato
	_activar_cooldown_input()

	var accion: Callable = al_cerrar_mensaje
	al_cerrar_mensaje = Callable()
	if accion.is_valid():
		accion.call()

## Agarra el Pokémon bajo el cursor con la animación de MOVER y espera a que
## termine. Devuelve false si la pantalla salió del árbol entretanto.
func _animar_agarrar() -> bool:
	_iniciar_animacion_mover()
	return await _esperar_mientras(func() -> bool: return animacion_mover_activa)

## Suelta el Pokémon de la mano con la animación de COLOCAR y espera a que
## termine. Devuelve false si la pantalla salió del árbol entretanto.
func _animar_soltar() -> bool:
	_iniciar_animacion_colocar()
	return await _esperar_mientras(func() -> bool: return animacion_colocar_activa)

## Espera a que un tween termine (o lo maten). false si la pantalla salió del árbol.
func _esperar_tween(tween: Tween) -> bool:
	return await _esperar_mientras(func() -> bool: return tween != null and tween.is_valid() and tween.is_running())

## Espera frame a frame mientras `condicion` sea cierta. false si la pantalla
## salió del árbol (la secuencia debe abandonarse).
func _esperar_mientras(condicion: Callable) -> bool:
	while condicion.call():
		if not is_inside_tree():
			return false
		await get_tree().process_frame
	return is_inside_tree()

## Indica si hay alguna animación o secuencia en curso (útil para pruebas).
func esta_ocupada() -> bool:
	return secuencia_activa or animacion_activa or animacion_mover_activa or animacion_colocar_activa \
		or animacion_dock_equipo_activa or animacion_reorganizacion_activa or animacion_cambio_caja_activa

## Verifica si hay un Pokémon en modo MOVER.
func esta_en_modo_mover() -> bool:
	return modo_mover_activo and modo_mover_basepokemon != null

## Obtiene el Pokémon temporal del modo MOVER.
func obtener_pokemon_temporal_mover() -> BasePokemon:
	return modo_mover_basepokemon if modo_mover_activo else null

## Coloca el Pokémon agarrado en el slot especificado.
func _colocar_pokemon_modo_mover() -> void:
	if not modo_mover_activo or not modo_mover_basepokemon:
		print("❌ [MODO MOVER] Error: no hay Pokémon temporal para colocar")
		return

	# Verificar que el destino es válido antes de iniciar la animación
	if modo_navegacion == ModoNavegacion.GRILLA:
		var slot_destino = _obtener_slot_en_posicion(cursor_x, cursor_y)
		if not slot_destino or not gestor_cajas.esta_slot_vacio(caja_actual, _obtener_indice_slot_actual()):
			print("❌ [MODO MOVER] Error: slot de destino no válido")
			return
		print("🎯 [MODO MOVER] Iniciando animación de colocación en grilla")
	elif modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		var indice_equipo: int = dock_equipo_controller.obtener_slot_actual()
		if indice_equipo < 0 or indice_equipo >= SistemaGuardado.MAX_POKEMON_EQUIPO or dock_equipo_controller.obtener_pokemon_actual() != null:
			print("❌ [MODO MOVER] Error: slot del equipo no válido")
			return
		print("🎯 [MODO MOVER] Iniciando animación de colocación en equipo")
	else:
		print("❌ [MODO MOVER] Error: Modo de navegación no soportado para colocar")
		return

	# Iniciar la animación de colocar
	_iniciar_animacion_colocar()

## Obtiene un slot por su índice lineal.
func _obtener_slot_por_indice(indice: int) -> SlotPokemon:
	if indice >= 0 and indice < slots_lista.size():
		return slots_lista[indice]
	return null

# ===================================
# FUNCIONES DE UTILIDAD PARA MODO MOVER
# ===================================

## Indica si el cursor está mostrando un estado especial en modo MOVER.
func _cursor_tiene_estado_especial() -> bool:
	return modo_mover_activo

## Muestra la pantalla de información del Pokémon seleccionado.
func _mostrar_pantalla_info_pokemon() -> void:
	# Si estamos en modo MOVER, mostrar info del Pokémon temporal
	if modo_mover_activo and modo_mover_basepokemon:
		print("📖 [PANTALLA_INFO] Mostrando información del Pokémon en modo MOVER: %s" % modo_mover_basepokemon.get_nombre_mostrar())

		# Crear lista con solo el Pokémon temporal
		var lista_modo_mover: Array[BasePokemon] = [modo_mover_basepokemon]
		_crear_pantalla_info(lista_modo_mover, 0)
		return

	# Obtener el Pokémon actualmente seleccionado (modo normal)
	var pokemon_actual: BasePokemon = null
	var indice_inicial: int = 0

	if modo_navegacion == ModoNavegacion.GRILLA:
		# Obtener pokemon en la posición del cursor
		var slot_actual = _obtener_slot_actual()
		pokemon_actual = slot_actual.obtener_pokemon() if slot_actual else null
		if pokemon_actual:
			indice_inicial = _obtener_indice_slot_actual()
	elif modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		# Obtener pokemon del equipo seleccionado
		pokemon_actual = dock_equipo_controller.obtener_pokemon_actual()
		if pokemon_actual:
			indice_inicial = dock_equipo_controller.obtener_slot_actual()

	if not pokemon_actual:
		print("❌ [PANTALLA_INFO] No hay Pokémon seleccionado para mostrar información")
		return

	print("📖 [PANTALLA_INFO] Mostrando información de: %s" % pokemon_actual.get_nombre_mostrar())

	# Obtener toda la lista de Pokémon de la caja/equipo actual
	var lista_pokemon: Array[BasePokemon] = []

	if modo_navegacion == ModoNavegacion.GRILLA:
		# Obtener todos los Pokémon de la caja actual
		lista_pokemon = _obtener_pokemones_caja_actual()
		indice_inicial = _calcular_indice_en_lista_caja(pokemon_actual)
	elif modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		# Obtener todos los Pokémon del equipo
		lista_pokemon = _obtener_pokemones_equipo()
		indice_inicial = _calcular_indice_en_lista_equipo(pokemon_actual)

	if lista_pokemon.is_empty():
		print("❌ [PANTALLA_INFO] No se encontraron Pokémon en la lista")
		return

	# Crear y mostrar la pantalla de información
	_crear_pantalla_info(lista_pokemon, indice_inicial)

## Obtiene todos los Pokémon de la caja actual.
func _obtener_pokemones_caja_actual() -> Array[BasePokemon]:
	var lista: Array[BasePokemon] = []

	if not gestor_cajas:
		return lista

	# Obtener todos los pokémon de la caja actual (30 slots)
	for i in range(SLOTS_TOTAL):
		var pokemon = gestor_cajas.obtener_pokemon(caja_actual, i)
		if pokemon:
			lista.append(pokemon)

	return lista

## Obtiene todos los Pokémon del equipo.
func _obtener_pokemones_equipo() -> Array[BasePokemon]:
	var lista: Array[BasePokemon] = []

	for pokemon in equipo_pokemon:
		if pokemon:
			lista.append(pokemon)

	return lista

## Calcula el índice del Pokémon en la lista de la caja.
func _calcular_indice_en_lista_caja(pokemon_buscado: BasePokemon) -> int:
	if not pokemon_buscado or not gestor_cajas:
		return 0

	var indice_lista = 0
	for i in range(SLOTS_TOTAL):
		var pokemon = gestor_cajas.obtener_pokemon(caja_actual, i)
		if pokemon:
			if pokemon == pokemon_buscado:
				return indice_lista
			indice_lista += 1

	return 0

## Calcula el índice del Pokémon en la lista del equipo.
func _calcular_indice_en_lista_equipo(pokemon_buscado: BasePokemon) -> int:
	if not pokemon_buscado:
		return 0

	var indice_lista = 0
	for pokemon in equipo_pokemon:
		if pokemon:
			if pokemon == pokemon_buscado:
				return indice_lista
			indice_lista += 1

	return 0

## Crea y muestra la pantalla de información.
func _crear_pantalla_info(lista_pokemon: Array[BasePokemon], indice_inicial: int) -> void:
	# Cargar la escena de pantalla_info
	var pantalla_info_scene = preload("res://UI/poke-info/pantalla-info.tscn")
	pantalla_info_activa = pantalla_info_scene.instantiate()
	pantalla_info_activa.set_z_index(pantalla_info_activa.get_z_index() + 2)  # Asegurar que esté por encima de todo

	if not pantalla_info_activa:
		print("❌ [PANTALLA_INFO] Error al cargar la escena de pantalla_info")
		return

	# Conectar señales
	pantalla_info_activa.pantalla_cerrada.connect(_on_pantalla_info_cerrada)

	# Agregar a la escena
	get_parent().add_child(pantalla_info_activa)

	# Deshabilitar input de la pantalla PC mientras se muestra la info
	cursor_activo = false
	pantalla_info_indice_inicial = indice_inicial

	print("📖 [PANTALLA_INFO] Mostrando lista de %d Pokémon, iniciando en índice %d" % [lista_pokemon.size(), indice_inicial])

	# Mostrar la información
	pantalla_info_activa.mostrar_info_lista_pokemon(lista_pokemon, indice_inicial)

## Maneja el cierre de la pantalla de información.
func _on_pantalla_info_cerrada(indice_final: int) -> void:
	print("📖 [PANTALLA_INFO] Pantalla cerrada, último índice visto: %d" % indice_final)

	# Limpiar la pantalla
	if pantalla_info_activa:
		# Desconectar la señal antes de eliminar el nodo
		if pantalla_info_activa.pantalla_cerrada.is_connected(_on_pantalla_info_cerrada):
			pantalla_info_activa.pantalla_cerrada.disconnect(_on_pantalla_info_cerrada)

		pantalla_info_activa.queue_free()
		pantalla_info_activa = null

	# Reactivar input de la pantalla PC
	cursor_activo = true

	# Opcional: Actualizar la posición del cursor basado en el último Pokémon visto
	if indice_final != pantalla_info_indice_inicial:
		_actualizar_cursor_desde_pantalla_info(indice_final)
		pantalla_info_indice_inicial = -1  # Resetear
	_activar_cooldown_input()

## Actualiza la posición del cursor basado en el índice devuelto de pantalla_info.
func _actualizar_cursor_desde_pantalla_info(indice_final: int) -> void:
	if modo_navegacion == ModoNavegacion.GRILLA:
		_actualizar_cursor_caja_desde_indice(indice_final)
	elif modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		_actualizar_cursor_equipo_desde_indice(indice_final)

## Actualiza el cursor de la caja basado en el índice de la lista.
func _actualizar_cursor_caja_desde_indice(indice_lista: int) -> void:
	if not gestor_cajas:
		return

	var contador_pokemon = 0
	for i in range(SLOTS_TOTAL):
		var pokemon = gestor_cajas.obtener_pokemon(caja_actual, i)
		if pokemon:
			if contador_pokemon == indice_lista:
				# Convertir índice de slot a coordenadas x,y
				cursor_x = i % SLOTS_HORIZONTAL
				cursor_y = i / SLOTS_HORIZONTAL  # División entera intencional
				_actualizar_sprite_pokemon()
				print("🎯 [CURSOR] Cursor actualizado a slot %d (%d,%d) por pantalla_info" % [i, cursor_x, cursor_y])
				return
			contador_pokemon += 1

## Actualiza el cursor del equipo basado en el índice de la lista.
func _actualizar_cursor_equipo_desde_indice(indice_lista: int) -> void:
	var contador_pokemon = 0
	var equipo_actual = dock_equipo_controller.obtener_equipo_completo()

	for i in range(equipo_actual.size()):
		if equipo_actual[i]:
			if contador_pokemon == indice_lista:
				mano.position = dock_equipo_controller.obtener_posicion_slot(i)
				dock_equipo_controller.configurar_slot_actual(i)
				print("🎯 [CURSOR] Cursor del equipo actualizado a slot %d por pantalla_info" % i)
				return
			contador_pokemon += 1

## Lógica para abrir el menú de opciones del Pokémon seleccionado.
func _abrir_menu_pokemon(nombre: String, del_equipo: bool, el_primero: bool, tiene_pokemon: bool) -> void:
	if movimiento_rapido:
		# Como pokeruby: solo se ejecuta si la primera opción es una acción de mover.
		var primera: String = menu_pc.primera_opcion_pokemon(del_equipo, el_primero, tiene_pokemon)
		if primera in OPCIONES_MOVIMIENTO_RAPIDO:
			_on_menu_pc_opcion_seleccionada(primera, {})
		return
	print("📋 [CAJAS PC] Abriendo menú de opciones para %s" % nombre)
	menu_pc.mostrar_opciones_pokemon(nombre, del_equipo, el_primero, tiene_pokemon)

## SELECT: alterna el movimiento rápido y el color de la mano (pokeruby sub_809CD88).
func _alternar_movimiento_rapido() -> void:
	movimiento_rapido = not movimiento_rapido
	_aplicar_textura_mano()

## Cambia la hoja de la mano: normal o la paleta alternativa del movimiento rápido.
func _aplicar_textura_mano() -> void:
	if not mano:
		return
	var textura: Texture2D = TEXTURA_MANO_RAPIDA if movimiento_rapido else TEXTURA_MANO
	for animacion: StringName in mano.sprite_frames.get_animation_names():
		for i in mano.sprite_frames.get_frame_count(animacion):
			var cuadro: AtlasTexture = mano.sprite_frames.get_frame_texture(animacion, i) as AtlasTexture
			if cuadro:
				cuadro.atlas = textura

## Maneja la acción de cancelar (botón B).
func _accion_cancelar() -> void:
	if modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		if operacion == OPERACION_DEJAR:
			# En DEJAR el panel es toda la pantalla: B pregunta si seguir.
			_preguntar_mas_cambios()
		else:
			# En MOVER cierra el panel (la mano conserva su Pokémon).
			_cerrar_equipo_pokemon()
	elif esta_en_modo_mover():
		# Con un Pokémon en la mano no se puede salir.
		_mensaje_moviendo()
		return
	else:
		_preguntar_mas_cambios()

	_reproducir_sonido_cancelar()

## Botón cerrar (o SALIR del equipo en DEJAR): "Salir de la CAJA." con SÍ
## preseleccionado. Con un Pokémon en la mano se rechaza.
func _preguntar_salir() -> void:
	if esta_en_modo_mover():
		_mensaje_moviendo()
		return
	confirmacion_pendiente = "salir"
	menu_pc.mostrar_confirmacion(TEXTO_SALIR_CAJA, true)

## B sin Pokémon en la mano: "¿Hacer más cambios?" con SÍ preseleccionado.
func _preguntar_mas_cambios() -> void:
	if esta_en_modo_mover():
		_mensaje_moviendo()
		return
	confirmacion_pendiente = "mas_cambios"
	menu_pc.mostrar_confirmacion(TEXTO_MAS_CAMBIOS, true)

## Respuesta de la ventana SÍ/NO. "Salir de la CAJA.": SÍ sale y NO/B vuelve.
## "¿Hacer más cambios?": SÍ vuelve y NO/B sale.
func _on_confirmacion_respondida(si: bool) -> void:
	var pendiente: String = confirmacion_pendiente
	confirmacion_pendiente = ""
	_activar_cooldown_input()
	match pendiente:
		"salir":
			if si:
				_salir_de_cajas()
		"mas_cambios":
			if not si:
				_salir_de_cajas()

## Maneja las opciones específicas del Pokémon (botón X).
func _accion_opciones_pokemon() -> void:
	var slot_actual = _obtener_slot_actual()
	var slot_index = _obtener_indice_slot_actual()
	var pokemon_en_slot = slot_actual.obtener_pokemon() if slot_actual else null

	if pokemon_en_slot:
		_mostrar_menu_pokemon(pokemon_en_slot, slot_index)

	_reproducir_sonido_menu()

## Maneja las opciones de la caja (botón Y).
func _accion_opciones_caja() -> void:
	_mostrar_menu_caja()
	_reproducir_sonido_menu()

# ===================================
# LÓGICA DE POKÉMON Y SLOTS
# ===================================

## Devuelve el índice lineal del slot actual basado en la posición del cursor.
func _obtener_indice_slot_actual() -> int:
	if modo_navegacion == ModoNavegacion.GRILLA:
		return cursor_y * SLOTS_HORIZONTAL + cursor_x
	return -1  # No válido si no estamos en la grilla

## Obtiene el Pokémon en un slot específico.
func _obtener_pokemon_en_slot(slot_index: int) -> BasePokemon:
	if not gestor_cajas:
		return null

	# Obtener el Pokémon del slot especificado
	return gestor_cajas.obtener_pokemon(caja_actual, slot_index)

## Selecciona un Pokémon para intercambio o visualización.
func _seleccionar_pokemon(pokemon: BasePokemon, slot_index: int) -> void:
	pokemon_seleccionado = pokemon
	slot_seleccionado = Vector2i(cursor_x, cursor_y)
	modo_intercambio = true

	# TODO: Actualizar visual del slot seleccionado
	print("✅ [CAJAS PC] Pokémon seleccionado: %s en slot %d" % [pokemon.nombre_interno, slot_index])

## Deselecciona el Pokémon actual.
func _deseleccionar_pokemon() -> void:
	pokemon_seleccionado = null
	slot_seleccionado = Vector2i(-1, -1)
	modo_intercambio = false

	# TODO: Restaurar visual normal de los slots
	print("❌ [CAJAS PC] Pokémon deseleccionado")

## Procesa el intercambio de un Pokémon a otro slot.
func _procesar_intercambio(slot_destino: int) -> void:
	if not pokemon_seleccionado:
		return

	var slot_origen = slot_seleccionado.y * SLOTS_HORIZONTAL + slot_seleccionado.x

	if slot_origen == slot_destino:
		# Mismo slot, cancelar selección
		_deseleccionar_pokemon()
		return

	# TODO: Ejecutar intercambio a través del gestor
	print("🔄 [CAJAS PC] Intercambiando Pokémon del slot %d al slot %d" % [slot_origen, slot_destino])

	# Deseleccionar después del intercambio
	_deseleccionar_pokemon()

## Maneja la acción en un slot vacío.
func _accion_slot_vacio(slot_index: int) -> void:
	if pokemon_seleccionado:
		# Mover Pokémon seleccionado al slot vacío
		_procesar_intercambio(slot_index)
	else:
		# TODO: Mostrar menú para depositar del equipo
		print("📥 [CAJAS PC] Slot vacío seleccionado: %d" % slot_index)

# ===================================
# MENÚS Y DIÁLOGOS
# ===================================

## Muestra el menú de opciones para un Pokémon específico.
func _mostrar_menu_pokemon(pokemon: BasePokemon, _slot_index: int) -> void:
	print("📋 [CAJAS PC] Mostrando menú para %s" % pokemon.nombre_interno)

	# TODO: Implementar menú con opciones:
	# - Ver información
	# - Mover
	# - Liberar
	# - Marcar/Desmarcar

## Muestra el menú de opciones para la caja actual.
func _mostrar_menu_caja() -> void:
	print("📋 [CAJAS PC] Mostrando menú de caja %d" % caja_actual)

	# TODO: Implementar menú con opciones:
	# - Cambiar nombre
	# - Cambiar fondo
	# - Organizar
	# - Buscar Pokémon

## Cancela el modo de intercambio actual.
func _cancelar_intercambio() -> void:
	_deseleccionar_pokemon()
	print("🚫 [CAJAS PC] Intercambio cancelado")

## Sale del sistema de cajas PC.
func _salir_de_cajas() -> void:
	if cajas_cerradas:
		return
	# Nunca se sale con un Pokémon en la mano (se perdería).
	if esta_en_modo_mover():
		_mensaje_moviendo()
		return
	print("🚪 [CAJAS PC] Saliendo del sistema de cajas...")
	cajas_cerradas = true
	cursor_activo = false

	# Guardar cambios pendientes
	_sincronizar_con_sistema_guardado()

	# TODO: Animación de salida

	# Emitir señal de cierre
	caja_cerrada.emit()

# ===================================
# AUDIO Y EFECTOS
# ===================================

## Reproduce el sonido de navegación del cursor.
func _reproducir_sonido_navegacion() -> void:
	# TODO: Implementar reproducción de audio
	pass

## Reproduce el sonido de selección.
func _reproducir_sonido_seleccion() -> void:
	# TODO: Implementar reproducción de audio
	pass

## Reproduce el sonido de cancelación.
func _reproducir_sonido_cancelar() -> void:
	# TODO: Implementar reproducción de audio
	pass

## Reproduce el sonido de apertura de menú.
func _reproducir_sonido_menu() -> void:
	# TODO: Implementar reproducción de audio
	pass

## Reproduce el sonido de cambio de caja.
func _reproducir_sonido_cambio_caja() -> void:
	# TODO: Implementar reproducción de audio
	pass

# ===================================
# API PÚBLICA
# ===================================

## Modos del menú Pokémon de Ruby (0 SACAR, 1 DEJAR, 2 MOVER) sobre la misma
## interfaz. En DEJAR el panel del equipo se abre de entrada con el cursor en
## el slot 0; en SACAR y MOVER el cursor empieza en la grilla.
func configurar_operacion(modo: int) -> void:
	operacion = clampi(modo, OPERACION_SACAR, OPERACION_MOVER)
	menu_pc.operacion_almacenamiento = operacion
	_activar_cooldown_input()
	if operacion == OPERACION_DEJAR:
		_abrir_equipo_pokemon()

## Abre el sistema de cajas en una caja específica (la caja activa guardada).
func abrir_caja(numero_caja: int = 0) -> void:
	caja_actual = clampi(numero_caja, 0, TOTAL_CAJAS - 1)
	cajas_cerradas = false
	cursor_activo = true
	modo_navegacion = ModoNavegacion.GRILLA
	columna_guardada = 0
	cursor_x = 0
	cursor_y = 0
	_mostrar_caja_sin_animacion(caja_actual)

	# Iniciar animación de la mano
	if mano:
		mano.play("idle")
		mano.flip_v = false  # Asegurar orientación normal en grilla

	# Mostrar sombra en grilla al abrir
	if sombra:
		sombra.visible = true

	_cargar_caja_actual()
	_actualizar_posicion_cursor()

	# Inicializar sprite del Pokémon según el slot inicial
	_actualizar_sprite_pokemon()

	print("🔓 [CAJAS PC] Sistema abierto en caja %d - Modo GRILLA" % caja_actual)

## Deja visible la instancia de `numero` (sin desplazamiento) y apunta a ella
## todas las referencias de la caja actual.
func _mostrar_caja_sin_animacion(numero: int) -> void:
	for i in instancias_cajas.size():
		instancias_cajas[i].visible = i == numero
		instancias_cajas[i].position = POSICION_CAJA_CENTRO
	_activar_caja_controller(numero)
	_actualizar_referencias_slots_caja_actual()
	if label_nombre_caja and gestor_cajas:
		label_nombre_caja.text = gestor_cajas.obtener_nombre_caja(numero)

## Cierra el sistema de cajas desde fuera. Si la mano llevaba un Pokémon se
## devuelve primero (nunca se pierde) y se cortan las animaciones en curso.
func cerrar_caja() -> void:
	for tween in [tween_mano_mover, tween_mano_colocar]:
		if tween and tween.is_valid():
			tween.kill()
	animacion_mover_activa = false
	animacion_colocar_activa = false
	animacion_activa = false
	secuencia_activa = false
	if esta_en_modo_mover():
		_devolver_pokemon_sostenido()
	menu_pc.ocultar_todo()
	mostrando_mensaje_pokemon = false
	_salir_de_cajas()

## Devuelve el número de la caja actualmente visible.
func obtener_caja_actual() -> int:
	return caja_actual

## Devuelve si el sistema de cajas está activo.
func esta_activo() -> bool:
	return cursor_activo

# ===================================
# UTILIDADES Y DEBUG
# ===================================

## Imprime información de debug del estado actual.
func _debug_info() -> void:
	var modo_str = ""
	match modo_navegacion:
		ModoNavegacion.GRILLA:
			modo_str = "GRILLA"
		ModoNavegacion.NOMBRE_CAJA:
			modo_str = "NOMBRE_CAJA"
		ModoNavegacion.BOTON_EQUIPO:
			modo_str = "BOTON_EQUIPO"
		ModoNavegacion.BOTON_CERRAR:
			modo_str = "BOTON_CERRAR"
		ModoNavegacion.EQUIPO_POKEMON:
			modo_str = "EQUIPO_POKEMON"

	print("🐛 [DEBUG CAJAS PC]")
	print("  - Caja actual: %d" % caja_actual)
	print("  - Cursor: (%d, %d)" % [cursor_x, cursor_y])
	print("  - Modo navegación: %s" % modo_str)
	print("  - Columna guardada: %d" % columna_guardada)
	print("  - Slot actual: %d" % _obtener_indice_slot_actual())
	if modo_navegacion == ModoNavegacion.EQUIPO_POKEMON:
		print("  - Equipo visible: %s" % dock_equipo_controller.esta_visible())
		print("  - Slot equipo actual: %d" % dock_equipo_controller.obtener_slot_actual())

func _validar_nodos_sprite() -> void:
	print("🖼️ [SPRITE] Validando nodos de sprite...")

	if not dock_info_controller:
		print("❌ DockInfoController no encontrado")
		return

	# Validar a través del controller
	if dock_info_controller.obtener_pokemon_sprite():
		print("✅ PokemonSprite encontrado vía controller")
		print("  - Gestionado por DockInfoController ✅")
	else:
		print("❌ PokemonSprite no encontrado en controller")

	if dock_info_controller.obtener_info_anim():
		print("✅ info_anim encontrado vía controller")
		print("  - Gestionado por DockInfoController ✅")
	else:
		print("❌ info_anim no encontrado en controller")

	print("🖼️ [SPRITE] Validación completada")
	print("  - Modo intercambio: %s" % modo_intercambio)
	print("  - Pokémon seleccionado: %s" % (pokemon_seleccionado.nombre_interno if pokemon_seleccionado else "Ninguno"))

# ===================================
# SISTEMA DE TRANSICIÓN DE SPRITE POKÉMON CON SHADER
# ===================================

## Genera una textura de ruido para las transiciones.
func _generar_textura_ruido() -> void:
	print("🎨 [CAJAS PC] Generando textura de ruido...")

	var texture_size = 64  # Tamaño de la textura de ruido
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGB8)

	print("🎨 [RUIDO] Imagen creada: %dx%d" % [texture_size, texture_size])

	# Intentar usar FastNoiseLite para mejor distribución
	var noise = FastNoiseLite.new()
	if noise:
		print("🎨 [RUIDO] Usando FastNoiseLite")
		noise.seed = randi()
		noise.frequency = 0.1
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

		for x in range(texture_size):
			for y in range(texture_size):
				# Usar FastNoiseLite para mejor distribución
				var noise_value = (noise.get_noise_2d(x, y) + 1.0) * 0.5  # Normalizar de -1,1 a 0,1
				var color = Color(noise_value, noise_value, noise_value)
				image.set_pixel(x, y, color)
	else:
		# Fallback: usar ruido aleatorio simple
		print("⚠️ [CAJAS PC] FastNoiseLite no disponible, usando ruido aleatorio")
		for x in range(texture_size):
			for y in range(texture_size):
				var noise_value = randf()  # Valor aleatorio entre 0 y 1
				var color = Color(noise_value, noise_value, noise_value)
				image.set_pixel(x, y, color)

	# Crear textura desde la imagen
	noise_texture = ImageTexture.new()
	noise_texture.set_image(image)

	print("✅ [CAJAS PC] Textura de ruido generada: %s" % str(noise_texture))
	print("✅ [RUIDO] Tamaño final: %dx%d" % [noise_texture.get_width(), noise_texture.get_height()])

## Inicializa el shader material para transiciones.
func _inicializar_shader_transicion() -> void:
	print("🎭 [CAJAS PC] Inicializando shader de transición...")

	# Cargar el shader
	var shader = load("res://UI/shaders/pokemon_blocky_simple.gdshader") as Shader
	if not shader:
		print("❌ [CAJAS PC] No se pudo cargar el shader de transición desde: res://UI/shaders/pokemon_blocky_simple.gdshader")
		return

	print("✅ [SHADER] Shader cargado correctamente")

	# Crear material con el shader
	sprite_material_shader = ShaderMaterial.new()
	sprite_material_shader.shader = shader

	print("✅ [SHADER] Material creado con shader")

	# Verificar que la textura de ruido esté disponible
	if not noise_texture:
		print("❌ [SHADER] Textura de ruido no disponible")
		return

	print("✅ [SHADER] Textura de ruido disponible: %s" % str(noise_texture))

	# Configurar parámetros iniciales
	sprite_material_shader.set_shader_parameter("transition_progress", 0.0)
	sprite_material_shader.set_shader_parameter("noise_texture", noise_texture)
	sprite_material_shader.set_shader_parameter("sprite_resolution", 64.0)

	print("✅ [CAJAS PC] Shader de transición inicializado con parámetros:")
	print("  - transition_progress: 0.0")
	print("  - noise_texture: %s" % str(noise_texture))
	print("  - sprite_resolution: 64.0")

## Inicia una transición animada para mostrar un sprite de Pokémon usando shader.
## `pokemon` (opcional) es el Pokémon concreto: aporta su personalidad (manchas
## de SPINDA) al sprite.
func _iniciar_transicion_sprite(nombre_pokemon: String, pokemon: BasePokemon = null) -> void:
	print("🚀 [SHADER] === INICIANDO TRANSICIÓN ===")
	print("🚀 [SHADER] Pokémon: %s" % nombre_pokemon)

	if not dock_info_controller:
		print("❌ [SHADER] dock_info_controller es null")
		return

	if not sprite_material_shader:
		print("❌ [SHADER] sprite_material_shader es null")
		return

	# Cancelar cualquier transición anterior
	_cancelar_transicion_sprite()

	sprite_animacion_activa = true
	sprite_pokemon_actual = _clave_sprite_pokemon(pokemon) if pokemon != null else nombre_pokemon

	print("🔄 [CAJAS PC] Iniciando transición shader a sprite: %s" % nombre_pokemon)

	# Configurar el nuevo Pokémon a través del controller
	if pokemon != null:
		dock_info_controller.configurar_sprite_pokemon(pokemon)
	else:
		dock_info_controller.configurar_sprite_pokemon(nombre_pokemon)

	# Obtener el sprite desde el controller para aplicar el shader
	var pokemon_sprite = dock_info_controller.obtener_pokemon_sprite()
	if not pokemon_sprite:
		print("❌ [SHADER] No se pudo obtener pokemon_sprite del controller")
		sprite_animacion_activa = false
		return

	# Aplicar material con shader
	pokemon_sprite.material = sprite_material_shader
	pokemon_sprite.visible = true

	# Configurar parámetros del shader
	sprite_material_shader.set_shader_parameter("transition_progress", 0.0)
	sprite_material_shader.set_shader_parameter("base_offset_pixels", 8.0)

	# Iniciar animación del shader
	_animar_transicion_shader()

## Anima la transición usando el shader.
func _animar_transicion_shader() -> void:
	if not dock_info_controller or not sprite_material_shader:
		print("❌ [SHADER] No se puede animar: controller=%s, material=%s" % [dock_info_controller != null, sprite_material_shader != null])
		return

	# Crear tween para la animación
	tween_sprite = create_tween()

	var duracion_total = 0.4  # 0.4 segundos, más parecido a los juegos originales

	# Resetear progreso del shader
	sprite_material_shader.set_shader_parameter("transition_progress", 0.0)

	# Animar el progreso de la transición
	tween_sprite.tween_method(_actualizar_progreso_shader, 0.0, 1.0, duracion_total)
	tween_sprite.tween_callback(_finalizar_transicion_shader).set_delay(duracion_total)

## Actualiza el progreso del shader durante la animación.
func _actualizar_progreso_shader(progress: float) -> void:
	if not sprite_material_shader or not sprite_animacion_activa:
		return

	sprite_material_shader.set_shader_parameter("transition_progress", progress)

## Finaliza la transición del shader.
func _finalizar_transicion_shader() -> void:
	if not dock_info_controller:
		sprite_animacion_activa = false
		return

	var pokemon_sprite = dock_info_controller.obtener_pokemon_sprite()
	if not pokemon_sprite:
		sprite_animacion_activa = false
		return

	# Remover el material del shader (volver a normal)
	pokemon_sprite.material = null
	sprite_animacion_activa = false

## Cancela cualquier transición de sprite en curso.
func _cancelar_transicion_sprite() -> void:
	if not sprite_animacion_activa:
		return

	if tween_sprite:
		tween_sprite.kill()
		tween_sprite = null

	if dock_info_controller:
		var pokemon_sprite = dock_info_controller.obtener_pokemon_sprite()
		if pokemon_sprite and is_instance_valid(pokemon_sprite):
			pokemon_sprite.material = null

	sprite_animacion_activa = false

# ===================================
# GESTIÓN DEL EQUIPO POKÉMON
# ===================================

## [DEPRECATED] Genera un equipo Pokémon de prueba.
## Esta función se mantiene para compatibilidad pero ya no se usa.
## Los datos ahora se cargan desde el sistema de guardado.
func _generar_equipo_prueba() -> void:
	print("⚠️ [EQUIPO] DEPRECATED: _generar_equipo_prueba() ya no se usa")
	print("   Los datos del equipo ahora se cargan desde el sistema de guardado")
	print("   Use _generar_equipo_inicial() para generar datos iniciales")

	# Mantener la función vacía para evitar errores si es llamada por código legacy
	return

## Sincroniza el array legacy con los datos del controlador del equipo.
func _sincronizar_equipo_desde_controlador() -> void:
	if dock_equipo_controller:
		var equipo_anterior_size = equipo_pokemon.size()
		equipo_pokemon = dock_equipo_controller.obtener_equipo_completo()
		print("🔄 [SINCRONIZACION] Array equipo_pokemon sincronizado: %d → %d Pokémon" % [equipo_anterior_size, equipo_pokemon.size()])
	else:
		print("⚠️ [SINCRONIZACION] Error: dock_equipo_controller no disponible")

## Imprime el estado actual del equipo para debugging.
func _imprimir_estado_equipo() -> void:
	print("👥 [EQUIPO] Estado final del equipo:")
	var equipo_actual = dock_equipo_controller.obtener_equipo_completo()
	for i in range(equipo_actual.size()):
		var pokemon = equipo_actual[i]
		if pokemon:
			print("   Slot %d: %s Nv.%d (número: %d)" % [i, pokemon.nombre_interno, pokemon.nivel, pokemon.numero_nacional])
		else:
			print("   Slot %d: VACÍO" % i)

## Cuenta la cantidad de Pokémon en el equipo.
func _contar_pokemon_equipo() -> int:
	var contador = 0
	var equipo_actual = dock_equipo_controller.obtener_equipo_completo()
	for pokemon in equipo_actual:
		if pokemon != null:
			contador += 1
	return contador

## Actualiza la visualización de los slots del equipo usando el controlador.
func _actualizar_slots_equipo() -> void:
	# Delegar completamente la actualización al controlador del equipo
	dock_equipo_controller.actualizar_slots_desde_controlador()

# ======================================================================
# FUNCIONES DE ANIMACIÓN DE REORGANIZACIÓN DEL EQUIPO
# ======================================================================

## Versión simplificada para cuando solo se necesita actualizar sin animación compleja.
func _actualizar_equipo_con_animacion_simple(equipo_nuevo: Array) -> void:
	# Para casos simples como agregar un Pokémon a un slot vacío
	equipo_pokemon = equipo_nuevo.duplicate()
	_actualizar_slots_equipo()
	print("✅ [REORGANIZACION] Actualización simple del equipo completada")

## Anima específicamente la reorganización cuando se remueve un Pokémon.
func _animar_reorganizacion_con_remocion(equipo_anterior: Array, equipo_con_null: Array, slot_removido: int) -> void:
	if animacion_reorganizacion_activa:
		print("⚠️ [REORGANIZACION] Animación ya en progreso, cancelando")
		_finalizar_reorganizacion_con_remocion(equipo_con_null, slot_removido)
		return

	if not dock_equipo_controller:
		print("⚠️ [REORGANIZACION] dock_equipo_controller no disponible")
		_finalizar_reorganizacion_con_remocion(equipo_con_null, slot_removido)
		return

	print("🎬 [REORGANIZACION] Iniciando animación de reorganización por remoción en slot %d" % slot_removido)
	animacion_reorganizacion_activa = true

	# Calcular los movimientos necesarios para la reorganización por remoción
	var datos_animacion = _calcular_movimientos_por_remocion(equipo_anterior, equipo_con_null, slot_removido)

	# Si no hay movimientos necesarios, finalizar directamente
	if datos_animacion.is_empty():
		print("ℹ️ [REORGANIZACION] No hay Pokémon para mover después del slot removido")
		_finalizar_reorganizacion_con_remocion(equipo_con_null, slot_removido)
		return

	# Crear tween para las animaciones
	if tween_reorganizacion_equipo:
		tween_reorganizacion_equipo.kill()
	tween_reorganizacion_equipo = create_tween()
	tween_reorganizacion_equipo.set_parallel(true)

	# Animar cada icono a su nueva posición
	for dato in datos_animacion:
		var icono_sprite = dato.sprite
		var posicion_destino = dato.posicion_destino

		print("🎯 [REORGANIZACION] Animando Pokémon de slot %d → slot %d" % [dato.slot_origen, dato.slot_destino])
		tween_reorganizacion_equipo.tween_property(icono_sprite, "position", posicion_destino, DURACION_ANIMACION_REORGANIZACION)

	# Cuando termine la animación, completar la reorganización
	tween_reorganizacion_equipo.finished.connect(_on_reorganizacion_remocion_terminada.bind(equipo_con_null, slot_removido), CONNECT_ONE_SHOT)

## Calcula los movimientos específicos para reorganización por remoción.
func _calcular_movimientos_por_remocion(equipo_anterior: Array, _equipo_con_null: Array, slot_removido: int) -> Array:
	var movimientos = []

	if not dock_equipo_controller.has_method("obtener_iconos_sprites"):
		print("⚠️ [REORGANIZACION] Método obtener_iconos_sprites no disponible")
		return movimientos

	var iconos_sprites = dock_equipo_controller.obtener_iconos_sprites()
	print("🔍 [REORGANIZACION] Calculando movimientos por remoción del slot %d" % slot_removido)
	print("🔍 [REORGANIZACION] Equipo anterior: %s" % _debug_equipo_string(equipo_anterior))

	# Verificar que hay Pokémon después del slot removido
	var hay_pokemon_posteriores = false
	for i in range(slot_removido + 1, equipo_anterior.size()):
		if equipo_anterior[i] != null:
			hay_pokemon_posteriores = true
			break

	if not hay_pokemon_posteriores:
		print("ℹ️ [REORGANIZACION] No hay Pokémon después del slot %d para mover" % slot_removido)
		return movimientos

	# Buscar todos los Pokémon que están después del slot removido
	for slot_actual in range(slot_removido + 1, equipo_anterior.size()):
		var pokemon_actual = equipo_anterior[slot_actual]

		if pokemon_actual != null:
			# Este Pokémon necesita moverse hacia arriba (slot_actual - 1)
			var slot_destino = slot_actual - 1
			var icono_sprite = iconos_sprites[slot_actual] if slot_actual < iconos_sprites.size() else null

			if icono_sprite and icono_sprite.visible:
				var posicion_destino = dock_equipo_controller.obtener_posicion_slot_relativa(slot_destino) + dock_equipo_controller.offset_iconos
				movimientos.append({
					"sprite": icono_sprite,
					"posicion_destino": posicion_destino,
					"slot_origen": slot_actual,
					"slot_destino": slot_destino,
					"pokemon": pokemon_actual
				})
				print("📊 [REORGANIZACION] 🎯 %s se moverá de slot %d → slot %d" % [pokemon_actual.get_nombre_mostrar(), slot_actual, slot_destino])
			else:
				print("⚠️ [REORGANIZACION] Icono no disponible para slot %d" % slot_actual)

	print("📊 [REORGANIZACION] Total Pokémon a mover: %d" % movimientos.size())
	return movimientos

## Callback cuando termina la animación de reorganización por remoción.
func _on_reorganizacion_remocion_terminada(equipo_con_null: Array, slot_removido: int) -> void:
	print("✅ [REORGANIZACION] Animación de remoción terminada, completando reorganización")
	_finalizar_reorganizacion_con_remocion(equipo_con_null, slot_removido)

## LEGACY: Completa la reorganización del equipo después de la animación.
## DEPRECATED: Ahora usa el DockEquipoController directamente.
func _finalizar_reorganizacion_con_remocion(_equipo_con_null: Array, _slot_removido: int) -> void:
	print("⚠️ [LEGACY] _finalizar_reorganizacion_con_remocion es deprecated - usando controlador")

	# El controlador ya maneja esto directamente
	# Solo sincronizar el array legacy
	equipo_pokemon = dock_equipo_controller.obtener_equipo_completo()

	# Actualizar la visualización con los datos finales
	_actualizar_slots_equipo()

	# Marcar animación como terminada
	animacion_reorganizacion_activa = false
	print("🎬 [REORGANIZACION] Reorganización por remoción completada via controlador")

## Calcula los movimientos necesarios para los iconos del equipo (versión detallada).
func _calcular_movimientos_iconos_detallado(equipo_anterior: Array, equipo_nuevo: Array) -> Array:
	var movimientos = []

	if not dock_equipo_controller.has_method("obtener_iconos_sprites"):
		print("⚠️ [REORGANIZACION] Método obtener_iconos_sprites no disponible")
		return movimientos

	var iconos_sprites = dock_equipo_controller.obtener_iconos_sprites()
	print("🔍 [REORGANIZACION] Analizando movimientos entre equipos...")
	print("🔍 [REORGANIZACION] Equipo anterior: %s" % _debug_equipo_string(equipo_anterior))
	print("🔍 [REORGANIZACION] Equipo nuevo: %s" % _debug_equipo_string(equipo_nuevo))

	# Detectar todos los Pokémon que han cambiado de posición
	for slot_nuevo in range(equipo_nuevo.size()):
		var pokemon_nuevo = equipo_nuevo[slot_nuevo] if slot_nuevo < equipo_nuevo.size() else null

		if pokemon_nuevo != null:
			# Buscar dónde estaba este Pokémon en el equipo anterior
			var slot_anterior = _encontrar_posicion_anterior(pokemon_nuevo, equipo_anterior)

			# Si el Pokémon se movió a una nueva posición
			if slot_anterior != -1 and slot_anterior != slot_nuevo:
				var icono_sprite = iconos_sprites[slot_anterior] if slot_anterior < iconos_sprites.size() else null
				if icono_sprite and icono_sprite.visible:  # Solo animar iconos visibles
					var posicion_destino = dock_equipo_controller.obtener_posicion_slot_relativa(slot_nuevo) + dock_equipo_controller.offset_iconos
					movimientos.append({
						"sprite": icono_sprite,
						"posicion_destino": posicion_destino,
						"slot_origen": slot_anterior,
						"slot_destino": slot_nuevo,
						"pokemon": pokemon_nuevo
					})
					print("📊 [REORGANIZACION] 🎯 Movimiento detectado: %s de slot %d a slot %d" % [pokemon_nuevo.get_nombre_mostrar(), slot_anterior, slot_nuevo])

	print("📊 [REORGANIZACION] Total movimientos detectados: %d" % movimientos.size())
	return movimientos

## Función de debug para mostrar el contenido del equipo.
func _debug_equipo_string(equipo: Array) -> String:
	var resultado = "["
	for i in range(equipo.size()):
		if i > 0:
			resultado += ", "
		if equipo[i] != null:
			resultado += "%s" % equipo[i].get_nombre_mostrar()
		else:
			resultado += "null"
	resultado += "]"
	return resultado

## Calcula los movimientos necesarios para los iconos del equipo.
func _calcular_movimientos_iconos(equipo_nuevo: Array) -> Array:
	var movimientos = []

	if not dock_equipo_controller.has_method("obtener_iconos_sprites"):
		print("⚠️ [REORGANIZACION] Método obtener_iconos_sprites no disponible")
		return movimientos

	var iconos_sprites = dock_equipo_controller.obtener_iconos_sprites()
	var equipo_actual = dock_equipo_controller.obtener_equipo_completo()

	# Comparar equipo actual con el nuevo para detectar movimientos
	for i in range(min(equipo_actual.size(), equipo_nuevo.size())):
		var pokemon_actual = equipo_actual[i] if i < equipo_actual.size() else null
		var pokemon_nuevo = equipo_nuevo[i] if i < equipo_nuevo.size() else null

		# Si el Pokémon cambió de posición, necesitamos animar
		if pokemon_actual != pokemon_nuevo and pokemon_nuevo != null:
			# Buscar dónde estaba este Pokémon antes
			var posicion_anterior = _encontrar_posicion_anterior(pokemon_nuevo, equipo_actual)
			if posicion_anterior != -1 and posicion_anterior != i:
				var icono_sprite = iconos_sprites[posicion_anterior] if posicion_anterior < iconos_sprites.size() else null
				if icono_sprite:
					var posicion_destino = dock_equipo_controller.obtener_posicion_slot_relativa(i) + dock_equipo_controller.offset_iconos
					movimientos.append({
						"sprite": icono_sprite,
						"posicion_destino": posicion_destino,
						"slot_origen": posicion_anterior,
						"slot_destino": i
					})

	return movimientos

## Encuentra la posición anterior de un Pokémon en el equipo.
func _encontrar_posicion_anterior(pokemon: BasePokemon, equipo_anterior: Array) -> int:
	for i in range(equipo_anterior.size()):
		if equipo_anterior[i] == pokemon:
			return i
	return -1

## Callback cuando termina la animación de reorganización.
func _on_reorganizacion_terminada(equipo_nuevo: Array) -> void:
	print("✅ [REORGANIZACION] Animación terminada, actualizando datos")
	_finalizar_reorganizacion_equipo(equipo_nuevo)

## Finaliza la reorganización actualizando los datos del equipo.
func _finalizar_reorganizacion_equipo(equipo_nuevo: Array) -> void:
	# Actualizar el equipo_pokemon con los nuevos datos
	equipo_pokemon = equipo_nuevo.duplicate()

	# Ahora actualizar la visualización con los datos finales
	_actualizar_slots_equipo()

	# Marcar animación como terminada
	animacion_reorganizacion_activa = false
	print("🎬 [REORGANIZACION] Reorganización completada")

# ===================================
# FUNCIONES DE DEBUG ADICIONALES
# ===================================

## Muestra información detallada solo de la caja actual.
func _debug_info_caja_actual() -> void:
	if not gestor_cajas:
		print("❌ [DEBUG] Gestor de cajas no disponible")
		return

	print("\n🔍 [DEBUG] ======= CAJA ACTUAL: %d =======" % caja_actual)
	print("📦 Nombre: %s" % gestor_cajas.obtener_nombre_caja(caja_actual))
	print("📍 Cursor en slot: %d (X:%d, Y:%d)" % [_obtener_indice_slot_actual(), cursor_x, cursor_y])

	var pokemon_en_caja = 0
	var pokemon_actual = gestor_cajas.obtener_pokemon(caja_actual, _obtener_indice_slot_actual())

	if pokemon_actual:
		print("\n🎯 POKÉMON EN CURSOR:")
		_debug_mostrar_pokemon_detallado(pokemon_actual)
	else:
		print("\n❌ Slot actual vacío")

	print("\n📋 CONTENIDO DE LA CAJA:")
	for slot in range(gestor_cajas.POKEMON_POR_CAJA):
		var pokemon = gestor_cajas.obtener_pokemon(caja_actual, slot)
		if pokemon:
			pokemon_en_caja += 1
			var marcador = "👉" if slot == _obtener_indice_slot_actual() else "  "
			var nombre_especie = _pad_string_to_length(pokemon.nombre_interno.substr(0, 10), 10)

			print("%s [%02d] #%03d %s Nv.%d %s %s" % [
				marcador,
				slot,
				pokemon.numero_nacional,
				nombre_especie,
				pokemon.nivel,
				"⭐" if pokemon.shiny else "  ",
				pokemon.sexo if pokemon.sexo != "" else "?"
			])

	print("\n📊 Total Pokémon en caja: %d/30" % pokemon_en_caja)

## Muestra estadísticas rápidas del sistema.
func _debug_estadisticas_rapidas() -> void:
	if not gestor_cajas:
		print("❌ [DEBUG] Gestor de cajas no disponible")
		return

	print("\n⚡ [DEBUG] ======= ESTADÍSTICAS RÁPIDAS =======")

	var total_pokemon = 0
	var cajas_usadas = 0
	var especies_unicas = {}
	var shinies_count = 0
	var pokemon_marcados = 0

	for caja_num in range(TOTAL_CAJAS):
		var pokemon_en_caja = 0
		for slot in range(gestor_cajas.POKEMON_POR_CAJA):
			var pokemon = gestor_cajas.obtener_pokemon(caja_num, slot)
			if pokemon:
				total_pokemon += 1
				pokemon_en_caja += 1
				especies_unicas[pokemon.numero_nacional] = true

				if pokemon.shiny:
					shinies_count += 1

				# Verificar marcas
				for marca in ["circulo", "cuadrado", "triangulo", "corazon"]:
					if pokemon.marcas.get(marca, false):
						pokemon_marcados += 1
						break

		if pokemon_en_caja > 0:
			cajas_usadas += 1

	print("📊 Total Pokémon: %d" % total_pokemon)
	print("📦 Cajas usadas: %d/%d" % [cajas_usadas, TOTAL_CAJAS])
	print("🎯 Especies únicas: %d" % especies_unicas.size())
	print("⭐ Shinies: %d (%.1f%%)" % [shinies_count, float(shinies_count) / max(total_pokemon, 1) * 100])
	print("🏷️ Con marcas: %d (%.1f%%)" % [pokemon_marcados, float(pokemon_marcados) / max(total_pokemon, 1) * 100])
	print("👥 En equipo: %d/6" % _contar_pokemon_equipo())

## Muestra información detallada de un Pokémon específico.
func _debug_mostrar_pokemon_detallado(pokemon: BasePokemon) -> void:
	if not pokemon:
		print("❌ Pokémon nulo")
		return

	print("  🎯 #%03d %s (Nv.%d) %s" % [pokemon.numero_nacional, pokemon.nombre_interno, pokemon.nivel, "⭐" if pokemon.shiny else ""])
	print("  🧬 Tipos: %s%s" % [pokemon.tipo_1, " / " + pokemon.tipo_2 if pokemon.tipo_2 != "" else ""])
	print("  ⚧ Sexo: %s | 🧠 Naturaleza: %s" % [pokemon.sexo if pokemon.sexo != "" else "Sin género", pokemon.naturaleza])
	print("  💪 Habilidad: %s" % pokemon.habilidad)

	# IVs
	print("  📈 IVs: PS:%d ATK:%d DEF:%d SATK:%d SDEF:%d SPD:%d" % [
		pokemon.iv_ps, pokemon.iv_ataque, pokemon.iv_defensa,
		pokemon.iv_ataque_especial, pokemon.iv_defensa_especial, pokemon.iv_velocidad
	])

	# Estadísticas finales
	print("  ⚔️ Stats: %d/%d/%d/%d/%d/%d" % [
		pokemon.estad_ps, pokemon.estad_ataque, pokemon.estad_defensa,
		pokemon.estad_ataque_especial, pokemon.estad_defensa_especial, pokemon.estad_velocidad
	])

	# Marcas
	var marcas_activas = []
	for marca in ["circulo", "cuadrado", "triangulo", "corazon"]:
		if pokemon.marcas.get(marca, false):
			marcas_activas.append(marca)

	if marcas_activas.size() > 0:
		print("  🏷️ Marcas: %s" % ", ".join(marcas_activas))

	# Movimientos
	if pokemon.movimientos.size() > 0:
		print("  🥊 Movimientos: %s" % ", ".join(pokemon.movimientos))

	print("  📍 OT: %s | ID: %d | Lugar: %s" % [pokemon.entrenador_original, pokemon.entrenador_id, pokemon.encuentro_lugar])

# ===================================
# ANIMACIÓN DE CAMBIO DE CAJA
# ===================================

## LEGACY: Función anterior comentada - ahora se usa _animar_cambio_caja_con_desplazamiento
func _cambiar_caja_con_animacion(nueva_caja: int, _direccion: int = 1) -> void:
	print("🎬 [LEGACY] Redirigiendo a nuevo sistema de animación...")
	_cambiar_a_caja_instancia(nueva_caja)

# ===================================
# FUNCIONES AUXILIARES
# ===================================

## Función helper para rellenar strings con espacios (reemplazo de pad_to).
func _pad_string_to_length(text: String, length: int) -> String:
	var result = text
	while result.length() < length:
		result += " "
	return result

# ===================================
# FIN DEL SCRIPT
# ===================================
