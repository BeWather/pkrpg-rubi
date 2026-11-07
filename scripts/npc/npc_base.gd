@tool
extends Node2D

# Versión 3 del script base para NPCs, con lógica de movimiento, interacción y máquina de estados.

signal _dialogo_objeto_recibido_terminado
## Emitida al empezar cada paso o salto hacia otra celda, con coord_celda ya
## apuntando a `destino` (reserva). La escuchan los seguidores (seguir_a).
signal paso_iniciado(origen: Vector2i, destino: Vector2i)

# Constantes para evitar valores mágicos
const TILE_SIZE: int = 16
const OFFSET: Vector2 = Vector2(8, 14)
const TEXTURA_SOMBRA: Texture2D = preload("res://graficos/character/player_shadow.png")
## Secuencias de giro en sitio (un paso por evento de temporizador).
const ROTACION_HORARIA_SECUENCIA := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const ROTACION_CONTRA_SECUENCIA := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
## Debe coincidir con Singleton.Z_INDEX_POR_CAPA (el autoload no existe en el editor).
const Z_INDEX_POR_CAPA: int = 10
## Suma de z_index mientras el NPC está sobre (o entrando en) una celda
## PUNTO_ELEVADO. No se acumula entre puntos elevados contiguos.
const OFFSET_ELEVACION: int = 10
const HIERBA_MUY_ALTA_SHADER: Shader = preload("res://escenas/character/hierba_muy_alta_clip.gdshader")
const HIERBA_MUY_ALTA_FRAMES: SpriteFrames = preload("res://escenas/mapas/animaciones/hierba_muy_alta.tres")
const HIERBA_MUY_ALTA_ANIM_OFFSET: Vector2 = Vector2(-8, -15)
const HIERBA_MUY_ALTA_CLIP_Y: float = -14.0
const HIERBA_MUY_ALTA_CLIP_X_IZQ: float = -8.0
const HIERBA_MUY_ALTA_CLIP_X_DER: float = 8.0
# const OFFSET: Vector2 = Vector2(0, 0)

## Clave en Singleton.TEMAS_REGISTRADOS de la fanfarria de objeto obtenido
## (pokeemerald MUS_OBTAIN_ITEM). Vacía = sin fanfarria.
var fanfarria_objeto: String = "OBTENIDO_OBJETO"
var _texto_objeto_listo: bool = false

enum TipoMovimientoNPC {
	SIN_MOVIMIENTO,
	MIRAR_ALREDEDOR,
	PASEAR_RANGO,
	PASEAR_ARRIBA_ABAJO,
	PASEAR_ABAJO_ARRIBA,
	PASEAR_IZQUIERDA_DERECHA,
	PASEAR_DERECHA_IZQUIERDA,
	MIRAR_ARRIBA,
	MIRAR_ABAJO,
	MIRAR_IZQUIERDA,
	MIRAR_DERECHA,
	MIRAR_ABAJO_ARRIBA,
	MIRAR_IZQUIERDA_DERECHA,
	MIRAR_IZQUIERDA_ARRIBA,
	MIRAR_ARRIBA_DERECHA,
	MIRAR_DERECHA_ABAJO,
	MIRAR_ABAJO_IZQUIERDA,
	ROTACION_HORARIA,
	ROTACION_CONTRA_HORARIA,
	CAMINAR_ARRIBA_ABAJO,
	CAMINAR_ABAJO_ARRIBA,
	CAMINAR_IZQUIERDA_DERECHA,
	CAMINAR_DERECHA_IZQUIERDA,
	CAMINAR_ARR_DER_IZQ_ABA,
	CAMINAR_DER_IZQ_ABA_ARR,
	CAMINAR_ABA_ARR_DER_IZQ,
	CAMINAR_IZQ_ABA_ARR_DER,
	CAMINAR_ARR_IZQ_DER_ABA,
	CAMINAR_IZQ_DER_ABA_ARR,
	CAMINAR_ABA_ARR_IZQ_DER,
	CAMINAR_DER_ABA_ARR_IZQ,
	CAMINAR_ENLUGAR_ABAJO,
	CAMINAR_ENLUGAR_ARRIBA,
	CAMINAR_ENLUGAR_IZQUIERDA,
	CAMINAR_ENLUGAR_DERECHA,
	INVISIBLE,
	# Añadidos al final para no cambiar los valores ya guardados en las escenas.
	MIRAR_ARRIBA_IZQUIERDA_DERECHA,		# FACE_UP_LEFT_AND_RIGHT
	MIRAR_ABAJO_IZQUIERDA_DERECHA,		# FACE_DOWN_LEFT_AND_RIGHT
	CAMINAR_ABA_IZQ_ARR_DER,			# WALK_SEQUENCE_DOWN_LEFT_UP_RIGHT
	MIRAR_ABAJO_ARRIBA_IZQUIERDA,		# FACE_DOWN_UP_AND_LEFT
	MIRAR_ABAJO_ARRIBA_DERECHA,			# FACE_DOWN_UP_AND_RIGHT
	CAMINAR_IZQ_ARR_ABA_DER,			# WALK_SEQUENCE_LEFT_UP_DOWN_RIGHT
	CAMINAR_ARR_ABA_DER_IZQ,			# WALK_SEQUENCE_UP_DOWN_RIGHT_LEFT
	CAMINAR_DER_IZQ_ARR_ABA,			# WALK_SEQUENCE_RIGHT_LEFT_UP_DOWN
	CAMINAR_ABA_DER_IZQ_ARR,			# WALK_SEQUENCE_DOWN_RIGHT_LEFT_UP
	CAMINAR_DER_ARR_ABA_IZQ,			# WALK_SEQUENCE_RIGHT_UP_DOWN_LEFT
	CAMINAR_ARR_ABA_IZQ_DER,			# WALK_SEQUENCE_UP_DOWN_LEFT_RIGHT
	CAMINAR_IZQ_DER_ARR_ABA,			# WALK_SEQUENCE_LEFT_RIGHT_UP_DOWN
	CAMINAR_ABA_IZQ_DER_ARR,			# WALK_SEQUENCE_DOWN_LEFT_RIGHT_UP
	CAMINAR_ARR_IZQ_ABA_DER,			# WALK_SEQUENCE_UP_LEFT_DOWN_RIGHT
	CAMINAR_ABA_DER_ARR_IZQ,			# WALK_SEQUENCE_DOWN_RIGHT_UP_LEFT
	CAMINAR_IZQ_ABA_DER_ARR,			# WALK_SEQUENCE_LEFT_DOWN_RIGHT_UP
	CAMINAR_DER_ARR_IZQ_ABA,			# WALK_SEQUENCE_RIGHT_UP_LEFT_DOWN
	CAMINAR_ARR_DER_ABA_IZQ,			# WALK_SEQUENCE_UP_RIGHT_DOWN_LEFT
	CAMINAR_IZQ_ARR_DER_ABA,			# WALK_SEQUENCE_LEFT_UP_RIGHT_DOWN
	CAMINAR_DER_ABA_IZQ_ARR,			# WALK_SEQUENCE_RIGHT_DOWN_LEFT_UP
	COPIAR_JUGADOR,						# COPY_PLAYER
	COPIAR_JUGADOR_OPUESTO,				# COPY_PLAYER_OPPOSITE
	COPIAR_JUGADOR_ANTIHORARIO,			# COPY_PLAYER_COUNTERCLOCKWISE
	COPIAR_JUGADOR_HORARIO,				# COPY_PLAYER_CLOCKWISE
	DISFRAZ_ARBOL,						# TREE_DISGUISE
	DISFRAZ_MONTANA,					# MOUNTAIN_DISGUISE
	COPIAR_JUGADOR_EN_HIERBA,			# COPY_PLAYER_IN_GRASS
	COPIAR_JUGADOR_OPUESTO_EN_HIERBA,	# COPY_PLAYER_OPPOSITE_IN_GRASS
	COPIAR_JUGADOR_ANTIHORARIO_EN_HIERBA,	# COPY_PLAYER_COUNTERCLOCKWISE_IN_GRASS
	COPIAR_JUGADOR_HORARIO_EN_HIERBA,	# COPY_PLAYER_CLOCKWISE_IN_GRASS
	OCULTO,								# HIDDEN (enterrado en ceniza, Ruta 113)
	TROTAR_ENLUGAR_ABAJO,				# JOG_IN_PLACE_DOWN
	TROTAR_ENLUGAR_ARRIBA,				# JOG_IN_PLACE_UP
	TROTAR_ENLUGAR_IZQUIERDA,			# JOG_IN_PLACE_LEFT
	TROTAR_ENLUGAR_DERECHA,				# JOG_IN_PLACE_RIGHT
	CORRER_ENLUGAR_ABAJO,				# RUN_IN_PLACE_DOWN
	CORRER_ENLUGAR_ARRIBA,				# RUN_IN_PLACE_UP
	CORRER_ENLUGAR_IZQUIERDA,			# RUN_IN_PLACE_LEFT
	CORRER_ENLUGAR_DERECHA,				# RUN_IN_PLACE_RIGHT
}

## MovementType_WalkInPlace/JogInPlace/RunInPlace: [dirección inicial,
## fotogramas (60 fps) de cada paso]. MovementAction_WalkInPlace{Normal,Fast,Fastest}.
const TIPOS_EN_SITIO := {
	TipoMovimientoNPC.CAMINAR_ENLUGAR_ABAJO: [Vector2.DOWN, 16],
	TipoMovimientoNPC.CAMINAR_ENLUGAR_ARRIBA: [Vector2.UP, 16],
	TipoMovimientoNPC.CAMINAR_ENLUGAR_IZQUIERDA: [Vector2.LEFT, 16],
	TipoMovimientoNPC.CAMINAR_ENLUGAR_DERECHA: [Vector2.RIGHT, 16],
	TipoMovimientoNPC.TROTAR_ENLUGAR_ABAJO: [Vector2.DOWN, 8],
	TipoMovimientoNPC.TROTAR_ENLUGAR_ARRIBA: [Vector2.UP, 8],
	TipoMovimientoNPC.TROTAR_ENLUGAR_IZQUIERDA: [Vector2.LEFT, 8],
	TipoMovimientoNPC.TROTAR_ENLUGAR_DERECHA: [Vector2.RIGHT, 8],
	TipoMovimientoNPC.CORRER_ENLUGAR_ABAJO: [Vector2.DOWN, 4],
	TipoMovimientoNPC.CORRER_ENLUGAR_ARRIBA: [Vector2.UP, 4],
	TipoMovimientoNPC.CORRER_ENLUGAR_IZQUIERDA: [Vector2.LEFT, 4],
	TipoMovimientoNPC.CORRER_ENLUGAR_DERECHA: [Vector2.RIGHT, 4],
}

## MovementType_CopyPlayer / CopyPlayerInGrass: [dirección inicial
## (gInitialMovementTypeFacingDirections), solo avanza sobre hierba].
const TIPOS_COPIAR_JUGADOR := {
	TipoMovimientoNPC.COPIAR_JUGADOR: [Vector2.UP, false],
	TipoMovimientoNPC.COPIAR_JUGADOR_OPUESTO: [Vector2.DOWN, false],
	TipoMovimientoNPC.COPIAR_JUGADOR_ANTIHORARIO: [Vector2.LEFT, false],
	TipoMovimientoNPC.COPIAR_JUGADOR_HORARIO: [Vector2.RIGHT, false],
	TipoMovimientoNPC.COPIAR_JUGADOR_EN_HIERBA: [Vector2.UP, true],
	TipoMovimientoNPC.COPIAR_JUGADOR_OPUESTO_EN_HIERBA: [Vector2.DOWN, true],
	TipoMovimientoNPC.COPIAR_JUGADOR_ANTIHORARIO_EN_HIERBA: [Vector2.LEFT, true],
	TipoMovimientoNPC.COPIAR_JUGADOR_HORARIO_EN_HIERBA: [Vector2.RIGHT, true],
}

## Direcciones de Gen 3 (DIR_SOUTH = 1, DIR_NORTH, DIR_WEST, DIR_EAST = 4).
const DIR_GBA := {Vector2.DOWN: 1, Vector2.UP: 2, Vector2.LEFT: 3, Vector2.RIGHT: 4}
const DIR_DESDE_GBA := [Vector2.ZERO, Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
## gUnknown_08375757 [referencia][movimiento]: gira el movimiento del jugador
## para que su dirección de referencia equivalga al norte.
const COPIA_RELATIVA := [[2, 1, 4, 3], [1, 2, 3, 4], [3, 4, 2, 1], [4, 3, 1, 2]]
## gUnknown_08375767 [dirección inicial del tipo][relativa]: igual (norte),
## opuesta (sur), 90° antihoraria (oeste) o 90° horaria (este).
const COPIA_FINAL := [[2, 1, 4, 3], [1, 2, 3, 4], [4, 3, 1, 2], [3, 4, 2, 1]]

## Disfraces (FLDEFF_TREE_DISGUISE / FLDEFF_MOUNTAIN_DISGUISE): anim "quieto"
## (frame 0) y "revelar" (frames 0..6, 4 fotogramas cada uno).
const FRAMES_DISFRAZ_ARBOL: SpriteFrames = preload("res://graficos/efectos_campo/disfraz_arbol.tres")
const FRAMES_DISFRAZ_MONTANA: SpriteFrames = preload("res://graficos/efectos_campo/disfraz_montana.tres")
## FLDEFF_POP_OUT_OF_ASH: frames 0..4, 6 fotogramas cada uno.
const FRAMES_SALIR_DE_CENIZA: SpriteFrames = preload("res://graficos/efectos_campo/salir_de_ceniza.tres")
## UpdateDisguiseFieldEffect: pos.y = alto/2 + pos_npc.y - 16, con el NPC de
## 16×32 queda centrado sobre él; la base del disfraz es el borde inferior de la
## celda (el sprite del NPC acaba en OFFSET.y + 2).
const OFFSET_DISFRAZ: Vector2 = Vector2(-8, -30)
## FldEff_PopOutOfAsh: 16×16 centrado en la celda del NPC.
const OFFSET_SALIR_DE_CENIZA: Vector2 = Vector2(-8, -14)
## Unknown_837619E (sub_8064704): altura del sprite en un salto, un valor por
## fotograma (16 entradas, pico de -12 px). Sirve para el salto en sitio (1
## fotograma por entrada) y para el salto de saliente de 2 casillas
## (MovementAction_Jump2*: 32 fotogramas, un valor cada 2, `frame >> 1`).
const ALTURAS_SALTO: Array[int] = [-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0]
## Duración del salto de saliente de 2 casillas (jump_2_*, velocidad 2 de
## sub_8064704): 32 fotogramas a 60 fps. Es la de los NPC y la del jugador.
const DURACION_SALTO_BORDE: float = 32.0 / 60.0

## Altura (px, negativa = hacia arriba) del sprite en el instante `t` (0..1) de un
## salto que recorre la tabla ALTURAS_SALTO completa. Fuera de rango se satura,
## porque el último paso de un bucle por tiempo puede pasarse de 1.0.
static func altura_salto_en_progreso(t: float) -> int:
	return ALTURAS_SALTO[clampi(int(t * float(ALTURAS_SALTO.size())), 0, ALTURAS_SALTO.size() - 1)]

## pokeruby MovementType_WalkSequence*: recorre las cuatro direcciones en orden,
## caminando en cada una hasta salir del rango. [secuencia, índice y eje (0 = x,
## 1 = y) del tramo que se salta si ya está alineado con la celda inicial].
const SECUENCIAS_CAMINATA := {
	TipoMovimientoNPC.CAMINAR_ARR_DER_IZQ_ABA: [[Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN], 2, 0],
	TipoMovimientoNPC.CAMINAR_DER_IZQ_ABA_ARR: [[Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP], 1, 0],
	TipoMovimientoNPC.CAMINAR_ABA_ARR_DER_IZQ: [[Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT], 1, 1],
	TipoMovimientoNPC.CAMINAR_IZQ_ABA_ARR_DER: [[Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT], 2, 1],
	TipoMovimientoNPC.CAMINAR_ARR_IZQ_DER_ABA: [[Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN], 2, 0],
	TipoMovimientoNPC.CAMINAR_IZQ_DER_ABA_ARR: [[Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP], 1, 0],
	TipoMovimientoNPC.CAMINAR_ABA_ARR_IZQ_DER: [[Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT], 1, 1],
	TipoMovimientoNPC.CAMINAR_DER_ABA_ARR_IZQ: [[Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT], 2, 1],
	TipoMovimientoNPC.CAMINAR_ABA_IZQ_ARR_DER: [[Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT], 2, 1],
	TipoMovimientoNPC.CAMINAR_IZQ_ARR_ABA_DER: [[Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT], 2, 1],
	TipoMovimientoNPC.CAMINAR_ARR_ABA_DER_IZQ: [[Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT], 1, 1],
	TipoMovimientoNPC.CAMINAR_DER_IZQ_ARR_ABA: [[Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN], 1, 0],
	TipoMovimientoNPC.CAMINAR_ABA_DER_IZQ_ARR: [[Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP], 2, 0],
	TipoMovimientoNPC.CAMINAR_DER_ARR_ABA_IZQ: [[Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT], 2, 1],
	TipoMovimientoNPC.CAMINAR_ARR_ABA_IZQ_DER: [[Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT], 1, 1],
	TipoMovimientoNPC.CAMINAR_IZQ_DER_ARR_ABA: [[Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN], 1, 0],
	TipoMovimientoNPC.CAMINAR_ABA_IZQ_DER_ARR: [[Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP], 2, 0],
	TipoMovimientoNPC.CAMINAR_ARR_IZQ_ABA_DER: [[Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT], 2, 1],
	TipoMovimientoNPC.CAMINAR_ABA_DER_ARR_IZQ: [[Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT], 2, 1],
	TipoMovimientoNPC.CAMINAR_IZQ_ABA_DER_ARR: [[Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP], 2, 0],
	TipoMovimientoNPC.CAMINAR_DER_ARR_IZQ_ABA: [[Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN], 2, 0],
	TipoMovimientoNPC.CAMINAR_ARR_DER_ABA_IZQ: [[Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT], 2, 1],
	TipoMovimientoNPC.CAMINAR_IZQ_ARR_DER_ABA: [[Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN], 2, 0],
	TipoMovimientoNPC.CAMINAR_DER_ABA_IZQ_ARR: [[Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP], 2, 0],
}

## Sorteo de los giros en tres direcciones (gUpLeftAndRightDirections,
## gDownUpAndLeftDirections…): una de las direcciones sale el doble de veces.
const DIRECCIONES_MIRAR_TRES := {
	TipoMovimientoNPC.MIRAR_ARRIBA_IZQUIERDA_DERECHA: [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP],
	TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA_DERECHA: [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.DOWN],
	TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_IZQUIERDA: [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.DOWN],
	TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_DERECHA: [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN],
}

# Estados de la máquina de estados
enum EstadoNPC {
	IDLE,				# Estado de reposo, el NPC puede decidir qué hacer
	MOVING,				# En movimiento (desplazándose entre tiles)
	WAITING,			# Esperando (pausado temporalmente)
	LOOKING,			# Bandera para indicar que hubo cambio de dirección en el frame actual
	INTERACTING,		# Interactuando con el jugador
	SCRIPTED_ACTION,	# Ejecutando una acción programada específica
	DISABLED			# Deshabilitado (invisible y sin acciones)
}

## Tamaño de los fotogramas del avatar (selec_frames). Determina el offset del
## AnimatedSprite2D: centrado en horizontal y con los pies 2 px por debajo del nodo
## (OFFSET.y = 14 en una celda de 16), igual que el NPC estándar.
enum TamanoSprite {
	NORMAL_16X22,	# NPC estándar (npc_001…npc_079)
	ALTO_16X32,		# Adulto alto de 16×32 (woman_7)
	ANCHO_32X32,	# 32×32, p. ej. ciclistas (rubi_ciclista_f / rubi_ciclista_m)
	OBJETO_16X16,	# 16×16, p. ej. un bolso u otros objetos (añadido al final: no cambia los valores guardados)
}

## Offset del AnimatedSprite2D para cada TamanoSprite: (-ancho / 2, 2 - alto).
const OFFSETS_TAMANO_SPRITE := {
	TamanoSprite.NORMAL_16X22: Vector2(-8, -20),
	TamanoSprite.ALTO_16X32: Vector2(-8, -30),
	TamanoSprite.ANCHO_32X32: Vector2(-16, -30),
	TamanoSprite.OBJETO_16X16: Vector2(-8, -14),
}
## Separación entre la coronilla del sprite y el "!" de mostrar_exclamacion().
const SEPARACION_EXCLAMACION: float = 15.0

@export var id_texto : String
## Mensaje distinto la primera vez (checkflag/setflag de Gen 3): se muestra en
## lugar de id_texto mientras bandera_primera_vez no esté activa, y la activa.
@export var id_texto_primera_vez : String
## Bandera persistente (SistemaGuardado) que marca el primer mensaje como visto.
@export var bandera_primera_vez : String
## Bandera de SistemaGuardado que oculta al NPC mientras está activa (campo
## `flag` de los object_events de Gen 3, p. ej. FLAG_HIDE_*). Se vuelve a
## comprobar cada vez que su mapa pasa a ser el actual.
@export var bandera_ocultar : String
## Inverso de bandera_ocultar: el NPC solo se ve mientras esta bandera está
## activa. Para los FLAG_HIDE_* que new_game.inc activa al empezar (el NPC
## aparece cuando un evento hace clearflag). Se combina con bandera_ocultar.
@export var bandera_mostrar : String
@export var tipo_movimiento : TipoMovimientoNPC:
	set(value):
		tipo_movimiento = value
		# Un COPIAR_* toma de nuevo su referencia (directionSequenceIndex = 0).
		_desconectar_copia()
		if is_inside_tree() and animated_sprite:
			direccion_inicial()
			update_configuration_warnings()
@export var rango : Vector2i = Vector2i.ZERO	# Medido en tiles
## Ajuste fino de z_index; se suma al derivado de capa_datos (normalmente 0).
@export var elevacion: int:
	set(value):
		elevacion = value
		_actualizar_z_index()
## Capa de datos a la que pertenece este NPC.
## -1 = visible/interactuable desde cualquier capa activa.
## >=0 = solo visible/interactuable desde esa capa específica.
## También fija el z_index: capa_datos * Z_INDEX_POR_CAPA (igual que el jugador).
@export var capa_datos: int = -1:
	set(value):
		capa_datos = value
		_actualizar_z_index()
## Seteo prioritario: para NPC que deben seguir actuando por su cuenta (pasear,
## girar, paso en sitio, copiar al jugador) aunque su mapa no sea el activo del
## AdministradorMapa; p. ej. escenas que mueven NPC de otro mapa de forma
## autónoma. Por defecto false: los NPC de un mapa que no es el activo (vecinos
## del overworld que se ven en pantalla) se quedan quietos. Solo afecta a
## puede_iniciar_acciones(): la visión del entrenador y la ocupación de celdas
## por el jugador siguen exigiendo es_mapa_activo(), porque comparan celdas
## locales de mapas distintos.
@export var procesar_fuera_del_mapa_activo: bool = false



var rango_ini : Vector2i = Vector2i.ZERO
var rango_fin : Vector2i = Vector2i.ZERO
## Celda inicial del NPC (initialCoords de Gen 3). Ancla del rango de paseo.
## NUNCA recalcular el rango desde coord_celda: el mapa queda instanciado y se
## oculta/muestra al cambiar de mapa (ver reinicializar_como_recien_agregado);
## anclar a la posición actual hace derivar el rango en cada visita.
var celda_origen : Vector2i = Vector2i.ZERO
## Caché de _obtener_mapa_propio(): se consulta en cada comprobación de celda y
## de mapa activo. Se descarta al cambiar de padre (NOTIFICATION_PARENTED) y se
## revalida con is_instance_valid + is_ancestor_of; nunca guarda null.
var _mapa_propio_cache: MapaConfiguracion = null
var moving = false
var coord_celda: Vector2i
var jugador: Node2D = null
var nodo_administrador: Node2D = null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D    # Referencia al nodo del sprite de este NPC
@onready var sombra: CanvasItem = get_node_or_null("sombra")
var step_count = 0
# Reemplazo del Timer por control por timestamp
var tiempo_hasta_proximo_evento: float = 0.0
## Dirección a la que mira el NPC. SIEMPRE Vector2 (nunca Vector2i): `mirar()`
## recibe Vector2i y debe convertir, o las comparaciones contra otros Vector2
## (y el acceso a `direcciones_opuestas`, cuyas claves son Vector2) fallan.
var facing_direction: Vector2 = Vector2.DOWN
var current_walk_direction = Vector2.UP  # Para patrones de caminata específicos
## Dirección "de reposo" definida por el tipo de movimiento: es a la que vuelven
## los MIRAR_* tras una interacción.
var direccion_base: Vector2 = Vector2.DOWN
const DIRECCIONES_POR_NOMBRE: Dictionary = {
	"arriba": Vector2.UP, "abajo": Vector2.DOWN, "izquierda": Vector2.LEFT, "derecha": Vector2.RIGHT,
}
## Dirección del sprite tal como lo dejó la escena (SIN_MOVIMIENTO); ver _direccion_de_escena.
var _direccion_escena: Vector2 = Vector2.ZERO
var _direccion_escena_leida: bool = false
## Índice actual dentro de la secuencia de giro (ROTACION_HORARIA / CONTRA).
var _rotacion_indice: int = 0

## Paso normal de Gen 3 (GetWalkNormalMovementAction): 16 px en 16 frames a
## 60 fps, igual que el jugador caminando (character.gd SPEED = 60 px/s).
const DURACION_PASO_CAMINAR: float = 16.0 / 60.0

## Velocidad de paso (applymovement walk_slow / walk_normal / walk_fast /
## walk_fastest de pokeruby). Es ABSOLUTA: cada valor son siempre los mismos
## fotogramas por casilla, sea cual sea la duración de paso base del actor.
## Ver duracion_para_velocidad().
enum VelocidadPaso { LENTO, NORMAL, RAPIDO, MUY_RAPIDO }

## Fotogramas (a 60 fps) por casilla de cada velocidad en el decomp:
## walk_slow = 32, walk_normal = 16, walk_fast = 8, walk_fastest = 4.
const FOTOGRAMAS_POR_CASILLA: Dictionary = {
	VelocidadPaso.LENTO: 32,
	VelocidadPaso.NORMAL: 16,
	VelocidadPaso.RAPIDO: 8,
	VelocidadPaso.MUY_RAPIDO: 4,
}


## Duración (s) de un paso a `velocidad`: fotogramas de FOTOGRAMAS_POR_CASILLA a
## 60 fps (LENTO 32/60, NORMAL 16/60, RAPIDO 8/60, MUY_RAPIDO 4/60).
static func duracion_para_velocidad(velocidad: VelocidadPaso) -> float:
	var fotogramas: int = FOTOGRAMAS_POR_CASILLA[velocidad]
	return float(fotogramas) / 60.0


## Velocidad con la que el NPC pasea según su `tipo_movimiento` (caminar al azar,
## secuencias, rutas...). Fija `duracion_paso`. Los pasos de guion
## (EventoGuionizado.caminar / recorrer) llevan su propia velocidad absoluta y no
## dependen de este valor.
@export var velocidad_paso: VelocidadPaso = VelocidadPaso.NORMAL:
	set(value):
		velocidad_paso = value
		duracion_paso = duracion_para_velocidad(value)

# Duración total del desplazamiento de una casilla (16 px). No se exporta: la
# fija velocidad_paso y el código la reasigna en ejecución (seguir_a, copiar al
# jugador, pasos de guion, la abuela de la guardería).
var duracion_paso: float = DURACION_PASO_CAMINAR

# Variables internas para el movimiento manual (sin tween)
var paso_en_curso: bool = false
var origen_paso: Vector2
var destino_paso: Vector2
var progreso_paso: float = 0.0  # 0..1
var direccion_paso: Vector2 = Vector2.ZERO
## Arena a los pies y huellas sobre tiles de desierto (solo en ejecución).
var _efectos_arena: EfectosArena = null
var _tierra_pies: TierraPies = null
var alterna_animacion: int = 2
var animaciones_pisar_pasto: Array = []
var material_hierba_muy_alta: ShaderMaterial = null
var hierba_muy_alta_activa: bool = false
## Agua termal (AGUA_TERMAL): recorta el cuerpo con el mismo material. Se crea junto a él.
var _sumersion_termal: SumersionTermal = null
var salpicadura: AnimatedSprite2D = null
## Salpicadura y ondas sobre AGUA_SALPICA (solo en ejecución, como la arena).
var _efectos_agua: EfectosAgua = null

enum TransicionHierba {
	NINGUNA,
	ENTRADA_ARRIBA,
	ENTRADA_ABAJO,
	ENTRADA_IZQUIERDA,
	ENTRADA_DERECHA,
	ACTIVA,
	SALIDA_ARRIBA,
	SALIDA_ABAJO,
	SALIDA_IZQUIERDA,
	SALIDA_DERECHA,
}

var transicion_hierba_activa: TransicionHierba = TransicionHierba.NINGUNA
## Duración del salto de saliente (ver DURACION_SALTO_BORDE). Interna: la
## reasignan seguir_a (a la del jugador y escalada por el ritmo del seguidor).
var duracion_salto: float = DURACION_SALTO_BORDE
## Salto parabólico en curso (ver _completar_paso_en_curso). El contador
## invalida la corrutina de un salto que se ha terminado de golpe.
var _salto_en_curso: bool = false
var _id_salto: int = 0
var _posicion_final_salto: Vector2 = Vector2.ZERO
var _offset_sprite_salto: Vector2 = Vector2.ZERO

# Seguimiento de un líder (jugador u otro NPC), ver seguir_a().
## Nodo al que sigue este NPC; null si no sigue a nadie.
var lider: Node2D = null
var _tipo_movimiento_previo: TipoMovimientoNPC = TipoMovimientoNPC.SIN_MOVIMIENTO
var _duracion_paso_previa: float = DURACION_PASO_CAMINAR
var _duracion_salto_previa: float = DURACION_SALTO_BORDE
## Celdas que el líder ha dejado y el seguidor aún debe recorrer, en orden. Si se
## acumulan, el seguidor acelera (hasta FACTOR_MAX_RITMO_SEGUIMIENTO) en vez de
## teletransportarse para alcanzarle.
var _cola_seguimiento: Array[Vector2i] = []

# Paso en sitio continuo (CAMINAR/TROTAR/CORRER_ENLUGAR_*), ver _procesar_paso_en_sitio().
var _en_sitio_activo: bool = false
var _en_sitio_tiempo: float = 0.0
var _en_sitio_alterna: int = 2

# Copia de los movimientos del jugador (COPIAR_JUGADOR_*), ver _procesar_copia_jugador().
## Dirección del jugador al activarse el NPC (directionSequenceIndex de
## MovementType_CopyPlayer_Step0). Vector2.ZERO = aún sin tomar.
var _copia_referencia: Vector2 = Vector2.ZERO
## Jugador cuya señal paso_iniciado está conectada; null = sin conectar.
var _copia_jugador: Node2D = null
## Última dirección del jugador vista: no hay señal de giro, se sondea.
var _copia_ultima_mirada: Vector2 = Vector2.ZERO
## Paso del jugador aún sin copiar: [origen, destino], o vacío.
var _copia_paso_pendiente: Array = []

# Disfraces (DISFRAZ_*) y ceniza (OCULTO), ver revelar().
## Disfraz que tapa al NPC; null si no tiene (o ya se lo quitó).
var _disfraz: AnimatedSprite2D = null
## Ya se quitó el disfraz: no vuelve hasta reinicializarse (directionSequenceIndex = 2).
var _disfraz_revelado: bool = false
## Ya salió de la ceniza: visible hasta reinicializarse.
var _oculto_revelado: bool = false
## Efecto de salir de la ceniza en curso.
var _efecto_ceniza: AnimatedSprite2D = null
## Salto en sitio en curso (GetJumpInPlaceMovementAction).
var _salto_en_sitio_activo: bool = false
## Altura aplicada ahora por _saltar_en_sitio (para deshacerla si se corta).
var _altura_salto_en_sitio_actual: int = 0
## Invalida las corrutinas de revelar() al reinicializarse el NPC.
var _id_revelar: int = 0
## El sprite lo oculta el tipo (INVISIBLE, OCULTO o DISFRAZ_* sin revelar).
var _sprite_oculto_por_tipo: bool = false

# Variables para la máquina de estados
var estado_actual: EstadoNPC = EstadoNPC.IDLE
var estado_anterior: EstadoNPC = EstadoNPC.IDLE
var tiempo_en_estado: float = 0.0	# Cuenta el tiempo que lleva en el estado actual
var accion_en_progreso: bool = false

# Variable para manejar interrupciones pendientes durante movimiento
var interrupcion_pendiente: bool = false

## Frames jugables que el NPC sigue mirando al jugador al terminar un encuentro
## (vuelta de la batalla) antes de retomar su rutina de giros o paseos.
const FRAMES_GRACIA_MIRADA: int = 30
## El diálogo cerró con una continuación (combate, entrega...): el encuentro sigue
## y el NPC no vuelve a su dirección de reposo hasta salir de INTERACTING.
var _mirada_fija_encuentro: bool = false
## Frames de gracia restantes tras el encuentro; solo descuentan con el juego activo.
var _frames_gracia_mirada: int = 0

@export var selec_frames: SpriteFrames = null:
	set(value):
		selec_frames = value
		if is_inside_tree() and animated_sprite:
			animated_sprite.sprite_frames = value
			update_configuration_warnings()
## Tamaño de los fotogramas de selec_frames. Debe coincidir con el avatar elegido:
## fija el offset del AnimatedSprite2D (ver OFFSETS_TAMANO_SPRITE).
@export var tamano_sprite: TamanoSprite = TamanoSprite.NORMAL_16X22:
	set(value):
		tamano_sprite = value
		if is_inside_tree() and animated_sprite:
			animated_sprite.offset = OFFSETS_TAMANO_SPRITE[value] + Vector2(0, _elevacion_activa())
## Píxeles que sube el pivote del nodo respecto a los pies de su celda, con el sprite
## bajando otro tanto para no moverse: la y del nodo queda `elevacion_pivote` por
## debajo de la de un NPC normal, así que el y-sort lo dibuja detrás de los que
## comparten celda con él (la barca del SR. ARENQUE). Se recalcula al cambiarlo,
## también en el editor.
@export var elevacion_pivote: float = 0.0:
	set(value):
		elevacion_pivote = value
		if is_inside_tree() and animated_sprite:
			_aplicar_elevacion_pivote()
@export var coord: Vector2i = Vector2i.ZERO:		# Coordenada en tiles
	set(value):
		coord = value
		if is_inside_tree() and animated_sprite:
			position = posicion_de_celda(value)
			update_configuration_warnings()
@export var loggear: bool = false
var no_mover: bool = false

var direcciones_opuestas = {
	Vector2.DOWN: Vector2.UP,
	Vector2.UP: Vector2.DOWN,
	Vector2.RIGHT: Vector2.LEFT,
	Vector2.LEFT: Vector2.RIGHT
}

# Callback para dialogos
var callback_dialogo: Callable = Callable()

## Los NPCs no traen nodo `sombra` en su escena: se crea igual que la del jugador
## (character.tscn) para que se vea al saltar un borde. Va detrás del sprite.
func _asegurar_sombra() -> void:
	if sombra != null or Engine.is_editor_hint():
		return
	var nodo := Sprite2D.new()
	nodo.name = "sombra"
	nodo.texture = TEXTURA_SOMBRA
	nodo.centered = false
	nodo.position = Vector2(0, -1)
	nodo.offset = Vector2(-8, -13)
	nodo.visible = false
	add_child(nodo)
	move_child(nodo, 0)
	sombra = nodo

func _ready() -> void:
	_asegurar_sombra()
	# NORMAL_16X22 conserva el offset de la escena: algunas instancias lo ajustan.
	if tamano_sprite != TamanoSprite.NORMAL_16X22 and animated_sprite:
		animated_sprite.offset = OFFSETS_TAMANO_SPRITE[tamano_sprite]
	if _elevacion_activa() != 0.0 and animated_sprite:
		_aplicar_elevacion_pivote()
	add_to_group("NPC")
	add_to_group("Reflectable")

	# Inicializar máquina de estados
	estado_actual = EstadoNPC.IDLE
	estado_anterior = EstadoNPC.IDLE
	tiempo_en_estado = 0.0
	accion_en_progreso = false

	# Si la escena del NPC está abierta directamente en el editor (no instanciada en un mapa),
	# no iniciar comportamiento runtime (timers, procesamiento).
	if esta_abierto_directamente_en_editor():
		if Engine.is_editor_hint() and selec_frames and animated_sprite:
			set_notify_transform(true)
			animated_sprite.sprite_frames = selec_frames
			update_configuration_warnings()
			# No inicializar timers ni lógica runtime
			return
	# Acciones solo en modo editor cuando está instanciado; abajo para el modo ejecución.
	if Engine.is_editor_hint() and selec_frames and animated_sprite:
		set_notify_transform(true)
		animated_sprite.sprite_frames = selec_frames
		update_configuration_warnings()
	else:
		# En tiempo de ejecución, obtener el AdministradorMapa de forma segura
		nodo_administrador = null
		if get_tree().root and get_tree().root.has_node("AdministradorMapa"):
			nodo_administrador = get_tree().root.get_node("AdministradorMapa")
			if nodo_administrador:
				jugador = nodo_administrador.jugador
			else:
				jugador = null
		else:
			jugador = null

	animated_sprite.sprite_frames = selec_frames
	_inicializar_efecto_hierba_muy_alta()
	if not Engine.is_editor_hint():
		salpicadura = EfectosAgua.crear_salpicadura_npc()
		add_child(salpicadura)
		# Una sola onda por paso (el jugador hace dos).
		_efectos_agua = EfectosAgua.new(_obtener_tp_capa_propia, _obtener_mapa_propio, salpicadura, 1)
		add_child(_efectos_agua)
		_efectos_arena = EfectosArena.new()
		add_child(_efectos_arena)
		# Tierra de los pies (bandera TIERRA_PIES): va encima de la arena.
		_tierra_pies = TierraPies.new()
		add_child(_tierra_pies)

	_actualizar_z_index()
	direccion_inicial()

	coord_celda = Vector2i(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
	celda_origen = coord_celda
	# También en el editor: el NPC se ve elevado si su celda inicial es PUNTO_ELEVADO.
	_sincronizar_elevacion_punto()
	rango_ini = celda_origen - rango
	rango_fin = celda_origen + rango
	actualizar_efecto_terreno_actual()
	_loggear("npc iniciado en %s" % coord_celda)
	_loggear("Rango inicial: %s Rango final: %s" % [rango_ini, rango_fin])

	# Inicializar y arrancar timer solo en runtime o cuando la escena está instanciada
	# Inicializar scheduling por timestamp en lugar de Timer
	_iniciar_temporizador()

	if not Engine.is_editor_hint():
		var mapa := _obtener_mapa_propio()
		if mapa != null:
			mapa.mapa_activado.connect(_on_mapa_activado)
		if not bandera_ocultar.is_empty() or not bandera_mostrar.is_empty():
			aplicar_bandera_ocultar()

## El overworld reutiliza mapas: entrar de nuevo no ejecuta _ready().
## Restablecer solo la orientación de FACE_*, sin recolocar NPCs ni reiniciar rutas.
func _on_mapa_activado(_por_warp: bool) -> void:
	# Como al recargar el mapa en el GBA: el disfraz y la ceniza vuelven y los
	# COPIAR_* toman de nuevo la dirección del jugador como referencia.
	_reiniciar_tipo_especial()
	if tipo_movimiento in [TipoMovimientoNPC.MIRAR_ARRIBA, TipoMovimientoNPC.MIRAR_ABAJO,
			TipoMovimientoNPC.MIRAR_IZQUIERDA, TipoMovimientoNPC.MIRAR_DERECHA] \
			or es_tipo_revelable(tipo_movimiento) or TIPOS_EN_SITIO.has(tipo_movimiento) \
			or TIPOS_COPIAR_JUGADOR.has(tipo_movimiento) or tipo_movimiento == TipoMovimientoNPC.INVISIBLE:
		direccion_inicial()
	else:
		_aplicar_tipo_especial()
	if not bandera_ocultar.is_empty() or not bandera_mostrar.is_empty():
		aplicar_bandera_ocultar()

## z_index = capa_datos * Z_INDEX_POR_CAPA + elevacion. Con capa_datos -1 (cualquier
## capa) cuenta como capa 0. Mismo criterio que Singleton._aplicar_z_index_foco_por_capa.
func _actualizar_z_index() -> void:
	z_index = maxi(capa_datos, 0) * Z_INDEX_POR_CAPA + elevacion + (OFFSET_ELEVACION if _elevado_punto else 0)

## true mientras el z_index lleva sumado OFFSET_ELEVACION (PUNTO_ELEVADO).
var _elevado_punto: bool = false

func _celda_es_punto_elevado(celda: Vector2i) -> bool:
	var tp := _obtener_tp_capa_propia()
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.PUNTO_ELEVADO)

func _fijar_elevacion_punto(activo: bool) -> void:
	if activo == _elevado_punto:
		return
	_elevado_punto = activo
	_actualizar_z_index()

## Al empezar un paso o salto: sube de inmediato si el destino es PUNTO_ELEVADO;
## si no, conserva el estado hasta que termine el paso.
func _elevar_si_destino_elevado(celda_destino: Vector2i) -> void:
	if _celda_es_punto_elevado(celda_destino):
		_fijar_elevacion_punto(true)

## Al terminar un paso o salto: el offset solo sigue activo si la celda actual
## es PUNTO_ELEVADO.
func _sincronizar_elevacion_punto() -> void:
	_sincronizar_elevacion_punto_en(coord_celda)

## Igual, para una celda concreta (el editor la conoce antes que coord_celda).
func _sincronizar_elevacion_punto_en(celda: Vector2i) -> void:
	_fijar_elevacion_punto(_celda_es_punto_elevado(celda))

## Oculta el NPC si `bandera_ocultar` está activa o `bandera_mostrar` no lo
## está (y lo muestra si no). Ambas aceptan, además de una bandera, una condición
## de CondicionTexto como «MEDALLA_4».
func aplicar_bandera_ocultar() -> void:
	if bandera_ocultar.is_empty() and bandera_mostrar.is_empty():
		return
	visible = (bandera_ocultar.is_empty() or not CondicionTexto.cumple(bandera_ocultar)) \
		and (bandera_mostrar.is_empty() or CondicionTexto.cumple(bandera_mostrar))

func direccion_inicial():
	match tipo_movimiento:
		# Tipos de movimiento que inician mirando hacia arriba
		TipoMovimientoNPC.PASEAR_ARRIBA_ABAJO, TipoMovimientoNPC.MIRAR_ARRIBA, TipoMovimientoNPC.MIRAR_ARRIBA_DERECHA, TipoMovimientoNPC.CAMINAR_ARR_DER_IZQ_ABA, TipoMovimientoNPC.CAMINAR_ARRIBA_ABAJO, \
		TipoMovimientoNPC.MIRAR_ARRIBA_IZQUIERDA_DERECHA, TipoMovimientoNPC.CAMINAR_ARR_IZQ_DER_ABA:
			animated_sprite.play("camina_arriba_1")
			facing_direction = Vector2.UP
			current_walk_direction = Vector2.UP
		TipoMovimientoNPC.PASEAR_ABAJO_ARRIBA, TipoMovimientoNPC.MIRAR_ABAJO, TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA, TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA, TipoMovimientoNPC.CAMINAR_ABA_ARR_DER_IZQ, TipoMovimientoNPC.CAMINAR_ABAJO_ARRIBA, \
		TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA_DERECHA, TipoMovimientoNPC.CAMINAR_ABA_ARR_IZQ_DER, TipoMovimientoNPC.CAMINAR_ABA_IZQ_ARR_DER:
			animated_sprite.play("camina_abajo_1")
			facing_direction = Vector2.DOWN
			current_walk_direction = Vector2.DOWN
		TipoMovimientoNPC.PASEAR_IZQUIERDA_DERECHA, TipoMovimientoNPC.MIRAR_IZQUIERDA, TipoMovimientoNPC.MIRAR_IZQUIERDA_DERECHA, TipoMovimientoNPC.MIRAR_IZQUIERDA_ARRIBA, TipoMovimientoNPC.CAMINAR_IZQUIERDA_DERECHA, \
		TipoMovimientoNPC.CAMINAR_IZQ_ABA_ARR_DER, TipoMovimientoNPC.CAMINAR_IZQ_DER_ABA_ARR:
			animated_sprite.play("camina_izquierda_1")
			facing_direction = Vector2.LEFT
			current_walk_direction = Vector2.LEFT
		TipoMovimientoNPC.PASEAR_DERECHA_IZQUIERDA, TipoMovimientoNPC.MIRAR_DERECHA, TipoMovimientoNPC.MIRAR_DERECHA_ABAJO, TipoMovimientoNPC.CAMINAR_DERECHA_IZQUIERDA, TipoMovimientoNPC.CAMINAR_DER_IZQ_ABA_ARR, \
		TipoMovimientoNPC.CAMINAR_DER_ABA_ARR_IZQ:
			animated_sprite.play("camina_derecha_1")
			facing_direction = Vector2.RIGHT
			current_walk_direction = Vector2.RIGHT
		# Para los demás tipos (incluyendo ROTACION_*), no iniciar animación de caminar aquí
		_:
			var inicial := _direccion_inicial_extra()
			if inicial != Vector2.ZERO:
				animated_sprite.play("camina_%s_1" % get_nombre_dir(inicial))
				facing_direction = inicial
				current_walk_direction = inicial
			elif tipo_movimiento == TipoMovimientoNPC.SIN_MOVIMIENTO:
				# El sprite de la escena manda: solo se sincroniza facing_direction
				# (y se repone esa animación si el juego lo había girado).
				var de_escena := _direccion_de_escena()
				if de_escena == Vector2.ZERO:
					# Sprite sin camina_* (animación propia): abajo, sin tocarlo.
					de_escena = Vector2.DOWN
				else:
					var anima := "camina_%s_1" % get_nombre_dir(de_escena)
					if not String(animated_sprite.animation).begins_with("camina_%s_" % get_nombre_dir(de_escena)) \
							and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(anima):
						animated_sprite.play(anima)
				facing_direction = de_escena
				current_walk_direction = de_escena

	# Guardar la dirección de reposo: es a la que vuelven los MIRAR_* tras hablar.
	direccion_base = facing_direction
	if SECUENCIAS_CAMINATA.has(tipo_movimiento):
		_rotacion_indice = 0

	# Asegurar que el sprite quede detenido y en el frame 0 al iniciar
	animated_sprite.stop()
	animated_sprite.frame = 0
	_en_sitio_activo = false
	_aplicar_tipo_especial()

## Dirección inicial de las secuencias de caminata (su primer tramo), de los
## giros FACE_DOWN_UP_AND_* y de los tipos añadidos al final del enum
## (gInitialMovementTypeFacingDirections).
func _direccion_inicial_extra() -> Vector2:
	if SECUENCIAS_CAMINATA.has(tipo_movimiento):
		var secuencia: Array = SECUENCIAS_CAMINATA[tipo_movimiento][0]
		return Vector2(secuencia[0])
	if TIPOS_EN_SITIO.has(tipo_movimiento):
		return TIPOS_EN_SITIO[tipo_movimiento][0]
	if TIPOS_COPIAR_JUGADOR.has(tipo_movimiento):
		return TIPOS_COPIAR_JUGADOR[tipo_movimiento][0]
	# LOOK_AROUND, WANDER_AROUND y ROTATE_* también empiezan mirando al sur: sin
	# esto el sprite de la escena (izquierda en npc_entrenador.tscn) no coincidía
	# con facing_direction y el entrenador veía hacia donde no parecía mirar.
	if tipo_movimiento in [TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_IZQUIERDA, TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_DERECHA,
			TipoMovimientoNPC.INVISIBLE, TipoMovimientoNPC.DISFRAZ_ARBOL, TipoMovimientoNPC.DISFRAZ_MONTANA,
			TipoMovimientoNPC.OCULTO, TipoMovimientoNPC.MIRAR_ALREDEDOR, TipoMovimientoNPC.PASEAR_RANGO,
			TipoMovimientoNPC.ROTACION_HORARIA, TipoMovimientoNPC.ROTACION_CONTRA_HORARIA]:
		return Vector2.DOWN
	return Vector2.ZERO

## SIN_MOVIMIENTO mira hacia donde la escena dejó el sprite (camina_<dir>_N): se
## lee la primera vez, antes de que el juego lo gire, y se reutiliza al
## reinicializar. ZERO si la animación de la escena no es un camina_* reconocible.
func _direccion_de_escena() -> Vector2:
	if _direccion_escena_leida and not Engine.is_editor_hint():
		return _direccion_escena
	var direccion := Vector2.ZERO
	if animated_sprite != null:
		var partes := String(animated_sprite.animation).split("_")
		if partes.size() >= 2 and partes[0] == "camina":
			direccion = DIRECCIONES_POR_NOMBRE.get(partes[1], Vector2.ZERO)
	_direccion_escena = direccion
	_direccion_escena_leida = true
	return direccion

func get_nombre_dir(direc: Vector2) -> String:
	match direc:
		Vector2.UP:
			return "arriba"
		Vector2.DOWN:
			return "abajo"
		Vector2.RIGHT:
			return "derecha"
		Vector2.LEFT:
			return "izquierda"

	# Fallback para evitar animaciones vacías
	print("⚠️ [NPC_V3] Dirección desconocida: ", direc)
	return "abajo"

func _elevacion_activa() -> float:
	# return 0.0 if Engine.is_editor_hint() else elevacion_pivote
	return elevacion_pivote


## Lleva el nodo a su celda con la elevación del pivote y compensa el sprite.
## Es absoluta (depende de coord, no de la posición previa), así que repetirla no acumula.
func _aplicar_elevacion_pivote() -> void:
	position = posicion_de_celda(coord)
	animated_sprite.offset = OFFSETS_TAMANO_SPRITE[tamano_sprite] + Vector2(0, _elevacion_activa())


## Posición del nodo cuando está en `celda` (los pies en OFFSET menos la elevación del pivote).
func posicion_de_celda(celda: Vector2i) -> Vector2:
	return Vector2(celda.x * TILE_SIZE + OFFSET.x, celda.y * TILE_SIZE + OFFSET.y - _elevacion_activa())


## Posición global de los pies del NPC (la del nodo más la elevación del pivote).
func posicion_pies_global() -> Vector2:
	return global_position + Vector2(0, _elevacion_activa())


# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED: # and Engine.is_editor_hint():
		var new_coord = Vector2i(round((position.x - OFFSET.x) / TILE_SIZE),
			round((position.y - OFFSET.y + _elevacion_activa()) / TILE_SIZE))
		coord = new_coord
		position = posicion_de_celda(coord)
		# Al arrastrarlo en el editor, el z_index sigue a la celda en que queda.
		if Engine.is_editor_hint() and is_inside_tree():
			_sincronizar_elevacion_punto_en(new_coord)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		# Un NPC que la escena guarda oculto (visible = false) la recibe al
		# instanciarse, antes de _ready: aún no hay sprite que reiniciar.
		# Detectar cuando el nodo cambia su visibilidad en el árbol
		# Si se hace invisible, reinicializamos el estado interno como si se hubiera agregado recién
		# (esto permite, por ejemplo, reponer variables y reiniciar timers)
		if not is_visible_in_tree():
			reinicializar_como_recien_agregado()
		else:
			# Al volver a visible, (re)iniciamos el scheduling para retomar comportamiento
			_iniciar_temporizador()
	elif what == NOTIFICATION_PARENTED:
		# Cambio de padre (reparent, add_child): el mapa propio puede ser otro.
		_mapa_propio_cache = null
	elif what == NOTIFICATION_EXIT_TREE:
		# _notification se llama en toda la cadena de herencia (los _exit_tree de
		# las subclases no llaman a super).
		_desconectar_copia()


func reinicializar_como_recien_agregado() -> void:
	# Un paso a medias se da por terminado: si no, el NPC queda entre dos celdas
	# (paso_en_curso sin estado MOVING que lo avance).
	_completar_paso_en_curso()
	# Oculto (p. ej. el jugador cambió de mapa) no puede seguir a nadie.
	if lider != null:
		dejar_de_seguir()
	# Restablecer estado interno a valores por defecto, sin cambiar la propiedad visible
	estado_actual = EstadoNPC.IDLE
	estado_anterior = EstadoNPC.IDLE
	tiempo_en_estado = 0.0
	accion_en_progreso = false
	moving = false
	no_mover = false
	step_count = 0
	interrupcion_pendiente = false
	# Oculto, el encuentro ya terminó (p. ej. warp tras perder): sin gracia
	# pendiente que lo congele al volver. No toca celda_origen ni el rango.
	_mirada_fija_encuentro = false
	_frames_gracia_mirada = 0
	# Disfraz y ceniza de vuelta; los COPIAR_* toman otra referencia.
	_reiniciar_tipo_especial()

	# Reestablecer dirección inicial según el tipo de movimiento
	direccion_inicial()

	# Recalcular la celda actual, pero el rango sigue anclado a celda_origen
	coord_celda = Vector2i(floor((position.x - OFFSET.x) / TILE_SIZE),
		floor((position.y - OFFSET.y + _elevacion_activa()) / TILE_SIZE))
	rango_ini = celda_origen - rango
	rango_fin = celda_origen + rango

	# Reiniciar scheduling temporal
	_iniciar_temporizador()


## Estado que se guarda con la partida mientras el NPC está en el mapa actual,
## como los EventObject de SaveBlock1 en Gen 3: celda actual (el destino si
## estaba a mitad de paso), dirección y el punto de sus patrones de movimiento.
func exportar_estado_guardado() -> Dictionary:
	return {
		"cx": coord_celda.x,
		"cy": coord_celda.y,
		"dir": [int(facing_direction.x), int(facing_direction.y)],
		"dir_paseo": [int(current_walk_direction.x), int(current_walk_direction.y)],
		"rotacion": _rotacion_indice,
	}


## Aplica un estado de `exportar_estado_guardado()` al cargar la partida. El
## rango de paseo sigue anclado a la celda inicial (initialCoords de Gen 3).
func restaurar_estado_guardado(datos: Dictionary) -> void:
	var celda := Vector2i(int(datos.get("cx", coord_celda.x)), int(datos.get("cy", coord_celda.y)))
	coord_celda = celda
	position = posicion_de_celda(celda)
	_sincronizar_elevacion_punto()
	var dir_paseo := _vector_guardado(datos.get("dir_paseo"))
	if dir_paseo != Vector2.ZERO:
		current_walk_direction = dir_paseo
	_rotacion_indice = int(datos.get("rotacion", _rotacion_indice))
	var dir := _vector_guardado(datos.get("dir"))
	if dir in direcciones_opuestas:
		update_direction(dir)
	actualizar_efecto_terreno_actual()


static func _vector_guardado(valor: Variant) -> Vector2:
	if valor is Array and valor.size() == 2:
		return Vector2(float(valor[0]), float(valor[1]))
	return Vector2.ZERO


## Devuelve true si el editor está mostrando directamente esta escena (escena del NPC abierta sola)
func esta_abierto_directamente_en_editor() -> bool:
	if not Engine.is_editor_hint():
		return false
	var tree = get_tree()
	if tree and tree.has_method("edited_scene_root"):
		# En Godot, edited_scene_root es la raíz de la escena abierta en el editor
		var edited_root = tree.edited_scene_root
		return edited_root == self
	# Fallback: si no hay edited_scene_root disponible, asumir que no está abierto directamente
	return false


func _process(_delta):
	# No procesar si estamos en el editor
	if Engine.is_editor_hint():
		return

	# Evitar procesar cuando se está editando la escena del NPC directamente
	if esta_abierto_directamente_en_editor():
		return

	# Búsqueda "lazy" del jugador si aún no está disponible
	if jugador == null and nodo_administrador != null:
		jugador = nodo_administrador.jugador
		if jugador != null:
			_loggear("Jugador encontrado de forma diferida en frame posterior")

	# Quitamos el flag de cambio de dirección porque ya pasó un frame
	if estado_actual == EstadoNPC.LOOKING:
		estado_actual = EstadoNPC.IDLE

	_descontar_gracia_mirada()

	if tiempo_en_estado == null:
		tiempo_en_estado = 0.0
	tiempo_en_estado += _delta
	# Gestionar scheduling basado en timestamps
	if tiempo_hasta_proximo_evento <= 0.0:
		# disparar evento
		_on_tiempo_evento()
	else:
		tiempo_hasta_proximo_evento -= _delta

	procesar_estado_actual(_delta)
	_procesar_paso_en_sitio(_delta)
	_procesar_copia_jugador()

## La gracia tras un encuentro cuenta frames jugables: no corre mientras siguen
## la pausa de batalla, el telón o un diálogo, sino desde que se vuelve al mapa.
func _descontar_gracia_mirada() -> void:
	if _frames_gracia_mirada <= 0:
		return
	if nodo_administrador != null and not nodo_administrador.puede_actuar_npc():
		return
	_frames_gracia_mirada -= 1

## ¿Sigue el NPC fijo mirando al jugador por un encuentro (diálogo con
## continuación, combate o la gracia posterior)?
func mirada_fija_por_encuentro() -> bool:
	return _frames_gracia_mirada > 0 or (_mirada_fija_encuentro and estado_actual == EstadoNPC.INTERACTING)

## Máquina de estados principal.
## EstadoNPC.MOVING es el único utilizado hasta ahora.
func procesar_estado_actual(delta: float) -> void:
	match estado_actual:
		EstadoNPC.IDLE:
			procesar_estado_idle(delta)
		EstadoNPC.MOVING:
			procesar_estado_moving(delta)		# Aqui se avanza en la posición del paso del NPC
		EstadoNPC.WAITING:
			procesar_estado_waiting(delta)
		EstadoNPC.LOOKING:
			procesar_estado_looking(delta)
		EstadoNPC.INTERACTING:					# Lo usaremos como estado durante combate
			procesar_estado_interacting(delta)
		EstadoNPC.SCRIPTED_ACTION:
			procesar_estado_scripted_action(delta)
		EstadoNPC.DISABLED:
			procesar_estado_disabled(delta)

## Cambiar estado con validaciones
func cambiar_estado(nuevo_estado: EstadoNPC) -> void:
	if nuevo_estado == estado_actual:
		return

	# Validar transiciones válidas
	if not es_transicion_valida(estado_actual, nuevo_estado):
		print("Transición inválida de ", EstadoNPC.keys()[estado_actual], " a ", EstadoNPC.keys()[nuevo_estado])
		return

	# Salir del estado actual
	salir_estado(estado_actual)

	# Cambiar estado
	estado_anterior = estado_actual
	estado_actual = nuevo_estado
	tiempo_en_estado = 0.0

	# Entrar al nuevo estado
	entrar_estado(nuevo_estado)

	_loggear("NPC cambió de estado: %s - %s" % [EstadoNPC.keys()[estado_anterior], EstadoNPC.keys()[estado_actual]])

## Validar si una transición entre estados es válida
func es_transicion_valida(desde: EstadoNPC, hacia: EstadoNPC) -> bool:
	match desde:
		EstadoNPC.IDLE:
			return hacia in [EstadoNPC.MOVING, EstadoNPC.LOOKING, EstadoNPC.WAITING, EstadoNPC.INTERACTING, EstadoNPC.SCRIPTED_ACTION, EstadoNPC.DISABLED]
		EstadoNPC.MOVING:
			return hacia in [EstadoNPC.IDLE, EstadoNPC.WAITING, EstadoNPC.INTERACTING, EstadoNPC.DISABLED]
		EstadoNPC.WAITING:
			return hacia in [EstadoNPC.IDLE, EstadoNPC.MOVING, EstadoNPC.LOOKING, EstadoNPC.INTERACTING, EstadoNPC.DISABLED]
		EstadoNPC.LOOKING:
			return hacia in [EstadoNPC.IDLE, EstadoNPC.WAITING, EstadoNPC.INTERACTING, EstadoNPC.DISABLED]
		EstadoNPC.INTERACTING:
			return hacia in [EstadoNPC.IDLE, EstadoNPC.MOVING, EstadoNPC.WAITING, EstadoNPC.DISABLED]
		EstadoNPC.SCRIPTED_ACTION:
			return hacia in [EstadoNPC.IDLE, EstadoNPC.MOVING, EstadoNPC.WAITING, EstadoNPC.LOOKING, EstadoNPC.DISABLED]
		EstadoNPC.DISABLED:
			return hacia in [EstadoNPC.IDLE]  # Solo puede volver a IDLE desde DISABLED
	return false

## Métodos de entrada a estados
func entrar_estado(estado: EstadoNPC) -> void:
	match estado:
		EstadoNPC.IDLE:
			accion_en_progreso = false
		EstadoNPC.MOVING:
			accion_en_progreso = true
		EstadoNPC.WAITING:
			accion_en_progreso = false
		EstadoNPC.LOOKING:
			accion_en_progreso = false
		EstadoNPC.INTERACTING:
			accion_en_progreso = true
			no_mover = true
		EstadoNPC.SCRIPTED_ACTION:
			accion_en_progreso = true
			no_mover = true
		EstadoNPC.DISABLED:
			accion_en_progreso = false
			no_mover = true
			if animated_sprite:
				animated_sprite.visible = false
			if _disfraz != null:
				_disfraz.visible = false

## Métodos de salida de estados
func salir_estado(estado: EstadoNPC) -> void:
	match estado:
		EstadoNPC.INTERACTING:
			no_mover = false
			if _mirada_fija_encuentro:
				_mirada_fija_encuentro = false
				_frames_gracia_mirada = FRAMES_GRACIA_MIRADA
		EstadoNPC.SCRIPTED_ACTION:
			no_mover = false
		EstadoNPC.DISABLED:
			no_mover = false
			# INVISIBLE, OCULTO y el disfraz siguen sin mostrar el sprite.
			if animated_sprite:
				animated_sprite.visible = Engine.is_editor_hint() or sprite_visible_por_tipo()
			if _disfraz != null:
				_disfraz.visible = true

# Procesamiento de cada estado específico
func procesar_estado_idle(_delta: float) -> void:
	# En IDLE, el NPC puede decidir qué hacer según su tipo de movimiento
	pass

func procesar_estado_moving(_delta: float) -> void:
	# Movimiento manual controlado aquí (reemplaza tween)
	if not paso_en_curso:
		return

	if duracion_paso <= 0:
		duracion_paso = 0.01

	progreso_paso += _delta / duracion_paso
	if progreso_paso > 1.0:
		progreso_paso = 1.0

	# Interpolación lineal de la posición
	position = origen_paso.lerp(destino_paso, progreso_paso)

	# Calcular píxeles avanzados para decidir frame (siempre eje principal)
	var desplazamiento_vector = position - origen_paso
	var pixeles_avanzados = abs(desplazamiento_vector.x + desplazamiento_vector.y)  # porque solo una componente cambia
	_actualizar_frame_paso(pixeles_avanzados)
	_actualizar_shader_hierba_transicion(pixeles_avanzados)
	if _efectos_arena:
		_efectos_arena.actualizar_progreso(pixeles_avanzados)
	if _tierra_pies:
		_tierra_pies.actualizar_progreso(pixeles_avanzados)
		_tierra_pies.visible = _tierra_pies.sobre_bandera
	if _efectos_agua:
		_efectos_agua.actualizar_progreso(pixeles_avanzados)

	if progreso_paso >= 1.0:
		_finalizar_paso_manual()

func procesar_estado_waiting(_delta: float) -> void:
	# Estado de espera, no hace nada específico
	pass

func procesar_estado_looking(_delta: float) -> void:
	# Estado para cuando el NPC está mirando en direcciones
	pass

func procesar_estado_interacting(_delta: float) -> void:
	# Estado durante la interacción con el jugador
	pass

func procesar_estado_scripted_action(_delta: float) -> void:
	# Estado para acciones programadas específicas
	pass

func procesar_estado_disabled(_delta: float) -> void:
	# Estado deshabilitado, no hace nada
	pass

# Métodos públicos para controlar el estado del NPC
func deshabilitar_npc() -> void:
	cambiar_estado(EstadoNPC.DISABLED)

func habilitar_npc() -> void:
	cambiar_estado(EstadoNPC.IDLE)

func forzar_accion_programada() -> void:
	cambiar_estado(EstadoNPC.SCRIPTED_ACTION)

func esta_ocupado() -> bool:
	return estado_actual in [EstadoNPC.MOVING, EstadoNPC.INTERACTING, EstadoNPC.SCRIPTED_ACTION]

func puede_moverse() -> bool:
	return estado_actual in [EstadoNPC.IDLE, EstadoNPC.LOOKING]

func obtener_estado_actual() -> EstadoNPC:
	return estado_actual

func obtener_tiempo_en_estado() -> float:
	return tiempo_en_estado

func evento_accion() -> void:
	_loggear("evento accion")

	# Si el NPC está en movimiento, marcar interrupción pendiente y congelar al jugador
	if estado_actual == EstadoNPC.MOVING:
		_loggear("NPC en movimiento, marcando interrupción pendiente")
		interrupcion_pendiente = true
		# Congelar al jugador ahora que vamos a interactuar
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(true)
		return

	_procesar_interaccion()

## Mensajes estándar de un objeto ya entregado (pokeemerald EventScript_ObtainItemMessage):
## "¡Obtuvo X!" se escribe a la par de la fanfarria y avanza solo cuando terminan
## ambos (waitfanfare); el del bolsillo espera el botón. Continúa en el cuadro
## del llamador y lo deja abierto: cerrarlo le corresponde al llamador.
func mostrar_objeto_recibido(objeto_id: String) -> void:
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		return
	var datos_objeto: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto_id)
	var nombre_objeto: String = str(datos_objeto.get("nombre", objeto_id))
	var nombre_bolsillo: String = str(datos_objeto.get("bolsillo_nombre", "")).to_upper()
	var mensaje_obtenido: String = tr("OBJETO_OBTENIDO").replace("{key}", nombre_objeto)
	_texto_objeto_listo = false
	continuar_dialogo(mensaje_obtenido, false, _marcar_texto_objeto_listo)
	await reproducir_fanfarria(_fanfarria_de_objeto(datos_objeto))
	if not _texto_objeto_listo:
		await _dialogo_objeto_recibido_terminado
	var mensaje_guardado: String = tr("OBJETO_GUARDADO")
	mensaje_guardado = mensaje_guardado.replace("{key}", nombre_objeto)
	mensaje_guardado = mensaje_guardado.replace("{bname}", nombre_bolsillo)
	continuar_dialogo(mensaje_guardado, true, _dialogo_objeto_recibido_terminado.emit)
	await _dialogo_objeto_recibido_terminado


## fanfarria_objeto, salvo con el valor por defecto: entonces la del bolsillo
## del objeto (MT/MO → OBTENIDA_UNA_MT).
func _fanfarria_de_objeto(datos_objeto: Dictionary) -> String:
	if fanfarria_objeto != Fanfarria.TEMA_OBJETO:
		return fanfarria_objeto
	return Fanfarria.tema_objeto_obtenido(int(datos_objeto.get("bolsillo_id", -1)))


func _marcar_texto_objeto_listo() -> void:
	_texto_objeto_listo = true
	_dialogo_objeto_recibido_terminado.emit()


## Escribe en el cuadro de diálogo sin cerrarlo al terminar, para encadenar
## mensajes en el mismo cuadro como un msgbox de Gen 3. Si ya estaba abierto es
## una continuación: el clic sonó al avanzar el mensaje anterior y no se repite.
func continuar_dialogo(texto: String, esperar_entrada: bool, callback: Callable) -> void:
	var cuadro = nodo_administrador.cuadro_dialogo
	cuadro.mostrar(texto, esperar_entrada, false, callback, false, cuadro.esta_activo)


## Toca una fanfarria interrumpiendo la música del mapa (playfanfare +
## waitfanfare). Ver Fanfarria.reproducir(). Devuelve false si el tema no pudo
## cargarse.
func reproducir_fanfarria(tema: String, esperar_subida: bool = false) -> bool:
	return await Fanfarria.reproducir(self, tema, esperar_subida)

## Procesa la interacción inmediata (cuando el NPC está parado) o pendiente (al terminar paso)
func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	cambiar_estado(EstadoNPC.INTERACTING)
	# SIN_MOVIMIENTO nunca gira, ni siquiera al hablarle.
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()

	# Protección para evitar error si no hay texto asignado
	if id_texto == null or id_texto.is_empty():
		_loggear("No hay diálogo asignado (id_texto está vacío).")
		# Descongelar al jugador ahora que no vamos a interactuar
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
	else:
		# Asegurar que el administrador exista antes de usarlo (puede no estar disponible en editor)
		if nodo_administrador:
			# Liberar controles; las miradas fijas conservan la dirección de conversación.
			var callback_cierre = func() -> void:
				var continuacion := callback_dialogo
				callback_dialogo = Callable()
				if jugador and jugador.has_method("esperar_dialogo"):
					jugador.esperar_dialogo(false)
				_loggear("Diálogo cerrado: controles liberados")
				if continuacion.is_valid():
					# El encuentro sigue (p. ej. el combate del entrenador): sin
					# volver a la dirección de reposo, mirando al jugador.
					_mirada_fija_encuentro = true
					continuacion.call_deferred()
				else:
					_volver_a_direccion_base()
					cambiar_estado(EstadoNPC.IDLE)
			nodo_administrador.cuadro_dialogo.mostrar(tr(_consumir_id_texto()), true, true, callback_cierre)
		else:
			_loggear("Advertencia: AdministradorMapa no disponible al invocar evento_accion")
			# Descongelar al jugador ahora que no vamos a interactuar
			if jugador and jugador.has_method("esperar_dialogo"):
				jugador.esperar_dialogo(false)
			cambiar_estado(EstadoNPC.IDLE)

## Clave del mensaje a mostrar ahora; si toca el de la primera vez, activa su bandera.
func _consumir_id_texto() -> String:
	if bandera_primera_vez.is_empty() or id_texto_primera_vez.is_empty() or SistemaGuardado.get_flag(bandera_primera_vez):
		return id_texto
	SistemaGuardado.set_flag(bandera_primera_vez, true)
	return id_texto_primera_vez

const TEXTURA_EXCLAMACION: Texture2D = preload("res://graficos/signo_exclamacion.png")
const TEXTURA_INTERROGACION: Texture2D = preload("res://graficos/signo_interrogacion.png")
## z_index relativo al NPC: el "!" queda por encima de capas superiores, sprites y reflejos.
const Z_INDEX_EXCLAMACION: int = 20

## "!" sobre el NPC (Common_Movement_ExclamationMark): aparece, rebota y se va.
## Lo usan la visión de npc_entrenador y los eventos guionizados.
func mostrar_exclamacion() -> void:
	await _mostrar_signo(TEXTURA_EXCLAMACION)


## emote_question_mark.
func mostrar_interrogacion() -> void:
	await _mostrar_signo(TEXTURA_INTERROGACION)


func _mostrar_signo(textura: Texture2D) -> void:
	var signo := Sprite2D.new()
	signo.texture = textura
	signo.z_index = Z_INDEX_EXCLAMACION
	# Sobre la coronilla: -35 / -45 / -30 con el sprite estándar de 16×22.
	var y_base: float = OFFSETS_TAMANO_SPRITE[tamano_sprite].y - SEPARACION_EXCLAMACION
	signo.position = Vector2(0, y_base)
	add_child(signo)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(signo, "position", Vector2(0, y_base - 10.0), 0.1)
	tween.tween_property(signo, "position", Vector2(0, y_base + 5.0), 0.2)
	tween.tween_interval(0.8)
	await tween.finished
	signo.queue_free()

func update_animation(input_dir: Vector2):
	moving = true
	var anima = "camina_" + get_nombre_dir(input_dir) + "_" + str(step_count % 2 + 1)
	animated_sprite.play(anima)
	step_count = (step_count + 1) % 2

## Gira hacia el jugador si este mira en dirección opuesta.
## El flujo base omite esta llamada para SIN_MOVIMIENTO; los NPCs con lógica
## propia (enfermera, vendedor) la invocan explícitamente y siguen girando.
func mirar_jugador() -> void:
	if jugador == null:
		return
	if jugador.facing_direction in direcciones_opuestas:
		update_direction(direcciones_opuestas[jugador.facing_direction])

## Actualiza la animación según la dirección de frente y se detiene porque solo está rotando el npc, no caminando.
func update_direction(input_dir: Vector2):
	facing_direction = input_dir
	var anima = "camina_" + get_nombre_dir(input_dir) + "_" + str(step_count % 2 + 1)
	animated_sprite.play(anima)
	animated_sprite.stop()
	animated_sprite.frame = 0
	step_count = (step_count + 1) % 2

## Devuelve al NPC a su dirección de reposo tras una interacción.
## Solo aplica a las miradas que alternan direcciones. Los cuatro FACE_* de Ruby
## conservan facing_direction hasta reinicializarse, también tras una conversación.
## SIN_MOVIMIENTO no gira y los ROTACION_* retoman su secuencia por temporizador.
func _volver_a_direccion_base() -> void:
	match tipo_movimiento:
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA, TipoMovimientoNPC.MIRAR_IZQUIERDA_DERECHA, \
		TipoMovimientoNPC.MIRAR_IZQUIERDA_ARRIBA, TipoMovimientoNPC.MIRAR_ARRIBA_DERECHA, \
		TipoMovimientoNPC.MIRAR_DERECHA_ABAJO, TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA, \
		TipoMovimientoNPC.MIRAR_ARRIBA_IZQUIERDA_DERECHA, TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA_DERECHA, \
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_IZQUIERDA, TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_DERECHA:
			update_direction(direccion_base)

func _iniciar_temporizador() -> void:
	var intervalo = 1.5
	match tipo_movimiento:
		TipoMovimientoNPC.SIN_MOVIMIENTO: intervalo = 2.5
		TipoMovimientoNPC.MIRAR_ALREDEDOR: intervalo = randf_range(0.8, 1.6)
		TipoMovimientoNPC.PASEAR_RANGO: intervalo = randf_range(0.9, 1.4)
		TipoMovimientoNPC.PASEAR_ARRIBA_ABAJO, TipoMovimientoNPC.PASEAR_ABAJO_ARRIBA, TipoMovimientoNPC.PASEAR_IZQUIERDA_DERECHA, TipoMovimientoNPC.PASEAR_DERECHA_IZQUIERDA: intervalo = 0.9
		TipoMovimientoNPC.CAMINAR_ARRIBA_ABAJO, TipoMovimientoNPC.CAMINAR_ABAJO_ARRIBA, TipoMovimientoNPC.CAMINAR_IZQUIERDA_DERECHA, TipoMovimientoNPC.CAMINAR_DERECHA_IZQUIERDA: intervalo = 0.03
		_:
			# Las secuencias de caminata no esperan entre pasos (MovementType_WalkSequence).
			intervalo = 0.03 if SECUENCIAS_CAMINATA.has(tipo_movimiento) else randf_range(1.0, 2.0)
	# Programar siguiente evento usando timestamps en _process
	tiempo_hasta_proximo_evento = intervalo

## ¿Puede este NPC iniciar una acción nueva ahora mismo?
## Regla central: no iniciar acciones si el juego está pausado (menú, batalla,
## diálogo, transición...), ni en estados que requieren espera.
## Delega en AdministradorMapa.puede_actuar_npc() para no duplicar condiciones.
## Mapa activo: todos los mapas del overworld están instanciados a la vez y los
## vecinos visibles en pantalla no son el mapa activo (ver es_mapa_activo). Sus NPC
## se quedan quietos: no inician acciones autónomas (pasear, girar, paso en sitio,
## copiar al jugador) salvo que tengan procesar_fuera_del_mapa_activo. Esta es la
## única puerta de las acciones autónomas (_on_tiempo_evento, _procesar_paso_en_sitio
## y _puede_copiar_jugador). NO afecta a lo que ya está en marcha ni a lo que manda
## un guion: inicialización (_ready, banderas de ocultar, _on_mapa_activado), pasos
## o saltos ya iniciados y estados MOVING / SCRIPTED_ACTION / INTERACTING,
## mover_npc(forzado), seguir_a y la sincronización de victoria del entrenador.
## Tras un encuentro (FRAMES_GRACIA_MIRADA) tampoco: sigue mirando al jugador.
func puede_iniciar_acciones() -> bool:
	if estado_actual in [EstadoNPC.INTERACTING, EstadoNPC.SCRIPTED_ACTION, EstadoNPC.DISABLED]:
		return false
	if _frames_gracia_mirada > 0:
		return false
	if nodo_administrador != null and not nodo_administrador.puede_actuar_npc():
		return false
	return procesar_fuera_del_mapa_activo or es_mapa_activo()

## Límites (mínimo, máximo) del eje de un CAMINAR_* de ida y vuelta.
## pokeruby MovementType_WalkBackAndForth: camina `rango` casillas hacia su
## dirección inicial y, al volver, se gira en la celda de origen; el rango no
## se extiende hacia el lado contrario.
func limites_ida_vuelta() -> Vector2i:
	var origen := rango_ini + rango
	match tipo_movimiento:
		TipoMovimientoNPC.CAMINAR_ARRIBA_ABAJO:
			return Vector2i(origen.y - rango.y, origen.y)
		TipoMovimientoNPC.CAMINAR_ABAJO_ARRIBA:
			return Vector2i(origen.y, origen.y + rango.y)
		TipoMovimientoNPC.CAMINAR_IZQUIERDA_DERECHA:
			return Vector2i(origen.x - rango.x, origen.x)
		TipoMovimientoNPC.CAMINAR_DERECHA_IZQUIERDA:
			return Vector2i(origen.x, origen.x + rango.x)
	return Vector2i(rango_ini.x, rango_fin.x)

## Evento de temporizador
func _on_tiempo_evento() -> void:
	_iniciar_temporizador()

	if not puede_iniciar_acciones():
		return

	# Manejar tipos de movimiento específicos
	match tipo_movimiento:
		TipoMovimientoNPC.CAMINAR_ARRIBA_ABAJO, TipoMovimientoNPC.CAMINAR_ABAJO_ARRIBA:
			if estado_actual == EstadoNPC.IDLE:
				var limites_y := limites_ida_vuelta()
				if current_walk_direction == Vector2.UP:
					_loggear("Caminando hacia arriba %s %s" % [coord_celda, limites_y])
					if coord_celda.y > limites_y.x:
						mover_npc(current_walk_direction)
					else:
						current_walk_direction = Vector2.DOWN
						mirar(current_walk_direction)
				elif current_walk_direction == Vector2.DOWN:
					_loggear("Caminando hacia abajo %s %s" % [coord_celda, limites_y])
					if coord_celda.y < limites_y.y:
						mover_npc(current_walk_direction)
					else:
						current_walk_direction = Vector2.UP
						mirar(current_walk_direction)
			return

		TipoMovimientoNPC.CAMINAR_IZQUIERDA_DERECHA, TipoMovimientoNPC.CAMINAR_DERECHA_IZQUIERDA:
			if estado_actual == EstadoNPC.IDLE:
				var limites_x := limites_ida_vuelta()
				if current_walk_direction == Vector2.LEFT:
					_loggear("Caminando hacia la izquierda %s %s" % [coord_celda, limites_x])
					if coord_celda.x > limites_x.x:
						mover_npc(current_walk_direction)
					else:
						current_walk_direction = Vector2.RIGHT
						mirar(current_walk_direction)
				elif current_walk_direction == Vector2.RIGHT:
					_loggear("Caminando hacia la derecha %s %s" % [coord_celda, limites_x])
					if coord_celda.x < limites_x.y:
						mover_npc(current_walk_direction)
					else:
						current_walk_direction = Vector2.LEFT
						mirar(current_walk_direction)
			return

		# Tipos de movimiento PASEAR con comportamiento probabilístico
		TipoMovimientoNPC.PASEAR_ARRIBA_ABAJO, TipoMovimientoNPC.PASEAR_ABAJO_ARRIBA:
			if estado_actual == EstadoNPC.IDLE:
				var accion = randf()
				if accion < 0.4:  # 40% probabilidad de no hacer nada
					pass
				elif accion < 0.7:  # 30% probabilidad de mirar
					var direcciones = [Vector2.UP, Vector2.DOWN]
					mirar(direcciones[randi() % direcciones.size()])
				else:  # 30% probabilidad de moverse
					_dar_paso_aleatorio_en_rango([Vector2.UP, Vector2.DOWN])
			return

		TipoMovimientoNPC.PASEAR_IZQUIERDA_DERECHA, TipoMovimientoNPC.PASEAR_DERECHA_IZQUIERDA:
			if estado_actual == EstadoNPC.IDLE:
				var accion = randf()
				if accion < 0.4:  # 40% probabilidad de no hacer nada
					pass
				elif accion < 0.7:  # 30% probabilidad de mirar
					var direcciones = [Vector2.LEFT, Vector2.RIGHT]
					mirar(direcciones[randi() % direcciones.size()])
				else:  # 30% probabilidad de moverse
					_dar_paso_aleatorio_en_rango([Vector2.LEFT, Vector2.RIGHT])
			return

		TipoMovimientoNPC.PASEAR_RANGO:
			if estado_actual == EstadoNPC.IDLE:
				var accion = randf()
				if accion < 0.3:  # 30% probabilidad de no hacer nada
					pass
				elif accion < 0.6:  # 30% probabilidad de mirar
					var direcciones = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
					mirar(direcciones[randi() % direcciones.size()])
				else:  # 40% probabilidad de moverse
					_dar_paso_aleatorio_en_rango([Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT])
			return

		TipoMovimientoNPC.MIRAR_ALREDEDOR:
			if estado_actual == EstadoNPC.IDLE:
				var prob_cambio_direc = randf()
				if prob_cambio_direc < 0.4:
					cambiar_estado(EstadoNPC.LOOKING)
					if prob_cambio_direc >= 0 and prob_cambio_direc < 0.1:
						mirar(Vector2.UP)
					elif prob_cambio_direc < 0.2:
						mirar(Vector2.DOWN)
					elif prob_cambio_direc < 0.3:
						mirar(Vector2.RIGHT)
					else:
						mirar(Vector2.LEFT)
					# Volver a IDLE después de mirar, salvo que entretanto haya empezado
					# otra cosa (un paso de seguimiento, una interacción...).
					await get_tree().create_timer(0.3).timeout
					if estado_actual == EstadoNPC.LOOKING:
						cambiar_estado(EstadoNPC.IDLE)

		# FACE_* no tienen giros periódicos: conservan la última dirección.
		TipoMovimientoNPC.MIRAR_ARRIBA, TipoMovimientoNPC.MIRAR_ABAJO, \
		TipoMovimientoNPC.MIRAR_IZQUIERDA, TipoMovimientoNPC.MIRAR_DERECHA:
			return

		# Las miradas de varias direcciones sí alternan por temporizador.
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA, TipoMovimientoNPC.MIRAR_IZQUIERDA_DERECHA, \
		TipoMovimientoNPC.MIRAR_IZQUIERDA_ARRIBA, TipoMovimientoNPC.MIRAR_ARRIBA_DERECHA, \
		TipoMovimientoNPC.MIRAR_DERECHA_ABAJO, TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA, \
		TipoMovimientoNPC.MIRAR_ARRIBA_IZQUIERDA_DERECHA, TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA_DERECHA, \
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_IZQUIERDA, TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_DERECHA:
			if estado_actual == EstadoNPC.IDLE:
				var elegida := _elegir_direccion_mirar()
				if elegida != Vector2i.ZERO and Vector2(elegida) != facing_direction:
					mirar(elegida)
			return

		# ROTACION_*: avanza un paso de su secuencia en cada evento (ritmo 1.0–2.0 s).
		TipoMovimientoNPC.ROTACION_HORARIA, TipoMovimientoNPC.ROTACION_CONTRA_HORARIA:
			if estado_actual == EstadoNPC.IDLE:
				var secuencia := _secuencia_rotacion()
				_rotacion_indice = _indice_rotacion_para(facing_direction)
				if _rotacion_indice < 0:
					_rotacion_indice = 0
				else:
					_rotacion_indice = (_rotacion_indice + 1) % secuencia.size()
				var siguiente: Vector2i = secuencia[_rotacion_indice]
				mirar(siguiente)
			return

	if SECUENCIAS_CAMINATA.has(tipo_movimiento) and estado_actual == EstadoNPC.IDLE:
		_avanzar_secuencia_caminata()


func mirar(direc: Vector2i) -> void:
	if not _puede_mirar(direc):
		return

	var anima = ""
	if direc == Vector2i.DOWN:
		anima = "camina_abajo_" + str(step_count % 2 + 1)
	elif direc == Vector2i.UP:
		anima = "camina_arriba_" + str(step_count % 2 + 1)
	elif direc == Vector2i.RIGHT:
		anima = "camina_derecha_" + str(step_count % 2 + 1)
	elif direc == Vector2i.LEFT:
		anima = "camina_izquierda_" + str(step_count % 2 + 1)

	if anima != "":
		animated_sprite.play(anima)
		animated_sprite.stop()
		animated_sprite.frame = 0
	estado_actual = EstadoNPC.LOOKING
	# `direc` es Vector2i: se convierte para no romper el tipo de facing_direction.
	facing_direction = Vector2(direc)

func _puede_mirar(direc: Vector2i) -> bool:
	var direcciones_validas = {
		TipoMovimientoNPC.MIRAR_ALREDEDOR: true,
		TipoMovimientoNPC.MIRAR_ARRIBA: direc == Vector2i.UP,
		TipoMovimientoNPC.MIRAR_ABAJO: direc == Vector2i.DOWN,
		TipoMovimientoNPC.MIRAR_IZQUIERDA: direc == Vector2i.LEFT,
		TipoMovimientoNPC.MIRAR_DERECHA: direc == Vector2i.RIGHT,
		TipoMovimientoNPC.MIRAR_ARRIBA_DERECHA: direc == Vector2i.UP or direc == Vector2i.RIGHT,
		TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA: direc == Vector2i.DOWN or direc == Vector2i.LEFT,
		TipoMovimientoNPC.MIRAR_IZQUIERDA_DERECHA: direc == Vector2i.LEFT or direc == Vector2i.RIGHT,
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA: direc == Vector2i.DOWN or direc == Vector2i.UP,
		TipoMovimientoNPC.MIRAR_DERECHA_ABAJO: direc == Vector2i.RIGHT or direc == Vector2i.DOWN,
		TipoMovimientoNPC.MIRAR_IZQUIERDA_ARRIBA: direc == Vector2i.LEFT or direc == Vector2i.UP,
		TipoMovimientoNPC.MIRAR_ARRIBA_IZQUIERDA_DERECHA: direc != Vector2i.DOWN,
		TipoMovimientoNPC.MIRAR_ABAJO_IZQUIERDA_DERECHA: direc != Vector2i.UP,
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_IZQUIERDA: direc != Vector2i.RIGHT,
		TipoMovimientoNPC.MIRAR_ABAJO_ARRIBA_DERECHA: direc != Vector2i.LEFT,
	}
	return direcciones_validas.get(tipo_movimiento, true)

## Direcciones permitidas para el tipo actual (los MIRAR_* admiten una o dos).
func _direcciones_mirar_validas() -> Array:
	var validas: Array = []
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _puede_mirar(d):
			validas.append(d)
	return validas

## Elige al azar una dirección permitida, o Vector2i.ZERO si no hay ninguna.
func _elegir_direccion_mirar() -> Vector2i:
	if DIRECCIONES_MIRAR_TRES.has(tipo_movimiento):
		var sorteo: Array = DIRECCIONES_MIRAR_TRES[tipo_movimiento]
		return sorteo[randi() % sorteo.size()]
	var validas := _direcciones_mirar_validas()
	if validas.is_empty():
		return Vector2i.ZERO
	var elegida: Vector2i = validas[randi() % validas.size()]
	return elegida

## Secuencia de giro correspondiente al tipo de rotación actual.
func _secuencia_rotacion() -> Array:
	if tipo_movimiento == TipoMovimientoNPC.ROTACION_HORARIA:
		return ROTACION_HORARIA_SECUENCIA
	return ROTACION_CONTRA_SECUENCIA

## Índice de `dir` dentro de la secuencia de rotación; -1 si no pertenece.
func _indice_rotacion_para(dir: Vector2) -> int:
	var secuencia := _secuencia_rotacion()
	for i in secuencia.size():
		var d: Vector2i = secuencia[i]
		if Vector2(d) == dir:
			return i
	return -1

## Mueve el NPC un tile completo en la dirección especificada
## `forzado`: paso de guion (applymovement de Gen 3), que no comprueba si la celda
## está ocupada por el jugador u otro NPC. Los bordes siguen haciendo el salto.
## `mirada`: si no es cero, el NPC camina hacia `direccion` sin dejar de mirar a
## `mirada` (lock_facing_direction + walk_*: paso hacia atrás o de lado).
func mover_npc(direccion: Vector2, forzado: bool = false, mirada: Vector2 = Vector2.ZERO) -> void:
	if estado_actual == EstadoNPC.MOVING or estado_actual == EstadoNPC.DISABLED:
		return

	var celda_origen := coord_celda
	var celda_destino := celda_origen + Vector2i(direccion)
	var celda_destino_real := celda_destino
	var salto_borde := false
	var tp := _obtener_tp_capa_propia()
	var borde_dir := _obtener_flag_borde_direccional(direccion)
	if tp != null and borde_dir != 0:
		var celda_destino_vec := Vector2(celda_destino)
		const MASK_BORDES := TPTileDataMap.Flags.BORDE_ABAJO | TPTileDataMap.Flags.BORDE_ARRIBA | \
			TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA
		if tp.get_flags(celda_destino_vec) & MASK_BORDES:
			if not tp.has_flag(celda_destino_vec, borde_dir):
				_loggear("Borde direccional bloquea el paso hacia %s" % celda_destino)
				return
			salto_borde = true
			celda_destino_real = celda_destino + Vector2i(direccion)

	if not forzado and not _celda_libre(celda_destino_real, direccion):
		_loggear("Celda destino ocupada, no se inicia movimiento: %s" % celda_destino_real)
		return

	_iniciar_paso(direccion, celda_destino_real, salto_borde, mirada)

## Arranque común de un paso (o salto de borde si `salto_borde`) ya validado:
## pasa a MOVING, reserva la celda de llegada en coord_celda y emite
## paso_iniciado. Lo usan mover_npc y el paso forzado de seguimiento.
## `mirada` (opcional): dirección que conserva el sprite durante el paso.
func _iniciar_paso(direccion: Vector2, celda_destino_real: Vector2i, salto_borde: bool, mirada: Vector2 = Vector2.ZERO) -> void:
	# LOOKING solo marca un giro de este frame y no admite pasar a MOVING.
	if estado_actual == EstadoNPC.LOOKING:
		cambiar_estado(EstadoNPC.IDLE)
	cambiar_estado(EstadoNPC.MOVING)
	# Sin MOVING nadie avanzaría el paso: no reservar la celda ni quedarse a medias.
	if estado_actual != EstadoNPC.MOVING:
		return

	var celda_salida := coord_celda
	var tp := _obtener_tp_capa_propia()
	facing_direction = mirada if mirada != Vector2.ZERO else direccion
	direccion_paso = direccion
	origen_paso = position
	destino_paso = position + direccion * TILE_SIZE

	var aplica_recorte_hierba_muy_alta := _evaluar_transicion_hierba(celda_salida, celda_destino_real, direccion)
	coord_celda = celda_destino_real
	_elevar_si_destino_elevado(celda_destino_real)
	paso_iniciado.emit(celda_salida, celda_destino_real)

	if salto_borde:
		paso_en_curso = false
		if _efectos_arena:
			_efectos_arena.ocultar()
		_ocultar_tierra_pies()
		realizar_salto_parabolico(direccion, celda_salida, celda_destino_real)
		return

	# Huella en el tile que se abandona; los NPCs ocultos no dejan rastro.
	if _efectos_arena:
		if is_visible_in_tree():
			_efectos_arena.iniciar_paso(tp, _obtener_mapa_propio(), celda_salida, celda_destino_real, direccion, false)
		else:
			_efectos_arena.ocultar()
	if _tierra_pies:
		if is_visible_in_tree():
			_tierra_pies.iniciar_paso(tp, celda_salida, celda_destino_real)
			_tierra_pies.visible = _tierra_pies.sobre_bandera
		else:
			_ocultar_tierra_pies()

	_aplicar_efecto_hierba_muy_alta(aplica_recorte_hierba_muy_alta)
	# Agua termal: solo tapa el cuerpo si la celda de salida y la de destino son termales.
	if _sumersion_termal:
		_sumersion_termal.iniciar_paso(tp, celda_salida, celda_destino_real)
	if _celda_tiene_hierba_mas_alta(Vector2(celda_destino_real)):
		_reproducir_animacion_hierba_muy_alta(celda_destino_real)
	elif _celda_tiene_hierba_alta(Vector2(celda_destino_real)):
		_spawn_animacion_pasto(celda_destino_real)

	progreso_paso = 0.0
	paso_en_curso = true

	# Inicializar animación en frame 0
	alterna_animacion = 1 if alterna_animacion == 2 else 2
	_inicializar_animacion_paso(facing_direction)

	# Salpicadura al iniciar paso; el charco (AGUA_PIES) dura mientras se pisa
	if _efectos_agua:
		_efectos_agua.iniciar_paso(Vector2(celda_salida), Vector2(celda_destino_real))

## Finaliza el movimiento del NPC y actualiza su estado

func _finalizar_paso_manual() -> void:
	paso_en_curso = false
	moving = false
	_sincronizar_elevacion_punto()
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0
	actualizar_efecto_terreno_actual()
	_intentar_burbujas_alga()

	if _celda_tiene_agua_salpica(Vector2(coord_celda)):
		_efectos_agua.disparar_salpicadura()

	# Comprobar si hay una interrupción pendiente antes de volver a IDLE
	if interrupcion_pendiente:
		_loggear("Procesando interrupción pendiente al finalizar paso")
		_procesar_interaccion()
		return

	# Volver a IDLE después del movimiento
	cambiar_estado(EstadoNPC.IDLE)
	_intentar_onda_agua()
	_procesar_cola_seguimiento()

# --- NUEVAS FUNCIONES PARA MOVIMIENTO MANUAL ---

## Se llama en cada paso: onda en la celda actual si es AGUA_SALPICA a ras de
## agua (EfectosAgua; sin capa de datos o sin mapa ancestro no hay ondas).
func _intentar_onda_agua() -> void:
	if _efectos_agua:
		_efectos_agua.intentar_ondas(Vector2(coord_celda), global_position)

## Inicializa la animación de paso en la dirección dada, la animación es la misma durante el paso, solo cambia el frame.
func _inicializar_animacion_paso(dir: Vector2) -> void:
	if not animated_sprite:
		return
	var base = _obtener_nombre_animacion_base(dir)
	if base == "":
		return
	var nombre_anim = base + "_" + str(alterna_animacion)
	if animated_sprite.animation != nombre_anim:
		animated_sprite.play(nombre_anim)
		animated_sprite.stop()
	animated_sprite.frame = 0

## Actualiza el frame de la animación según los píxeles avanzados
func _actualizar_frame_paso(pixeles: float) -> void:
	if not animated_sprite:
		return
	var numero_frame = 0
	if pixeles >= 4 and pixeles < 12:
		numero_frame = 1
	else:
		numero_frame = 0
	animated_sprite.frame = numero_frame

func _obtener_nombre_animacion_base(dir: Vector2) -> String:
	if dir == Vector2.UP:
		return "camina_arriba"
	elif dir == Vector2.DOWN:
		return "camina_abajo"
	elif dir == Vector2.LEFT:
		return "camina_izquierda"
	elif dir == Vector2.RIGHT:
		return "camina_derecha"
	return ""

func _actualizar_animacion_salto_parabolico(dir: Vector2, pixeles_salto: float, alterna_paso_1: int, alterna_paso_2: int) -> void:
	if not animated_sprite:
		return
	var base := _obtener_nombre_animacion_base(dir)
	if base == "":
		return
	var pixeles_totales := clampf(pixeles_salto, 0.0, float(TILE_SIZE * 2))
	var alterna_tramo := alterna_paso_1
	var pixeles_tramo := pixeles_totales
	if pixeles_totales >= float(TILE_SIZE):
		alterna_tramo = alterna_paso_2
		pixeles_tramo -= float(TILE_SIZE)
	alterna_animacion = alterna_tramo
	var numero_frame := 1 if pixeles_tramo >= 4.0 and pixeles_tramo < 12.0 else 0
	var nombre_anim := base + "_" + str(alterna_tramo)
	if animated_sprite.animation != nombre_anim:
		animated_sprite.play(nombre_anim)
		animated_sprite.stop()
	animated_sprite.frame = numero_frame

func realizar_salto_parabolico(dir: Vector2, _celda_origen: Vector2i, celda_aterrizaje: Vector2i) -> void:
	var tiempo: float = 0.0
	var posicion_inicial := position
	var posicion_final := position + dir * TILE_SIZE * 2
	var alterna_paso_1 := alterna_animacion
	var alterna_paso_2 := 1 if alterna_paso_1 == 2 else 2
	var aterriza_en_hierba_muy_alta := _celda_tiene_hierba_mas_alta(Vector2(celda_aterrizaje))
	var transicion_entrada_hierba := TransicionHierba.NINGUNA
	var efecto_hierba_salto_iniciado := false
	var animacion_hierba_muy_alta_reproducida := false
	var offset_inicial := Vector2.ZERO
	if animated_sprite:
		offset_inicial = animated_sprite.offset
	if sombra:
		sombra.visible = true
	_id_salto += 1
	var id_salto := _id_salto
	_salto_en_curso = true
	_posicion_final_salto = posicion_final
	_offset_sprite_salto = offset_inicial

	if aterriza_en_hierba_muy_alta:
		match dir:
			Vector2.UP:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_ARRIBA
			Vector2.DOWN:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_ABAJO
			Vector2.LEFT:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_IZQUIERDA
			Vector2.RIGHT:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_DERECHA

	while tiempo < duracion_salto:
		tiempo += get_process_delta_time()
		var t := tiempo / duracion_salto
		var pixeles_salto := clampf(t * float(TILE_SIZE * 2), 0.0, float(TILE_SIZE * 2))
		var y_offset := float(altura_salto_en_progreso(t))  # Tabla del decomp
		position.x = lerp(posicion_inicial.x, posicion_final.x, t)
		position.y = lerp(posicion_inicial.y, posicion_final.y, t)
		_actualizar_animacion_salto_parabolico(dir, pixeles_salto, alterna_paso_1, alterna_paso_2)
		if aterriza_en_hierba_muy_alta:
			var pixeles_en_celda_aterrizaje := clampf(pixeles_salto - float(TILE_SIZE), 0.0, float(TILE_SIZE))
			if pixeles_en_celda_aterrizaje > 8.0:
				if not efecto_hierba_salto_iniciado:
					transicion_hierba_activa = transicion_entrada_hierba
					_aplicar_efecto_hierba_muy_alta(true)
					efecto_hierba_salto_iniciado = true
				if not animacion_hierba_muy_alta_reproducida:
					_reproducir_animacion_hierba_muy_alta(celda_aterrizaje)
					animacion_hierba_muy_alta_reproducida = true
				_actualizar_shader_hierba_transicion(pixeles_en_celda_aterrizaje)
		if animated_sprite:
			animated_sprite.offset.y = offset_inicial.y + y_offset
		await get_tree().create_timer(get_process_delta_time()).timeout
		# Terminado de golpe por _completar_paso_en_curso (seguimiento).
		if id_salto != _id_salto:
			return

	_salto_en_curso = false
	position = posicion_final
	alterna_animacion = alterna_paso_2
	if animated_sprite:
		animated_sprite.offset = offset_inicial
		animated_sprite.stop()
		animated_sprite.frame = 0
	if sombra:
		sombra.visible = false
	transicion_hierba_activa = TransicionHierba.ACTIVA if aterriza_en_hierba_muy_alta else TransicionHierba.NINGUNA
	_sincronizar_elevacion_punto()
	actualizar_efecto_terreno_actual()
	levanta_polvo(celda_aterrizaje, animacion_hierba_muy_alta_reproducida)
	if interrupcion_pendiente:
		_procesar_interaccion()
	else:
		cambiar_estado(EstadoNPC.IDLE)
		_procesar_cola_seguimiento()

func levanta_polvo(celda_efecto: Vector2i, omitir_hierba_muy_alta: bool = false) -> void:
	var animacion: Node = null
	if not omitir_hierba_muy_alta and _celda_tiene_hierba_mas_alta(Vector2(celda_efecto)):
		_reproducir_animacion_hierba_muy_alta(celda_efecto)
	elif _celda_tiene_hierba_alta(Vector2(celda_efecto)):
		_spawn_animacion_pasto(celda_efecto)
	else:
		animacion = Singleton.animacion_polvo.instantiate()
		animacion.position = position + Vector2(0, -4)
		add_child(animacion)


## Devuelve el TPTileDataMap de la capa propia de este NPC.
## Sube por el árbol hasta encontrar MapaConfiguracion para no depender de Singleton.
## Si capa_datos == -1 usa la capa activa del Singleton como fallback.
func _obtener_tp_capa_propia() -> TPTileDataMap:
	var mapa := _obtener_mapa_propio()
	if mapa == null:
		return null
	var capa_id: int = capa_datos if capa_datos >= 0 else _capa_activa_singleton()
	return mapa.get_capa_resuelta(capa_id)

## Primer MapaConfiguracion ancestro del NPC, o null.
## Usa _mapa_propio_cache mientras siga vivo y siga siendo ancestro (el padre del
## NPC solo cambia con reparent/add_child, que la invalidan). Un null no se cachea:
## un NPC aún sin mapa lo busca de nuevo en cada llamada.
func _obtener_mapa_propio() -> MapaConfiguracion:
	# Se lee la caché directamente en is_instance_valid: copiarla antes a una
	# variable tipada fallaría si el mapa fue liberado.
	if is_instance_valid(_mapa_propio_cache) and _mapa_propio_cache.is_ancestor_of(self):
		return _mapa_propio_cache
	_mapa_propio_cache = null
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			_mapa_propio_cache = nodo as MapaConfiguracion
			return _mapa_propio_cache
		nodo = nodo.get_parent()
	return null

## ¿Pertenece este NPC al mapa activo del AdministradorMapa?
## Todos los mapas exteriores del overworld están instanciados a la vez y sus
## celdas no comparten sistema: la del jugador (pos_celda_act, obtener_celda_destino)
## es local al mapa ACTIVO y coord_celda es local al mapa PROPIO del NPC. Comparar
## celdas de mapas distintos da falsos positivos (un entrenador de la Ruta 102
## "veía" al jugador desde Pueblo Escaso). Toda decisión que cruce celdas del
## jugador con las del NPC debe exigir esto, SIEMPRE: también cuando el NPC tiene
## procesar_fuera_del_mapa_activo (ese seteo solo permite que actúe, nunca que
## compare celdas locales de otro mapa).
## Regla de actividad: puede_iniciar_acciones() usa este mismo criterio, así que
## un NPC de un mapa que no es el activo no inicia acciones autónomas (ver allí
## qué sigue funcionando).
## En interiores el mapa activo es el propio interior, que contiene a sus NPC.
## Si no se puede determinar (sin administrador, NPC fuera de un MapaConfiguracion,
## mapa_actual nulo o liberado: dobles de test, editor) devuelve true para no bloquear.
func es_mapa_activo() -> bool:
	if not is_instance_valid(nodo_administrador):
		return true
	var activo: Variant = nodo_administrador.get("mapa_actual")
	# is_instance_valid también cubre null, un valor no Object y una instancia liberada.
	if not is_instance_valid(activo):
		return true
	var propio := _obtener_mapa_propio()
	if propio == null:
		return true
	return propio == activo

## Mismo filtro de capa que la interacción con A (administrador_mapa._nodo_en_celda):
## capa_datos -1 comparte cualquier capa; >=0 solo la capa activa del jugador. Un NPC
## sobre un puente (capa 1) no ve ni se bloquea con el jugador que pasa debajo (capa 0).
func _comparte_capa_con_jugador() -> bool:
	return capa_datos < 0 or capa_datos == _capa_activa_singleton()

## Capa de datos activa según el Singleton.
## En el editor el autoload no es utilizable: singleton.gd no es @tool, así que
## Godot solo tiene un placeholder para él y leer sus propiedades provoca
## "Invalid access to property or key". Se usa la capa 0 (la de por defecto)
## para que la previsualización del mapa en el editor funcione igual.
func _capa_activa_singleton() -> int:
	if Engine.is_editor_hint():
		return 0
	return Singleton.capa_activa

func obtener_tp_capa_actual() -> TPTileDataMap:
	return _obtener_tp_capa_propia()

func _inicializar_efecto_hierba_muy_alta() -> void:
	if not animated_sprite:
		return
	material_hierba_muy_alta = animated_sprite.material as ShaderMaterial
	if material_hierba_muy_alta != null:
		# El ShaderMaterial de npc_base.tscn es un sub_resource compartido por todas
		# las instancias: sin duplicarlo, el recorte de un NPC se aplica a todos.
		material_hierba_muy_alta = material_hierba_muy_alta.duplicate() as ShaderMaterial
		animated_sprite.material = material_hierba_muy_alta
	else:
		material_hierba_muy_alta = ShaderMaterial.new()
		material_hierba_muy_alta.shader = HIERBA_MUY_ALTA_SHADER
		animated_sprite.material = material_hierba_muy_alta
	material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
	material_hierba_muy_alta.set_shader_parameter("clip_local_y", 2.0)
	material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", -16.0)
	material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", 16.0)
	_sumersion_termal = SumersionTermal.new(material_hierba_muy_alta)

func actualizar_efecto_terreno_actual() -> void:
	var tiene_hierba_muy_alta := _celda_tiene_hierba_mas_alta(Vector2(coord_celda))
	transicion_hierba_activa = TransicionHierba.ACTIVA if tiene_hierba_muy_alta else TransicionHierba.NINGUNA
	_aplicar_efecto_hierba_muy_alta(tiene_hierba_muy_alta)
	if _sumersion_termal:
		_sumersion_termal.actualizar_reposo(_obtener_tp_capa_propia(), coord_celda)
	if _efectos_arena:
		_efectos_arena.actualizar_reposo(_obtener_tp_capa_propia(), coord_celda)
	if _tierra_pies:
		_tierra_pies.actualizar_reposo(_obtener_tp_capa_propia(), coord_celda)
		_tierra_pies.visible = _tierra_pies.sobre_bandera
	# Agua de los pies (AGUA_PIES): se repite mientras esté quieto sobre el charco.
	if _efectos_agua:
		_efectos_agua.actualizar_reposo(Vector2(coord_celda))

## Sin tierra en los pies (NPC oculto o en el aire durante un salto).
func _ocultar_tierra_pies() -> void:
	if _efectos_agua:
		_efectos_agua.ocultar()
	if _tierra_pies:
		_tierra_pies.ocultar()
		_tierra_pies.visible = false

## Salpicadura y ondas solo a ras de agua (EfectosAgua): sobre un puente (capa
## de datos >= 1 o celda con bandera PUENTE_*) nunca se disparan.
func _celda_tiene_agua_salpica(cell: Vector2) -> bool:
	return _efectos_agua != null and _efectos_agua.celda_tiene_agua_salpica(cell)

func _celda_tiene_hierba_alta(cell: Vector2) -> bool:
	var datos := _tp_de_celda(cell)
	return datos[0] != null and (datos[0] as TPTileDataMap).has_flag(datos[1], TPTileDataMap.Flags.HIERBA_ALTA)

func _celda_tiene_hierba_mas_alta(cell: Vector2) -> bool:
	var datos := _tp_de_celda(cell)
	return datos[0] != null and (datos[0] as TPTileDataMap).has_flag(datos[1], TPTileDataMap.Flags.HIERBA_MAS_ALTA)

## [TPTileDataMap, celda] con los que mirar `cell` (celda del mapa propio). Si cae
## fuera del mapa (un guion lleva al NPC al mapa vecino del Overworld, como a
## BLASCO a la RUTA 102), se mira en el vecino; el NPC sigue en su mapa.
func _tp_de_celda(cell: Vector2) -> Array:
	var tp := _obtener_tp_capa_propia()
	var mapa := _obtener_mapa_propio()
	if mapa == null or mapa.mapa_rect_px == Rect2() or mapa.mapa_rect_px.has_point(cell * TILE_SIZE) \
			or nodo_administrador == null or not nodo_administrador.has_method("encontrar_mapa_en_posicion_mundo"):
		return [tp, cell]
	var mundo: Vector2 = mapa.posicion_en_mundo() + cell * TILE_SIZE
	var vecino: MapaConfiguracion = nodo_administrador.encontrar_mapa_en_posicion_mundo(mundo)
	if vecino == null or vecino == mapa:
		return [tp, cell]
	var capa_id: int = capa_datos if capa_datos >= 0 else _capa_activa_singleton()
	return [vecino.get_capa_resuelta(capa_id), ((mundo - vecino.posicion_en_mundo()) / TILE_SIZE).floor()]

func _evaluar_transicion_hierba(celda_actual: Vector2i, celda_destino: Vector2i, direccion: Vector2) -> bool:
	var celda_act := _celda_tiene_hierba_mas_alta(Vector2(celda_actual))
	var celda_sig := _celda_tiene_hierba_mas_alta(Vector2(celda_destino))
	if not celda_act and celda_sig:
		match direccion:
			Vector2.UP:
				transicion_hierba_activa = TransicionHierba.ENTRADA_ARRIBA
			Vector2.DOWN:
				transicion_hierba_activa = TransicionHierba.ENTRADA_ABAJO
			Vector2.LEFT:
				transicion_hierba_activa = TransicionHierba.ENTRADA_IZQUIERDA
			Vector2.RIGHT:
				transicion_hierba_activa = TransicionHierba.ENTRADA_DERECHA
			_:
				transicion_hierba_activa = TransicionHierba.NINGUNA
	elif celda_act and not celda_sig:
		match direccion:
			Vector2.UP:
				transicion_hierba_activa = TransicionHierba.SALIDA_ARRIBA
			Vector2.DOWN:
				transicion_hierba_activa = TransicionHierba.SALIDA_ABAJO
			Vector2.LEFT:
				transicion_hierba_activa = TransicionHierba.SALIDA_IZQUIERDA
			Vector2.RIGHT:
				transicion_hierba_activa = TransicionHierba.SALIDA_DERECHA
			_:
				transicion_hierba_activa = TransicionHierba.NINGUNA
	elif celda_act and celda_sig:
		transicion_hierba_activa = TransicionHierba.ACTIVA
	else:
		transicion_hierba_activa = TransicionHierba.NINGUNA
	return celda_act or celda_sig

func _actualizar_shader_hierba_transicion(pixeles: float) -> void:
	if material_hierba_muy_alta == null:
		return
	match transicion_hierba_activa:
		TransicionHierba.ENTRADA_ARRIBA:
			if pixeles >= 4.0:
				material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
		TransicionHierba.ENTRADA_ABAJO:
			var t := clampf(pixeles / 16.0, 0.0, 1.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", lerpf(2.0, HIERBA_MUY_ALTA_CLIP_Y, t))
		TransicionHierba.ENTRADA_IZQUIERDA:
			var t_der := clampf(pixeles / 16.0, 0.0, 1.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", lerpf(HIERBA_MUY_ALTA_CLIP_X_IZQ, HIERBA_MUY_ALTA_CLIP_X_DER, t_der))
		TransicionHierba.ENTRADA_DERECHA:
			var t_izq := clampf(pixeles / 16.0, 0.0, 1.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", lerpf(HIERBA_MUY_ALTA_CLIP_X_DER, HIERBA_MUY_ALTA_CLIP_X_IZQ, t_izq))
		TransicionHierba.SALIDA_ARRIBA:
			var t_sal_arr := clampf(pixeles / 16.0, 0.0, 1.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", lerpf(HIERBA_MUY_ALTA_CLIP_Y, 2.0, t_sal_arr))
		TransicionHierba.SALIDA_ABAJO:
			if pixeles >= 12.0:
				material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
		TransicionHierba.SALIDA_IZQUIERDA:
			var t_sal_izq := clampf(pixeles / 16.0, 0.0, 1.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", lerpf(HIERBA_MUY_ALTA_CLIP_X_IZQ, HIERBA_MUY_ALTA_CLIP_X_DER, t_sal_izq))
		TransicionHierba.SALIDA_DERECHA:
			var t_sal_der := clampf(pixeles / 16.0, 0.0, 1.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", lerpf(HIERBA_MUY_ALTA_CLIP_X_DER, HIERBA_MUY_ALTA_CLIP_X_IZQ, t_sal_der))

func _aplicar_efecto_hierba_muy_alta(activa: bool) -> void:
	hierba_muy_alta_activa = activa
	if material_hierba_muy_alta == null:
		return
	if not activa:
		_desactivar_efecto_hierba_muy_alta()
		return
	match transicion_hierba_activa:
		TransicionHierba.ENTRADA_ARRIBA:
			material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", HIERBA_MUY_ALTA_CLIP_Y)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", HIERBA_MUY_ALTA_CLIP_X_IZQ)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", HIERBA_MUY_ALTA_CLIP_X_DER)
		TransicionHierba.ENTRADA_ABAJO:
			material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", 2.0)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", HIERBA_MUY_ALTA_CLIP_X_IZQ)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", HIERBA_MUY_ALTA_CLIP_X_DER)
		TransicionHierba.ENTRADA_IZQUIERDA:
			material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", HIERBA_MUY_ALTA_CLIP_Y)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", HIERBA_MUY_ALTA_CLIP_X_IZQ)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", HIERBA_MUY_ALTA_CLIP_X_IZQ)
		TransicionHierba.ENTRADA_DERECHA:
			material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", HIERBA_MUY_ALTA_CLIP_Y)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", HIERBA_MUY_ALTA_CLIP_X_DER)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", HIERBA_MUY_ALTA_CLIP_X_DER)
		_:
			material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", HIERBA_MUY_ALTA_CLIP_Y)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", HIERBA_MUY_ALTA_CLIP_X_IZQ)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", HIERBA_MUY_ALTA_CLIP_X_DER)

func _desactivar_efecto_hierba_muy_alta() -> void:
	hierba_muy_alta_activa = false
	if material_hierba_muy_alta == null:
		return
	material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
	material_hierba_muy_alta.set_shader_parameter("clip_local_y", 2.0)
	material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", -16.0)
	material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", 16.0)

func _reproducir_animacion_hierba_muy_alta(cell: Vector2i) -> void:
	var contenedor := get_parent()
	if contenedor == null:
		return
	var animacion := AnimatedSprite2D.new()
	animacion.name = "HierbaMuyAltaAnim"
	animacion.centered = false
	animacion.offset = HIERBA_MUY_ALTA_ANIM_OFFSET
	animacion.z_index = animated_sprite.z_index if animated_sprite != null else 0
	animacion.sprite_frames = HIERBA_MUY_ALTA_FRAMES
	animacion.animation = &"default"
	animacion.animation_finished.connect(func(): animacion.queue_free(), CONNECT_ONE_SHOT)
	animacion.position = Vector2(cell) * TILE_SIZE + Vector2(8.0, 15.0)
	contenedor.add_child(animacion)
	animacion.play(&"default")

## GroundEffect_Seaweed (OnFinishStep): en el original vale para cualquier objeto
## de evento, no solo el jugador. Los NPCs ocultos no lo disparan.
func _intentar_burbujas_alga() -> void:
	if not is_visible_in_tree():
		return
	BurbujasAlga.crear_si_alga(_obtener_tp_capa_propia(), coord_celda, get_parent())

func _spawn_animacion_pasto(cell: Vector2i) -> void:
	var contenedor := get_parent()
	if contenedor == null:
		return
	var animacion = Singleton.animacion_pisar_pasto.instantiate()
	animaciones_pisar_pasto.append(animacion)
	animacion.position = Vector2(cell) * TILE_SIZE + Vector2(8.0, 15.0)
	contenedor.add_child(animacion)

## Devuelve true si la celda indicada (Vector2i) no está ocupada por otro NPC ni por el jugador
func _celda_libre(celda: Vector2i, direccion: Vector2 = Vector2.ZERO) -> bool:
	# Comprobar bloqueo de tile en la capa de datos propia del NPC
	var tp := _obtener_tp_capa_propia()
	if tp != null:
		var celda_actual_vec := Vector2(coord_celda)
		var bloqueo_dir := _obtener_flag_bloqueo_direccional(direccion)
		if bloqueo_dir != 0 and tp.has_flag(celda_actual_vec, bloqueo_dir):
			return false
		var celda_vec := Vector2(celda)
		# Bloqueo declarado solo en el tile de destino: basta con una de las dos celdas.
		var bloqueo_entrada := _obtener_flag_bloqueo_direccional(-direccion)
		if bloqueo_entrada != 0 and tp.has_flag(celda_vec, bloqueo_entrada):
			return false
		if tp.has_flag(celda_vec, TPTileDataMap.Flags.BLOQUEO):
			return false

	# Comprobar jugador: ocupa su celda y, a mitad de paso, también la de llegada
	# (la posición en píxeles aún cae en la de salida al ir a derecha/abajo).
	# Sus celdas son locales al mapa activo: un NPC de otro mapa cargado no se
	# bloquea con ellas (ver es_mapa_activo). Tampoco si están en capas distintas.
	if jugador and es_mapa_activo() and _comparte_capa_con_jugador():
		var jug_pos = Vector2i(floor((jugador.position.x - OFFSET.x) / TILE_SIZE), floor((jugador.position.y - OFFSET.y) / TILE_SIZE))
		if jug_pos == celda:
			return false
		if "pos_celda_act" in jugador and jugador.pos_celda_act == celda:
			return false
		if jugador.has_method("obtener_celda_destino") and jugador.obtener_celda_destino() == celda:
			return false

	# Comprobar otros NPCs en el grupo "NPC"
	for nodo in get_tree().get_nodes_in_group("NPC"):
		if nodo == self or not _npc_bloquea_celdas(nodo):
			continue
		# Todos los mapas del overworld están instanciados a la vez y coord_celda es
		# local a cada mapa: un NPC de otro mapa con la misma celda local no bloquea.
		if nodo.has_method("_obtener_mapa_propio") and nodo.call("_obtener_mapa_propio") != _obtener_mapa_propio():
			continue
		# coord_celda es una propiedad (has_method no la detecta); fallback a getter
		var other_coord = null
		if "coord_celda" in nodo:
			other_coord = nodo.coord_celda
		elif nodo.has_method("obtener_coord_celda"):
			other_coord = nodo.obtener_coord_celda()
		if other_coord != null and other_coord == celda:
			return false

	return true

## Como en pokeruby (objetos `invisible`), un NPC oculto o deshabilitado no bloquea.
## Tampoco los nodos que declaran no bloquear con bloquea_paso() (objeto oculto:
## bg_hidden_item_event, que no es un objeto del mapa y se puede pisar).
func _npc_bloquea_celdas(nodo: Node) -> bool:
	if nodo is CanvasItem and not nodo.is_visible_in_tree():
		return false
	if "estado_actual" in nodo and nodo.estado_actual == EstadoNPC.DISABLED:
		return false
	if nodo.has_method("bloquea_paso") and not nodo.bloquea_paso():
		return false
	return true

func _obtener_flag_bloqueo_direccional(direccion: Vector2) -> int:
	match direccion:
		Vector2.UP:
			return TPTileDataMap.Flags.BLOQUEO_ARRIBA
		Vector2.DOWN:
			return TPTileDataMap.Flags.BLOQUEO_ABAJO
		Vector2.LEFT:
			return TPTileDataMap.Flags.BLOQUEO_IZQUIERDA
		Vector2.RIGHT:
			return TPTileDataMap.Flags.BLOQUEO_DERECHA
		_:
			return 0

func _obtener_flag_borde_direccional(direccion: Vector2) -> int:
	match direccion:
		Vector2.UP:
			return TPTileDataMap.Flags.BORDE_ARRIBA
		Vector2.DOWN:
			return TPTileDataMap.Flags.BORDE_ABAJO
		Vector2.LEFT:
			return TPTileDataMap.Flags.BORDE_IZQUIERDA
		Vector2.RIGHT:
			return TPTileDataMap.Flags.BORDE_DERECHA
		_:
			return 0

## Intenta dar un paso aleatorio en una de las direcciones válidas, respetando el rango
func _dar_paso_aleatorio_en_rango(direcciones_posibles: Array) -> void:
	var direcciones_validas = []

	# Filtrar direcciones que no excedan el rango
	for direccion in direcciones_posibles:
		var nueva_celda = coord_celda + Vector2i(direccion)
		if nueva_celda.x >= rango_ini.x and nueva_celda.x <= rango_fin.x and nueva_celda.y >= rango_ini.y and nueva_celda.y <= rango_fin.y:
			if _celda_libre(nueva_celda, direccion):
				direcciones_validas.append(direccion)

	# Si hay al menos una dirección válida, moverse
	if direcciones_validas.size() > 0:
		var direccion_elegida = direcciones_validas[randi() % direcciones_validas.size()]
		mover_npc(direccion_elegida)
	else:
		_loggear("No hay direcciones válidas para pasear desde %s" % coord_celda)

## Un paso de las secuencias de caminata (pokeruby MoveNextDirectionInSequence).
## `_rotacion_indice` guarda el tramo actual (se persiste como "rotacion").
func _avanzar_secuencia_caminata() -> void:
	var datos: Array = SECUENCIAS_CAMINATA[tipo_movimiento]
	var secuencia: Array = datos[0]
	var indice_salto: int = datos[1]
	var eje: int = datos[2]
	if _rotacion_indice == indice_salto and coord_celda[eje] == celda_origen[eje]:
		_rotacion_indice = indice_salto + 1
	if _rotacion_indice == 3 and coord_celda == celda_origen:
		_rotacion_indice = 0
	var direccion: Vector2i = secuencia[_rotacion_indice]
	if fuera_de_rango_paseo(coord_celda + direccion):
		_rotacion_indice = mini(_rotacion_indice + 1, 3)
		direccion = secuencia[_rotacion_indice]
	var destino := coord_celda + direccion
	if fuera_de_rango_paseo(destino) or not _celda_libre(destino, Vector2(direccion)):
		# Bloqueado: camina en el sitio mirando hacia el tramo actual.
		mirar(direccion)
		return
	mover_npc(Vector2(direccion))

## IsCoordOutsideObjectEventMovementRange: un eje con rango 0 no limita.
func fuera_de_rango_paseo(celda: Vector2i) -> bool:
	if rango.x != 0 and (celda.x < celda_origen.x - rango.x or celda.x > celda_origen.x + rango.x):
		return true
	if rango.y != 0 and (celda.y < celda_origen.y - rango.y or celda.y > celda_origen.y + rango.y):
		return true
	return false

## ============================================================================
## SEGUIMIENTO DE UN LÍDER
## ============================================================================
## El seguidor entra, en cada paso del líder, en la celda que este deja (como
## los acompañantes de Gen 3). El líder puede ser el jugador u otro NPC: basta
## con que emita paso_iniciado(origen, destino) y exponga duracion_paso y
## facing_direction. Solo dentro del mismo mapa (mismo padre).

## Empieza a seguir a `nuevo_lider`. Mientras sigue no pasea por su cuenta.
func seguir_a(nuevo_lider: Node2D) -> void:
	if nuevo_lider == null or nuevo_lider == self:
		return
	if lider != null:
		dejar_de_seguir()
	if not nuevo_lider.has_signal("paso_iniciado"):
		push_warning("[NPC] %s no emite paso_iniciado: no se puede seguir" % nuevo_lider.name)
		return
	lider = nuevo_lider
	_tipo_movimiento_previo = tipo_movimiento
	_duracion_paso_previa = duracion_paso
	_duracion_salto_previa = duracion_salto
	_cola_seguimiento.clear()
	tipo_movimiento = TipoMovimientoNPC.SIN_MOVIMIENTO
	lider.paso_iniciado.connect(_on_lider_paso_iniciado)
	_loggear("Siguiendo a %s" % lider.name)

## Deja de seguir y retoma su tipo de movimiento en la celda donde se quedó.
func dejar_de_seguir() -> void:
	if lider != null and is_instance_valid(lider) and lider.paso_iniciado.is_connected(_on_lider_paso_iniciado):
		lider.paso_iniciado.disconnect(_on_lider_paso_iniciado)
	var seguia := lider != null
	lider = null
	if not seguia:
		return
	duracion_paso = _duracion_paso_previa
	duracion_salto = _duracion_salto_previa
	_cola_seguimiento.clear()
	tipo_movimiento = _tipo_movimiento_previo
	# Excepción deliberada a "el rango nunca se recalcula desde coord_celda": el
	# acompañante se ha recolocado a propósito y su nuevo hogar es donde se le
	# dejó (como el abuelo de la guardería, se actualiza también celda_origen).
	celda_origen = coord_celda
	rango_ini = celda_origen - rango
	rango_fin = celda_origen + rango
	_iniciar_temporizador()

## Máximo que acelera el seguidor para alcanzar al líder (x2, x3).
const FACTOR_MAX_RITMO_SEGUIMIENTO: int = 3

func esta_siguiendo() -> bool:
	return lider != null and is_instance_valid(lider)

## El líder empieza un paso desde `origen`: el seguidor entra en esa celda. Si aún
## está recorriendo la anterior, la encola y acelera para ponerse al día.
func _on_lider_paso_iniciado(origen: Vector2i, destino: Vector2i) -> void:
	# Cambio de mapa del líder (warp, cruce de borde): el seguimiento termina.
	if not esta_siguiendo() or lider.get_parent() != get_parent():
		dejar_de_seguir()
		return
	if estado_actual in [EstadoNPC.INTERACTING, EstadoNPC.SCRIPTED_ACTION, EstadoNPC.DISABLED]:
		# Ocupado (diálogo, guion): se recoloca en el siguiente paso del líder.
		return
	# El líder va a pisar un warp (se dispara al llegar a su celda): el seguidor no da
	# el último paso. Si lo diera, quedaría delante de la puerta y al volver a salir
	# bloquearía la única celda de salida del jugador.
	if _celda_es_warp(destino):
		return
	# coord_celda ya es la celda de llegada si hay un paso en curso.
	var ultima: Vector2i = _cola_seguimiento.back() if not _cola_seguimiento.is_empty() else coord_celda
	if origen == ultima:
		return
	if absi(origen.x - ultima.x) + absi(origen.y - ultima.y) > FACTOR_MAX_RITMO_SEGUIMIENTO:
		# Líder lejos (teletransporte): lo viejo ya no importa.
		_cola_seguimiento.clear()
	_cola_seguimiento.append(origen)
	if estado_actual == EstadoNPC.MOVING:
		_acelerar_paso_en_curso()
	_procesar_cola_seguimiento()

## Consume la cola cuando el seguidor está libre: un paso por celda, un salto si
## entre las dos hay un borde, o un teletransporte si quedó demasiado lejos.
func _procesar_cola_seguimiento() -> void:
	while esta_siguiendo() and not _cola_seguimiento.is_empty():
		if estado_actual != EstadoNPC.IDLE and estado_actual != EstadoNPC.LOOKING:
			return
		var celda: Vector2i = _cola_seguimiento.pop_front()
		var d := celda - coord_celda
		if d == Vector2i.ZERO:
			continue
		var factor := _factor_ritmo_seguimiento()
		var distancia := absi(d.x) + absi(d.y)
		if d.x == 0 or d.y == 0:
			var dir := Vector2(signi(d.x), signi(d.y))
			if distancia == 1:
				_dar_paso_forzado(dir, _duracion_paso_lider() / factor)
				return
			if distancia == 2 and _hay_borde_en(coord_celda + Vector2i(dir)):
				# El líder saltó un borde: el seguidor salta tras él.
				duracion_salto = _duracion_salto_previa / factor
				_iniciar_paso(dir, celda, true)
				return
			if distancia <= FACTOR_MAX_RITMO_SEGUIMIENTO:
				# Celdas sueltas sin borde (p. ej. el líder pisó un warp): paso a paso.
				_cola_seguimiento.push_front(celda)
				_dar_paso_forzado(dir, _duracion_paso_lider() / factor)
				return
		_cola_seguimiento.clear()
		_teletransportar_a(celda, lider.facing_direction)
		return

## 1 = ritmo del líder; 2 o 3 si quedan celdas pendientes tras la actual.
func _factor_ritmo_seguimiento() -> float:
	return float(clampi(1 + _cola_seguimiento.size(), 1, FACTOR_MAX_RITMO_SEGUIMIENTO))

## Un paso normal se puede acelerar a mitad; un salto no (saltaría el parabólico).
func _acelerar_paso_en_curso() -> void:
	if paso_en_curso and esta_siguiendo():
		duracion_paso = _duracion_paso_lider() / _factor_ritmo_seguimiento()

func _hay_borde_en(celda: Vector2i) -> bool:
	var tp := _obtener_tp_capa_propia()
	if tp == null:
		return true
	const MASK_BORDES := TPTileDataMap.Flags.BORDE_ABAJO | TPTileDataMap.Flags.BORDE_ARRIBA | 		TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA
	return tp.get_flags(Vector2(celda)) & MASK_BORDES != 0

## ¿Hay en `celda` un warp que se dispara al pisarlo (puerta o escalera)? Las
## salidas de borde de mapa no: se activan con la cruceta.
func _celda_es_warp(celda: Vector2i) -> bool:
	var mapa := _obtener_mapa_propio()
	if mapa == null:
		return false
	for grupo in ["Puertas", "Escaleras"]:
		for warp in get_tree().get_nodes_in_group(grupo):
			if mapa.is_ancestor_of(warp) and warp.get("coord_celda") == celda:
				return true
	return false

## Paso impuesto por el líder hacia la celda que acaba de dejar. No consulta
## _celda_libre: esa celda la reserva el líder para su seguidor.
func _dar_paso_forzado(direccion: Vector2, duracion: float) -> void:
	if duracion > 0.0:
		duracion_paso = duracion
	_iniciar_paso(direccion, coord_celda + Vector2i(direccion), false)

func _duracion_paso_lider() -> float:
	var duracion = lider.get("duracion_paso")
	if duracion is float and duracion > 0.0:
		return duracion
	return duracion_paso

## Recolocación directa (líder lejos: teletransporte, salto largo...).
func _teletransportar_a(celda: Vector2i, direccion: Vector2) -> void:
	coord_celda = celda
	position = posicion_de_celda(celda)
	_sincronizar_elevacion_punto()
	if direccion in direcciones_opuestas:
		update_direction(direccion)
	actualizar_efecto_terreno_actual()

## Termina de golpe el paso o salto en curso (posición = destino) sin procesar
## la interacción pendiente: la atenderá el final del siguiente paso.
func _completar_paso_en_curso() -> void:
	if _salto_en_curso:
		_id_salto += 1
		_salto_en_curso = false
		position = _posicion_final_salto
		if animated_sprite:
			animated_sprite.offset = _offset_sprite_salto
		if sombra:
			sombra.visible = false
	elif paso_en_curso:
		position = destino_paso
		progreso_paso = 1.0
		paso_en_curso = false
	else:
		return
	moving = false
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0
	_sincronizar_elevacion_punto()
	actualizar_efecto_terreno_actual()
	if estado_actual == EstadoNPC.MOVING:
		cambiar_estado(EstadoNPC.IDLE)

## ============================================================================
## TIPOS ESPECIALES: EN SITIO, INVISIBLE, COPIAR AL JUGADOR, DISFRAZ Y CENIZA
## ============================================================================

## Fotogramas (60 fps) de cada paso de un tipo en sitio; 0 si no lo es.
static func fotogramas_paso_en_sitio(tipo: int) -> int:
	if TIPOS_EN_SITIO.has(tipo):
		return TIPOS_EN_SITIO[tipo][1]
	return 0

static func es_tipo_disfraz(tipo: int) -> bool:
	return tipo == TipoMovimientoNPC.DISFRAZ_ARBOL or tipo == TipoMovimientoNPC.DISFRAZ_MONTANA

## Tipos que revelar() destapa (trainer_see.c sub_80843DC salta a esa rama).
static func es_tipo_revelable(tipo: int) -> bool:
	return es_tipo_disfraz(tipo) or tipo == TipoMovimientoNPC.OCULTO

## state_to_direction: dirección en la que se mueve un COPIAR_* cuando el jugador
## va hacia `movimiento`, si al activarse el jugador miraba hacia `referencia`.
## Vector2.ZERO si el tipo no copia o alguna dirección no es cardinal.
static func direccion_copiada(tipo: int, referencia: Vector2, movimiento: Vector2) -> Vector2:
	if not TIPOS_COPIAR_JUGADOR.has(tipo) or not DIR_GBA.has(referencia) or not DIR_GBA.has(movimiento):
		return Vector2.ZERO
	var inicial: int = DIR_GBA[TIPOS_COPIAR_JUGADOR[tipo][0]]
	var relativa: int = COPIA_RELATIVA[DIR_GBA[referencia] - 1][DIR_GBA[movimiento] - 1]
	return DIR_DESDE_GBA[COPIA_FINAL[inicial - 1][relativa - 1]]

## CopyablePlayerMovement_*: si la celda de llegada choca (GetCollisionAtCoords)
## o, en las variantes EN_HIERBA, no es hierba (MetatileBehavior_IsPokeGrass),
## el NPC solo gira hacia esa dirección.
static func copia_solo_gira(destino_libre: bool, solo_en_hierba: bool, destino_es_hierba: bool) -> bool:
	return not destino_libre or (solo_en_hierba and not destino_es_hierba)

## GetDirectionToFace: primero el eje horizontal.
static func direccion_hacia(desde: Vector2i, hacia: Vector2i) -> Vector2:
	if desde.x > hacia.x:
		return Vector2.LEFT
	if desde.x < hacia.x:
		return Vector2.RIGHT
	if desde.y > hacia.y:
		return Vector2.UP
	return Vector2.DOWN

## ¿Debe verse el sprite del NPC según su tipo? INVISIBLE nunca
## (MovementType_Invisible); OCULTO y DISFRAZ_* hasta revelar().
func sprite_visible_por_tipo() -> bool:
	if tipo_movimiento == TipoMovimientoNPC.INVISIBLE:
		return false
	if tipo_movimiento == TipoMovimientoNPC.OCULTO:
		return _oculto_revelado
	if es_tipo_disfraz(tipo_movimiento):
		return _disfraz_revelado
	return true

## Oculta solo el sprite, nunca el nodo: `visible` reinicializa al NPC y lo usan
## bandera_ocultar/mostrar; así sigue ocupando su celda. Solo toca el sprite si
## el tipo lo oculta o lo ocultaba (no pisa los set_invisible de otros guiones).
## En el editor no se toca, para poder ver y colocar al NPC.
func _actualizar_visibilidad_sprite() -> void:
	if Engine.is_editor_hint() or animated_sprite == null:
		return
	var oculto := not sprite_visible_por_tipo()
	if oculto or _sprite_oculto_por_tipo:
		animated_sprite.visible = not oculto and estado_actual != EstadoNPC.DISABLED
	_sprite_oculto_por_tipo = oculto

## Ajustes visuales y conexiones que dependen del tipo (al cambiarlo, en _ready
## y al reinicializar, vía direccion_inicial()).
func _aplicar_tipo_especial() -> void:
	if not TIPOS_COPIAR_JUGADOR.has(tipo_movimiento):
		_desconectar_copia()
	_preparar_disfraz()
	_actualizar_visibilidad_sprite()

## Vuelta al estado de recién cargado: el disfraz y la ceniza reaparecen (si el
## tipo lo sigue siendo) y las corrutinas de revelar() en curso se abandonan.
func _reiniciar_tipo_especial() -> void:
	_id_revelar += 1
	if _efecto_ceniza != null:
		_efecto_ceniza.queue_free()
		_efecto_ceniza = null
	if _salto_en_sitio_activo:
		_salto_en_sitio_activo = false
		if animated_sprite:
			animated_sprite.offset.y -= _altura_salto_en_sitio_actual
		if sombra:
			sombra.visible = false
	_altura_salto_en_sitio_actual = 0
	_disfraz_revelado = false
	_oculto_revelado = false
	_desconectar_copia()
	_detener_paso_en_sitio()

# --- En sitio ---

## MovementType_WalkInPlace/JogInPlace/RunInPlace: pasos en sitio sin fin hacia
## facing_direction (tras hablar siguen hacia donde quedaron). Cada paso muestra
## el frame de zancada la primera mitad y el de reposo la segunda, alternando
## camina_<dir>_1/_2 como evento_guionizado.trotar_en_sitio().
func _procesar_paso_en_sitio(delta: float) -> void:
	var fotogramas := fotogramas_paso_en_sitio(tipo_movimiento)
	if fotogramas <= 0 or animated_sprite == null \
			or not (estado_actual in [EstadoNPC.IDLE, EstadoNPC.LOOKING]) or not puede_iniciar_acciones():
		_detener_paso_en_sitio()
		return
	var duracion := fotogramas / 60.0
	if not _en_sitio_activo:
		_en_sitio_activo = true
		_en_sitio_tiempo = 0.0
		_empezar_paso_en_sitio()
	else:
		_en_sitio_tiempo += delta
		if _en_sitio_tiempo >= duracion:
			_en_sitio_tiempo = fmod(_en_sitio_tiempo, duracion)
			_empezar_paso_en_sitio()
	animated_sprite.frame = 1 if _en_sitio_tiempo < duracion / 2.0 else 0

func _empezar_paso_en_sitio() -> void:
	_en_sitio_alterna = 1 if _en_sitio_alterna == 2 else 2
	var base := _obtener_nombre_animacion_base(facing_direction)
	if base == "":
		return
	animated_sprite.play("%s_%d" % [base, _en_sitio_alterna])
	animated_sprite.stop()

## Pausa (diálogo, guion, menú...): el NPC queda en el frame de reposo.
func _detener_paso_en_sitio() -> void:
	if not _en_sitio_activo:
		return
	_en_sitio_activo = false
	_en_sitio_tiempo = 0.0
	if animated_sprite:
		animated_sprite.frame = 0

# --- Copiar al jugador ---

## MovementType_CopyPlayer(InGrass): en cada paso o giro del jugador el NPC hace
## lo mismo en la dirección transformada (direccion_copiada). Los pasos llegan
## por la señal paso_iniciado y se ejecutan aquí; los giros en sitio se detectan
## sondeando facing_direction (el jugador no emite señal al girar).
func _procesar_copia_jugador() -> void:
	if not TIPOS_COPIAR_JUGADOR.has(tipo_movimiento):
		_desconectar_copia()
		return
	if not is_instance_valid(jugador) or not _jugador_en_mi_mapa():
		_copia_paso_pendiente = []
		return
	if _copia_jugador != jugador:
		_desconectar_copia()
		_conectar_copia()
	var mirada: Vector2 = jugador.facing_direction
	if _copia_referencia == Vector2.ZERO:
		# MovementType_CopyPlayer_Step0: la referencia es hacia donde mira el jugador.
		_copia_referencia = mirada
		_copia_ultima_mirada = mirada
		_copia_paso_pendiente = []
		return
	var giro := mirada != _copia_ultima_mirada
	_copia_ultima_mirada = mirada
	# El paso anterior aún no ha terminado: el siguiente del jugador espera
	# (MovementType_CopyPlayer_Step2 antes de volver a Step1).
	if estado_actual == EstadoNPC.MOVING and not _copia_paso_pendiente.is_empty():
		return
	var paso := _copia_paso_pendiente
	_copia_paso_pendiente = []
	if not _puede_copiar_jugador():
		return
	if not paso.is_empty():
		_copiar_paso_jugador(paso[0], paso[1])
	elif giro and not (jugador.has_method("esta_en_movimiento") and jugador.esta_en_movimiento()):
		# CopyablePlayerMovement_FaceDirection
		var direccion := direccion_copiada(tipo_movimiento, _copia_referencia, mirada)
		if direccion != Vector2.ZERO:
			mirar(Vector2i(direccion))

func _jugador_en_mi_mapa() -> bool:
	return jugador.get_parent() == get_parent() and is_visible_in_tree()

func _puede_copiar_jugador() -> bool:
	if estado_actual in [EstadoNPC.MOVING, EstadoNPC.INTERACTING, EstadoNPC.SCRIPTED_ACTION, EstadoNPC.DISABLED]:
		return false
	return puede_iniciar_acciones()

## CopyablePlayerMovement_GoSpeed0..2 (paso de una celda al ritmo del jugador)
## y _Jump (salto de dos celdas): si no puede avanzar, solo gira.
func _copiar_paso_jugador(origen: Vector2i, destino: Vector2i) -> void:
	var d := destino - origen
	if d == Vector2i.ZERO or (d.x != 0 and d.y != 0):
		return
	var direccion := direccion_copiada(tipo_movimiento, _copia_referencia, Vector2(signi(d.x), signi(d.y)))
	if direccion == Vector2.ZERO:
		return
	var salto := absi(d.x) + absi(d.y) >= 2
	var celda := coord_celda + Vector2i(direccion) * (2 if salto else 1)
	var celda_vec := Vector2(celda)
	var es_hierba := _celda_tiene_hierba_alta(celda_vec) or _celda_tiene_hierba_mas_alta(celda_vec)
	if copia_solo_gira(_copia_celda_libre(celda, direccion, salto), TIPOS_COPIAR_JUGADOR[tipo_movimiento][1], es_hierba):
		mirar(Vector2i(direccion))
		return
	if salto:
		var duracion_salto_jugador = jugador.get("duracion_salto")
		if duracion_salto_jugador is float and duracion_salto_jugador > 0.0:
			duracion_salto = duracion_salto_jugador
	else:
		var duracion_jugador = jugador.get("duracion_paso")
		if duracion_jugador is float and duracion_jugador > 0.0:
			duracion_paso = duracion_jugador
	_iniciar_paso(direccion, celda, salto)

## GetCollisionAtCoords: fuera del rango de paseo (0 = sin límite), bloqueo u
## ocupada. Un borde en la celda de un paso normal también lo frena: el NPC no
## salta bordes por su cuenta (en el salto copiado solo cuenta la de llegada).
func _copia_celda_libre(celda: Vector2i, direccion: Vector2, salto: bool) -> bool:
	if fuera_de_rango_paseo(celda):
		return false
	if not salto:
		var tp := _obtener_tp_capa_propia()
		const MASK_BORDES := TPTileDataMap.Flags.BORDE_ABAJO | TPTileDataMap.Flags.BORDE_ARRIBA | \
			TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA
		if tp != null and tp.get_flags(Vector2(celda)) & MASK_BORDES:
			return false
	return _celda_libre(celda, direccion)

func _on_jugador_paso_copiable(origen: Vector2i, destino: Vector2i) -> void:
	# El salto de borde del jugador se anuncia justo tras el paso normal desde el
	# mismo origen: el último anuncio manda.
	_copia_paso_pendiente = [origen, destino]

func _conectar_copia() -> void:
	if not is_instance_valid(jugador) or not jugador.has_signal("paso_iniciado"):
		return
	if not jugador.paso_iniciado.is_connected(_on_jugador_paso_copiable):
		jugador.paso_iniciado.connect(_on_jugador_paso_copiable)
	_copia_jugador = jugador

## Suelta la señal del jugador y olvida la referencia (se toma de nuevo).
func _desconectar_copia() -> void:
	if is_instance_valid(_copia_jugador) and _copia_jugador.paso_iniciado.is_connected(_on_jugador_paso_copiable):
		_copia_jugador.paso_iniciado.disconnect(_on_jugador_paso_copiable)
	_copia_jugador = null
	_copia_referencia = Vector2.ZERO
	_copia_paso_pendiente = []

# --- Disfraz y ceniza ---

func _frames_disfraz() -> SpriteFrames:
	match tipo_movimiento:
		TipoMovimientoNPC.DISFRAZ_ARBOL:
			return FRAMES_DISFRAZ_ARBOL
		TipoMovimientoNPC.DISFRAZ_MONTANA:
			return FRAMES_DISFRAZ_MONTANA
	return null

## MovementType_TreeDisguise/MountainDisguise: el disfraz (anim 0, frame 0 fijo)
## tapa al NPC y le sigue como hijo. Solo en ejecución: en el editor no se crean
## nodos que podrían acabar guardados en el mapa.
func _preparar_disfraz() -> void:
	var frames := _frames_disfraz()
	if frames == null or _disfraz_revelado or Engine.is_editor_hint() or not is_inside_tree():
		_quitar_disfraz()
		return
	if _disfraz == null:
		_disfraz = AnimatedSprite2D.new()
		_disfraz.name = "Disfraz"
		_disfraz.centered = false
		_disfraz.offset = OFFSET_DISFRAZ
		# subpriority - 1 en el GBA: por delante del NPC.
		add_child(_disfraz)
	_disfraz.sprite_frames = frames
	_disfraz.visible = estado_actual != EstadoNPC.DISABLED
	_disfraz.play(&"quieto")

func _quitar_disfraz() -> void:
	if _disfraz != null:
		_disfraz.queue_free()
		_disfraz = null

## Destapa al NPC (MOVEMENT_ACTION_REVEAL_TRAINER). DISFRAZ_*: el disfraz se
## deshace y desaparece. OCULTO: sale de la ceniza de un salto. Para los demás
## tipos (o si ya se reveló) vuelve enseguida.
func revelar() -> void:
	if es_tipo_disfraz(tipo_movimiento):
		await _revelar_disfraz()
	elif tipo_movimiento == TipoMovimientoNPC.OCULTO:
		await _salir_de_ceniza()

## UpdateDisguiseFieldEffect con anim 1 (frames 0..6) y FieldEffectStop al acabar.
## El NPC, que estaba debajo, se ve desde el primer frame de la animación.
func _revelar_disfraz() -> void:
	if _disfraz_revelado:
		return
	_disfraz_revelado = true
	_actualizar_visibilidad_sprite()
	var disfraz := _disfraz
	var id := _id_revelar
	if disfraz == null or not is_inside_tree():
		_quitar_disfraz()
		return
	disfraz.play(&"revelar")
	while is_instance_valid(disfraz) and disfraz.is_playing() and id == _id_revelar:
		await get_tree().process_frame
	if id == _id_revelar and _disfraz == disfraz:
		_quitar_disfraz()

## trainer_see.c sub_80845C8..sub_80846C8: mira al jugador, la ceniza estalla en
## su celda y, en el frame 2 del efecto, el NPC aparece con un salto en sitio.
## Termina cuando acaba el efecto.
func _salir_de_ceniza() -> void:
	if _oculto_revelado:
		return
	var id := _id_revelar
	if is_instance_valid(jugador):
		var celda_jugador: Vector2i = jugador.pos_celda_act if "pos_celda_act" in jugador else coord_celda
		update_direction(direccion_hacia(coord_celda, celda_jugador))
	if not is_inside_tree():
		_oculto_revelado = true
		_actualizar_visibilidad_sprite()
		return
	var efecto := AnimatedSprite2D.new()
	efecto.name = "SalirDeCeniza"
	efecto.centered = false
	efecto.offset = OFFSET_SALIR_DE_CENIZA
	efecto.sprite_frames = FRAMES_SALIR_DE_CENIZA
	add_child(efecto)
	_efecto_ceniza = efecto
	efecto.play(&"default")
	while is_instance_valid(efecto) and efecto.is_playing() and efecto.frame < 2 and id == _id_revelar:
		await get_tree().process_frame
	if id != _id_revelar:
		return
	_oculto_revelado = true
	_actualizar_visibilidad_sprite()
	_saltar_en_sitio(id)
	while id == _id_revelar and (_salto_en_sitio_activo or (is_instance_valid(efecto) and efecto.is_playing())):
		await get_tree().process_frame
	if is_instance_valid(efecto):
		efecto.queue_free()
	if _efecto_ceniza == efecto:
		_efecto_ceniza = null

## GetJumpInPlaceMovementAction (sub_8064704 con Unknown_837619E): 16 fotogramas
## sin cambiar de celda, con la animación de paso y la sombra.
func _saltar_en_sitio(id: int) -> void:
	if animated_sprite == null:
		return
	_salto_en_sitio_activo = true
	if sombra:
		sombra.visible = true
	var base := _obtener_nombre_animacion_base(facing_direction)
	if base != "":
		animated_sprite.play(base + "_1")
		animated_sprite.stop()
	var tiempo := 0.0
	var total := ALTURAS_SALTO.size()
	while id == _id_revelar:
		var fotograma := int(tiempo * 60.0)
		if fotograma >= total:
			break
		var altura := ALTURAS_SALTO[fotograma]
		animated_sprite.offset.y += altura - _altura_salto_en_sitio_actual
		_altura_salto_en_sitio_actual = altura
		animated_sprite.frame = 1 if fotograma < total / 2 else 0
		await get_tree().process_frame
		tiempo += get_process_delta_time()
	if id != _id_revelar:
		return
	animated_sprite.offset.y -= _altura_salto_en_sitio_actual
	_altura_salto_en_sitio_actual = 0
	animated_sprite.frame = 0
	if sombra:
		sombra.visible = false
	_salto_en_sitio_activo = false

func _loggear(mensaje: String) -> void:
	if loggear:
		print("[🤖 %s] → %s" % [self.name, mensaje])
