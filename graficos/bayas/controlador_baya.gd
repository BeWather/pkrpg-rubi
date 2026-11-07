@tool
extends Node2D
class_name ControladorBaya

## Parcela de tierra blanda donde se plantan BAYAS (árbol de bayas de Gen III).
##
## Referencias pokeruby: src/berry.c (crecimiento, riego, rendimiento),
## data/scripts/berry_tree.inc + data/text/berry_tree.inc (diálogos),
## src/item_use.c (USAR CUBO WAILMER / BAYA desde la mochila frente a la
## parcela) y src/event_object_movement.c (MovementType_BerryTreeGrowth:
## destello y parpadeo al cambiar de etapa).
##
## Única diferencia DELIBERADA con Ruby: una vez en FRUTO la planta se queda
## así indefinidamente hasta que el jugador cosecha (sin caída de bayas, sin
## ciclos de rebrote, sin límite de regeneraciones y sin vaciado por ausencia
## larga). Al cosechar la parcela queda vacía, como en Ruby.
##
## Los datos de cada baya (horas por etapa, rendimiento mínimo/máximo...)
## salen de la tabla Bayas de poke.db (gBerries de pokeruby).
##
## Debe ser hija del nodo "NPCs" del mapa: expone `coord_celda`, así que
## AdministradorMapa.next_to_npc() la usa para accionarla y para bloquear el
## paso (como los objetos de árbol de bayas de Ruby).

## Emitida al terminar cada mensaje de un flujo de diálogo (uso interno).
signal _mensaje_terminado

enum EEtapas {
	VACIA = 0,
	PLANTADA = 1,
	BROTE = 2,
	TALLO = 3,
	FLOR = 4,
	FRUTO = 5,
}

# ──────────────────────────────────────────────────────────────────────────────
# ENUM – nombre enum = nombre del .tres, valor = id en tabla Objetos de la DB
# ──────────────────────────────────────────────────────────────────────────────
enum ENBayas {
	BAYA_ALGAMA     = 147,    # KELPSY
	BAYA_ANDANO     = 160,    # BELUE
	BAYA_ANGO       = 138,    # MAGO
	BAYA_AOSTAN     = 153,    # MAGOST
	BAYA_ARABOL     = 184,    # STARF   REV SPRITES
	BAYA_ARANJA     = 132,    # ORAN
	BAYA_ARICOC     = 182,    # APICOT	REV SPRITES
	BAYA_ASLAC      = 180,    # SALAC	REV SPRITES
	BAYA_ATANIA     = 127,    # CHESTO
	BAYA_CAQUIC     = 133,    # PERSIM
	BAYA_ENIGMA     = 185,    # ENIGMA	REV SPRITES    24h c/e 1-2 bayas
	BAYA_FRAMBU     = 141,    # RAZZ
	BAYA_GONLAN     = 179,    # GANLON	REV SPRITES
	BAYA_GRANA      = 146,    # POMEG
	BAYA_GUAYA      = 139,    # AGUAV
	BAYA_HIGOG      = 136,    # FIGY
	BAYA_ISPERO     = 148,    # QUALOT
	BAYA_LATANO     = 143,    # NANAB
	BAYA_LICHI      = 178,    # LIECHI	REV SPRITES
	BAYA_MAIS       = 152,    # CORNN
	BAYA_MELOC      = 128,    # PECHA
	BAYA_MELUCE     = 149,    # HONDEW
	BAYA_MONLI      = 155,    # NOMEL
	BAYA_ORAM       = 142,    # BLUK
	BAYA_PABAYA     = 140,    # IAPAPA
	BAYA_PERAGU     = 144,    # WEPEAR
	BAYA_PERASI     = 130,    # ASPEAR
	BAYA_PINIA      = 145,    # PINAP
	BAYA_PLAMA      = 157,    # PAMTRE
	BAYA_RAUTAN     = 154,    # RABUTA
	BAYA_RUDION     = 159,    # DURIN
	BAYA_SAFRE      = 129,    # RAWST
	BAYA_SAMBIA     = 158,    # WATMEL
	BAYA_TAMATE     = 151,    # TAMATO
	BAYA_UVAV       = 150,    # GREPA
	BAYA_WIKANO     = 156,    # SPELON
	BAYA_WIKI       = 137,    # WIKI
	BAYA_YAPATI     = 181,    # PETAYA	REV SPRITES    24h c/e 1-2 bayas
	BAYA_ZANAMA     = 131,    # LEPPA
	BAYA_ZIDRA      = 135,    # SITRUS
	BAYA_ZIUELA     = 134,    # LUM
	BAYA_ZONLAN     = 183,    # LANSAT	REV SPRITES    24h c/e 1-2 bayas
	BAYA_ZREZA      = 126,    # CHERI
}

# ──────────────────────────────────────────────────────────────────────────────
# CONSTANTES
# ──────────────────────────────────────────────────────────────────────────────

## Tamaño del tile y offset de anclaje (igual que npc_base).
const TILE_SIZE: int    = 16
const OFFSET: Vector2  = Vector2(8, 14)   ## Centro del tile; el sprite tiene su propio offset vertical.

## Nombres de animación del SpriteFrames indexados por etapa (0 = vacío).
const ANIM_ETAPAS: Array[StringName] = [
	&"",           # 0 – parcela vacía (sprite oculto)
	&"1_plantada",
	&"2_brote",
	&"3_tallo",
	&"4_flor",
	&"5_fruto",
]

## nombre_interno (Objetos) de las regaderas. Van en el bolsillo de objetos clave.
const REGADERAS: Array[String] = ["CUBOWAILMER"]

## Bolsillos de la mochila (índices 0-based, ver ObjetosLlevados).
const BOLSILLO_BAYAS: int = 3
const BOLSILLO_CLAVE: int = 4

## Etapas de crecimiento antes del fruto (PLANTADA → BROTE → TALLO → FLOR → FRUTO).
const ETAPAS_CRECIMIENTO: int = 4

## Valores si la baya no tiene fila en la tabla Bayas. Como GetBerryInfo de
## pokeruby, una baya inválida se trata como ZREZA (CHERI): 3 h, 2-3 bayas.
const HORAS_ETAPA_DEFECTO: int = 3
const RENDIMIENTO_MIN_DEFECTO: int = 2
const RENDIMIENTO_MAX_DEFECTO: int = 3

## Cada cuánto se recalcula el crecimiento con el jugador en el mapa
## (DoTimeBasedEvents → BerryTreeTimeUpdate trabaja en minutos).
const INTERVALO_ACTUALIZACION: float = 60.0
const INTERVALO_ACTUALIZACION_DEBUG: float = 1.0

## Fanfarria al cosechar (MUS_OBTAIN_BERRY), clave de temas_musicales.json.
const FANFARRIA_BAYA: String = "OBTENIDA_BAYA"

## Destello FLDEFF_BERRY_TREE_GROWTH_SPARKLE (pokeruby
## graphics/field_effect_objects/pics/berry_tree_growth_sparkle.png, 6 frames de 16x16).
const RUTA_DESTELLO: String = "res://graficos/bayas/destello_baya.png"
const FRAMES_DESTELLO: int = 6
const TAM_FRAME_DESTELLO: int = 16
## FldEff_BerryTreeGrowthSparkle: centro en (+8, +4) desde la esquina del tile.
const POS_DESTELLO: Vector2 = Vector2(8, 4) - OFFSET
## Frames (a 60 fps) que dura cada mitad del parpadeo (MovementType_BerryTreeGrowth_Step3/4).
const FRAMES_PARPADEO: int = 64
## Duración de DoWateringBerryTreeAnim (pose de regar del jugador).
const ESPERA_ANIM_RIEGO: float = 2.0

const ESCENA_MOCHILA: PackedScene = preload("res://UI/mochila/mochila.tscn")
const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const SEGUNDOS_HORA: int = 3600
const OPCIONES_DEBUG: PackedStringArray = [
	"SEGUIR", "+1 HORA", "+6 HORAS", "ETAPA ANTERIOR", "ETAPA SIGUIENTE", "REGAR", "SALIR",
]

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN DE INSTANCIA (exportable desde el editor)
# ──────────────────────────────────────────────────────────────────────────────

## Celda que ocupa la parcela; la lee AdministradorMapa.next_to_npc() para
## accionarla y para bloquear el paso.
var coord_celda: Vector2i = Vector2i.ZERO

## Coordenada en tiles. Al cambiarla mueve el nodo al tile correspondiente.
@export var coord: Vector2i = Vector2i.ZERO:
	set(value):
		coord = value
		coord_celda = value
		if is_inside_tree():
			position = Vector2(value.x * TILE_SIZE + OFFSET.x, value.y * TILE_SIZE + OFFSET.y)
			if Engine.is_editor_hint():
				update_configuration_warnings()

## Identificador único de esta parcela. Formato: "mapa_parcela_N", p.ej. "ruta_123_parcela_0"
@export var id_parcela: String = ""

## Si es true, la parcela comienza con `baya_inicial` ya plantada (primera vez).
@export var preplantada: bool = false

## Baya que se planta automáticamente si `preplantada = true`.
@export var baya_inicial: ENBayas = ENBayas.BAYA_ZIDRA:
	set(value):
		baya_inicial = value
		if Engine.is_editor_hint() and is_inside_tree():
			_actualizar_sprite_editor()

## Etapa con la que arranca la parcela (editor y runtime).
## En el editor muestra el sprite; en runtime fija el estado inicial si no hay partida guardada.
@export var etapa_inicial: EEtapas = EEtapas.FRUTO:
	set(value):
		etapa_inicial = value
		if Engine.is_editor_hint() and is_inside_tree():
			_actualizar_sprite_editor()

## Modo de prueba: las horas de cada etapa pasan a ser minutos.
@export var debug_acelerar: bool = false

# ──────────────────────────────────────────────────────────────────────────────
# NODOS
# ──────────────────────────────────────────────────────────────────────────────

@onready var sprite: AnimatedSprite2D = $sprite

# ──────────────────────────────────────────────────────────────────────────────
# ESTADO INTERNO
# ──────────────────────────────────────────────────────────────────────────────

## Clave del enum como string, p.ej. "BAYA_ZIDRA". "" = parcela vacía.
var _nombre_baya: String        = ""
## Etapa actual: 0 vacía | 1-4 creciendo | 5 lista para cosechar.
var _etapa: int                 = EEtapas.VACIA
## Segundos de crecimiento acumulados desde la plantación.
var _tiempo_vivo: int           = 0
## Etapas en las que se regó (watered1..watered4 de pokeruby), 0-4.
var _veces_regada: int          = 0
## True si ya se regó en la etapa actual (un riego por etapa).
var _regada_esta_etapa: bool    = false
## Bayas que dará la cosecha: se calcula UNA vez al pasar de FLOR a FRUTO
## (BerryTreeGrow → CalcBerryYield). 0 = todavía sin calcular.
var _rendimiento: int           = 0
## Marca de tiempo Unix (hora del sistema) de la última actualización.
var _ts_actualizacion: int      = 0

var _admin: Node = null
var _inicializada: bool = false
## Hay un flujo de diálogo en curso con esta parcela.
var _interactuando: bool = false
## Destello + parpadeo de cambio de etapa en curso (BERRY_STAGE_SPARKLING).
var _destellando: bool = false
var _temporizador: Timer = null

static var _cache_frames_destello: SpriteFrames = null

# ──────────────────────────────────────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		update_configuration_warnings()
		_actualizar_sprite_editor()
		return
	coord_celda = coord
	# Fallback por si la parcela no cuelga de "NPCs" (next_to_npc no la vería).
	if Singleton != null and not Singleton.buscar_evento_accion.is_connected(_on_singleton_buscar_evento):
		Singleton.buscar_evento_accion.connect(_on_singleton_buscar_evento)
	_crear_temporizador()
	call_deferred(&"_inicializar")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		# Snap al tile más cercano al arrastrar en el editor
		var snappedd := Vector2i(
			round((position.x - OFFSET.x) / TILE_SIZE),
			round((position.y - OFFSET.y) / TILE_SIZE)
		)
		coord = snappedd
		position = Vector2(coord.x * TILE_SIZE + OFFSET.x, coord.y * TILE_SIZE + OFFSET.y)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if id_parcela == "":
		warnings.append("id_parcela está vacío. Asigna un identificador único, p.ej. \"ruta_123_parcela_0\".")
	if get_parent() != null and get_parent().name != &"NPCs":
		warnings.append("La parcela debe ser hija del nodo \"NPCs\" del mapa: si no, no bloquea el paso.")
	return warnings


func _inicializar() -> void:
	if _inicializada:
		return
	_inicializada = true
	_admin = get_tree().root.get_node_or_null("AdministradorMapa")
	if id_parcela == "":
		push_warning("[ControladorBaya] '%s': id_parcela no configurado." % name)
	_cargar_estado()
	_avanzar_crecimiento()
	_actualizar_sprite()


func _crear_temporizador() -> void:
	_temporizador = Timer.new()
	_temporizador.wait_time = INTERVALO_ACTUALIZACION_DEBUG if debug_acelerar else INTERVALO_ACTUALIZACION
	_temporizador.autostart = true
	_temporizador.timeout.connect(_on_temporizador)
	add_child(_temporizador)


## Crecimiento en vivo mientras el jugador está en el mapa. Si la etapa cambia
## se reproduce el destello + parpadeo de MovementType_BerryTreeGrowth.
func _on_temporizador() -> void:
	if not _inicializada or _interactuando or _destellando or Singleton.esta_pausado():
		return
	if _avanzar_crecimiento():
		_animar_cambio_etapa()

# ──────────────────────────────────────────────────────────────────────────────
# PERSISTENCIA  (usa datos_persistentes de SistemaGuardado)
# ──────────────────────────────────────────────────────────────────────────────
# Claves: "baya_<id_parcela>_<campo>"
# Campos: baya (texto), etapa, tiempo_vivo, veces_regada, rendimiento
#         (contadores), regada_etapa (bandera), ts_update (timestamp).
# Campos de versiones anteriores que se ignoran: replantaciones, inicializada.

func _k(campo: String) -> String:
	return "baya_%s_%s" % [id_parcela, campo]


func _cargar_estado() -> void:
	if id_parcela == "":
		if preplantada and _nombre_baya == "":
			_aplicar_preplantada()
		return
	# Si la parcela nunca guardó estado es su primera carga: se aplica
	# `preplantada`. Una parcela cosechada sí tiene estado (baya = ""), así
	# que no vuelve a plantarse. Esto también repara las partidas en las que
	# la preplantada se marcó "inicializada" sin llegar a guardarse.
	if preplantada and not SistemaGuardado.has_texto(_k("baya")):
		_aplicar_preplantada()
		return
	_nombre_baya       = SistemaGuardado.get_texto(_k("baya"))
	_etapa             = SistemaGuardado.get_contador(_k("etapa"))
	_tiempo_vivo       = SistemaGuardado.get_contador(_k("tiempo_vivo"))
	_veces_regada      = SistemaGuardado.get_contador(_k("veces_regada"))
	_regada_esta_etapa = SistemaGuardado.get_flag(_k("regada_etapa"))
	_rendimiento       = SistemaGuardado.get_contador(_k("rendimiento"))
	_ts_actualizacion  = SistemaGuardado.get_timestamp(_k("ts_update"))
	if _nombre_baya == "" or not _nombre_baya in ENBayas:
		_nombre_baya = ""
		_etapa = EEtapas.VACIA


func _guardar_estado() -> void:
	if id_parcela == "":
		return
	SistemaGuardado.set_texto(_k("baya"),              _nombre_baya)
	SistemaGuardado.set_contador(_k("etapa"),          _etapa)
	SistemaGuardado.set_contador(_k("tiempo_vivo"),    _tiempo_vivo)
	SistemaGuardado.set_contador(_k("veces_regada"),   _veces_regada)
	SistemaGuardado.set_flag(_k("regada_etapa"),       _regada_esta_etapa)
	SistemaGuardado.set_contador(_k("rendimiento"),    _rendimiento)
	SistemaGuardado.set_timestamp(_k("ts_update"),     _ts_actualizacion)


## Planta `baya_inicial` en `etapa_inicial` (setberrytree de los scripts de
## mapa → PlantBerryTree). En FRUTO el rendimiento se calcula ya, sin riegos.
func _aplicar_preplantada() -> void:
	var clave: String = _enum_key_de(baya_inicial)
	if clave == "":
		return
	var etapa_objetivo: int = clampi(etapa_inicial, EEtapas.PLANTADA, EEtapas.FRUTO)
	_plantar_interna(clave)
	_etapa = etapa_objetivo
	_tiempo_vivo = (etapa_objetivo - EEtapas.PLANTADA) * _segundos_por_etapa()
	if _etapa == EEtapas.FRUTO:
		_rendimiento = _calcular_rendimiento()
	_guardar_estado()

# ──────────────────────────────────────────────────────────────────────────────
# LÓGICA DE CRECIMIENTO  (mecánicas Gen III, hora real del sistema)
# ──────────────────────────────────────────────────────────────────────────────

## Suma el tiempo transcurrido desde la última actualización y recalcula la
## etapa. En FRUTO no avanza más (decisión del proyecto: no hay rebrote ni
## pérdida). Devuelve true si la etapa cambió.
func _avanzar_crecimiento() -> bool:
	if _etapa == EEtapas.VACIA or _nombre_baya == "":
		return false
	var etapa_anterior: int = _etapa
	var ahora: int = int(Time.get_unix_time_from_system())
	if _ts_actualizacion <= 0 or ahora < _ts_actualizacion:
		# Sin referencia (o el reloj retrocedió): se toma "ahora" como base.
		_ts_actualizacion = ahora
	elif _etapa < EEtapas.FRUTO:
		var segundos_etapa: int = _segundos_por_etapa()
		_tiempo_vivo = mini(_tiempo_vivo + ahora - _ts_actualizacion, ETAPAS_CRECIMIENTO * segundos_etapa)
		_etapa = mini(EEtapas.PLANTADA + _tiempo_vivo / segundos_etapa, EEtapas.FRUTO)
		_ts_actualizacion = ahora
	else:
		_ts_actualizacion = ahora
	# BerryTreeGrow: el rendimiento se fija al pasar de FLOR a FRUTO (también
	# repara partidas antiguas que llegaron a FRUTO sin rendimiento guardado).
	if _etapa == EEtapas.FRUTO and _rendimiento <= 0:
		_rendimiento = _calcular_rendimiento()
	if _etapa != etapa_anterior:
		_regada_esta_etapa = false
	_guardar_estado()
	return _etapa != etapa_anterior


## Segundos reales por etapa (horas_etapa de la tabla Bayas). Con
## debug_acelerar las horas se tratan como minutos.
func _segundos_por_etapa() -> int:
	var horas: int = int(_datos_baya().get("horas_etapa", HORAS_ETAPA_DEFECTO))
	var multiplicador: int = 60 if debug_acelerar else 3600
	return maxi(1, horas * multiplicador)


## Fila de la tabla Bayas de la baya plantada ({} si no hay).
func _datos_baya() -> Dictionary:
	if _nombre_baya == "" or not _nombre_baya in ENBayas:
		return {}
	return DatabaseManager.obtener_datos_baya(ENBayas[_nombre_baya])


## Rendimiento con los datos de la baya y los riegos actuales (CalcBerryYield).
func _calcular_rendimiento() -> int:
	var datos: Dictionary = _datos_baya()
	var minimo: int = int(datos.get("rendimiento_min", RENDIMIENTO_MIN_DEFECTO))
	var maximo: int = int(datos.get("rendimiento_max", RENDIMIENTO_MAX_DEFECTO))
	return calcular_rendimiento(minimo, maximo, _veces_regada)


## CalcBerryYieldInternal de pokeruby: sin riegos da el mínimo; cada etapa
## regada acerca el resultado al máximo (con 4 riegos siempre da el máximo).
static func calcular_rendimiento(minimo: int, maximo: int, riegos: int) -> int:
	if riegos <= 0:
		return minimo
	var rango: int = maxi(0, maximo - minimo)
	var rand_min: int = rango * (riegos - 1)
	var rand_max: int = rango * riegos
	var valor: int = rand_min + randi() % (rand_max - rand_min + 1)
	var extra: int = valor / 4 + 1 if valor % 4 > 1 else valor / 4
	return extra + minimo


## Texto de la flor según las etapas regadas (berry_tree.inc: 0 → cutely,
## 4 → very beautifully, resto → prettily). Devuelve la clave de dialogos.csv.
static func clave_estado_flor(riegos: int) -> String:
	if riegos <= 0:
		return "BAYA_FLOR_SIN_RIEGO"
	if riegos >= ETAPAS_CRECIMIENTO:
		return "BAYA_FLOR_RIEGO_COMPLETO"
	return "BAYA_FLOR_REGADA"


## Limpia el estado de la parcela (cosechada).
func _resetear_parcela() -> void:
	_nombre_baya       = ""
	_etapa             = EEtapas.VACIA
	_tiempo_vivo       = 0
	_veces_regada      = 0
	_regada_esta_etapa = false
	_rendimiento       = 0
	_ts_actualizacion  = 0
	_guardar_estado()
	_actualizar_sprite()

# ──────────────────────────────────────────────────────────────────────────────
# VISUAL
# ──────────────────────────────────────────────────────────────────────────────

## Actualiza el sprite en el editor según baya_inicial y etapa_inicial.
## No depende del estado de runtime (_nombre_baya, _etapa).
func _actualizar_sprite_editor() -> void:
	var spr: AnimatedSprite2D = get_node_or_null("sprite")
	if spr == null:
		return
	if etapa_inicial == EEtapas.VACIA:
		spr.visible = false
		spr.stop()
		return
	var key: String = _enum_key_de(baya_inicial)
	if key == "":
		spr.visible = false
		spr.stop()
		return
	var path: String = "res://graficos/bayas/%s.tres" % key
	if not ResourceLoader.exists(path):
		push_warning("[ControladorBaya] SpriteFrames no encontrado: %s" % path)
		spr.visible = false
		spr.stop()
		return
	# PROCESS_MODE_ALWAYS garantiza que AnimatedSprite2D anime en el editor.
	spr.process_mode  = Node.PROCESS_MODE_ALWAYS
	spr.sprite_frames = load(path)
	spr.animation     = ANIM_ETAPAS[etapa_inicial]
	spr.visible       = true
	spr.play()


func _actualizar_sprite() -> void:
	if sprite == null:
		return
	if _nombre_baya == "" or _etapa == EEtapas.VACIA:
		sprite.visible = false
		return

	var path: String = "res://graficos/bayas/%s.tres" % _nombre_baya
	if not ResourceLoader.exists(path):
		push_warning("[ControladorBaya] SpriteFrames no encontrado: %s" % path)
		sprite.visible = false
		return

	sprite.sprite_frames = load(path)
	sprite.animation     = ANIM_ETAPAS[_etapa]
	sprite.visible       = true
	sprite.play()


## MovementType_BerryTreeGrowth_Step2..4: destello, 64 frames parpadeando con
## el gráfico anterior y otros 64 con el nuevo (la animación queda en pausa).
func _animar_cambio_etapa() -> void:
	if not is_inside_tree() or sprite == null:
		_actualizar_sprite()
		return
	_destellando = true
	crear_destello()
	sprite.pause()
	await _parpadear(FRAMES_PARPADEO)
	_actualizar_sprite()
	sprite.pause()
	await _parpadear(FRAMES_PARPADEO)
	_actualizar_sprite()
	_destellando = false


## Parpadeo de Step3/Step4: `invisible = (contador & 2) >> 1` a 60 fps.
func _parpadear(frames: int) -> void:
	var visible_base: bool = sprite.visible
	var tiempo: float = 0.0
	var contador: int = 0
	while contador <= frames:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		tiempo += get_process_delta_time()
		contador = int(tiempo * 60.0)
		sprite.visible = visible_base and (contador & 2) == 0
	sprite.visible = visible_base


## Crea el efecto FLDEFF_BERRY_TREE_GROWTH_SPARKLE sobre la parcela; se libera solo.
func crear_destello() -> AnimatedSprite2D:
	var frames: SpriteFrames = _frames_destello()
	if frames == null:
		return null
	var destello := AnimatedSprite2D.new()
	destello.name = "Destello"
	destello.sprite_frames = frames
	destello.position = POS_DESTELLO
	destello.z_index = 1
	destello.animation_finished.connect(destello.queue_free)
	add_child(destello)
	destello.play(&"destello")
	return destello


## gFieldEffectAnim_8374E38: frames 0-5 a 8 ticks, 4 vueltas a 4 ticks y otra
## a 8 ticks (≈3,2 s a 60 fps). Se construye una vez y se comparte.
static func _frames_destello() -> SpriteFrames:
	if _cache_frames_destello != null:
		return _cache_frames_destello
	var textura: Texture2D = load(RUTA_DESTELLO) as Texture2D
	if textura == null:
		push_warning("[ControladorBaya] No se pudo cargar %s" % RUTA_DESTELLO)
		return null
	var cuadros: Array[AtlasTexture] = []
	for i in range(FRAMES_DESTELLO):
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(i * TAM_FRAME_DESTELLO, 0, TAM_FRAME_DESTELLO, TAM_FRAME_DESTELLO)
		cuadros.append(atlas)
	var frames := SpriteFrames.new()
	frames.add_animation(&"destello")
	frames.set_animation_loop(&"destello", false)
	frames.set_animation_speed(&"destello", 60.0)
	for cuadro: AtlasTexture in cuadros:
		frames.add_frame(&"destello", cuadro, 8.0)
	for _vuelta in range(4):
		for cuadro: AtlasTexture in cuadros:
			frames.add_frame(&"destello", cuadro, 4.0)
	for cuadro: AtlasTexture in cuadros:
		frames.add_frame(&"destello", cuadro, 8.0)
	_cache_frames_destello = frames
	return frames

# ──────────────────────────────────────────────────────────────────────────────
# API PÚBLICA
# ──────────────────────────────────────────────────────────────────────────────

## Planta una baya sin tocar la mochila. [param nombre_baya] es la clave del
## enum, p.ej. "BAYA_ZIDRA". Devuelve false si no es una baya plantable.
func plantar(nombre_baya: String) -> bool:
	if not nombre_baya in ENBayas:
		push_warning("[ControladorBaya] Baya desconocida: '%s'" % nombre_baya)
		return false
	_plantar_interna(nombre_baya)
	_guardar_estado()
	_actualizar_sprite()
	return true


## Planta la baya `nombre_interno` (Objetos) gastando 1 del bolsillo de bayas
## (removeitem VAR_ITEM_ID, 1 + S_PlantBerryTree). Devuelve false si la
## parcela no está vacía, la baya no es plantable o el jugador no la tiene.
func plantar_baya_jugador(nombre_interno: String) -> bool:
	if not esta_vacia():
		return false
	var clave: String = enum_de_nombre_interno(nombre_interno)
	if clave == "":
		return false
	var objeto: String = nombre_interno.strip_edges().to_upper()
	if not SistemaGuardado.quitar_objeto_jugador(objeto, 1, BOLSILLO_BAYAS):
		return false
	return plantar(clave)


## Riega la planta (ObjectEventInteractionWaterBerryTree): marca como regada
## la etapa actual; volver a regar en la misma etapa no suma. Devuelve true
## si la planta está creciendo (etapas PLANTADA a FLOR).
func regar() -> bool:
	if not se_puede_regar():
		return false
	if not _regada_esta_etapa:
		_regada_esta_etapa = true
		_veces_regada      = mini(_veces_regada + 1, ETAPAS_CRECIMIENTO)
	_guardar_estado()
	return true


func se_puede_regar() -> bool:
	return _nombre_baya != "" and _etapa >= EEtapas.PLANTADA and _etapa <= EEtapas.FLOR


func esta_vacia() -> bool:
	return _nombre_baya == "" or _etapa == EEtapas.VACIA


## Cosecha (ObjectEventInteractionPickBerryTree + RemoveBerryTree): entrega
## el rendimiento ya calculado y deja la parcela vacía. Devuelve la cantidad
## entregada, o 0 si no estaba lista o no se pudo entregar (la parcela no se
## toca). A diferencia de Ruby no se comprueba si la mochila está llena.
func cosechar() -> int:
	if _etapa < EEtapas.FRUTO or _nombre_baya == "":
		return 0
	if _rendimiento <= 0:
		_rendimiento = _calcular_rendimiento()
		_guardar_estado()
	var cantidad: int = _rendimiento
	var nombre_interno: String = _get_nombre_interno_db()
	if nombre_interno == "":
		push_warning("[ControladorBaya] '%s' sin nombre_interno en la BD: no se cosecha." % _nombre_baya)
		return 0
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(nombre_interno, cantidad)
	if not bool(resultado.get("exito", false)):
		return 0
	_resetear_parcela()
	return cantidad


## Bayas que dará la cosecha (0 si aún no está en FRUTO).
func get_rendimiento() -> int:
	return _rendimiento


func get_etapa() -> int:
	return _etapa


## Devuelve el estado de la parcela como diccionario (para debug o UI externa).
func get_estado() -> Dictionary:
	return {
		"id_parcela":        id_parcela,
		"baya":              _nombre_baya,
		"etapa":             _etapa,
		"tiempo_vivo":       _tiempo_vivo,
		"veces_regada":      _veces_regada,
		"regada_esta_etapa": _regada_esta_etapa,
		"rendimiento":       _rendimiento,
	}


## Debug: adelanta el reloj de la planta `segundos` y recalcula la etapa.
func debug_saltar_tiempo(segundos: int) -> void:
	if esta_vacia() or _etapa >= EEtapas.FRUTO:
		return
	var ahora: int = int(Time.get_unix_time_from_system())
	if _ts_actualizacion <= 0:
		_ts_actualizacion = ahora
	_ts_actualizacion -= segundos
	_avanzar_crecimiento()
	_actualizar_sprite()


## Debug: fija la etapa (PLANTADA a FRUTO) con tiempo vivo y riegos coherentes.
func debug_fijar_etapa(etapa: int) -> void:
	if esta_vacia():
		return
	etapa = clampi(etapa, EEtapas.PLANTADA, EEtapas.FRUTO)
	if etapa == _etapa:
		return
	_etapa = etapa
	_tiempo_vivo = (etapa - EEtapas.PLANTADA) * _segundos_por_etapa()
	_ts_actualizacion = int(Time.get_unix_time_from_system())
	_veces_regada = mini(_veces_regada, etapa - EEtapas.PLANTADA)
	_regada_esta_etapa = false
	_rendimiento = _calcular_rendimiento() if etapa == EEtapas.FRUTO else 0
	_guardar_estado()
	_actualizar_sprite()
	crear_destello()


## PlayerHasBerries: ¿hay algo en el bolsillo de bayas?
static func jugador_tiene_bayas() -> bool:
	SistemaGuardado.inicializar_mochila_estructura()
	var bolsillos: Dictionary = SistemaGuardado.datos_vivos.mochila.bolsillos
	var clave: String = str(BOLSILLO_BAYAS)
	return bolsillos.has(clave) and not (bolsillos[clave].items as Array).is_empty()


## nombre_interno de la primera regadera que lleva el jugador ("" si ninguna).
static func regadera_del_jugador() -> String:
	for regadera: String in REGADERAS:
		if SistemaGuardado.tiene_objeto(regadera, 1, BOLSILLO_CLAVE):
			return regadera
	return ""


## Clave de ENBayas de un objeto por su nombre_interno ("" si no es plantable,
## p. ej. las bayas de 4ª generación de la BD).
static func enum_de_nombre_interno(nombre_interno: String) -> String:
	if nombre_interno.strip_edges() == "":
		return ""
	var datos: Dictionary = DatabaseManager.obtener_datos_objeto(nombre_interno.strip_edges())
	var id_objeto: int = int(datos.get("id", 0))
	if id_objeto <= 0:
		return ""
	var idx: int = ENBayas.values().find(id_objeto)
	return ENBayas.keys()[idx] if idx >= 0 else ""


## Parcela a la que mira el jugador en el mapa actual (null si no hay):
## equivalente a GetObjectEventScriptPointerPlayerFacing() == S_BerryTree.
static func parcela_frente_jugador() -> ControladorBaya:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return null
	var admin: Node = arbol.root.get_node_or_null("AdministradorMapa")
	if admin == null or admin.get("mapa_actual") == null or admin.get("jugador") == null:
		return null
	return admin.next_to_npc(admin.celda_frente_jugador()) as ControladorBaya

# ──────────────────────────────────────────────────────────────────────────────
# INTERACCIÓN OVERWORLD  (data/scripts/berry_tree.inc)
# ──────────────────────────────────────────────────────────────────────────────

## Punto de entrada desde AdministradorMapa.next_to_npc (A frente a la parcela).
func evento_accion() -> void:
	if not _preparar_interaccion():
		return
	if not esta_vacia() and _debug_activo() and not await _menu_debug():
		_cerrar_interaccion()
		return
	# Se recalcula al hablarle; el cambio se muestra sin animación.
	if not _destellando and _avanzar_crecimiento():
		_actualizar_sprite()
	if _destellando:
		# BERRY_STAGE_SPARKLING: "!" mientras dura el destello.
		await _mostrar(_texto("BAYA_DESTELLO"), true)
		_cerrar_interaccion()
	elif esta_vacia():
		_flujo_parcela_vacia()
	elif _etapa >= EEtapas.FRUTO:
		_flujo_cosechar()
	else:
		_flujo_creciendo()


## Continuación en el campo de USAR el CUBO WAILMER desde la mochila
## (S_WaterBerryTreeFromBag). El riego ya se aplicó en UsoObjetosCampo.
func mostrar_riego_desde_mochila() -> void:
	if not _preparar_interaccion():
		return
	await _mensajes_riego()
	_cerrar_interaccion()


## Continuación en el campo de USAR una BAYA desde la mochila frente a la
## parcela vacía (S_PlantBerryTreeFromBag). La baya ya se plantó.
func mostrar_plantada_desde_mochila() -> void:
	if not _preparar_interaccion():
		return
	await _mostrar(_texto("BAYA_PLANTADA"), true)
	_cerrar_interaccion()


func _debug_activo() -> bool:
	return _admin != null and _admin.has_method(&"debug_activo") and _admin.debug_activo()


## Menú debug del administrador (iniciar_debug). true = seguir con la interacción normal.
func _menu_debug() -> bool:
	var contenedor: Node = _admin.get_node_or_null("Menu")
	if contenedor == null:
		return true
	while true:
		var cabecera := PackedStringArray([
			"%s  ETAPA %d/5  RIEGOS %d%s" % [
				_nombre_corto_baya(), _etapa, _veces_regada, "  REGADA" if _regada_esta_etapa else "",
			],
		])
		match await MenuDebugLista.elegir(contenedor, OPCIONES_DEBUG, cabecera):
			0:
				return true
			1:
				debug_saltar_tiempo(SEGUNDOS_HORA)
			2:
				debug_saltar_tiempo(6 * SEGUNDOS_HORA)
			3:
				debug_fijar_etapa(_etapa - 1)
			4:
				debug_fijar_etapa(_etapa + 1)
			5:
				regar()
			_:
				return false
	return false


## Bloquea al jugador para un flujo de diálogo. false si no hay caja o ya hay uno.
func _preparar_interaccion() -> bool:
	if _interactuando:
		return false
	if _admin == null:
		_admin = get_tree().root.get_node_or_null("AdministradorMapa")
	if _admin == null or _admin.cuadro_dialogo == null:
		return false
	_interactuando = true
	Singleton.mantener_pausa(&"baya", true)
	if _admin.jugador:
		_admin.jugador.no_control = true
	return true


## Libera el control del jugador al terminar la interacción.
func _cerrar_interaccion() -> void:
	_interactuando = false
	if _admin == null:
		return
	# Cerrar el diálogo si sigue abierto (p. ej. tras un NO de preguntaSiNo).
	if _admin.cuadro_dialogo:
		_admin.cuadro_dialogo.cerrar()
	Singleton.mantener_pausa(&"baya", false)
	if _admin.jugador:
		_admin.jugador.no_control = false


## Muestra un mensaje y espera a que termine. cerrar = false deja la caja
## abierta para encadenar el siguiente (msgbox de Gen 3).
func _mostrar(texto: String, cerrar: bool = false, esperar_entrada: bool = true) -> void:
	var cuadro: NinePatchRect = _admin.cuadro_dialogo
	cuadro.mostrar(texto, esperar_entrada, cerrar, _mensaje_terminado.emit, false, cuadro.esta_activo)
	await _mensaje_terminado


## Pregunta SÍ/NO; cancelar equivale a NO.
func _preguntar_si_no(texto: String) -> bool:
	var cuadro: NinePatchRect = _admin.cuadro_dialogo
	# preguntaSiNo() exige IDLE: cerrar() y reabrir en el mismo frame no se ve.
	var continua: bool = cuadro.esta_activo
	cuadro.cerrar()
	cuadro.omitir_siguiente_sonido_inicio = continua
	cuadro.preguntaSiNo(texto)
	while true:
		var datos: Array = await cuadro.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false


## BerryTree_EventScript_1A153D: sin bayas sólo se describe la tierra.
func _flujo_parcela_vacia() -> void:
	if not jugador_tiene_bayas():
		await _mostrar(_texto("BAYA_TIERRA"), true)
		_cerrar_interaccion()
		return
	if not await _preguntar_si_no(_texto("BAYA_PREGUNTA_PLANTAR")):
		_cerrar_interaccion()
		return
	var nombre_interno: String = await _elegir_baya_en_mochila()
	if nombre_interno == "":
		_cerrar_interaccion()
		return
	if enum_de_nombre_interno(nombre_interno) == "":
		var nombre_objeto: String = str(SistemaGuardado.obtener_datos_objeto_completos(nombre_interno).get("nombre", nombre_interno))
		await _mostrar(_texto("BAYA_NO_PLANTABLE").replace("{objeto}", nombre_objeto), true)
		_cerrar_interaccion()
		return
	if plantar_baya_jugador(nombre_interno):
		await _mostrar(_texto("BAYA_PLANTADA"), true)
	_cerrar_interaccion()


## Berry_FadeAndGoToBerryBagMenu: abre la mochila fijada en el bolsillo de
## bayas y devuelve el nombre_interno elegido ("" si se cancela).
func _elegir_baya_en_mochila() -> String:
	var contenedor: Node = _admin.get_node_or_null("Menu")
	if contenedor == null:
		push_warning("[ControladorBaya] No se encontró el contenedor 'Menu' para abrir la mochila.")
		return ""
	_admin.cuadro_dialogo.cerrar()
	if _admin.jugador:
		_admin.jugador.no_control = true
	await Singleton.transicion("oscurecer")
	var mochila: MochilaUI = ESCENA_MOCHILA.instantiate() as MochilaUI
	contenedor.add_child(mochila)
	var eleccion: Dictionary = {"nombre_interno": ""}
	mochila.objeto_seleccionado_selector.connect(
		func(objeto: Dictionary) -> void: eleccion.nombre_interno = str(objeto.get("nombre_interno", ""))
	)
	mochila.activar_modo_selector(BOLSILLO_BAYAS, tr("BAYA_SELECTOR_CERRAR"), true)
	await mochila.mochila_cerrada
	contenedor.remove_child(mochila)
	mochila.queue_free()
	await Singleton.transicion("aclarar")
	return str(eleccion.nombre_interno)


## Etapas 1-4: mensaje de estado y, con regadera, pregunta de riego
## (BerryTree_EventScript_1A1595..1A15BC + 1A165F).
func _flujo_creciendo() -> void:
	var texto_estado: String
	match _etapa:
		EEtapas.PLANTADA: texto_estado = _texto("BAYA_ETAPA_PLANTADA")
		EEtapas.BROTE:    texto_estado = _texto("BAYA_ETAPA_BROTE")
		EEtapas.TALLO:    texto_estado = _texto("BAYA_ETAPA_TALLO")
		_:                texto_estado = _texto("BAYA_ETAPA_FLOR").replace("{estado}", tr(clave_estado_flor(_veces_regada)))
	var regadera: String = regadera_del_jugador()
	if regadera == "":
		await _mostrar(texto_estado, true)
		_cerrar_interaccion()
		return
	await _mostrar(texto_estado)
	var pregunta: String = _texto("BAYA_PREGUNTA_REGAR").replace("{objeto}", _nombre_objeto(regadera))
	if await _preguntar_si_no(pregunta):
		regar()
		await _mensajes_riego()
	_cerrar_interaccion()


## S_WaterBerryTree: "{PN} regó..." + animación de riego + "Parece sentarle...".
func _mensajes_riego() -> void:
	await _mostrar(_texto("BAYA_REGADA"), false, false)
	# DoWateringBerryTreeAnim: pose `regar_*` del jugador.
	var jugador: Node = _admin.jugador if _admin != null else null
	if jugador != null and jugador.has_method(&"animar_regar"):
		await jugador.animar_regar(ESPERA_ANIM_RIEGO)
	else:
		await get_tree().create_timer(ESPERA_ANIM_RIEGO).timeout
	await _mostrar(_texto("BAYA_REGADA_EFECTO"), true)


## BerryTree_EventScript_1A15F9: pregunta, cosecha con fanfarria o mensajes
## de bolsillo lleno / no recogidas.
func _flujo_cosechar() -> void:
	var clave_pregunta: String = "BAYA_PREGUNTA_RECOGER_UNA" if _rendimiento == 1 else "BAYA_PREGUNTA_RECOGER"
	if not await _preguntar_si_no(_texto(clave_pregunta)):
		await _mostrar(_texto("BAYA_SIN_RECOGER"), true)
		_cerrar_interaccion()
		return
	# Los textos se preparan antes de vaciar la parcela (necesitan la baya).
	var texto_recogidas: String = _texto("BAYA_RECOGIDA_UNA" if _rendimiento == 1 else "BAYA_RECOGIDAS")
	var texto_guardadas: String = _texto("BAYA_GUARDADAS")
	var texto_lleno: String = _texto("BAYA_BOLSILLO_LLENO")
	if cosechar() <= 0:
		await _mostrar(texto_lleno, true)
		_cerrar_interaccion()
		return
	# La parcela vacía destella (Step0 con animNum 4 → FLDEFF_BERRY_TREE_GROWTH_SPARKLE).
	crear_destello()
	# playfanfare MUS_OBTAIN_BERRY a la par del mensaje; el siguiente espera al jingle.
	var fanfarria: Dictionary = {"terminada": false}
	var tocar: Callable = func() -> void:
		await Fanfarria.reproducir(self, FANFARRIA_BAYA)
		fanfarria.terminada = true
	tocar.call()
	await _mostrar(texto_recogidas)
	while not bool(fanfarria.terminada) and is_inside_tree():
		await get_tree().process_frame
	await _mostrar(texto_guardadas, true)
	_cerrar_interaccion()

# ──────────────────────────────────────────────────────────────────────────────
# UTILIDADES PRIVADAS
# ──────────────────────────────────────────────────────────────────────────────

## Planta internamente sin guardar ni actualizar sprite.
func _plantar_interna(nombre_baya: String) -> void:
	_nombre_baya       = nombre_baya
	_etapa             = EEtapas.PLANTADA
	_tiempo_vivo       = 0
	_veces_regada      = 0
	_regada_esta_etapa = false
	_rendimiento       = 0
	_ts_actualizacion  = int(Time.get_unix_time_from_system())


## Obtiene la clave string del enum a partir de su valor int.
## Necesario para convertir el @export baya_inicial (int) en nombre de archivo.
func _enum_key_de(valor: int) -> String:
	var idx: int = ENBayas.values().find(valor)
	if idx >= 0:
		return ENBayas.keys()[idx]
	push_warning("[ControladorBaya] Valor de enum no encontrado: %d" % valor)
	return ""


## Obtiene el nombre_interno de la DB para la baya plantada (necesario para dar_objeto_jugador).
func _get_nombre_interno_db() -> String:
	if _nombre_baya == "" or not _nombre_baya in ENBayas:
		return ""
	var id_baya: int = ENBayas[_nombre_baya]
	return DatabaseManager.obtener_nombre_interno_objeto_por_id(id_baya)


## Nombre del objeto en la BD (p. ej. "CUBO WAILMER").
func _nombre_objeto(nombre_interno: String) -> String:
	return str(SistemaGuardado.obtener_datos_objeto_completos(nombre_interno).get("nombre", nombre_interno))


## Nombre de la baya sin "BAYA " (el {STR_VAR_1} de Ruby: "ZIDRA").
func _nombre_corto_baya() -> String:
	var nombre: String = _nombre_baya.replace("_", " ")
	var nombre_interno: String = _get_nombre_interno_db()
	if nombre_interno != "":
		nombre = _nombre_objeto(nombre_interno)
	return nombre.trim_prefix("BAYA ").strip_edges()


## Texto de dialogos.csv con {baya} y {n} ya sustituidos ({PN} lo resuelve la caja).
func _texto(clave: String) -> String:
	return tr(clave).replace("{baya}", _nombre_corto_baya()).replace("{n}", str(_rendimiento))


## Handler para el evento global "buscar_evento_accion" de Singleton.gd.
## Sólo llega aquí si la parcela no cuelga de "NPCs" (si no, la acciona next_to_npc).
func _on_singleton_buscar_evento(celda_accion: Vector2i, mapa_origen: Node) -> void:
	var administrador := get_tree().root.get_node_or_null("AdministradorMapa")
	var mapa_propietario := get_parent().get_parent() if get_parent() else null
	if administrador == null or administrador.mapa_actual != mapa_origen or mapa_propietario != mapa_origen:
		return
	if celda_accion == coord:
		evento_accion()
