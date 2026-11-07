extends Node2D
class_name BattleSceneController

const DatosInicioBatallaScript = preload("res://escenas/batalla/datos_inicio_batalla.gd")
const BattleAIIntegratorScene = preload("res://scripts/battle_ai/battle_ai_integrator.gd")
const BattleItemEvaluator = preload("res://scripts/battle_ai/ItemEvaluator.gd")
const BattleCaptureService = preload("res://escenas/batalla/battle_capture_service.gd")
const BallThrowAnimator = preload("res://escenas/batalla/battle_ball_throw_animator.gd")
## Tema de temas_musicales.json que suena al atrapar (pokeruby MUS_CAUGHT).
const TEMA_CAPTURA := "CAPTURA_POKEMON"
## Combate tutorial de BLASCO: su sprite de espaldas (graphics/trainers/wally_back.png).
const SPRITE_BLASCO_ESPALDA := "res://escenas/batalla/blasco_espalda.tres"
const NOMBRE_BLASCO := "BLASCO"
## WallyHandleActions: PLACAJE en los dos primeros turnos y POKé BALL en el tercero,
## cada elección tras B_WAIT_TIME_LONG (64 fotogramas).
const TURNOS_PLACAJE_TUTORIAL := 2
const ESPERA_TUTORIAL_BLASCO := 64.0 / 60.0
const PokemonCombatState = preload("res://scripts/pokemon_en_combate.gd")
const CuadroSubirNivelScene = preload("res://escenas/batalla/cuadro_subir_nivel.tscn")
const ESCENA_DESTELLOS_VARIOCOLOR: PackedScene = preload("res://escenas/batalla/destellos_variocolor.tscn")
const CRY_BASE_PATH := "res://Audio/SE/Cries/"
## sub_8046AD0 (pokeball.c): el grito suena 4 cuadros después de abrirse la ball.
const RETARDO_GRITO_SALIDA := 4.0 / 60.0
const TAMANIO_PANTALLA_BATALLA := Vector2(240, 160)
const DURACION_CAIDA_DEBILITADO := 0.35
const DESPLAZAMIENTO_CAIDA_DEBILITADO := 28.0
const DURACION_FADE_SALIDA := 0.4
const DURACION_ANIMACION_EXP := 0.75
## Pausa tras un mensaje que no pide confirmación (pokeruby `waitmessage 64`,
## 64 frames a 60 fps).
const PAUSA_MENSAJE_BATALLA := 64.0 / 60.0
## Primer combate (BATTLE_TYPE_FIRST_BATTLE): BattleText_BirchDontLeaveMe al
## intentar huir y BattleText_FledWild cuando el salvaje huye.
const TEXTO_NO_ME_DEJES := "PROF. ABEDUL: ¡N-no me\ndejes aquí así!"
## El sufijo "salvaje" lo pone `BasePokemon.get_nombre_combate()`.
const TEXTO_SALVAJE_HUYO := "¡%s\nhuyó!"
const SE_HUIDA: AudioStream = preload("res://Audio/BGS/Flee.WAV")

## La lógica de aplicación de movimientos de estado (antes varios métodos
## nombrados aquí) vive ahora en `StatusEffectResolver`
## (escenas/batalla/status_effect_resolver.gd, SDD
## 2026-09-14-move-effect-resolver, etapa 2) — ya no en este archivo.

@export_file("*.json") var archivo_positions_json: String = "res://escenas/batalla/battle_positions.json"
@export var saltar_animaciones: bool = false

@onready var cortina_arriba: ColorRect = $CortinaArriba
@onready var cortina_abajo: ColorRect = $CortinaAbajo
@onready var fondo_batalla: Sprite2D = $Campo/btlFondo
@onready var caja_texto: CajaTextoBatalla = $UI/CajaDialogo/RichTextLabel
@onready var cursor: AnimatedSprite2D = $UI/CajaDialogo/Cursor
@onready var suelo_arriba: Sprite2D = $Campo/btlSueloArriba
@onready var suelo_abajo: Sprite2D = $Campo/btlSueloAbajo
@onready var btlDecoFrente: Node2D = $Campo/btlDecoFrente
@onready var sprite_prota: AnimatedSprite2D = $Campo/btlJugador
@onready var sprite_rival: AnimatedSprite2D = $Campo/btlRival
@onready var soporte_balls_arriba: Node2D = $UI/SoporteBallsArriba
@onready var soporte_balls_abajo: Node2D = $UI/SoporteBallsAbajo
@onready var nodo_iconos_pokeball: Node2D = $UI/IconosPokeball
@onready var slot_rival: BattleSlot = $Campo/btlSueloArriba/SlotRival1
@onready var slot_rival_secundario: BattleSlot = $Campo/btlSueloArriba/SlotRival2
@onready var slot_jugador: BattleSlot = $Campo/btlSueloAbajo/SlotJugador1
@onready var slot_jugador_secundario: BattleSlot = $Campo/btlSueloAbajo/SlotJugador2
@onready var spr_pokemon_rival: Sprite2D = slot_rival.sprite_pokemon
@onready var spr_pokemon_jugador: Sprite2D = slot_jugador.sprite_pokemon
## `cuadro_ps_jugador`/`cuadro_ps_rival` viven en `hud` (ver
## battle_hud_controller.gd) desde la Etapa 2. La Etapa 2 dejó aquí un shim
## de compatibilidad de solo lectura mientras las Etapas 3/4 reapuntaban los
## call sites externos uno por uno a `hud.*`; con esa migración completa (ver
## tasks.md Etapas 3/4), el shim se retiró en la Etapa 4 — sin llamadores
## restantes, confirmado por grep repo-wide (tasks.md 5.1).
@onready var poke_ball_rival: PokeballSprite2 = slot_rival.pokeball
@onready var poke_ball_jugador: PokeballSprite2 = slot_jugador.pokeball
@onready var cuadro_ps_rival_1: Node2D = $UI/CuadroPSRival1
@onready var cuadro_ps_rival_2: Node2D = $UI/CuadroPSRival2
@onready var cuadro_ps_jugador_1: Node2D = $UI/CuadroPSJugador1
@onready var cuadro_ps_jugador_2: Node2D = $UI/CuadroPSJugador2
## Caja compacta del slot principal del jugador en doble (pokeruby usa
## gBattleWindowSmall2Gfx para los dos battlers del jugador: sin PS numéricos
## ni barra de EXP). La del slot secundario ya es compacta en la escena.
@onready var cuadro_ps_jugador_1_doble: Node2D = $UI/CuadroPSJugador1Doble
@onready var marcador_objetivo_rival_1: Line2D = $UI/CuadroPSRival1/MarcadorObjetivo1
@onready var marcador_objetivo_rival_2: Line2D = $UI/CuadroPSRival2/MarcadorObjetivo2
@onready var marcador_objetivo_jugador_1: Line2D = $UI/CuadroPSJugador1/MarcadorObjetivo1
@onready var marcador_objetivo_jugador_2: Line2D = $UI/CuadroPSJugador2/MarcadorObjetivo2
@onready var marcador_objetivo_jugador_1_doble: Line2D = $UI/CuadroPSJugador1Doble/MarcadorObjetivo1
@onready var iluminacion_campo: ColorRect = $Campo/IluminacionCampo
@onready var animacion_intro: AnimationPlayer = $AnimIntro
## Second AnimationPlayer dedicado a la Pokeball del jugador durante la intro
## salvaje. Mantenerlo separado del `animacion_intro` principal es lo que
## permite reproducir la animación "cae_pokeball_y_sale_pokemon" en paralelo
## con "2. Jugador lanza pokeball" del AnimationPlayer raíz: un único
## AnimationPlayer no puede reproducir dos animaciones a la vez. Disparo la
## animación de este reproductor desde el Call Method Track de la
## animación 2 a t=0.62 (`_iniciar_caida_pokeball`).
@onready var pkb_anim: AnimationPlayer = $PkbAnim

var emisor_particulas: Resource = preload("res://graficos/emisor.tscn")

var shader_pokemon_rival: PokemonBattleShaderController
var shader_pokemon_jugador: PokemonBattleShaderController
var reproductor_grito: AudioStreamPlayer
var overlay_fade_salida: ColorRect

const posiciones: Dictionary = {
	"cortina_arriba_inicial": Vector2(0, 0),
	"cortina_arriba_final": Vector2(0, -80),
	"cortina_abajo_inicial": Vector2(0, 80),
	"cortina_abajo_final": Vector2(0, 160),
	"frente_inicial": Vector2(0, 32),
	"suelo_arriba_inicial": Vector2(-128, 48),
	"suelo_arriba_final": BattleLayout.SUELO_ARRIBA_FINAL,
	"sprite_rival_inicial": Vector2(-96, 8),
	"sprite_rival_final": Vector2(144, 8),
	"sprite_rival_salida": Vector2(260, 8),
	"suelo_abajo_inicial": Vector2(240, 101),
	"suelo_abajo_final": BattleLayout.SUELO_ABAJO_FINAL,
	"sprite_prota_inicial": Vector2(288, 48),
	"sprite_prota_final": Vector2(48, 48),
	"sprite_prota_salida": Vector2(-64, 48),
	"gancho_arriba_inicial": Vector2(-160, 40),
	"gancho_arriba_final": Vector2(-56, 40),
	"gancho_arriba_salida": Vector2(0, 40),
	"gancho_abajo_inicial": Vector2(240, 96),
	"gancho_abajo_final": Vector2(136, 96),
	"gancho_abajo_salida": Vector2(80, 96),
	"icono_pb_rival_inicial": Vector2(-32, 32),
	"icono_pb_rival_final": Vector2(76, 32),    # Solo la primera pokeball, las siguientes estarán a la izquierda cada 6 píxeles
	"icono_pb_rival_salida": Vector2(272, 32),
	"icono_pb_jugador_inicial": Vector2(272, 88),
	"icono_pb_jugador_final": Vector2(156, 88),   # Solo la primera pokeball, las siguientes estarán a la derecha cada 6 píxeles
	"icono_pb_jugador_salida": Vector2(-32, 88),
	"pokemon_rival_inicial": Vector2(-96, 22),		# Bulbasaur como referencia
	"pokemon_rival_final": Vector2(144, 22),
	"pokemon_jugador_inicial": Vector2(272, 48),
	"pokemon_jugador_final": Vector2(32, 48),
	"cuadro_ps_rival_inicial": Vector2(-120, 6),
	"cuadro_ps_rival_final": Vector2(13, 6),
	"cuadro_ps_jugador_inicial": Vector2(246, 74),
	"cuadro_ps_jugador_final": Vector2(126, 74),
	# Intro salvaje (coreografía propia: el prota queda 3px a la izquierda). La
	# tira de entrada (frente) la mueve AnimacionEntradaBatalla según el terreno.
	"sprite_prota_final_salvaje": Vector2(45, 48),
	# Slots secundarios de la batalla doble.
	"pokemon_jugador2_final": Vector2(50, 56),
	"pokemon_rival2_final": Vector2(120, 14),
	"pokemon_rival_rel_suelo": BattleLayout.SLOT_RIVAL_REL_SUELO,
	"pokemon_rival2_rel_suelo": BattleLayout.SLOT_RIVAL2_REL_SUELO,
	"pokemon_jugador_rel_suelo": BattleLayout.SLOT_JUGADOR_REL_SUELO,
	"pokemon_jugador2_rel_suelo": BattleLayout.SLOT_JUGADOR2_REL_SUELO,
	# En doble el slot principal también se desplaza (gUnknown_0837F578).
	"pokemon_rival_doble_rel_suelo": BattleLayout.SLOT_RIVAL_DOBLE_REL_SUELO,
	"pokemon_jugador_doble_rel_suelo": BattleLayout.SLOT_JUGADOR_DOBLE_REL_SUELO,
	# Cuadros de PS en batalla doble (pokeruby, sub_8043F44): centro del sprite
	# 64x32 menos (32,16), más el ajuste del arte de Godot medido en simple
	# (jugador (158,88) -> (126,74)). Rival: (44,19) y (32,44); jugador:
	# (159,77) y (171,102).
	"cuadro_ps_rival_doble_final": Vector2(13, 5),
	"cuadro_ps_rival2_final": Vector2(1, 30),
	"cuadro_ps_jugador_doble_final": Vector2(127, 63),
	"cuadro_ps_jugador2_final": Vector2(139, 88),
	# StartHealthboxSlideIn: los cuadros entran desde 115 px fuera de su sitio.
	"cuadro_ps_desplazamiento_entrada": Vector2(115, 0)
}

# Nota: las constantes de color/offset de aparición y de la fila de iconos de
# pokéball viven ahora en battle_intro_controller.gd (Etapa 1, SDD
# 2026-09-14-battle-architecture-split).

var iconos_rival: Array[AnimatedSprite2D] = []
var iconos_jugador: Array[AnimatedSprite2D] = []

## Etapa 2 (SDD 2026-09-15-battle-launch-service): mapeo_temas_texturas,
## mapeo_temas_texturas_frente y _resolver_tema_grafico_frente() se movieron a
## BattleLaunchService (owner compartido con configuracion_debug_batalla.gd/
## ventana_debug_batalla.gd, antes réplicas manuales). Ver
## escenas/batalla/battle_launch_service.gd.

var tipo_batalla: Singleton.TipoBatalla = Singleton.TipoBatalla.SALVAJE
## Plan 20260912 (Alcance 1): formato del combate (SIMPLE/DOBLE).
var formato_batalla: Singleton.FormatoBatalla = Singleton.FormatoBatalla.SIMPLE
## Ruleset efectivo. SIN_EQUIPO no viene en los datos: se deriva de
## batalla_sin_pokemon (equipo vacío o todos DEBILITADOS).
var ruleset_batalla: Singleton.RulesetBatalla = Singleton.RulesetBatalla.NORMAL
## Balls temporales de zona salvaje (memoria separada de la mochila).
var balls_zona_disponibles: int = 0

var tween: Tween
var tween2: Tween
var tween_b: Tween

var t: float = 0.0
var duration: float = 1
var rota: float = 0


# Data seam: battle setup reads Pokemon data through DatabaseManager instead of
# opening its own SQLite connection. Injectable for tests via inyectar_proveedor_datos().
var proveedor_datos = DatabaseManager

func inyectar_proveedor_datos(p) -> void:
	proveedor_datos = p

## Instancia del pokémon actual del jugador
var poke_jugador: BasePokemon
## Instancia del pokémon actual del enemigo/salvaje
var poke_enemigo: BasePokemon

# Nuevas variables para equipos múltiples
var equipo_jugador_pokemones: Array[BasePokemon] = []
var equipo_enemigo_pokemones: Array[BasePokemon] = []
var pokemones_activos_jugador: Array[BasePokemon] = []
var pokemones_activos_enemigo: Array[BasePokemon] = []
## Relevos ya colocados por `_reponer_slots_dobles` que aún no salieron de su ball.
var envios_dobles_pendientes: Array[Dictionary] = []
var combatientes_activos: Dictionary = {}
var equipo_jugador_participantes_exp: Array[BasePokemon] = []
## gSentPokesToOpponent[1]: en dobles, cada rival lleva su propia lista.
var equipo_jugador_participantes_exp_flanco2: Array[BasePokemon] = []
var indice_pokemon_jugador: int = 0
## Orden de las cajas de la pantalla de equipo en batalla
## (gBattlePartyCurrentOrder): los activos delante y, en cada cambio, el que se
## retira ocupa la caja del que entra. No reordena equipo_jugador_pokemones.
var orden_visual_equipo: Array[BasePokemon] = []
## gBattleStruct->runTries: intentos de huida previos en este combate.
var intentos_huida: int = 0
const OBJETO_BOLA_DE_HUMO := "BOLADEHUMO"
const EFECTOS_OBJETOS_X = preload("res://scripts/objetos/efectos_objetos_x.gd")
var indice_pokemon_enemigo: int = 0
var batalla_sin_pokemon: bool = false
## BATTLE_TYPE_FIRST_BATTLE (DatosInicioBatalla.es_primer_combate()).
var primer_combate: bool = false
## BATTLE_TYPE_WALLY_TUTORIAL (DatosInicioBatalla.es_tutorial_blasco()).
var tutorial_blasco: bool = false
## BATTLE_TYPE_BATTLE_TOWER (DatosInicioBatalla.EXTRA_TORRE_BATALLA).
var torre_batalla: bool = false
## BATTLE_TYPE_ROAMER (DatosInicioBatalla.EXTRA_ERRANTE): el salvaje huye (AI_Roaming).
var errante: bool = false
var objeto_mochila_batalla: Dictionary = {}

## Battle phase state. Etapa 5 (parcial, SDD 2026-09-14-battle-architecture-split),
## renombrado en el SDD `2026-09-15-battle-flow-and-hud-controllers` (Etapa 1,
## Decisión D1): la máquina de estados vive en su propia clase
## (battle_phase_controller.gd), instanciada en _ready(). Read sites (`fase == X`,
## `match fase`) stay source-compatible via the getter-backed properties below;
## write sites go through `fases.cambiar_fase(X)` / `fases.avanzar_subfase_inicio()` /
## `fases.reiniciar_subfase_inicio()`.
## Sin dependencia de `self` (a diferencia de intro_controller/presentacion):
## inicializado inline, igual que `maquina` antes de esta etapa, para que
## instancias sueltas de batalla.gd (fuera del árbol de escena) sigan
## teniendo `fase`/`fases.cambiar_fase(...)` utilizables — patrón del que
## dependen los tests de caracterización (ver test/batalla/handlers_estado_test.gd).
var fases := BattlePhaseController.new()

## Per-battle immutable item-effect snapshots; payload keys use Ruby source banks.
const HeldItemEffectProvider=preload("res://scripts/battle/held_item_effect_provider.gd")
var held_item_effects: HeldItemEffectProvider=HeldItemEffectProvider.new()

func configure_held_item_effects(data: DatosInicioBatalla) -> bool:
	if data==null:return false
	return held_item_effects.configure(data.extras.get("enigma_saved_profile",null),data.extras.get("enigma_link_profiles",{}),data.extras.get("enigma_bank_overrides",{}))


func _init() -> void:
	fases.maquina.fase_cambiada.connect(_al_cambiar_fase_presentacion_sustituto)

func _al_cambiar_fase_presentacion_sustituto(_anterior: int, nueva: int) -> void:
	if nueva==FIN_BATALLA:_retirar_presentaciones_sustituto()

func _retirar_presentaciones_sustituto() -> void:
	bank_damage_history.clear()
	# FIN retires bank-bound seed and side hazards, even without scene exit.
	field_rules.clear()
	screen_rules.clear()
	safeguard_rules.clear()
	dust_weather_rules.clear()
	healing_stream_rules.clear()
	BattleHeldItemRules.clear(self)
	held_item_effects.configure()
	preload("res://scripts/battle/recycle_rules.gd").clear(self)
	# DisableStruct's Stockpile counter retires with battle authority, not art.
	for state: PokemonEnCombate in [combatiente_jugador,combatiente_enemigo]:
		BattleStockpileRules.retire(state);BattleTransformRules.retire(state)
		BattleRampageRules.retire(state)
		BattleCounterRules.retire(state)
		field_rules.retire(state)
		if state!=null:state.cancelar_continuacion();state.retire_body_attacks()
	for state in combatientes_activos.values():
		if state is PokemonEnCombate:
			BattleStockpileRules.retire(state);BattleTransformRules.retire(state)
			BattleRampageRules.retire(state)
			BattleCounterRules.retire(state)
			state.cancelar_continuacion();state.retire_body_attacks()
	var field: Node=get_node_or_null("Campo")
	if field==null:return
	for node: Node in field.find_children("*","",true,false):
		if node is BattleSlot:
			BattleSubstitutePresentation.retire(node);BattleTransformPresentation.retire(node)

func _retirar_sustituto_de_pokemon(pokemon: BasePokemon) -> void:
	if pokemon==null:return
	var state: PokemonEnCombate=_obtener_combatiente(pokemon)
	if state!=null:
		state.substitute_hp=0
		state.retire_body_attacks()
		BattleStockpileRules.retire(state)
		BattleRampageRules.retire(state)
		BattleCounterRules.retire(state)
		if pokemon.estad_ps_actual<=0:BattleTransformRules.retire(state)
	if hud!=null:
		var slot: BattleSlot=hud._obtener_slot_de_pokemon(pokemon)
		if slot!=null:
			BattleSubstitutePresentation.retire(slot);BattleTransformPresentation.retire(slot)

## Etapa 5.2 (SDD 2026-09-14-battle-architecture-split): resolución de turno
## a turno (selección de acción, orden, ataques, IA enemiga). A diferencia de
## intro_controller/presentacion, necesita soportar instancias sueltas (ver
## test/batalla/handlers_estado_test.gd, que llama a
## `b.turno._evaluar_accion_antes_de_moverse(...)` sobre un `batalla.gd` sin
## `_ready()`), así que se inicializa inline pasándose `self` — igual que
## `fases`, salvo que sí depende de `self` porque necesita la referencia `_b`.
var turno := BattleTurnController.new(self)

## Habilidades en combate (entrada, fin de ronda, salida, presentación de sus
## efectos). Inline como `turno`: solo guarda la referencia a `self`.
var habilidades := BattleAbilityController.new(self)
var bank_damage_history := preload("res://scripts/battle/bank_damage_history.gd").new(self)
var field_rules := BattleFieldEffects.new(self)
var screen_rules := BattleScreenRules.new(self)
var safeguard_rules := BattleSafeguardRules.new(self)
var healing_stream_rules := BattleHealingStreamRules.new(self)
var dust_weather_rules := BattleDustWeatherRules.new(self)

## Animación del lanzamiento de POKé BALL al rival (battle_ball_throw_animator.gd).
## Inline como `turno`: no toca nodos hasta que se lanza una ball.
var lanzamiento_ball = BallThrowAnimator.new(self)

## Etapa 5.3 (SDD 2026-09-14-battle-architecture-split): victoria/derrota/
## captura, EXP/subida de nivel, y cambio de Pokémon del jugador. A diferencia
## de `turno`/`fases`, ningún test lo usa sobre una instancia suelta, así que
## se instancia en `_ready()` — igual que `intro_controller`/`presentacion`.
var resultado: BattleResultController

## Etapa 1 (SDD 2026-09-14-battle-architecture-split): la intro vive en su
## propia clase. Instanciado en _ready(); ver battle_intro_controller.gd.
var intro_controller: BattleIntroController

## Animación de la tira de entrada (btlDecoFrente) por terreno, como
## StartBattleIntroAnim de Rubí. Hijo creado en _ready(); la arranca la intro.
var animacion_entrada: AnimacionEntradaBatalla

## Etapa 4 (SDD 2026-09-14-battle-architecture-split): menús, caja de texto
## y mochila viven en su propia clase. Instanciado en _ready(); ver
## battle_presentation_controller.gd.
var presentacion: BattlePresentationController

## Etapa 2 (SDD 2026-09-15-battle-flow-and-hud-controllers): dueño de los
## cuadros de PS/EXP/nivel y del cosmético de wiggle. Igual que
## `resultado`/`intro_controller`/`presentacion`, ningún test lo usa sobre
## una instancia suelta, así que se instancia en `_ready()`; ver
## battle_hud_controller.gd.
var hud: BattleHudController
var sirena_ps_bajos: SirenaPsBajos

const INICIO := MaquinaEstadosBatalla.Fase.INICIO
const INPUT := MaquinaEstadosBatalla.Fase.INPUT
const RONDA := MaquinaEstadosBatalla.Fase.RONDA
const CAMBIO_POKEMON := MaquinaEstadosBatalla.Fase.CAMBIO_POKEMON
const FIN_BATALLA := MaquinaEstadosBatalla.Fase.FIN_BATALLA
var fase: int : get = _get_fase
func _get_fase() -> int: return fases.fase

const INI_SUELO := MaquinaEstadosBatalla.SubfaseInicio.INI_SUELO
const INI_ICONOS_POKEBALL := MaquinaEstadosBatalla.SubfaseInicio.INI_ICONOS_POKEBALL
const INI_RIVAL_SALE := MaquinaEstadosBatalla.SubfaseInicio.INI_RIVAL_SALE
const INI_JUGADOR_SALE := MaquinaEstadosBatalla.SubfaseInicio.INI_JUGADOR_SALE
var subfase_inicio: int : get = _get_subfase_inicio
func _get_subfase_inicio() -> int: return fases.subfase_inicio

var scn_menu1 = preload("res://escenas/batalla/batalla_menu_1.tscn")
var timer_pkm_actual = Timer.new()
## El objeto `Timer` sigue aquí (inicializado inline, como antes) para que
## instancias sueltas de `batalla.gd` puedan liberarlo sin `_ready()` — ver
## la nota de cabecera de `battle_hud_controller.gd` (Etapa 2, resolución
## del riesgo de instancia suelta). El comportamiento del wiggle
## (`_on_timer_cuadro_ps_timeout()`) vive en `hud`; este campo solo se
## arranca/detiene a través de `hud.iniciar_timer_ps()`/`hud.detener_timer_ps()`.
var timer_cuadro_ps = Timer.new()
var timer_pkm_actual_cambio: bool = false

enum { LUCHA, POKEMON, MOCHILA, HUIDA }

# Control para evitar input fantasma al regresar de pantallas
var ignorar_input_temporal: bool = false

var scn_menu_movs = preload("res://escenas/batalla/batalla_menu_mov.tscn")

# Pantalla de equipo
var _scn_pantalla_equipo: PackedScene
var scn_pantalla_equipo: PackedScene:
	get:
		# Resolve after script initialization; UI combat types also refer to this scene.
		if _scn_pantalla_equipo == null:
			_scn_pantalla_equipo = load("res://UI/equipo/pantalla-equipo.tscn") as PackedScene
		return _scn_pantalla_equipo

enum { MOV1, MOV2, MOV3, MOV4 }

var movimiento_jugador: Movimiento
var movimiento_enemigo: Movimiento
var movimiento_jugador_primario_doble: Movimiento
var movimiento_jugador_secundario: Movimiento
var movimiento_enemigo_secundario: Movimiento
var slot_jugador_seleccionado: int = 0
var accion_enemiga: Dictionary = {}
var accion_enemiga_secundaria: Dictionary = {}
var seleccionando_objetivo_doble: bool = false
var bloquear_confirmacion_objetivo_doble: bool = false
var indice_objetivo_doble: int = 0
var objetivos_doble: Array[BasePokemon] = []
var objetivo_jugador_primario_doble: BasePokemon
var objetivo_jugador_secundario_doble: BasePokemon

const PRIORIDADES := MaquinaEstadosBatalla.FaseRonda.PRIORIDADES
const TURNO_JUGADOR := MaquinaEstadosBatalla.FaseRonda.TURNO_JUGADOR
const TURNO_ENEMIGO := MaquinaEstadosBatalla.FaseRonda.TURNO_ENEMIGO
const REVISAR_RONDA := MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA
var fase_ronda: int : get = _get_fase_ronda
func _get_fase_ronda() -> int: return fases.fase_ronda
var turno_jugador_pasado: bool = false
var turno_enemigo_pasado: bool = false
var mensaje_inicio_entrenador: String = "¡A luchar contra\n{CLASE_ENTRENADOR} {NOMBRE_ENTRENADOR}!"
var mensaje_rival_envia: String = "¡{NOMBRE_POKEMON} es el POKéMON enviado\npor {CLASE_ENTRENADOR} {NOMBRE_ENTRENADOR}!"
## Textos de la ROM española para la intro doble (BattleText_SentOutDouble1 y
## BattleText_SentOutDouble4): el rival nombra primero a su 2.º Pokémon.
var mensaje_rival_envia_doble: String = "¡{NOMBRE_POKEMON_2} y {NOMBRE_POKEMON} son la opción\nde {CLASE_ENTRENADOR} {NOMBRE_ENTRENADOR}!"
var mensaje_jugador_envia_doble: String = "¡Adelante, {NOMBRE_POKEMON} y\n{NOMBRE_POKEMON_2}!"
var _fase_input_token: int = 0
var mensaje_que_hacer: String = "¿Qué debería hacer\n{NOMBRE_POKEMON}?"

## Callback a ejecutar cuando termine el combate
var callback_batalla: Callable = Callable()
var _resultado_notificado: bool = false
## Pokémon del jugador que subieron de nivel en este combate (gLeveledUpInBattle).
## OverworldBattleManager los intenta evolucionar al ganar (TryEvolvePokemon).
var pokemon_subieron_nivel: Array[BasePokemon] = []

## {"tipo": Singleton.TipoBatalla,
## "formato": Singleton.FormatoBatalla,
## "ruleset": Singleton.RulesetBatalla,
## "tema_grafico": Singleton.TemaBatalla,
## "tema_grafico_frente": Singleton.TemaBatallaFrente,
## "entrenador": DatosEntrenador,
## "pokemon_salvaje": { "nombre_interno": String, "nivel": int },
## "equipo_jugador": Array[BasePokemon],
## "ubicacion": String,  # clave de lugar (Lugares), p. ej. "RUTA_113"
## "puede_huir": bool,
## "permite_captura": bool,
## "comentario": String }
var configuracion_batalla: DatosInicioBatalla = null
var datos_batalla: Dictionary = {}
var ai_integrador: RefCounted
var contador_turnos: int = 0
var auto_iniciar_prueba: bool = true
## Clima activo durante la batalla. Se lee de DatosInicioBatalla al arrancar;
## los movimientos de clima (Día Soleado, Lluvia, etc.) lo cambiarían aquí.
var clima_activo: Singleton.ClimaBatalla = Singleton.ClimaBatalla.NINGUNO
## Clima con el que arrancó la batalla (overworld o configuración). Se anuncia
## una sola vez antes de las habilidades de entrada y luego queda en NINGUNO.
var clima_inicial: Singleton.ClimaBatalla = Singleton.ClimaBatalla.NINGUNO
var combatiente_jugador: PokemonEnCombate
var combatiente_enemigo: PokemonEnCombate

# Evita que _restaurar_orden_original_equipo() se llame dos veces (p.ej. al salir)
var _orden_restaurado: bool = false

# Variables para modo de prueba independiente
var modo_prueba: bool = false
var datos_prueba: Dictionary = {}

## ============================================================================
## FUNCIONES AUXILIARES DE INICIALIZACIÓN
## ============================================================================

func _ready():
	print("[BATALLA] _ready() inicio — frame: %d" % Engine.get_process_frames())
	# Configuración inicial
	visible = false
	intro_controller = BattleIntroController.new(self)
	animacion_entrada = AnimacionEntradaBatalla.new()
	animacion_entrada.name = "AnimacionEntrada"
	add_child(animacion_entrada)
	presentacion = BattlePresentationController.new(self)
	resultado = BattleResultController.new(self)
	hud = BattleHudController.new(self)
	_configurar_interfaz_slots()
	hud.inicializar()
	sirena_ps_bajos = SirenaPsBajos.new(self)
	add_child(sirena_ps_bajos)

	# 2. UI y menús
	_inicializar_interfaces()

	# 3. Timers
	_configurar_timers()

	# 4. Señales
	_conectar_senales()

	# 5. Recursos
	_inicializar_escena()

	# Cargar dos del JSON de posiciones
	_cargar_json_positions()

	# Detectar modo de prueba
	_detectar_modo_prueba()

	print("[BATALLA] _ready() fin — cuadro_ps_rival válido: %s — frame: %d" % [str(hud != null and is_instance_valid(hud.cuadro_ps_rival)), Engine.get_process_frames()])

	# Seteamos los shaders
	call_deferred("_inicializar_shaders")

	# Configurar manejo de input para editor de posiciones
	# set_process_input(true)

## Los slots contienen el Pokémon y la Pokéball; los elementos de HUD viven
## en la rama UI. Se conectan aquí para conservar una API simple en BattleSlot
## sin acoplarlo a rutas relativas frágiles hacia la raíz de la escena.
func _configurar_interfaz_slots() -> void:
	slot_rival.configurar_interfaz(cuadro_ps_rival_1, marcador_objetivo_rival_1)
	slot_rival_secundario.configurar_interfaz(cuadro_ps_rival_2, marcador_objetivo_rival_2)
	slot_jugador.configurar_interfaz(cuadro_ps_jugador_1, marcador_objetivo_jugador_1)
	slot_jugador_secundario.configurar_interfaz(cuadro_ps_jugador_2, marcador_objetivo_jugador_2)
	for slot: BattleSlot in [slot_rival, slot_rival_secundario, slot_jugador, slot_jugador_secundario]:
		slot.aparicion_iniciada.connect(_al_salir_de_la_ball.bind(slot))
		slot.aparicion_terminada.connect(iniciar_destellos_variocolor.bind(slot))


## Salida desde la Poké Ball (jugador, rival y cambios): grito de la especie.
func _al_salir_de_la_ball(slot: BattleSlot) -> void:
	reproducir_grito(_pokemon_de_slot(slot), RETARDO_GRITO_SALIDA)


func _pokemon_de_slot(slot: BattleSlot) -> BasePokemon:
	if slot == slot_jugador:
		return poke_jugador
	if slot == slot_rival:
		return poke_enemigo
	var activos: Array[BasePokemon] = pokemones_activos_jugador if slot == slot_jugador_secundario else pokemones_activos_enemigo
	return activos[1] if activos.size() > 1 else null


## TryShinyAnimation: destellos del Pokémon del slot si es variocolor y se ve su sprite. Por defecto, el Pokémon
## activo del slot; las entradas de dobles que aún no lo fijaron lo pasan. Devuelve la escena, o null si no hay.
func iniciar_destellos_variocolor(slot: BattleSlot, pokemon: BasePokemon = null) -> Node2D:
	var ocupante: BasePokemon = pokemon if pokemon != null else _pokemon_de_slot(slot)
	if ocupante == null or not ocupante.es_shiny() or not slot.sprite_pokemon.visible:
		return null
	var campo: Node2D = get_node(^"Campo") as Node2D
	var destellos: Node2D = ESCENA_DESTELLOS_VARIOCOLOR.instantiate() as Node2D
	destellos.z_index = EfectoMovimientoNativo.z_absoluto(slot.sprite_pokemon) + 1
	destellos.z_as_relative = false
	campo.add_child(destellos)
	destellos.iniciar(AnimacionEscenaNativa._base(campo, slot, slot.sprite_pokemon), slot.es_jugador, BattleLayout.TAM_CAMPO)
	slot.destellos_variocolor = destellos
	return destellos


## Los controladores de la ROM no siguen hasta finishedShinyMonAnim. Sin variocolor vuelve en el acto.
func esperar_destellos_variocolor(slot: BattleSlot, pokemon: BasePokemon = null) -> void:
	var ocupante: BasePokemon = pokemon if pokemon != null else _pokemon_de_slot(slot)
	if ocupante != null and ocupante.es_shiny():
		await slot.esperar_destellos_variocolor()


## Grito de la especie en un reproductor propio, para que dos salidas seguidas
## (dobles) no se corten entre sí. El de debilitamiento usa `reproductor_grito`.
func reproducir_grito(pokemon: BasePokemon, retardo: float = 0.0) -> void:
	var ruta: String = resultado._obtener_ruta_grito_pokemon(pokemon)
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return
	var stream := load(ruta) as AudioStream
	if stream == null:
		return
	if retardo > 0.0:
		await get_tree().create_timer(retardo).timeout
		if not is_inside_tree():
			return
	var reproductor := AudioStreamPlayer.new()
	reproductor.bus = "Master"
	reproductor.stream = stream
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor)
	reproductor.play()

## Instancia y configura todos los menús e interfaces.
func _inicializar_interfaces():
	presentacion.inicializar(caja_texto, cursor, scn_menu1, scn_menu_movs, scn_pantalla_equipo)
	_crear_reproductor_grito()
	_crear_overlay_fade_salida()
	hud._crear_panel_subida_nivel()

	print("✅ [BATALLA] Interfaces inicializadas y preinstanciadas")

func _crear_reproductor_grito() -> void:
	if is_instance_valid(reproductor_grito):
		return
	reproductor_grito = AudioStreamPlayer.new()
	reproductor_grito.name = "ReproductorGrito"
	reproductor_grito.bus = "Master"
	add_child(reproductor_grito)

func _crear_overlay_fade_salida() -> void:
	if is_instance_valid(overlay_fade_salida):
		return
	overlay_fade_salida = ColorRect.new()
	overlay_fade_salida.name = "OverlayFadeSalida"
	overlay_fade_salida.visible = false
	overlay_fade_salida.position = Vector2.ZERO
	overlay_fade_salida.size = TAMANIO_PANTALLA_BATALLA
	overlay_fade_salida.color = Color.BLACK
	overlay_fade_salida.modulate.a = 0.0
	overlay_fade_salida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_fade_salida.z_index = 200
	add_child(overlay_fade_salida)

## Configura y añade los timers al árbol de nodos.
func _configurar_timers():
	# Timer para movimiento del Pokémon actual
	timer_pkm_actual.wait_time = 0.4
	timer_pkm_actual.one_shot = false
	add_child(timer_pkm_actual)
	timer_pkm_actual.stop()

	# Timer para movimiento del cuadro de PS
	timer_cuadro_ps.wait_time = 0.3
	timer_cuadro_ps.one_shot = false
	add_child(timer_cuadro_ps)
	timer_cuadro_ps.stop()
	print("✅ [BATALLA] Timers configurados")

## Conectar todas las señales necesarias.
func _conectar_senales():
	# Conectar timers
	timer_pkm_actual.connect("timeout", Callable(self, "_on_timer_pkm_actual_timeout"))
	timer_cuadro_ps.connect("timeout", Callable(hud, "_on_timer_cuadro_ps_timeout"))

	# Conectar señales del Singleton
	Singleton.connect("batalla_menu1_seleccionado", Callable(self, "_on_batalla_menu_1_seleccionado"))
	Singleton.connect("batalla_movimiento_seleccionado", Callable(turno, "_on_batalla_movimiento_seleccionado"))

	# Conectar señales de la pantalla de equipo
	presentacion.pantalla_equipo.connect("pokemon_elegido", Callable(resultado, "_on_pokemon_seleccionado"))
	presentacion.pantalla_equipo.connect("seleccion_cancelada", Callable(resultado, "_on_seleccion_cancelada"))

	print("✅ [BATALLA] Señales conectadas")

## Inicializa la escena de batalla. Elementos visuales.
func _inicializar_escena():
	presentacion.set_texto_instantaneo("")

	# Inicializamos posiciones
	cortina_arriba.position = posiciones.get("cortina_arriba_inicial")
	cortina_abajo.position = posiciones.get("cortina_abajo_inicial")
	suelo_arriba.position = posiciones.get("suelo_arriba_inicial")
	suelo_abajo.position = posiciones.get("suelo_abajo_inicial")
	btlDecoFrente.position = posiciones.get("frente_inicial")
	sprite_prota.position = posiciones.get("sprite_prota_inicial")
	sprite_rival.position = posiciones.get("sprite_rival_inicial")
	hud.posicionar_cuadros_ps_inicial()

	# Elementos que se usan siempre
	cortina_arriba.visible = true
	cortina_abajo.visible = true
	fondo_batalla.visible = true
	suelo_arriba.visible = true
	suelo_abajo.visible = true

	# Elementos dinámicos u opcionales
	btlDecoFrente.visible = false
	sprite_prota.visible = false
	sprite_rival.visible = false
	spr_pokemon_rival.visible = false
	spr_pokemon_jugador.visible = false
	hud.ocultar_cuadros_ps()
	soporte_balls_arriba.visible = false
	soporte_balls_abajo.visible = false
	nodo_iconos_pokeball.visible = false
	cursor.visible = false
	slot_rival.ocultar()
	slot_rival_secundario.ocultar()
	slot_jugador.ocultar()
	slot_jugador_secundario.ocultar()
	iluminacion_campo.visible = false

	print("✅ [BATALLA] Escena de batalla inicializada")

func _inicializar_shaders():
	loggear("Inicializando shaders de batalla")
	shader_pokemon_rival = slot_rival.shader_pokemon
	shader_pokemon_jugador = slot_jugador.shader_pokemon

var pos_poke: Dictionary
## Cargar posiciones de los Pokémon desde un archivo JSON.
func _cargar_json_positions():
	var file = FileAccess.open(archivo_positions_json, FileAccess.READ)
	if not file:
		print("❌ [BATALLA] No se pudo abrir el archivo de posiciones JSON: %s" % archivo_positions_json)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		print("❌ [BATALLA] Error al parsear JSON de posiciones: %s" % json.error_string)
		return

	var json_data = json.data
	if not json_data is Dictionary:
		print("❌ [BATALLA] JSON no contiene un diccionario válido")
		return

	# Limpiar el diccionario anterior
	pos_poke.clear()

	# Cargar las posiciones en el formato esperado
	for pokemon_name in json_data.keys():
		var pokemon_data = json_data[pokemon_name]

		# Verificar que tiene la estructura correcta
		if not pokemon_data.has("player_offset") or not pokemon_data.has("enemy_offset"):
			print("⚠️ [BATALLA] Pokémon %s no tiene estructura correcta, saltando" % pokemon_name)
			continue

		# Guardar los offsets como Vector2 en pos_poke
		pos_poke[pokemon_name] = {
			"player_offset": Vector2(
				pokemon_data.player_offset.x,
				pokemon_data.player_offset.y
			),
			"enemy_offset": Vector2(
				pokemon_data.enemy_offset.x,
				pokemon_data.enemy_offset.y
			),
			# Clave opcional: solo un booleano `true` activa la sombra; ausente (o de
			# otro tipo) = false. No se compara con `== true`: float == bool es un error.
			"sombra": _es_bandera_activa(pokemon_data.get("sombra", false))
		}

	print("✅ [BATALLA] Posiciones cargadas desde JSON: %d Pokémon" % pos_poke.size())

## Offset visual local del Pokémon según el lado de la batalla.
func obtener_offset_pokemon(nombre_pokemon: String, es_jugador: bool = true) -> Vector2:
	if pos_poke.is_empty():
		_cargar_json_positions()
	if not pos_poke.has(nombre_pokemon):
		return Vector2.ZERO
	var clave := "player_offset" if es_jugador else "enemy_offset"
	return pos_poke[nombre_pokemon].get(clave, Vector2.ZERO)

## true si la especie tiene activada la sombra bajo el Pokémon (`sombra` en
## battle_positions.json; por defecto false).
func obtener_sombra_pokemon(nombre_pokemon: String) -> bool:
	if pos_poke.is_empty():
		_cargar_json_positions()
	if not pos_poke.has(nombre_pokemon):
		return false
	return _es_bandera_activa(pos_poke[nombre_pokemon].get("sombra", false))

func _es_bandera_activa(valor: Variant) -> bool:
	return valor is bool and valor

func aplicar_offset_a_slot(slot: BattleSlot, pokemon: BasePokemon, es_jugador: bool) -> void:
	if pokemon == null:
		slot.fijar_sombra_activa(false)
		return
	slot.fijar_offset_pokemon(obtener_offset_pokemon(pokemon.nombre_interno, es_jugador))
	# En el campo del jugador la sombra quedaría fuera de la pantalla: nunca se muestra.
	slot.fijar_sombra_activa(not es_jugador and obtener_sombra_pokemon(pokemon.nombre_interno))

## Sprite, posición y sombra de la forma `forma` (`NOMBRE_n`; 0 = base). Es solo de
## la escena: al entrar otra vez, el slot vuelve a cargar `nombre_interno`.
func aplicar_forma_a_slot(slot: BattleSlot, pokemon: BasePokemon, forma: int) -> void:
	var es_jugador: bool = slot == slot_jugador or slot == slot_jugador_secundario
	var nombre: String = pokemon.nombre_interno if forma <= 0 else "%s_%d" % [pokemon.nombre_interno, forma]
	cargar_sprite_pokemon_seguro(slot.sprite_pokemon, nombre, not es_jugador, pokemon.es_shiny())
	slot.fijar_offset_pokemon(obtener_offset_pokemon(nombre, es_jugador))
	slot.fijar_sombra_activa(not es_jugador and obtener_sombra_pokemon(nombre))

## ============================================================================
## API PÚBLICA. Punto de entrada para iniciar una batalla.
## ============================================================================

## API Pública. Inicia una batalla con animaciones fade out.
func _iniciar_batalla_con_transicion(datos_ini: Dictionary, callback_finalizacion: Callable = Callable()) -> void:
	var configuracion: DatosInicioBatalla = DatosInicioBatallaScript.desde_diccionario(datos_ini)
	await iniciar_batalla_con_configuracion(configuracion, callback_finalizacion)

func iniciar_batalla_con_configuracion(datos_ini: DatosInicioBatalla, callback_finalizacion: Callable = Callable()) -> bool:
	print("[BATALLA] 4️⃣ iniciar_batalla_con_configuracion() — frame: %d — is_node_ready: %s — cuadro_ps_rival válido: %s" % [Engine.get_process_frames(), str(is_node_ready()), str(hud != null and is_instance_valid(hud.cuadro_ps_rival))])
	if datos_ini == null:
		push_error("[BATALLA] DatosInicioBatalla es null")
		return false
	var errores_validacion: PackedStringArray = datos_ini.obtener_errores_validacion()
	if not errores_validacion.is_empty():
		push_error("[BATALLA] DatosInicioBatalla inválidos: %s" % ", ".join(errores_validacion))
		return false

	if not configure_held_item_effects(datos_ini):return false

	# El add_child viene de _process (árbol bloqueado), por lo que Godot lo difiere.
	# La MessageQueue (call_deferred) se vacía ANTES que la cola de nodos pendientes,
	# así que _ready() puede no haber corrido todavía. Esperamos aquí.
	if not is_node_ready():
		print("[BATALLA] ⏳ Esperando ready() — frame: %d" % Engine.get_process_frames())
		await ready
		print("[BATALLA] ✅ ready() completado — frame: %d — cuadro_ps_rival válido: %s" % [Engine.get_process_frames(), str(hud != null and is_instance_valid(hud.cuadro_ps_rival))])

	# Guardar callback para después de la transición
	callback_batalla = callback_finalizacion
	_resultado_notificado = false
	configuracion_batalla = datos_ini
	datos_batalla = datos_ini.a_diccionario()
	# En juego normal la música ya fue resuelta por OverworldBattleManager. El
	# lanzador de depuración no marca este extra y conserva su camino autónomo.
	if not bool(datos_ini.extras.get("musica_gestionada_overworld", false)):
		_reproducir_musica_batalla_mapa_si_corresponde()

	# gBattleResults se pone a cero al empezar cada combate.
	ResultadosCombate.reiniciar()
	# Configurar datos específicos de esta batalla
	_configurar_datos_batalla()

	visible = true
	# Iniciar animaciones o saltar según configuración
	if saltar_animaciones:
		_aplicar_texturas_basicas()
		_configurar_batalla_sin_animaciones()
		if batalla_sin_pokemon and tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
			# Plan 20260912 (tipo 6): la derrota inmediata también aplica
			# cuando se saltan las animaciones.
			await derrota_inmediata_sin_equipo()
		else:
			fase_input()
	else:
		print("No se saltan animaciones")
		_aplicar_texturas_basicas()
		_aplicar_texturas_transicion()
		await get_tree().create_timer(0.5).timeout
		poke_ball_jugador.visible = false
		intro_controller.ejecutar()
	return true


## Único punto de salida del resultado. Protege el contrato exactamente-una-vez.
func notificar_resultado(resultado: ResultadoBatalla.Valor) -> void:
	if _resultado_notificado:
		push_warning("[BATALLA] Se ignoró un segundo resultado: %s" % resultado)
		return
	_resultado_notificado = true
	# HandleEndTurn_FinishBattle: especies del jugador en el campo (gBattleResults).
	ResultadosCombate.registrar_fin(pokemones_activos_jugador if formato_batalla == Singleton.FormatoBatalla.DOBLE else [poke_jugador])
	var callback := callback_batalla
	callback_batalla = Callable()
	if callback.is_valid():
		callback.call(resultado)

## Aplica las texturas básicas (sin animaciones)
func _aplicar_texturas_basicas() -> void:

	# Fondo y suelo: escenario resuelto como en Rubí (DrawMainBattleBackground) o,
	# si no viene (lanzador de depuración), el mapeo legado del tema gráfico.
	var texturas = _rutas_escenario()
	if texturas.is_empty():
		var tema = datos_batalla.get("tema_grafico", Singleton.TemaBatalla.EDIFICIO_1)
		texturas = BattleLaunchService.MAPEO_TEMAS_TEXTURAS.get(tema, {})
	if texturas:
		var textura_fondo = load(texturas.get("fondo", ""))
		var textura_suelo = load(texturas.get("suelo", ""))
		if textura_fondo:
			fondo_batalla.texture = textura_fondo
		if textura_suelo:
			suelo_arriba.texture = textura_suelo
			suelo_abajo.texture = textura_suelo

	# Cargar sprites de los Pokémon actuales
	actualizar_sprites_batalla()

## Rutas {fondo, suelo, entrada} del escenario de los datos de batalla, o {} si
## no trae escenario (se usa entonces el mapeo legado de BattleLaunchService).
func _rutas_escenario() -> Dictionary:
	var escenario := str(datos_batalla.get("escenario", ""))
	if escenario.is_empty():
		return {}
	return EscenarioBatalla.rutas(escenario)

## gBattleTerrain del combate (EscenarioBatalla.Terreno) para la animación de
## la tira de entrada: el de los datos o, si no viene, el deducido del escenario
## o del tema gráfico legado (BattleLaunchService.resolver_terreno_datos).
func obtener_terreno_batalla() -> EscenarioBatalla.Terreno:
	return BattleLaunchService.resolver_terreno_datos(datos_batalla)

## Aplica las texturas para la transición inicial
func _aplicar_texturas_transicion() -> void:

	# Frente (entrada) del campo de batalla: LoadBattleEntryBackground según el
	# escenario o, sin él, el mapeo legado del tema gráfico.
	var textura_frente_path: String = str(_rutas_escenario().get("entrada", ""))
	if textura_frente_path.is_empty():
		var tema_frente = datos_batalla.get("tema_grafico_frente", BattleLaunchService.resolver_tema_grafico_frente(datos_batalla.get("tema_grafico", Singleton.TemaBatalla.EDIFICIO_1)))
		textura_frente_path = BattleLaunchService.MAPEO_TEMAS_TEXTURAS_FRENTE.get(tema_frente, "")
	if textura_frente_path != "":
		var textura_frente = load(textura_frente_path)
		if textura_frente:
			# Remover sprites anteriores si existen
			for child in btlDecoFrente.get_children():
				child.queue_free()
			# Crear y añadir nuevos sprites
			for i in range(4):
				var spr_frente = Sprite2D.new()
				spr_frente.name = "Frente%d" % (i + 1)
				spr_frente.texture = textura_frente
				spr_frente.centered = false
				spr_frente.position = Vector2(i * 256, 0)
				btlDecoFrente.add_child(spr_frente)
			btlDecoFrente.visible = true

	# Ajustar textura del jugador
	var sexo_jugador = SistemaGuardado.datos_vivos.jugador.get("sexo", "M")
	var textura_prota: SpriteFrames = null
	if bool(datos_batalla.get(DatosInicioBatallaScript.EXTRA_TUTORIAL_BLASCO, false)):
		textura_prota = load(SPRITE_BLASCO_ESPALDA)  # WallyHandleDrawTrainerPic
	else:
		match sexo_jugador:
			"M": textura_prota = load("res://escenas/batalla/jugador_masculino.tres")
			"F": textura_prota = load("res://escenas/batalla/jugador_femenino.tres")
			_: textura_prota = load("res://escenas/batalla/jugador_masculino.tres")
	sprite_prota.sprite_frames = textura_prota
	sprite_prota.visible = true

	if poke_jugador != null:
		var bola_jugador := poke_jugador.encuentro_bola if not poke_jugador.encuentro_bola.is_empty() else "POKEBALL"
		slot_jugador.configurar_pokeball(bola_jugador)
	else:
		slot_jugador.pokeball.visible = false

	# Ajustes para batalla contra entrenador
	if tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		sprite_rival.visible = true
		var entrenador: DatosEntrenador = datos_batalla.get("entrenador", null)
		if entrenador:
			var total_frames = sprite_rival.sprite_frames.get_frame_count(sprite_rival.animation)
			if entrenador.num_sprite < total_frames:
				sprite_rival.frame = entrenador.num_sprite
			else:
				sprite_rival.frame = 0  # Fallback si el índice es inválido
				print("⚠️ [BATALLA] num_sprite fuera de rango, usando frame 0")
		else:
			print("❌ [BATALLA] Error: No se encontraron datos del entrenador")

		var bola_rival := poke_enemigo.encuentro_bola if not poke_enemigo.encuentro_bola.is_empty() else "POKEBALL"
		slot_rival.configurar_pokeball(bola_rival)

	# Ajustes para batalla contra salvaje
	else:
		sprite_rival.visible = true

## Configura solo los datos específicos de esta batalla
func _configurar_datos_batalla() -> void:
	contador_turnos = 0
	primer_combate = bool(datos_batalla.get(DatosInicioBatallaScript.EXTRA_PRIMER_COMBATE, false))
	tutorial_blasco = bool(datos_batalla.get(DatosInicioBatallaScript.EXTRA_TUTORIAL_BLASCO, false))
	errante = bool(datos_batalla.get(DatosInicioBatallaScript.EXTRA_ERRANTE, false))
	torre_batalla = bool(datos_batalla.get(DatosInicioBatallaScript.EXTRA_TORRE_BATALLA, false))
	caja_texto.confirmacion_automatica = bool(datos_batalla.get(DatosInicioBatallaScript.EXTRA_TEXTOS_AUTOMATICOS, false))
	ai_integrador = null
	accion_enemiga = {}
	movimiento_jugador = null
	movimiento_enemigo = null
	combatiente_jugador = null
	combatiente_enemigo = null
	equipo_jugador_participantes_exp.clear()
	equipo_jugador_participantes_exp_flanco2.clear()

	# Crear equipos de forma segura verificando que los Pokémon existan
	print("=== Inicializando equipos de batalla ===")

	# El equipo del jugador puede venir explícitamente desde la escena de prueba.
	equipo_jugador_pokemones = _obtener_equipo_jugador_para_batalla()

	# Guardar orden original del equipo y reorganizar si es necesario
	_guardar_orden_original_equipo()
	_reorganizar_equipo_para_batalla()
	orden_visual_equipo.clear()
	intentos_huida = 0

	# Verificar si hay datos de batalla. Inicializamos equipo_enemigo_pokemones.
	if datos_batalla.size() > 0:

		match datos_batalla.get("tipo", Singleton.TipoBatalla.SALVAJE_TEST):
			Singleton.TipoBatalla.SALVAJE_TEST:
				print("🐾 [BATALLA] Batalla de prueba contra Pokémon salvaje")
				# Crear equipo con un solo Pokémon salvaje de prueba
				equipo_enemigo_pokemones = crear_equipo_salvaje("EEVEE", 5)
				tipo_batalla = Singleton.TipoBatalla.SALVAJE

			Singleton.TipoBatalla.SALVAJE:
				print("🐾 [BATALLA] Batalla contra Pokémon salvaje")
				var equipo_prebuilt_s: Array = datos_batalla.get("equipo_rival", [])
				if not equipo_prebuilt_s.is_empty():
					equipo_enemigo_pokemones.clear()
					for pokemon in equipo_prebuilt_s:
						if pokemon is BasePokemon:
							equipo_enemigo_pokemones.append(pokemon)
				else:
					var pokemon_salvaje = datos_batalla.get("pokemon_salvaje", {})
					var nombre_interno = pokemon_salvaje.get("nombre_interno", "EEVEE")
					var nivel = pokemon_salvaje.get("nivel", 5)
					var snapshot_salvaje: Dictionary = pokemon_salvaje.get("snapshot", {})
					equipo_enemigo_pokemones = crear_equipo_salvaje(nombre_interno, nivel, snapshot_salvaje)
				tipo_batalla = Singleton.TipoBatalla.SALVAJE

			# BattleIntegrationManager.TipoBatalla.ENTRENADOR_RUTA, BattleIntegrationManager.TipoBatalla.ENTRENADOR_LIDER, BattleIntegrationManager.TipoBatalla.ENTRENADOR_ELITE, BattleIntegrationManager.TipoBatalla.ENTRENADOR_CAMPEON:
			Singleton.TipoBatalla.ENTRENADOR:
				print("👨‍💼 [BATALLA] Batalla contra entrenador")
				var equipo_prebuilt_e: Array = datos_batalla.get("equipo_rival", [])
				if not equipo_prebuilt_e.is_empty():
					equipo_enemigo_pokemones.clear()
					for pokemon in equipo_prebuilt_e:
						if pokemon is BasePokemon:
							equipo_enemigo_pokemones.append(pokemon)
				else:
					var entrenador: DatosEntrenador = datos_batalla.get("entrenador", null)
					if entrenador:
						equipo_enemigo_pokemones = crear_equipo_desde_entrenador(entrenador)
					else:
						print("❌ [BATALLA] Error: No se encontraron datos del entrenador")
						equipo_enemigo_pokemones = crear_equipo_seguro(["EEVEE"], "")
				tipo_batalla = Singleton.TipoBatalla.ENTRENADOR
			_:
				print("⚠️ [BATALLA] Tipo de batalla desconocido, usando equipo por defecto")
				equipo_enemigo_pokemones = crear_equipo_seguro(["EEVEE"], "")
				tipo_batalla = Singleton.TipoBatalla.SALVAJE

	else:
		print("🎮 [BATALLA] Sin datos específicos, generando batalla por defecto")
		# El equipo enemigo se sigue generando localmente para la batalla
		var enemigo_preferidos = ["EEVEE"]
		equipo_enemigo_pokemones = crear_equipo_seguro(enemigo_preferidos, "")
		tipo_batalla = Singleton.TipoBatalla.SALVAJE

	# Todo el equipo rival (salvaje, entrenador, equipos ya construidos como los
	# del lanzador de depuración u OverworldBattleManager) lleva su etiqueta de
	# combate durante toda la batalla: decide "salvaje"/"enemigo" en los mensajes.
	for rival in equipo_enemigo_pokemones:
		etiquetar_pokemon_rival(rival)

	if tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		var entrenador_configurado: DatosEntrenador = datos_batalla.get("entrenador", null)
		if entrenador_configurado:
			_configurar_ia_entrenador(entrenador_configurado)

	# El rival siempre necesita un Pokémon, pero el jugador puede entrar sin equipo.
	if equipo_enemigo_pokemones.size() == 0:
		print("❌ Error: No se pudo crear el equipo enemigo")
		return
	batalla_sin_pokemon = equipo_jugador_pokemones.is_empty()

	# Plan 20260912 (Alcance 1): formato y ruleset viajan en los datos de inicio.
	formato_batalla = int(datos_batalla.get("formato", Singleton.FormatoBatalla.SIMPLE))
	ruleset_batalla = int(datos_batalla.get("ruleset", Singleton.RulesetBatalla.NORMAL))
	if batalla_sin_pokemon:
		ruleset_batalla = Singleton.RulesetBatalla.SIN_EQUIPO
	elif ruleset_batalla == Singleton.RulesetBatalla.SIN_EQUIPO:
		ruleset_batalla = Singleton.RulesetBatalla.NORMAL
	_seleccionar_cuadro_ps_jugador_principal()
	balls_zona_disponibles = int(datos_batalla.get("balls_zona", 0)) if ruleset_batalla == Singleton.RulesetBatalla.ZONA_SALVAJE else 0
	clima_activo = int(datos_batalla.get("clima", Singleton.ClimaBatalla.NINGUNO))
	clima_inicial = clima_activo

	# Validar que los índices sean válidos
	if indice_pokemon_enemigo >= equipo_enemigo_pokemones.size():
		indice_pokemon_enemigo = 0
	if not batalla_sin_pokemon and indice_pokemon_jugador >= equipo_jugador_pokemones.size():
		indice_pokemon_jugador = 0

	# Asignar pokemones actuales para compatibilidad con código existente
	poke_enemigo = equipo_enemigo_pokemones[indice_pokemon_enemigo]
	if not batalla_sin_pokemon:
		poke_jugador = equipo_jugador_pokemones[indice_pokemon_jugador]
		resultado._registrar_participante_experiencia(poke_jugador)
	_configurar_pokemones_activos()
	_reiniciar_estados_combate_activos()
	if formato_batalla == Singleton.FormatoBatalla.DOBLE:
		for participante in pokemones_activos_jugador:
			resultado._registrar_participante_experiencia(participante)

	# Validar que los pokemones asignados no sean nulos
	if poke_enemigo == null:
		print("❌ Error: Pokemon enemigo es nulo")
		return

	# El cuadro de PS del rival se configura siempre: la intro lo muestra también
	# en batallas sin equipo (tipos 5 y 6).
	iniciar_cuadro_enemigo(poke_enemigo)

	if batalla_sin_pokemon:
		print("👤 Batalla iniciada sin Pokémon del jugador")
		return
	if poke_jugador == null:
		print("❌ Error: Pokemon jugador es nulo")
		return

	print("Equipo enemigo: ", equipo_enemigo_pokemones.size(), " pokemones")
	print("Equipo jugador: ", equipo_jugador_pokemones.size(), " pokemones")
	print("Pokemon actual enemigo: ", poke_enemigo.nombre_interno)
	print("Pokemon actual jugador: ", poke_jugador.nombre_interno)

	# Validar coherencia de todos los Pokémon creados
	validar_coherencia_pokemones()

	# Verificar sprites disponibles para los equipos
	verificar_sprites_equipos()

	# Configurar cuadro de PS del jugador específico para esta batalla
	iniciar_cuadro_jugador(poke_jugador)

## Marca a `pokemon` como rival de esta batalla según `tipo_batalla` (SALVAJE →
## "salvaje", ENTRENADOR → "enemigo"). Usar también con cualquier Pokémon que se
## añada al equipo rival una vez empezada la batalla. Las etiquetas reservadas
## (DOMINANTE, OSCURO) las pondrá quien las implemente, tras llamar a esto.
func etiquetar_pokemon_rival(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	if tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		pokemon.etiqueta_combate = BasePokemon.EtiquetaCombate.ENTRENADOR
	else:
		pokemon.etiqueta_combate = BasePokemon.EtiquetaCombate.SALVAJE

func _obtener_equipo_jugador_para_batalla() -> Array[BasePokemon]:
	var equipo_desde_datos = datos_batalla.get("equipo_jugador", [])
	if equipo_desde_datos is Array and not equipo_desde_datos.is_empty():
		var equipo_copiado: Array[BasePokemon] = []
		for pokemon in equipo_desde_datos:
			if pokemon is BasePokemon:
				equipo_copiado.append(pokemon.duplicate())
		if not equipo_copiado.is_empty():
			return equipo_copiado
	return SistemaGuardado.get_equipo()

func _configurar_pokemones_activos() -> void:
	pokemones_activos_jugador.clear()
	pokemones_activos_enemigo.clear()

	var cantidad_slots := 2 if formato_batalla == Singleton.FormatoBatalla.DOBLE else 1
	if not batalla_sin_pokemon:
		for pokemon in equipo_jugador_pokemones:
			if pokemon != null and pokemon.puede_combatir():
				pokemones_activos_jugador.append(pokemon)
				if pokemones_activos_jugador.size() >= cantidad_slots:
					break
	for pokemon in equipo_enemigo_pokemones:
		if pokemon != null and pokemon.estad_ps_actual > 0:
			pokemones_activos_enemigo.append(pokemon)
			if pokemones_activos_enemigo.size() >= cantidad_slots:
				break

	for pokemon in pokemones_activos_enemigo:
		_registrar_rival_visto(pokemon)
	if not pokemones_activos_enemigo.is_empty():
		poke_enemigo = pokemones_activos_enemigo[0]
	if not pokemones_activos_jugador.is_empty():
		poke_jugador = pokemones_activos_jugador[0]

	for slot: BattleSlot in [slot_rival, slot_jugador]:
		if is_instance_valid(slot) and slot.is_node_ready():
			slot.fijar_posicion_relativa_al_suelo(posicion_slot_rel_suelo(slot))
	_configurar_slot_secundario(
		pokemones_activos_jugador, slot_jugador_secundario, true,
		posicion_slot_rel_suelo(slot_jugador_secundario), posicion_final_cuadro_ps(slot_jugador_secundario)
	)
	_configurar_slot_secundario(
		pokemones_activos_enemigo, slot_rival_secundario, false,
		posicion_slot_rel_suelo(slot_rival_secundario), posicion_final_cuadro_ps(slot_rival_secundario)
	)

## El slot principal del jugador usa la caja grande en simple y la compacta en
## doble. Se elige al conocer el formato, antes de configurar el Pokémon.
func _seleccionar_cuadro_ps_jugador_principal() -> void:
	var doble := formato_batalla == Singleton.FormatoBatalla.DOBLE
	var cuadro: Node2D = cuadro_ps_jugador_1_doble if doble else cuadro_ps_jugador_1
	if slot_jugador.cuadro_ps == cuadro:
		return
	var anterior: Node2D = slot_jugador.cuadro_ps
	slot_jugador.configurar_interfaz(cuadro, marcador_objetivo_jugador_1_doble if doble else marcador_objetivo_jugador_1)
	cuadro.position = anterior.position
	anterior.visible = false
	if hud:
		hud.cuadro_ps_jugador = cuadro

## Posición de `slot` relativa a su suelo según el formato: en doble los slots
## principales también se apartan para dejar sitio a los secundarios.
func posicion_slot_rel_suelo(slot: BattleSlot) -> Vector2:
	var doble := formato_batalla == Singleton.FormatoBatalla.DOBLE
	if slot == slot_jugador_secundario:
		return posiciones.get("pokemon_jugador2_rel_suelo")
	if slot == slot_rival_secundario:
		return posiciones.get("pokemon_rival2_rel_suelo")
	if slot == slot_rival:
		return posiciones.get("pokemon_rival_doble_rel_suelo" if doble else "pokemon_rival_rel_suelo")
	return posiciones.get("pokemon_jugador_doble_rel_suelo" if doble else "pokemon_jugador_rel_suelo")

## Ancla de `slot` en coordenadas del campo con los suelos en su sitio final.
func posicion_campo_slot(slot: BattleSlot) -> Vector2:
	var suelo: Vector2 = posiciones.get("suelo_abajo_final" if slot.es_jugador else "suelo_arriba_final")
	return suelo + posicion_slot_rel_suelo(slot)

## Posición final del cuadro de PS de `slot`: en batalla doble los cuadros
## principales también cambian de sitio para dejar hueco a los secundarios.
func posicion_final_cuadro_ps(slot: BattleSlot) -> Vector2:
	var doble := formato_batalla == Singleton.FormatoBatalla.DOBLE
	if slot == slot_rival_secundario:
		return posiciones.get("cuadro_ps_rival2_final")
	if slot == slot_jugador_secundario:
		return posiciones.get("cuadro_ps_jugador2_final")
	if slot == slot_rival:
		return posiciones.get("cuadro_ps_rival_doble_final" if doble else "cuadro_ps_rival_final")
	return posiciones.get("cuadro_ps_jugador_doble_final" if doble else "cuadro_ps_jugador_final")

func _configurar_slot_secundario(equipo_activo: Array[BasePokemon], slot: BattleSlot, es_jugador: bool, posicion_slot: Vector2, posicion_cuadro: Vector2) -> void:
	var activo := formato_batalla == Singleton.FormatoBatalla.DOBLE and equipo_activo.size() > 1
	slot.visible = activo
	if not activo:
		slot.ocultar()
		return
	slot.fijar_posicion_relativa_al_suelo(posicion_slot)
	slot.cuadro_ps.position = posicion_cuadro
	slot.configurar_pokemon(equipo_activo[1], es_jugador, hud._estadoE2S(equipo_activo[1].estado), resultado._obtener_exp_inicio_nivel(equipo_activo[1]) if es_jugador else 0)
	if not es_jugador:
		_actualizar_indicador_capturado(slot, equipo_activo[1])
	aplicar_offset_a_slot(slot, equipo_activo[1], es_jugador)
	slot.sprite_pokemon.visible = true
	slot.cuadro_ps.visible = true

func _reiniciar_estados_combate_activos() -> void:
	combatientes_activos.clear()
	combatiente_jugador = PokemonCombatState.new(poke_jugador) if poke_jugador != null else null
	combatiente_enemigo = PokemonCombatState.new(poke_enemigo) if poke_enemigo != null else null
	if combatiente_jugador != null:
		combatientes_activos[poke_jugador] = combatiente_jugador
	if combatiente_enemigo != null:
		combatientes_activos[poke_enemigo] = combatiente_enemigo
	if formato_batalla == Singleton.FormatoBatalla.DOBLE:
		if pokemones_activos_jugador.size() > 1:
			combatientes_activos[pokemones_activos_jugador[1]] = PokemonCombatState.new(pokemones_activos_jugador[1])
		if pokemones_activos_enemigo.size() > 1:
			combatientes_activos[pokemones_activos_enemigo[1]] = PokemonCombatState.new(pokemones_activos_enemigo[1])

## SwitchInClearSetData / UndoEffectsAfterFainting: el enamoramiento acaba cuando quien
## lo causó sale del campo, por cambio o por debilitamiento.
func _liberar_enamorados_de(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	for estado: PokemonEnCombate in combatientes_activos.values():
		if estado.target_enamorado == pokemon:
			estado.esta_enamorado = false
			estado.target_enamorado = null


func _obtener_combatiente(pokemon: BasePokemon) -> PokemonEnCombate:
	var state: PokemonEnCombate=null
	if combatientes_activos.has(pokemon):state=combatientes_activos[pokemon]
	elif pokemon==poke_jugador:state=combatiente_jugador
	elif pokemon==poke_enemigo:state=combatiente_enemigo
	# Resolve live side authority also for new switch/partner combatants. Mist
	# itself remains in side timers and never travels with a party member.
	if state!=null:
		state.bind_body_attack_owner(self)
		var bank: Dictionary=turno._posicion_pokemon(pokemon)
		state.set_meta("source_mist_authority",{"authority":weakref(screen_rules),"side":0 if bool(bank.get("player",false)) else 1})
	return state


func _configurar_ia_entrenador(entrenador: DatosEntrenador) -> void:
	ai_integrador = BattleAIIntegratorScene.new(self)
	ai_integrador.initialize_enemy_ai(
		entrenador.clase_entrenador,
		{},
		_calcular_dificultad_ia_entrenador(entrenador)
	)
	ai_integrador.configurar_objetos_entrenador(entrenador.objetos)

func _calcular_dificultad_ia_entrenador(entrenador: DatosEntrenador) -> int:
	var total_niveles := 0
	var cantidad := 0
	for pokemon_data in entrenador.pokemon:
		total_niveles += pokemon_data.nivel
		cantidad += 1

	var nivel_promedio: float = float(total_niveles) / float(max(cantidad, 1))
	if nivel_promedio >= 50.0:
		return 5
	if nivel_promedio >= 35.0:
		return 4
	if nivel_promedio >= 20.0:
		return 3
	if nivel_promedio >= 10.0:
		return 2
	return 1

## Configura la batalla saltando las animaciones.
func _configurar_batalla_sin_animaciones():
	print("Saltando animaciones")
	fondo_batalla.visible = true
	suelo_arriba.visible = true
	suelo_abajo.visible = true
	spr_pokemon_rival.visible = true
	spr_pokemon_jugador.visible = not batalla_sin_pokemon
	hud.mostrar_cuadros_ps_sin_animaciones(batalla_sin_pokemon)

	iluminacion_campo.visible = false
	sprite_rival.visible = false
	sprite_prota.visible = false
	nodo_iconos_pokeball.visible = false
	cortina_arriba.visible = false
	cortina_abajo.visible = false
	btlDecoFrente.visible = false
	sprite_prota.visible = false
	soporte_balls_arriba.visible = false
	soporte_balls_abajo.visible = false
	poke_ball_rival.visible = false
	poke_ball_jugador.visible = false

	suelo_arriba.position = posiciones.get("suelo_arriba_final")
	suelo_abajo.position = posiciones.get("suelo_abajo_final")
	hud.posicionar_cuadros_ps_final()
	slot_rival.fijar_posicion_relativa_al_suelo(posicion_slot_rel_suelo(slot_rival))
	slot_jugador.fijar_posicion_relativa_al_suelo(posicion_slot_rel_suelo(slot_jugador))
	aplicar_offset_a_slot(slot_rival, poke_enemigo, false)
	aplicar_offset_a_slot(slot_jugador, poke_jugador, true)
	cursor.visible = false

	var mensaje := "¿Qué debería hacer?" if batalla_sin_pokemon else mensaje_que_hacer.replace("{NOMBRE_POKEMON}", poke_jugador.mote if poke_jugador.mote != "" else poke_jugador.nombre)
	presentacion.set_texto_instantaneo(mensaje)


## Reabre el menú de acciones tras un mensaje que requería confirmación
## durante la fase de INPUT (p. ej. "¡No puedes huir de un entrenador!").
func _on_input_continuar() -> void:
	if fase == INPUT:
		fase_input()

func fase_input(reiniciar_slot: bool = true):
	# waitmessage 64: el último mensaje del turno se lee antes de abrir el menú.
	# Una llamada posterior a fase_input sustituye a la que sigue esperando, y si
	# el flujo cambió de fase durante la pausa, el menú ya no corresponde.
	_fase_input_token += 1
	var token: int = _fase_input_token
	if presentacion != null and presentacion.tiene_lectura_pendiente():
		var fase_previa: int = fase
		await presentacion.esperar_lectura_pendiente()
		if token != _fase_input_token or not is_inside_tree() or fase != fase_previa:
			return
	fases.cambiar_fase(INPUT)
	if formato_batalla == Singleton.FormatoBatalla.DOBLE and reiniciar_slot:
		slot_jugador_seleccionado = 0 if poke_jugador != null and poke_jugador.estad_ps_actual > 0 else 1
	# El flag lo activa la selección de Pokémon mientras la tecla sigue pulsada y
	# los menús inactivos no lo limpian: si ya se soltó, liberarlo ahora para no
	# descartar la primera pulsación nueva de btn_accion/btn_cancelar.
	if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"):
		ignorar_input_temporal = false
	# Plan 20260912 (tipo 5): sin equipo el menú se reduce a MOCHILA + HUIDA.
	if batalla_sin_pokemon:
		presentacion.menu1.configurar_opciones([MOCHILA, HUIDA])
	else:
		presentacion.menu1.restaurar_opciones()
	var activo_input: BasePokemon = poke_jugador
	if formato_batalla == Singleton.FormatoBatalla.DOBLE and slot_jugador_seleccionado == 1 and pokemones_activos_jugador.size() > 1:
		activo_input = pokemones_activos_jugador[1]
	if not batalla_sin_pokemon and turno.continuar_movimiento_pendiente(activo_input): return
	var mensaje := "¿Qué debería hacer?" if batalla_sin_pokemon or activo_input == null else "¿Qué debería hacer\n%s?" % activo_input.get_nombre_mostrar()
	_mostrar_mensaje(mensaje, true)
	presentacion.mostrar_menu_principal()
	timer_pkm_actual.start()
	hud.iniciar_timer_ps()
	if tutorial_blasco:
		_accion_tutorial_blasco()

func _on_timer_pkm_actual_timeout():
	timer_pkm_actual_cambio = !timer_pkm_actual_cambio
	if timer_pkm_actual_cambio:
		spr_pokemon_jugador.offset.y = 1
	else:
		spr_pokemon_jugador.offset.y = 0

## Emite partículas desde la posición dada con parámetros opcionales.
func emitir_particulas_pokeball(parametros: Dictionary = {}) -> void:
	loggear("Emitiendo partículas en posición: %s" % parametros.posicion)

	# Instanciar la escena del emisor de partículas
	if emisor_particulas == null:
		print("❌ [BATALLA] No se pudo cargar la escena del emisor de partículas")
		return

	var emisor: Node2D = emisor_particulas.instantiate()
	if not emisor:
		print("❌ [BATALLA] No se pudo instanciar el emisor de partículas")
		return

	# Configurar la posición del emisor
	emisor.position = parametros.posicion
	emisor.offset_posicion = Vector2(32,32)  # Resetear offset ya que usamos position

	# Configurar parámetros personalizados si se proporcionan
	if not parametros.is_empty():
		emisor.configurar(parametros)

	# Añadir el emisor como hijo temporal de la escena
	add_child(emisor)

	print("✨ [BATALLA] Emisor de partículas iniciado en posición: %s" % parametros.posicion)

	# Programar la eliminación del emisor después de que termine
	# Calculamos el tiempo basado en: tiempo_emision + duracion_movimiento + margen
	var tiempo_total: float
	if parametros.has("tiempo_emision") and parametros.tiempo_emision > 0:
		# Modo por tiempo: tiempo_emision + tiempo para que terminen las últimas partículas
		tiempo_total = parametros.tiempo_emision + emisor.duracion_movimiento + 0.5
		print("⏱️ [BATALLA] Modo por tiempo: %.2f segundos de emisión + %.2f de movimiento = %.2f total" % [parametros.tiempo_emision, emisor.duracion_movimiento, tiempo_total])
	else:
		# Modo por cantidad (compatibilidad hacia atrás): (max_particulas * intervalo_emision) + duracion_movimiento + margen
		tiempo_total = (emisor.max_particulas * emisor.intervalo_emision) + emisor.duracion_movimiento + 0.5
		print("🔢 [BATALLA] Modo por cantidad: %d partículas × %.3f intervalo + %.2f movimiento = %.2f total" % [emisor.max_particulas, emisor.intervalo_emision, emisor.duracion_movimiento, tiempo_total])

	get_tree().create_timer(tiempo_total).timeout.connect(func():
		if is_instance_valid(emisor):
			emisor.queue_free()
			print("🗑️ [BATALLA] Emisor de partículas eliminado")
	)

func iniciar_cuadro_enemigo(pkm) -> void:
	_registrar_rival_visto(pkm)
	if not is_instance_valid(slot_rival):
		push_error("[BATALLA] Slot rival nulo en iniciar_cuadro_enemigo")
		return
	slot_rival.configurar_pokemon(pkm, false, hud._estadoE2S(pkm.estado))
	_actualizar_indicador_capturado(slot_rival, pkm)
	aplicar_offset_a_slot(slot_rival, pkm, false)

## Indicador de POKé BALL del cuadro de PS rival (TryAddPokeballIconToHealthbox de
## Emerald): solo en combates salvajes (no entrenador, no tutorial de Blasco) y
## cuando la especie ya figura como atrapada en la POKéDEX.
func _rival_ya_atrapado(pkm: BasePokemon) -> bool:
	if pkm == null or pkm.huevo or tutorial_blasco:
		return false
	if tipo_batalla != Singleton.TipoBatalla.SALVAJE:
		return false
	return SistemaGuardado.pokemon_atrapado(pkm.nombre_interno)

## Muestra u oculta el icono de captura del cuadro de `slot` (lado rival).
func _actualizar_indicador_capturado(slot: BattleSlot, pkm: BasePokemon) -> void:
	if not is_instance_valid(slot) or not is_instance_valid(slot.cuadro_ps):
		return
	if slot.cuadro_ps.has_method("set_capturado"):
		slot.cuadro_ps.set_capturado(_rival_ya_atrapado(pkm))

func iniciar_cuadro_jugador(pkm) -> void:
	slot_jugador.configurar_pokemon(pkm, true, hud._estadoE2S(pkm.estado), resultado._obtener_exp_inicio_nivel(pkm))
	aplicar_offset_a_slot(slot_jugador, pkm, true)

## Recibe la señal del menú principal de batalla cuando se selecciona una opción.
func _on_batalla_menu_1_seleccionado(opcion: int) -> void:
	# A stale menu signal is not permission to switch, use an item or flee
	# during Ruby STATUS2_MULTIPLETURNS. Validate current native occupancy.
	var actor_input: BasePokemon=poke_jugador
	if formato_batalla==Singleton.FormatoBatalla.DOBLE and slot_jugador_seleccionado==1 and pokemones_activos_jugador.size()>1:
		actor_input=pokemones_activos_jugador[1]
	if BattleLockedMoveRules.multi_turn(self,actor_input)!=null:
		if fase==INPUT:turno.continuar_movimiento_pendiente(actor_input)
		return
	loggear("opcion seleccionada: %s " % opcion)
	match opcion:
		LUCHA:
			presentacion.ocultar_menu_principal()
			if batalla_sin_pokemon:
				_mostrar_mensaje("¡No tienes ningún\nPOKéMON!", false, Callable(self, "fase_input"))
				return
			var activo_menu: BasePokemon = poke_jugador
			if formato_batalla == Singleton.FormatoBatalla.DOBLE and slot_jugador_seleccionado == 1 and pokemones_activos_jugador.size() > 1:
				activo_menu = pokemones_activos_jugador[1]
			if turno._pendiente(activo_menu)!=null:
				turno.continuar_movimiento_pendiente(activo_menu);return
			if preload("res://scripts/battle/move_availability_rules.gd").slots(self,activo_menu).is_empty():
				var original: Dictionary=field_rules.capture(activo_menu)
				await mostrar_texto_batalla("¡No quedan movimientos utilizables!")
				if field_rules.valid(original):await turno._on_batalla_movimiento_seleccionado(0,preload("res://scripts/battle/move_availability_rules.gd").struggle())
				return
			# REGLA (decomp, sub_8012324): con Otra Vez, LUCHA confirma el movimiento sin abrir su menú.
			if preload("res://scripts/battle/encore_rules.gd").move(self,activo_menu)!=null:
				turno.continuar_movimiento_pendiente(activo_menu,true);return
			iniciar_cuadro_movimientos(activo_menu)
			presentacion.mostrar_menu_movimientos()
		POKEMON:
			presentacion.ocultar_menu_principal()
			seleccionar_pokemon()
		MOCHILA:
			presentacion.ocultar_menu_principal()
			if torre_batalla:
				# BattleScript_ActionSelectionItemsCantBeUsed: no gasta el turno.
				_mostrar_mensaje(tr("TORRE_BATALLA_SIN_OBJETOS"), false, Callable(self, "_esperar_accion_cancelar"))
			else:
				_abrir_mochila_batalla()
		HUIDA:
			presentacion.ocultar_menu_principal()
			intentar_huida()

## Función para abrir la pantalla del equipo, no necesariamente para cambiar de pokémon.
func seleccionar_pokemon():
	if batalla_sin_pokemon:
		fase_input()
		return
	mostrar_pantalla_equipo("Elegir un POKéMON.", Singleton.ModoPEquipo.BATALLA_DATOS)

func _abrir_mochila_batalla() -> void:
	await presentacion.abrir_mochila(
		Callable(self, "_on_mochila_batalla_cerrada"),
		Callable(self, "_on_objeto_listo_para_usar")
	)

## Llamado cuando el jugador confirma USAR en la mochila.
func _on_objeto_listo_para_usar(item: Dictionary) -> void:
	objeto_mochila_batalla = item
	if item.get("bolsillo_id", -1) == 1:  # Poké Ball (bolsillo 1, 0-indexed)
		await presentacion.oscurecer()
		presentacion.cerrar_mochila()
		await presentacion.aclarar()
		_resolver_captura_pokeball(item)
		return
	if EFECTOS_OBJETOS_X.es_soportado(str(item.get("nombre_interno", ""))):
		await _usar_objeto_x(item)
		return
	if EFECTOS_OBJETOS_X.es_huida(str(item.get("nombre_interno", ""))):
		await _usar_objeto_huida(item)
		return
	# Como ItemUseInBattle_Medicine: la pantalla de equipo aplica el objeto
	# (UseMedicine) y avisa con objeto_usado; B vuelve a la mochila.
	var pantalla: PantallaEquipoControlador = presentacion.pantalla_equipo
	pantalla.objeto_a_usar = item
	pantalla.bolsillo_objeto_a_usar = int(item.get("bolsillo_id", 0))
	pantalla.obtener_combatiente = Callable(self, "_obtener_combatiente")
	_conectar_pantalla_equipo_para_objeto()
	pantalla.z_index = 6
	await presentacion.oscurecer()
	presentacion.cerrar_mochila()
	pantalla.mostrar_equipo_modo(
		Singleton.ModoPEquipo.BATALLA_OBJETO,
		crear_equipo_adaptado(),
		FormateadorLigaduras.formatear(tr("EQUIPO_USAR_EN_QUIEN"))
	)
	await presentacion.aclarar()

## ItemUseInBattle_StatIncrease: se aplica al Pokémon activo con la mochila abierta. Sin efecto no se gasta y sigue
## en la lista; con efecto (sub_80CA2BC: 8 frames y SE_USE_ITEM) se gasta, y tras el mensaje se pierde el turno.
func _usar_objeto_x(item: Dictionary) -> void:
	var nombre_interno: String = str(item.get("nombre_interno", ""))
	var actor: BasePokemon = _actor_menu_objeto()
	var mensaje: String = EFECTOS_OBJETOS_X.aplicar(nombre_interno, actor, _obtener_combatiente(actor), screen_rules)
	objeto_mochila_batalla = {}
	if mensaje.is_empty():
		Singleton.emit_signal("play_sound", "cursor_menu")
		await presentacion.mostrar_mensaje_sobre_mochila(tr("MEDICINA_SIN_EFECTO"))
		presentacion.mochila_batalla.volver_a_lista_batalla()
		return
	await get_tree().create_timer(8.0 / 60.0).timeout
	Singleton.play_sound.emit("SE_USE_ITEM_KAIFUKU")
	if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, int(item.get("bolsillo_id", 0))):
		push_warning("[BATALLA] No se pudo quitar 1 x %s" % nombre_interno)
	await presentacion.mostrar_mensaje_sobre_mochila(mensaje)
	_obtener_combatiente(actor).fury_cutter_count = 0 # Ruby HandleAction_UseItem5379.
	await presentacion.oscurecer()
	presentacion.cerrar_mochila()
	await presentacion.aclarar()
	_ceder_turno_al_enemigo()

## ItemUseInBattle_Escape: contra un entrenador, Consejo de PAPÁ sin gastarlo; si no, se gasta, sale «usó» y
## BattleScript_RunByUsingItem cierra el combate con SE_FLEE (sin tirada, sin trampas y sin más texto).
func _usar_objeto_huida(item: Dictionary) -> void:
	objeto_mochila_batalla = {}
	if tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		await presentacion.mostrar_mensaje_sobre_mochila(tr("MOCHILA_CONSEJO_PAPA"))
		presentacion.mochila_batalla.volver_a_lista_batalla()
		return
	var nombre_interno: String = str(item.get("nombre_interno", ""))
	if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, int(item.get("bolsillo_id", 0))):
		push_warning("[BATALLA] No se pudo quitar 1 x %s" % nombre_interno)
	await presentacion.mostrar_mensaje_sobre_mochila(tr("MOCHILA_USO_OBJETO").replace("{key}", str(item.get("nombre", nombre_interno))))
	await presentacion.oscurecer()
	presentacion.cerrar_mochila()
	await presentacion.aclarar()
	_reproducir_efecto(SE_HUIDA)
	fases.cambiar_fase(FIN_BATALLA)
	await resultado.cerrar_batalla_con_oscurecimiento()
	_restaurar_orden_original_equipo()
	loggear("Batalla terminada por objeto de huida")
	notificar_resultado(ResultadoBatalla.Valor.HUIDA)

## El Pokémon que eligió la acción de objeto (gBattlerInMenuId).
func _actor_menu_objeto() -> BasePokemon:
	if formato_batalla == Singleton.FormatoBatalla.DOBLE and slot_jugador_seleccionado < pokemones_activos_jugador.size():
		return pokemones_activos_jugador[slot_jugador_seleccionado]
	return poke_jugador

## Llamado cuando el jugador cierra la mochila sin elegir objeto.
func _on_mochila_batalla_cerrada() -> void:
	objeto_mochila_batalla = {}
	presentacion.cerrar_mochila()
	fase_input()
	await presentacion.aclarar()

## Desconecta los handlers de resultado de la pantalla de equipo y conecta
## los handlers de objeto (one-shot) para que no interfieran entre sí.
func _conectar_pantalla_equipo_para_objeto() -> void:
	var pantalla: PantallaEquipoControlador = presentacion.pantalla_equipo
	if pantalla.pokemon_elegido.is_connected(Callable(resultado, "_on_pokemon_seleccionado")):
		pantalla.pokemon_elegido.disconnect(Callable(resultado, "_on_pokemon_seleccionado"))
	if pantalla.seleccion_cancelada.is_connected(Callable(resultado, "_on_seleccion_cancelada")):
		pantalla.seleccion_cancelada.disconnect(Callable(resultado, "_on_seleccion_cancelada"))
	pantalla.objeto_usado.connect(Callable(self, "_on_objeto_usado_en_equipo"), CONNECT_ONE_SHOT)
	pantalla.seleccion_cancelada.connect(Callable(self, "_on_cancelar_objeto"), CONNECT_ONE_SHOT)

## Quita el handler one-shot que no se disparó y restaura las conexiones de
## resultado. Se llama en los dos caminos de salida del flujo de objeto.
func _desconectar_pantalla_equipo_objeto() -> void:
	var pantalla: PantallaEquipoControlador = presentacion.pantalla_equipo
	if pantalla.objeto_usado.is_connected(Callable(self, "_on_objeto_usado_en_equipo")):
		pantalla.objeto_usado.disconnect(Callable(self, "_on_objeto_usado_en_equipo"))
	if pantalla.seleccion_cancelada.is_connected(Callable(self, "_on_cancelar_objeto")):
		pantalla.seleccion_cancelada.disconnect(Callable(self, "_on_cancelar_objeto"))
	_reconectar_pantalla_equipo_resultado()

## Restaura las conexiones de resultado después de un flujo de objeto.
func _reconectar_pantalla_equipo_resultado() -> void:
	if not presentacion.pantalla_equipo.pokemon_elegido.is_connected(Callable(resultado, "_on_pokemon_seleccionado")):
		presentacion.pantalla_equipo.pokemon_elegido.connect(Callable(resultado, "_on_pokemon_seleccionado"))
	if not presentacion.pantalla_equipo.seleccion_cancelada.is_connected(Callable(resultado, "_on_seleccion_cancelada")):
		presentacion.pantalla_equipo.seleccion_cancelada.connect(Callable(resultado, "_on_seleccion_cancelada"))

## La pantalla de equipo ya usó el objeto y cerró su mensaje
## (battle_party_menu.c Task_80952E4): con efecto se vuelve al combate con el
## HUD al valor nuevo y se gasta el turno (sin texto: BattleScript_PlayerUsesItem
## no muestra nada); sin efecto se vuelve a la mochila de batalla.
func _on_objeto_usado_en_equipo(indice_visual: int, tuvo_efecto: bool) -> void:
	var indice := indice_equipo_desde_visual(indice_visual)
	_desconectar_pantalla_equipo_objeto()
	objeto_mochila_batalla = {}
	if not tuvo_efecto:
		_volver_a_mochila_batalla()
		return
	# Item action belongs to the acting bank, not the selected healed party member.
	var actor: BasePokemon=_actor_menu_objeto()
	var state: PokemonEnCombate=_obtener_combatiente(actor)
	if state!=null:state.fury_cutter_count=0 # Ruby HandleAction_UseItem5379.
	await presentacion.oscurecer()
	presentacion.pantalla_equipo.ocultar_pantalla_equipo()
	presentacion.pantalla_equipo.z_index = 1
	if indice >= 0 and indice < equipo_jugador_pokemones.size():
		_colocar_hud_tras_objeto(equipo_jugador_pokemones[indice])
	await presentacion.aclarar()
	_ceder_turno_al_enemigo()

## B en la pantalla de equipo: vuelve a la mochila de batalla sin gastar nada
## (HandleBattlePartyMenu). La mochila se liberó al abrir el equipo, así que
## se abre otra en el último bolsillo visto.
func _on_cancelar_objeto() -> void:
	_desconectar_pantalla_equipo_objeto()
	objeto_mochila_batalla = {}
	_volver_a_mochila_batalla()

func _volver_a_mochila_batalla() -> void:
	# Sin input en el equipo mientras se funde (B ya no está conectada).
	presentacion.pantalla_equipo.activo = false
	await presentacion.oscurecer()
	presentacion.pantalla_equipo.ocultar_pantalla_equipo()
	presentacion.pantalla_equipo.z_index = 1
	await presentacion.abrir_mochila(
		Callable(self, "_on_mochila_batalla_cerrada"),
		Callable(self, "_on_objeto_listo_para_usar"),
		false
	)

## Pone el cuadro de PS del Pokémon (si está en el campo) en sus PS y estado
## nuevos sin animar, como pokeruby al volver al combate desde el equipo.
## TODO: en doble, revivir al compañero debilitado que sigue en su hueco
## (gAbsentBattlerFlags + CopyPlayerPartyMonToBattleData) no lo vuelve a
## mostrar en el campo; solo se actualizan sus datos.
func _colocar_hud_tras_objeto(poke: BasePokemon) -> void:
	if hud == null:
		return
	var cuadro: Node = hud._obtener_cuadro_ps_de_pokemon(poke)
	if cuadro != null and cuadro.has_method("set_salud_instantanea"):
		cuadro.set_salud_instantanea(poke.estad_ps, poke.estad_ps_actual)
	hud._actualizar_estado_visual_pokemon(poke)

## Lanzamiento de una POKé BALL desde la mochila (pokeruby
## ItemUseInBattle_PokeBall + BattleScript_BallThrow + atkEF_handleballthrow).
## Con equipo y PC llenos la ball no se gasta; contra un ENTRENADOR (o si la
## batalla no permite capturar) se gasta y el rival la bloquea; un fallo gasta
## el turno. Si se atrapa, el Pokémon se guarda en _finalizar_captura(),
## después de restaurar el orden del equipo.
func _resolver_captura_pokeball(item: Dictionary) -> void:
	var nombre_interno := str(item.get("nombre_interno", "")).to_upper()
	var bolsillo_id: int = item.get("bolsillo_id", 1)
	if SistemaGuardado.almacenamiento_lleno():
		await _mostrar_texto_y_esperar_confirmacion("¡La CAJA del PC\nestá llena!")
		fase_input()
		return
	if not BattleCaptureService.es_ball(nombre_interno) \
			or not SistemaGuardado.quitar_objeto_jugador(nombre_interno, 1, bolsillo_id):
		_mostrar_mensaje("No puedes usar esa\nPOKé BALL.", false, Callable(self, "fase_input"))
		return
	_detener_animaciones_de_espera()
	var nombre_ball := BattleCaptureService.nombre_ball_mostrar(str(item.get("nombre", nombre_interno)).strip_edges())
	# pokeruby BattleScript_BallThrow: el mensaje queda en pantalla mientras
	# vuela la ball (no hay waitmessage antes de handleballthrow).
	await mostrar_texto_batalla("¡%s ha usado\n%s!" % [_obtener_nombre_jugador_mostrar(), nombre_ball])

	if not captura_permitida():
		await lanzamiento_ball.reproducir_bloqueo_entrenador(nombre_interno)
		await _mostrar_mensaje_con_pausa("¡El ENTRENADOR ha\nbloqueado la BALL!")
		await _mostrar_mensaje_con_pausa("¡No seas ladrón!")
		_ceder_turno_al_enemigo()
		return

	# atkEF_handleballthrow: gBattleResults.usedMasterBall / usedBalls.
	ResultadosCombate.registrar_ball(nombre_interno)
	var tirada := _calcular_tirada_captura(nombre_interno)
	var atrapado := bool(tirada.get("atrapado", false))
	await lanzamiento_ball.reproducir_lanzamiento(nombre_interno, int(tirada.get("sacudidas", 0)), atrapado)
	if atrapado:
		_registrar_datos_encuentro(poke_enemigo, nombre_interno)
		# pokeruby BattleText_BallCaught1: el mensaje se escribe con la fanfarria
		# sonando, {WAIT_SE} y {PLAY_BGM MUS_CAUGHT}.
		await mostrar_texto_batalla("¡Has atrapado a\n%s!" % poke_enemigo.get_nombre_mostrar())
		await lanzamiento_ball.esperar_fanfarria_captura()
		Singleton.reproducir_tema(TEMA_CAPTURA)
		await esperar_confirmacion_texto()
		resultado._finalizar_captura()
		return

	await _mostrar_mensaje_con_pausa(BattleCaptureService.mensaje_escape(int(tirada.get("sacudidas", 0))))
	_ceder_turno_al_enemigo()

## ============================================================================
## COMBATE TUTORIAL DE BLASCO (BATTLE_TYPE_WALLY_TUTORIAL)
## ============================================================================

## battle_controller_wally.c WallyHandleActions: el jugador no controla nada. Con el
## menú a la vista y tras B_WAIT_TIME_LONG, LUCHA → PLACAJE en los dos primeros
## turnos y MOCHILA → POKé BALL en el tercero.
func _accion_tutorial_blasco() -> void:
	presentacion.menu1.activo = false
	var lanzar_ball := contador_turnos >= TURNOS_PLACAJE_TUTORIAL
	presentacion.menu1.cambiar_opcion(MOCHILA if lanzar_ball else LUCHA)
	await get_tree().create_timer(ESPERA_TUTORIAL_BLASCO).timeout
	if not is_inside_tree() or fase != INPUT:
		return
	Singleton.play_sound.emit("SE_SELECT")
	presentacion.ocultar_menu_principal()
	if lanzar_ball:
		await _lanzar_ball_tutorial_blasco()
		return
	iniciar_cuadro_movimientos(poke_jugador)  # WallyHandleChooseMove
	presentacion.mostrar_menu_movimientos()
	presentacion.menu_movs.activo = false
	await get_tree().create_timer(ESPERA_TUTORIAL_BLASCO).timeout
	if not is_inside_tree():
		return
	Singleton.play_sound.emit("SE_SELECT")
	presentacion.menu_movs.visible = false
	turno._on_batalla_movimiento_seleccionado(MOV1)


## BattleScript_BallThrowByWally + BattleScript_WallyBallThrow: «¡BLASCO usó POKé
## BALL!», la ball siempre atrapa y «¡Ya está! ¡RALTS atrapado!» con MUS_CAUGHT.
## Sin gastar balls del jugador, sin POKéDEX, sin mote y sin guardar el RALTS
## (B_OUTCOME_CAUGHT y fin del combate).
func _lanzar_ball_tutorial_blasco() -> void:
	_detener_animaciones_de_espera()
	await mostrar_texto_batalla("¡%s usó\n%s!" % [NOMBRE_BLASCO, BattleCaptureService.nombre_ball_mostrar("POKé BALL")])
	await lanzamiento_ball.reproducir_lanzamiento("POKEBALL", BattleCaptureService.SACUDIDAS_CAPTURA, true)
	# BattleText_BallCaught2: fanfarria, {WAIT_SE}, {PLAY_BGM MUS_CAUGHT}, {PAUSE 127}.
	await mostrar_texto_batalla("¡Ya está!\n¡%s atrapado!" % poke_enemigo.get_nombre_mostrar())
	await lanzamiento_ball.esperar_fanfarria_captura()
	Singleton.reproducir_tema(TEMA_CAPTURA)
	await get_tree().create_timer(PAUSA_MENSAJE_BATALLA).timeout
	await get_tree().create_timer(PAUSA_MENSAJE_BATALLA).timeout  # {PAUSE 127}
	fases.cambiar_fase(FIN_BATALLA)
	lanzamiento_ball.limpiar()
	await resultado.cerrar_batalla_con_oscurecimiento(false)
	notificar_resultado(ResultadoBatalla.Valor.CAPTURA)


## Aplica la fórmula de Gen 3 al Pokémon rival activo con la ball indicada.
func _calcular_tirada_captura(nombre_ball: String) -> Dictionary:
	var ratio := 0
	if proveedor_datos != null and proveedor_datos.has_method("obtener_ratio_captura"):
		ratio = int(proveedor_datos.obtener_ratio_captura(poke_enemigo.nombre_interno))
	var contexto := {
		"turnos": contador_turnos,
		# TODO: usar el tipo de mapa (inmersión) cuando exista el buceo; el
		# terreno BAJO_AGUA es el que pokeruby asigna en esos mapas.
		"bajo_agua": (str(datos_batalla.get("escenario", "")) == EscenarioBatalla.ID_BAJO_AGUA
				or int(datos_batalla.get("tema_grafico", Singleton.TemaBatalla.NO_TIENE)) == Singleton.TemaBatalla.BAJO_AGUA),
		"especie_atrapada": SistemaGuardado.pokemon_atrapado(poke_enemigo.nombre_interno),
	}
	return BattleCaptureService.calcular_captura(nombre_ball, ratio, poke_enemigo, contexto)

## true si esta batalla admite capturas: solo salvajes y con `permite_captura`
## (DatosInicioBatalla), que por defecto es true en SALVAJE y false en ENTRENADOR.
func captura_permitida() -> bool:
	if tipo_batalla != Singleton.TipoBatalla.SALVAJE:
		return false
	return bool(datos_batalla.get("permite_captura", true))

## Marca como vista en la POKéDEX la especie de un Pokémon rival al entrar en
## combate (salvaje o de entrenador), como pokeruby al enviarlo.
func _registrar_rival_visto(pokemon) -> void:
	if torre_batalla:
		return
	if pokemon is BasePokemon and not pokemon.nombre_interno.is_empty():
		SistemaGuardado.registrar_pokemon_visto(pokemon.nombre_interno)

## Fija los datos de encuentro del Pokémon atrapado antes de guardarlo.
func _registrar_datos_encuentro(pokemon: BasePokemon, nombre_ball: String) -> void:
	pokemon.encuentro_bola = nombre_ball
	pokemon.encuentro_nivel = pokemon.nivel
	pokemon.encuentro_lugar = _resolver_lugar_encuentro(pokemon.encuentro_lugar)

## Clave de lugar de captura (ver `Lugares`): `ubicacion` de los datos de
## inicio, o la sección del mapa actual, o el último lugar guardado; si no hay
## ninguno, conserva `actual`. Cualquier valor se normaliza a clave de zona.
func _resolver_lugar_encuentro(actual: String) -> String:
	var ubicacion := Lugares.normalizar_clave(str(datos_batalla.get("ubicacion", "")))
	if not ubicacion.is_empty():
		return ubicacion
	if is_inside_tree():
		var admin: Node = get_tree().root.get_node_or_null("AdministradorMapa")
		if admin != null and "mapa_actual" in admin and admin.mapa_actual is MapaConfiguracion:
			var seccion_mapa := (admin.mapa_actual as MapaConfiguracion).obtener_seccion_efectiva()
			if not seccion_mapa.is_empty():
				return seccion_mapa
	var lugar_guardado := Lugares.normalizar_clave(str(SistemaGuardado.datos_vivos.posicion.get("nombre_lugar", "")))
	if not lugar_guardado.is_empty():
		return lugar_guardado
	var lugar_actual := Lugares.normalizar_clave(actual)
	return lugar_actual if not lugar_actual.is_empty() else Lugares.DESCONOCIDO

func _obtener_nombre_jugador_mostrar() -> String:
	if tutorial_blasco:
		return NOMBRE_BLASCO
	var nombre := String(SistemaGuardado.get_nombre_jugador()).strip_edges()
	return nombre.to_upper() if not nombre.is_empty() else "JUGADOR"

## Muestra un mensaje y lo deja en pantalla un momento sin pedir confirmación
## (pokeruby `waitmessage 64`).
func _mostrar_mensaje_con_pausa(texto: String) -> void:
	await mostrar_texto_batalla(texto)
	await get_tree().create_timer(PAUSA_MENSAJE_BATALLA).timeout

## Detiene el balanceo del Pokémon/cuadro de PS del jugador al salir de INPUT
## sin elegir movimiento (mismo reinicio que la selección de movimiento).
func _detener_animaciones_de_espera() -> void:
	timer_pkm_actual.stop()
	if hud != null:
		hud.detener_timer_ps()
		if is_instance_valid(hud.cuadro_ps_jugador):
			hud.cuadro_ps_jugador.set_offset_y(0)
	if is_instance_valid(spr_pokemon_jugador):
		spr_pokemon_jugador.offset.y = 0

## El jugador gastó su turno en una acción que no es un movimiento (objeto,
## POKé BALL fallida o bloqueada): ahora actúa el rival.
func _ceder_turno_al_enemigo() -> void:
	if batalla_sin_pokemon:
		_atacar_sin_pokemon()
		return
	_detener_animaciones_de_espera()
	if formato_batalla == Singleton.FormatoBatalla.DOBLE:
		turno.registrar_objeto_doble()
		return
	turno.ceder_turno_al_rival()

## Turno del salvaje cuando el jugador no tiene POKéMON (plan 20260912, tipo 5).
## El salvaje actúa siempre tras cada acción fallida del jugador: si elige un
## movimiento de daño el jugador se desmaya y termina la batalla; si elige un
## movimiento de estado sin daño, el jugador recibe otro turno.
func _atacar_sin_pokemon() -> void:
	var movimiento := turno._seleccionar_movimiento_enemigo_aleatorio()
	if movimiento == null or poke_enemigo == null:
		resultado.mostrar_resultado_derrota()
		return
	await mostrar_texto_batalla("¡%s usó\n%s!" % [poke_enemigo.get_nombre_combate(), movimiento.nombre])
	if MoveResolver.es_movimiento_estado(movimiento):
		fase_input()
		return
	resultado.mostrar_resultado_derrota()

## Tipo 6 (plan 20260912): jugador sin POKéMON contra entrenador. Tras la intro
## completa del combate cae derrotado sin llegar a INPUT.
func derrota_inmediata_sin_equipo() -> void:
	var nombre_jugador := "JUGADOR"
	if SistemaGuardado and SistemaGuardado.has_method("get_nombre_jugador"):
		var nombre := String(SistemaGuardado.get_nombre_jugador()).strip_edges()
		if not nombre.is_empty():
			nombre_jugador = nombre.to_upper()
	await _mostrar_texto_y_esperar_confirmacion("%s no tiene POKéMON\ncapaces de luchar" % nombre_jugador)
	resultado.mostrar_resultado_derrota()

func mostrar_pantalla_equipo(mensaje: String, modo: Singleton.ModoPEquipo = Singleton.ModoPEquipo.NORMAL):
	var equipo_adaptado = crear_equipo_adaptado()
	var pantalla: PantallaEquipoControlador = presentacion.pantalla_equipo
	if pantalla.has_meta("battle_blocked_party_indices"):
		var blocked: Array[int] = []
		for party_index: int in pantalla.get_meta("battle_blocked_party_indices"):
			if party_index >= 0 and party_index < equipo_jugador_pokemones.size():
				blocked.append(orden_visual_equipo.find(equipo_jugador_pokemones[party_index]))
		pantalla.set_meta("battle_blocked_visual_indices", blocked)
	elif pantalla.has_meta("battle_blocked_visual_indices"):
		pantalla.remove_meta("battle_blocked_visual_indices")
	presentacion.ocultar_menu_principal()
	await presentacion.oscurecer()
	presentacion.pantalla_equipo.mostrar_equipo_modo(modo, equipo_adaptado, mensaje)
	await presentacion.aclarar()

## Equipo en el orden de la pantalla de equipo de batalla (orden_visual_equipo).
## Los índices que emite la pantalla son de caja: se traducen con
## indice_equipo_desde_visual().
func crear_equipo_adaptado():
	_actualizar_orden_visual_equipo()
	var equipo_wrapper = EquipoPokemon.new()
	for pokemon in orden_visual_equipo:
		equipo_wrapper.agregar_pokemon(pokemon)
	# El activo siempre ocupa la primera caja.
	equipo_wrapper.pokemon_actual_indice = 0 if not _activos_jugador_en_orden().is_empty() else -1
	return equipo_wrapper

## Índice en equipo_jugador_pokemones del Pokémon de la caja `indice_visual`.
func indice_equipo_desde_visual(indice_visual: int) -> int:
	if indice_visual < 0 or indice_visual >= orden_visual_equipo.size():
		return indice_visual
	return equipo_jugador_pokemones.find(orden_visual_equipo[indice_visual])

## Activos del jugador en el orden de sus slots (J0, J1).
func _activos_jugador_en_orden() -> Array[BasePokemon]:
	var activos: Array[BasePokemon] = []
	if formato_batalla == Singleton.FormatoBatalla.DOBLE:
		for pokemon in pokemones_activos_jugador:
			if pokemon != null:
				activos.append(pokemon)
	elif poke_jugador != null:
		activos.append(poke_jugador)
	return activos

## Pone los activos al frente de orden_visual_equipo. La primera vez (o si el
## equipo cambió) lo crea como sub_8094998: activos y luego el resto en orden de
## equipo. Después, como sub_8094C98 en Task_BattlePartyMenuShift, el Pokémon
## que entra intercambia su caja con la del que estaba en ese slot.
func _actualizar_orden_visual_equipo() -> void:
	var activos := _activos_jugador_en_orden()
	var valido := orden_visual_equipo.size() == equipo_jugador_pokemones.size()
	if valido:
		for pokemon in equipo_jugador_pokemones:
			if not orden_visual_equipo.has(pokemon):
				valido = false
				break
	if not valido:
		orden_visual_equipo.clear()
		orden_visual_equipo.append_array(activos)
		for pokemon in equipo_jugador_pokemones:
			if not orden_visual_equipo.has(pokemon):
				orden_visual_equipo.append(pokemon)
		return
	for slot in range(activos.size()):
		var caja := orden_visual_equipo.find(activos[slot])
		if caja != slot:
			orden_visual_equipo[caja] = orden_visual_equipo[slot]
			orden_visual_equipo[slot] = activos[slot]

func intentar_huida():
	if primer_combate:
		# IsRunningFromBattleImpossible → gNoEscapeStringIds[1]: no gasta el turno.
		_mostrar_mensaje(TEXTO_NO_ME_DEJES, false, Callable(self, "_esperar_accion_cancelar"))
	elif tipo_batalla == Singleton.TipoBatalla.SALVAJE:
		# SOMBRA TRAMPA, TRAMPA ARENA e IMÁN impiden huir (FUGA lo permite siempre).
		# CanRunFromBattle: BOLA DE HUMO libra de todo; si no, el aviso vuelve al menú sin gastar turno.
		var trampa := {} if batalla_sin_pokemon or poke_jugador.objeto == OBJETO_BOLA_DE_HUMO else HabilidadesCombate.impide_huida(poke_jugador, habilidades.crear_campo())
		if not trampa.is_empty():
			_mostrar_mensaje(HabilidadesCombate.mensaje_impide_huida(trampa), false, Callable(self, "_esperar_accion_cancelar"))
			return
		var huye: bool = randi() % 100 < 50 if batalla_sin_pokemon else intentar_huida_jugador()
		if huye:
			await terminar_batalla_por_huida()
		else:
			# HandleAction_Run: fallar la huida gasta el turno y el salvaje actúa.
			_mostrar_mensaje("¡No puedes huir!", false, Callable(self, "_atacar_sin_pokemon") if batalla_sin_pokemon else Callable(turno, "ceder_turno_al_rival"))
	elif tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		var callback_mensaje = Callable(self, "_esperar_accion_cancelar")
		var mensaje = "¡No puedes huir de un\ncombate contra un ENTRENADOR!"
		_mostrar_mensaje(mensaje, false, callback_mensaje)
	else:
		presentacion.set_texto_instantaneo("Tipo de batalla desconocido")
		await get_tree().create_timer(1.0).timeout
		fase_input()

func terminar_batalla_por_huida() -> void:
	presentacion.set_texto_instantaneo("¡Has huido de la batalla!")
	await get_tree().create_timer(2.0).timeout
	fases.cambiar_fase(FIN_BATALLA)
	await resultado.cerrar_batalla_con_oscurecimiento()
	_restaurar_orden_original_equipo()
	loggear("Batalla terminada por huida")
	notificar_resultado(ResultadoBatalla.Valor.HUIDA)

## TryRunFromBattle (battle_main.c), para HUIDA y para el NO de "¿Usas el
## siguiente POKéMON?": BOLA DE HUMO o FUGA huyen siempre; si no, con la
## velocidad del Pokémon del jugador (aunque esté debilitado) frente a la del
## salvaje y 30 más por intento anterior.
func intentar_huida_jugador() -> bool:
	if poke_jugador.objeto == OBJETO_BOLA_DE_HUMO or HabilidadesCombate.huida_garantizada(poke_jugador):
		return true
	var huye := huye_por_velocidad(poke_jugador.estad_velocidad, poke_enemigo.estad_velocidad, intentos_huida, randi() & 0xFF)
	intentos_huida += 1
	return huye

## Parte de velocidad de TryRunFromBattle; `aleatorio` en 0..255.
static func huye_por_velocidad(velocidad: int, velocidad_rival: int, intentos: int, aleatorio: int) -> bool:
	if velocidad >= velocidad_rival:
		return true
	return (velocidad * 128 / velocidad_rival + intentos * 30) % 256 > aleatorio

## BattleScript_WildMonFled (HandleEndTurn_MonFled): el salvaje del primer combate
## huye (AI_GoEasy) y el combate acaba sin experiencia.
func huida_rival_salvaje(objetivo_forzado: BasePokemon=null) -> void:
	_reproducir_efecto(SE_HUIDA)
	var mensaje: String=TEXTO_SALVAJE_HUYO % poke_enemigo.get_nombre_combate() if objetivo_forzado==null else "¡%s fue arrastrado fuera del combate!"%objetivo_forzado.get_nombre_combate()
	await _mostrar_texto_y_esperar_confirmacion(mensaje)
	fases.cambiar_fase(FIN_BATALLA)
	await resultado.cerrar_batalla_con_oscurecimiento()
	_restaurar_orden_original_equipo()
	loggear("Batalla terminada por huida del salvaje")
	notificar_resultado(ResultadoBatalla.Valor.HUIDA)


func _reproducir_efecto(stream: AudioStream) -> void:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = stream
	add_child(reproductor)
	reproductor.finished.connect(reproductor.queue_free)
	reproductor.play()

func _esperar_accion_cancelar():
	presentacion.esperar_confirmacion_con_callback(Callable(self, "_on_input_continuar"))


func _unhandled_input(event: InputEvent) -> void:
	if not seleccionando_objetivo_doble or formato_batalla != Singleton.FormatoBatalla.DOBLE:
		return
	if bloquear_confirmacion_objetivo_doble:
		return
	# sub_802C2EC: IZQ/ARRIBA y DER/ABAJO recorren el anillo {0, 2, 3, 1}
	# (incluye al compañero); cada pulsación suena SE_SELECT.
	if event.is_action_pressed("btn_izquierda") or event.is_action_pressed("btn_arriba"):
		Singleton.play_sound.emit("SE_SELECT")
		if objetivos_doble.size() > 1:
			indice_objetivo_doble = (indice_objetivo_doble - 1 + objetivos_doble.size()) % objetivos_doble.size()
			turno._actualizar_marcadores_objetivo_doble()
	elif event.is_action_pressed("btn_derecha") or event.is_action_pressed("btn_abajo"):
		Singleton.play_sound.emit("SE_SELECT")
		if objetivos_doble.size() > 1:
			indice_objetivo_doble = (indice_objetivo_doble + 1) % objetivos_doble.size()
			turno._actualizar_marcadores_objetivo_doble()
	elif event.is_action_pressed("btn_accion"):
		Singleton.play_sound.emit("SE_SELECT")
		turno._confirmar_objetivo_doble(objetivos_doble[indice_objetivo_doble], slot_jugador_seleccionado)
	elif event.is_action_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		seleccionando_objetivo_doble = false
		objetivos_doble.clear()
		slot_rival.marcar_objetivo(false)
		slot_rival_secundario.marcar_objetivo(false)
		slot_jugador.marcar_objetivo(false)
		slot_jugador_secundario.marcar_objetivo(false)
		iniciar_cuadro_movimientos(pokemones_activos_jugador[slot_jugador_seleccionado])
		presentacion.mostrar_menu_movimientos()

func iniciar_cuadro_movimientos(pkm) -> void:
	presentacion.menu_movs.set_movs(BattleTransformRules.moves(pkm))

## `elecciones_jugador` ({slot: BasePokemon}) trae los relevos que el jugador
## eligió en el equipo; los slots sin elección toman la primera reserva.
## Orden de bancos de HandleFaintedMonActions (0,1,2,3): J0, R0, J1, R1.
func _reponer_slots_dobles(elecciones_jugador: Dictionary = {}) -> void:
	for indice in range(2):
		for lado in [true, false]:
			var activos := pokemones_activos_jugador if lado else pokemones_activos_enemigo
			var equipo := equipo_jugador_pokemones if lado else equipo_enemigo_pokemones
			var slots := [slot_jugador, slot_jugador_secundario] if lado else [slot_rival, slot_rival_secundario]
			if indice >= activos.size():
				continue
			var activo: BasePokemon = activos[indice]
			if activo != null and activo.estad_ps_actual > 0:
				continue
			# OpponentHandlecmd22 lee aún los datos de combate del que cayó.
			var elegido: BasePokemon = elecciones_jugador.get(indice) if lado else resultado.elegir_relevo_rival(activo)
			HabilidadesCombate.limpiar_combate(activo)
			_liberar_enamorados_de(activo)
			var reemplazo: BasePokemon = null
			if elegido != null and elegido.puede_combatir() and not activos.has(elegido):
				reemplazo = elegido
			else:
				for candidato in equipo:
					if candidato != null and candidato.puede_combatir() and not activos.has(candidato):
						reemplazo = candidato
						break
			activos[indice] = reemplazo
			if reemplazo == null:
				slots[indice].ocultar()
				if indice == 0:
					if lado:
						poke_jugador = null
						combatiente_jugador = null
					else:
						poke_enemigo = null
						combatiente_enemigo = null
				continue
			if not lado:
				_registrar_rival_visto(reemplazo)
				resultado._reiniciar_participantes_exp(indice)
			combatientes_activos[reemplazo] = PokemonCombatState.new(reemplazo)
			if lado:
				resultado._registrar_participante_experiencia(reemplazo)
			slots[indice].configurar_pokemon(reemplazo, lado, hud._estadoE2S(reemplazo.estado), resultado._obtener_exp_inicio_nivel(reemplazo) if lado else 0)
			if not lado:
				_actualizar_indicador_capturado(slots[indice], reemplazo)
			aplicar_offset_a_slot(slots[indice], reemplazo, lado)
			cargar_sprite_pokemon_seguro(slots[indice].sprite_pokemon, reemplazo.nombre_interno, not lado, reemplazo.es_shiny(), reemplazo.personalidad)
			# Sale de la ball en `resultado.presentar_envio_doble`, que también dispara grito y destellos.
			resultado.preparar_envio_pokemon_slot(slots[indice])
			envios_dobles_pendientes.append({"slot": slots[indice], "pokemon": reemplazo})
			if indice == 0:
				if lado:
					poke_jugador = reemplazo
					combatiente_jugador = combatientes_activos[reemplazo]
				else:
					poke_enemigo = reemplazo
					combatiente_enemigo = combatientes_activos[reemplazo]

## Etapa 3 (D4): `_actualizar_estado_visual_pokemon`/`_obtener_slot_de_pokemon`/
## `_obtener_cuadro_ps_de_pokemon` se mudaron a `BattleHudController` — ver
## `hud._actualizar_estado_visual_pokemon()` etc. Los llamadores de este
## archivo (`_procesar_bostezo_fin_ronda`/`_procesar_danio_estado_fin_ronda`)
## pasan por `hud.` directamente.

func _aplicar_danio_a_pokemon(objetivo: BasePokemon, cuadro_ps_objetivo: Node, dano: int, body_cause: Dictionary={}) -> Dictionary:
	var hp_inicial = objetivo.estad_ps_actual
	var hp_final = maxi(0, hp_inicial - dano)
	var resistio_aguante = false
	var combatiente = _obtener_combatiente(objetivo)
	# Only an admitted source162 opcode0 attack bypasses this legacy safeguard.
	var source_super_fang: bool=preload("res://scripts/battle/fixed_damage_rules.gd").owns_endure_bypass(self,body_cause)
	if not source_super_fang and combatiente != null and combatiente.aguante_este_turno and hp_inicial > 0 and hp_final < 1:
		hp_final = 1
		resistio_aguante = true
	var dano_aplicado = maxi(0, hp_inicial - hp_final)
	objetivo.estad_ps_actual = hp_final
	# atk0B_healthbarupdate: gBattleResults.playerMonWasDamaged.
	if dano > 0 and equipo_jugador_pokemones.has(objetivo):
		ResultadosCombate.registrar_dano_jugador()
	# Synchronous source datahpupdate receipt precedes lethal retirement and HUD.
	if dano>=0 and not body_cause.is_empty():bank_damage_history.commit(body_cause,dano_aplicado)
	if hp_final <= 0 and combatiente != null:
		combatiente.cancelar_continuacion()
		_retirar_sustituto_de_pokemon(objetivo)
	if dano_aplicado > 0 and cuadro_ps_objetivo != null:
		# Etapa 3 (D5): solo el trigger visual vive en BattleHudController;
		# el cálculo de daño y el chequeo de `aguante` (arriba) se quedan aquí.
		await hud.animar_dano(cuadro_ps_objetivo, objetivo.estad_ps, objetivo.estad_ps_actual)
	return {
		"damage": dano_aplicado,
		"endured": resistio_aguante
	}

func _procesar_fin_de_ronda() -> bool:
	if not await screen_rules.end_round():return false
	if not await safeguard_rules.end_round():return false
	if not await healing_stream_rules.wish_end_round():return false
	if not await dust_weather_rules.end_round():return false
	var activos: Array[BasePokemon] = []
	if formato_batalla == Singleton.FormatoBatalla.DOBLE:
		activos.append_array(pokemones_activos_jugador)
		activos.append_array(pokemones_activos_enemigo)
	else:
		activos.assign([poke_jugador, poke_enemigo])
	# Ruby HandleTurnEffects progresses each bank: ability, item, seed, poison/burn,
	# then later Yawn. Ingrain precedes per-mon abilities as in Ruby.
	for pokemon: BasePokemon in habilidades.activos_por_velocidad():
		var accepted: Dictionary=field_rules.capture(pokemon)
		if accepted.is_empty():continue
		if not await healing_stream_rules.ingrain(pokemon):return false
		if not field_rules.valid(accepted):continue
		await habilidades.fin_de_turno(pokemon)
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/held_leftovers_rules.gd").end_round(self,accepted)
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/recycle_rules.gd").hp_end_round(self,pokemon,accepted)
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/held_pp_berry_rules.gd").end_round(self,accepted)
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/held_status_berry_rules.gd").round_pass(self,accepted)
		if not field_rules.valid(accepted):continue
		await field_rules.drain(pokemon)
		if not field_rules.valid(accepted):continue
		await _procesar_danio_estado_fin_ronda(pokemon,accepted.state.get_ref())
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/curse_nightmare_rules.gd").residual(self,pokemon,accepted.state.get_ref())
		if not field_rules.valid(accepted):continue
		if not await preload("res://scripts/battle/turn_trap_rules.gd").residual(self,pokemon,accepted.state.get_ref()):return false
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/uproar_rules.gd").end_round(self,pokemon,accepted.state.get_ref())
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/disable_rules.gd").end_round(self,pokemon,accepted.state.get_ref())
		if not field_rules.valid(accepted):continue
		await preload("res://scripts/battle/encore_rules.gd").end_round(self,pokemon,accepted.state.get_ref())
		if not field_rules.valid(accepted):continue
		await _procesar_bostezo_fin_ronda(pokemon,accepted.state.get_ref())
	if not await turno.settle_end_round_faints(): return false
	await turno.resolve_future_attacks()
	if not turno._future_battle_live(): return false
	if not await preload("res://scripts/battle/perish_song_rules.gd").end_round(self):return false
	for pokemon in activos:
		var combatiente := _obtener_combatiente(pokemon) if pokemon != null else null
		if combatiente != null:
			var was_semi := not combatiente.semi_invulnerable.is_empty()
			var rampage_confused: bool=BattleRampageRules.finish_round(self,combatiente,contador_turnos)
			combatiente.finalizar_ronda()
			if rampage_confused:await mostrar_texto_batalla("¡%s se confundió!" % pokemon.get_nombre_combate())
			if was_semi: turno._proyectar_semi(pokemon)
	bank_damage_history.clear() # TurnValuesCleanUp(false), once after all actual tails.
	return true

func _procesar_bostezo_fin_ronda(pokemon: BasePokemon, combatiente: PokemonEnCombate) -> void:
	if pokemon == null or combatiente == null or pokemon.estad_ps_actual <= 0:
		return
	if combatiente.turnos_bostezo <= 0:
		return
	combatiente.turnos_bostezo -= 1
	if combatiente.turnos_bostezo > 0 or pokemon.estado != Singleton.ProblemaEstado.NORMAL:
		return
	if preload("res://scripts/battle/uproar_rules.gd").blocks_sleep(self,pokemon):return
	# INSOMNIO / ESPÍRITU VITAL (p. ej. tras RASTRO) impiden dormirse.
	var bloqueo_sueno := HabilidadesCombate.mensaje_impide_estado(pokemon, HabilidadesCombate.ESTADO_DORMIDO)
	if not bloqueo_sueno.is_empty():
		await mostrar_texto_batalla(bloqueo_sueno)
		return
	pokemon.estado = Singleton.ProblemaEstado.DORMIDO
	combatiente.iniciar_sueno()
	# Ruby YawnMakesAsleep emits statusanimation before status icon/message.
	if not await turno.presentar_fase_estado("ruby:status/4",pokemon):return
	hud._actualizar_estado_visual_pokemon(pokemon)
	await mostrar_texto_batalla("¡%s se quedó dormido!" % pokemon.get_nombre_combate())

func _procesar_danio_estado_fin_ronda(pokemon: BasePokemon, combatiente: PokemonEnCombate) -> void:
	if pokemon == null or combatiente == null or pokemon.estad_ps_actual <= 0:
		return

	var dano = 0
	var mensaje = ""
	match pokemon.estado:
		Singleton.ProblemaEstado.ENVENENADO:
			if combatiente.envenenamiento_grave:
				# ENDTURN_BAD_POISON: el mínimo de 1 va antes de multiplicar; la cuenta topa en 15.
				var cuenta: int = maxi(combatiente.contador_veneno_grave, 1)
				dano = maxi(1, pokemon.estad_ps / 16) * cuenta
				combatiente.contador_veneno_grave = mini(cuenta + 1, 15)
				mensaje = "¡%s sufrió daño por veneno grave!" % pokemon.get_nombre_combate()
			else:
				dano = maxi(1, pokemon.estad_ps / 8)
				mensaje = "¡%s sufrió daño por veneno!" % pokemon.get_nombre_combate()
		Singleton.ProblemaEstado.QUEMADO:
			dano = maxi(1, pokemon.estad_ps / 8)
			mensaje = "¡%s sufrió daño por quemadura!" % pokemon.get_nombre_combate()
		_:
			return

	# Status source visual paces the already-selected residual outcome; never reapplies HP.
	var status_key: String="ruby:status/0" if pokemon.estado==Singleton.ProblemaEstado.ENVENENADO else "ruby:status/2"
	if not await turno.presentar_fase_estado(status_key,pokemon):return
	var resultado = await _aplicar_danio_a_pokemon(pokemon, hud._obtener_cuadro_ps_de_pokemon(pokemon), dano)
	if int(resultado.get("damage", 0)) <= 0 and not bool(resultado.get("endured", false)):
		return
	await mostrar_texto_batalla(mensaje)
	if bool(resultado.get("endured", false)):
		await mostrar_texto_batalla("¡%s aguantó con 1 PS!" % pokemon.get_nombre_combate())

func _reproducir_musica_batalla_mapa_si_corresponde() -> void:
	if not Singleton.has_method("reproducir_tema"):
		return
	var indice_bus_master := AudioServer.get_bus_index("Master")
	if indice_bus_master >= 0 and AudioServer.is_bus_mute(indice_bus_master):
		return
	var admin_mapas = get_tree().root.get_node_or_null("AdministradorMapa")
	if admin_mapas == null:
		return
	var mapa_actual: MapaConfiguracion = admin_mapas.get("mapa_actual") as MapaConfiguracion
	if mapa_actual == null:
		return
	var reproductor_musica = Singleton.obtener_nodo("ReproductorMusica")
	if reproductor_musica != null and reproductor_musica.has_method("obtener_tema_actual"):
		var tema_actual := str(reproductor_musica.call("obtener_tema_actual"))
		var tema_lugar := mapa_actual.obtener_musica_mapa_efectiva()
		if admin_mapas.has_method("obtener_musica_lugar_actual"):
			tema_lugar = str(admin_mapas.call("obtener_musica_lugar_actual"))
		if not tema_actual.is_empty() and tema_actual != tema_lugar:
			return
	var musica_mapa := mapa_actual.obtener_musica_batalla_efectiva()
	var musica_batalla := ""
	if configuracion_batalla != null and configuracion_batalla.tipo == Singleton.TipoBatalla.ENTRENADOR:
		musica_batalla = BattleLaunchService.resolver_musica_entrenador(
			configuracion_batalla.entrenador, musica_mapa)
	else:
		musica_batalla = BattleLaunchService.resolver_musica_salvaje(musica_mapa)
	Singleton.reproducir_tema(musica_batalla)

## Función para limpiar todos los tweens al salir.
func _exit_tree():
	field_rules.clear()
	screen_rules.clear()
	safeguard_rules.clear()
	dust_weather_rules.clear()
	healing_stream_rules.clear()
	BattleHeldItemRules.clear(self)
	preload("res://scripts/battle/recycle_rules.gd").clear(self)
	_retirar_presentaciones_sustituto()
	for state: PokemonEnCombate in [combatiente_jugador,combatiente_enemigo]:
		if state!=null:state.substitute_hp=0
	if turno != null: turno.future_attacks.clear()
	for state in combatientes_activos.values():
		if state is PokemonEnCombate:
			state.cancelar_continuacion();state.substitute_hp=0
	# Restaurar orden original si no se hizo antes (seguridad)
	# El flag _orden_restaurado evita doble ejecución (ya se llamó al terminar la batalla)
	_restaurar_orden_original_equipo()
	lanzamiento_ball.limpiar()

	# Limpiar tweens antes de salir
	if tween:
		tween.kill()
		tween = null
	if tween2:
		tween2.kill()
		tween2 = null
	if tween_b:
		tween_b.kill()
		tween_b = null
	# DatabaseManager (autoload) owns the connection lifecycle; nothing to close here.

# Métodos para el control de input temporal
func get_ignorar_input_temporal() -> bool:
	return ignorar_input_temporal

func reset_ignorar_input_temporal() -> void:
	ignorar_input_temporal = false
	loggear("Input temporal reactivado")

## Función auxiliar para crear equipo de forma segura
## Devuelve un array de BasePokemon
func crear_equipo_seguro(nombres_preferidos: Array, tipo_entrenador: String = "") -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []
	var pokemones_disponibles = proveedor_datos.obtener_lista_pokemon_por_nombre()

	if pokemones_disponibles.size() == 0:
		print("⚠️ No hay Pokémon disponibles en la base de datos")
		return equipo

	# Intentar usar los nombres preferidos
	for nomintpk in nombres_preferidos:
		if proveedor_datos.existe_pokemon(nomintpk):
			var nivel = randi_range(20, 30)  # Nivel aleatorio entre 20-30
			var pokemon: BasePokemon = BasePokemon.new(nomintpk, nivel, tipo_entrenador)
			equipo.append(pokemon)
			print("✅ Creado: %s nivel %d para %s" % [nomintpk, nivel, tipo_entrenador if tipo_entrenador != "" else "enemigo"])
		else:
			print("⚠️ %s no encontrado, se omitirá del equipo" % nomintpk)

	# Si no tenemos suficientes Pokémon, rellenar con aleatorios
	while equipo.size() < 2 and pokemones_disponibles.size() > 0:
		var pokemon_aleatorio = pokemones_disponibles[randi() % pokemones_disponibles.size()]
		var nomintpk = pokemon_aleatorio["nombre_interno"]

		# Evitar duplicados
		var ya_existe = false
		for poke: BasePokemon in equipo:
			if poke.nombre_interno == nomintpk:
				ya_existe = true
				break

		if not ya_existe:
			var nivel = randi_range(20, 30)
			var pokemon: BasePokemon = BasePokemon.new(nomintpk, nivel, tipo_entrenador)
			equipo.append(pokemon)
			print("🎲 Agregado aleatoriamente: %s nivel %d" % [nomintpk, nivel])

	return equipo

# === SISTEMA DE SPRITES MEJORADO ===

## Crear placeholder si no existe
# func crear_placeholder_si_no_existe():
# 	var placeholder_path = "res://graficos/pokemon/placeholder.png"
# 	if not ResourceLoader.exists(placeholder_path):
# 		print("🔧 Creando placeholder para sprites faltantes...")
# 		# No podemos guardar archivos en runtime, así que usaremos texture temporal
# 		print("ℹ️ Se usarán texturas temporales para sprites faltantes")

## Actualizar sprites de batalla según Pokémon actuales
func actualizar_sprites_batalla():
	if poke_enemigo and spr_pokemon_rival:
		cargar_sprite_pokemon_seguro(spr_pokemon_rival, poke_enemigo.nombre_interno, true, poke_enemigo.es_shiny(), poke_enemigo.personalidad)
	if formato_batalla == Singleton.FormatoBatalla.DOBLE and pokemones_activos_enemigo.size() > 1:
		cargar_sprite_pokemon_seguro(slot_rival_secundario.sprite_pokemon, pokemones_activos_enemigo[1].nombre_interno, true, pokemones_activos_enemigo[1].es_shiny(), pokemones_activos_enemigo[1].personalidad)

	if poke_jugador and spr_pokemon_jugador:
		cargar_sprite_pokemon_seguro(spr_pokemon_jugador, poke_jugador.nombre_interno, false, poke_jugador.es_shiny())
	if formato_batalla == Singleton.FormatoBatalla.DOBLE and pokemones_activos_jugador.size() > 1:
		cargar_sprite_pokemon_seguro(slot_jugador_secundario.sprite_pokemon, pokemones_activos_jugador[1].nombre_interno, false, pokemones_activos_jugador[1].es_shiny())

## Actualizar solo el sprite del Pokémon jugador
func actualizar_sprite_pokemon_jugador():
	if poke_jugador and spr_pokemon_jugador:
		cargar_sprite_pokemon_seguro(spr_pokemon_jugador, poke_jugador.nombre_interno, false, poke_jugador.es_shiny())

## Actualizar solo el sprite del Pokémon enemigo
func actualizar_sprite_pokemon_enemigo():
	if poke_enemigo and spr_pokemon_rival:
		cargar_sprite_pokemon_seguro(spr_pokemon_rival, poke_enemigo.nombre_interno, true, poke_enemigo.es_shiny(), poke_enemigo.personalidad)

## Cargar sprite de Pokémon con manejo de errores.
## `personalidad` (opcional, -1 = ninguna): la del Pokémon mostrado. En el frente
## (rival) decide las manchas de SPINDA (pokeruby battle_7.c); la espalda del
## jugador nunca las lleva.
func cargar_sprite_pokemon_seguro(nodo_sprite: Sprite2D, nombre_interno: String, es_frente: bool, es_shiny: bool = false, personalidad: int = -1):
	if nodo_sprite == null:
		print("❌ Error: nodo Sprite2D es null")
		return

	var sprite_path = construir_ruta_sprite_segura(nombre_interno, es_frente, es_shiny)

	# Intentar cargar el sprite
	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path) as Texture2D
		if texture != null:
			if es_frente and personalidad >= 0 and ManchasSpinda.aplica_a(nombre_interno):
				# Variante con manchas (cacheada por personalidad en el manager).
				texture = PokemonSpriteManager.cargar_sprite_pokemon(nombre_interno, PokemonSpriteManager.SpriteType.FRONT, es_shiny, personalidad)
			nodo_sprite.texture = texture
			_configurar_frame_sprite_nuevo(nodo_sprite)
			var tipo_texto = "frente" if es_frente else "espalda"
			var shiny_texto = " shiny" if es_shiny else ""
			print("✅ Sprite cargado: %s (%s%s)" % [nombre_interno, tipo_texto, shiny_texto])
			return
		else:
			print("⚠️ Error al cargar texture: %s" % sprite_path)
	else:
		print("⚠️ Sprite no encontrado: %s" % sprite_path)

	# Usar placeholder
	nodo_sprite.texture = crear_sprite_placeholder(nombre_interno, es_frente)
	_configurar_frame_sprite_nuevo(nodo_sprite)
	print("🔄 Usando placeholder para: %s" % nombre_interno)

func _configurar_frame_sprite_nuevo(sprite: Sprite2D) -> void:
	# A new party graphic is a whole native image, not the prior appearance's
	# selected atlas/region/frame. Only this explicit loader owns these writes.
	sprite.hframes=1;sprite.vframes=1;sprite.frame=0;sprite.region_enabled=false
	sprite.flip_h=false;sprite.flip_v=false

## Construir ruta de sprite de forma segura
func construir_ruta_sprite_segura(nombre_interno: String, es_frente: bool, es_shiny: bool = false) -> String:
	var nombre_sprite = nombre_interno.to_upper()
	var base_path = "res://graficos/pokemon/"

	if es_shiny:
		if es_frente:
			base_path += "front-shiny/"
		else:
			base_path += "back-shiny/"
	else:
		if es_frente:
			base_path += "front/"
		else:
			base_path += "back/"

	return base_path + nombre_sprite + ".png"

## Crear sprite placeholder temporal
func crear_sprite_placeholder(_nombre_pokemon: String, es_frente: bool) -> ImageTexture:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)

	# Color según tipo
	var color = Color.MAGENTA if es_frente else Color.CYAN
	image.fill(color)

	# Borde negro
	for x in range(64):
		image.set_pixel(x, 0, Color.BLACK)
		image.set_pixel(x, 63, Color.BLACK)

	for y in range(64):
		image.set_pixel(0, y, Color.BLACK)
		image.set_pixel(63, y, Color.BLACK)

	# X simple en el centro
	for i in range(20):
		var offset = 22 + i
		if offset < 64:
			image.set_pixel(offset, offset, Color.WHITE)
			image.set_pixel(63 - offset, offset, Color.WHITE)

	return ImageTexture.create_from_image(image)

## ============================================================================
## FUNCIONES DE MANEJO DE ORDEN DE EQUIPO
## ============================================================================

## Guarda el orden original del equipo antes de la batalla
func _guardar_orden_original_equipo():
	print("📝 [BATALLA] Guardando orden original del equipo")
	for i in range(equipo_jugador_pokemones.size()):
		var pokemon: BasePokemon = equipo_jugador_pokemones[i]
		if pokemon != null:
			pokemon.indice_orden_original = i
			print("  - %s: posición original %d" % [pokemon.nombre_interno, i])
		else:
			print("  ⚠️ Pokémon en posición %d es null" % i)

## Índice del primer Pokémon del equipo que puede combatir (PS > 0 y no es
## un huevo), o -1 si no hay ninguno.
static func indice_primer_pokemon_combatiente(equipo: Array) -> int:
	for i in range(equipo.size()):
		var pokemon: BasePokemon = equipo[i]
		if pokemon != null and pokemon.puede_combatir():
			return i
	return -1

## Reorganiza el equipo para la batalla: pone al primer Pokémon que puede
## combatir (con PS y que no sea un huevo) como líder.
func _reorganizar_equipo_para_batalla():
	print("🔄 [BATALLA] Reorganizando equipo para batalla")

	# Si el primer Pokémon ya está en condiciones, no hacer nada
	if equipo_jugador_pokemones.size() > 0 and equipo_jugador_pokemones[0] != null and equipo_jugador_pokemones[0].puede_combatir():
		print("  - El primer Pokémon ya está en condiciones, no se reorganiza")
		return

	# Buscar el primer Pokémon que puede combatir
	var indice_pokemon_valido := indice_primer_pokemon_combatiente(equipo_jugador_pokemones)

	# Si encontramos un Pokémon válido que no esté en primera posición, intercambiar
	if indice_pokemon_valido > 0:
		var pokemon_valido: BasePokemon = equipo_jugador_pokemones[indice_pokemon_valido]
		var pokemon_debilitado: BasePokemon = equipo_jugador_pokemones[0]

		print("  - Intercambiando %s (pos. %d) con %s (pos. 0)" % [
			pokemon_valido.nombre_interno,
			indice_pokemon_valido,
			pokemon_debilitado.nombre_interno
		])

		# Realizar el intercambio
		equipo_jugador_pokemones[0] = pokemon_valido
		equipo_jugador_pokemones[indice_pokemon_valido] = pokemon_debilitado

		print("  - Nuevo orden de batalla establecido")
	elif indice_pokemon_valido == -1:
		print("  ⚠️ No hay Pokémon válidos para batalla")

## Restaura el orden original del equipo al finalizar la batalla
func _restaurar_orden_original_equipo():
	if turno != null: turno.future_attacks.clear()
	if _orden_restaurado:
		print("🔙 [BATALLA] Orden ya restaurado, omitiendo")
		return
	_orden_restaurado = true
	# Habilidad prestada (RASTRO) y tipos de CAMBIO COLOR no sobreviven al combate.
	habilidades.limpiar_equipos()
	# El equipo del tutorial es el de BLASCO (datos de inicio), no el guardado.
	if tutorial_blasco:
		return
	print("🔙 [BATALLA] Restaurando orden original del equipo")

	# Verificar que tenemos un equipo válido
	if equipo_jugador_pokemones == null or equipo_jugador_pokemones.size() == 0:
		print("  ⚠️ No hay equipo para restaurar")
		return

	var equipo_original_orden := reconstruir_orden_original_equipo(equipo_jugador_pokemones)
	for i in range(equipo_original_orden.size()):
		print("  - %s restaurado a posición %d" % [equipo_original_orden[i].nombre_interno, i])

	# Limpiar los índices de orden original
	for pokemon in equipo_jugador_pokemones:
		if pokemon == null:
			continue
		pokemon.indice_orden_original = -1

	# Actualizar el equipo del sistema de guardado directamente
	SistemaGuardado.datos_vivos.equipo_pokemon = equipo_original_orden
	print("  ✅ Orden original restaurado en el sistema de guardado")

## Reconstruye el equipo en su orden previo a la batalla a partir de
## `indice_orden_original`, sin perder Pokémon ni dejar huecos `null`: los que
## tienen un índice válido y no repetido vuelven a su posición relativa; el
## resto (p. ej. índice -1 de un Pokémon añadido durante la batalla) se agrega
## al final en el orden en que aparece. Pura: no toca SistemaGuardado ni
## limpia los índices.
static func reconstruir_orden_original_equipo(equipo: Array) -> Array[BasePokemon]:
	var por_posicion: Array[BasePokemon] = []
	por_posicion.resize(equipo.size())
	var sin_posicion: Array[BasePokemon] = []
	for pokemon in equipo:
		if not (pokemon is BasePokemon):
			continue
		var indice: int = pokemon.indice_orden_original
		if indice >= 0 and indice < por_posicion.size() and por_posicion[indice] == null:
			por_posicion[indice] = pokemon
		else:
			sin_posicion.append(pokemon)

	var reconstruido: Array[BasePokemon] = []
	for pokemon in por_posicion:
		if pokemon != null:
			reconstruido.append(pokemon)
	reconstruido.append_array(sin_posicion)
	return reconstruido

## ============================================================================
## FUNCIONES DE VALIDACIÓN
## ============================================================================

## Validar coherencia de Pokémon creados
func validar_coherencia_pokemones():
	print("\n🔍 VALIDANDO COHERENCIA DE POKÉMON:")
	print("=====================================")

	for i in range(equipo_jugador_pokemones.size()):
		var poke = equipo_jugador_pokemones[i]
		validar_pokemon_individual(poke, "JUGADOR", i + 1)

	for i in range(equipo_enemigo_pokemones.size()):
		var poke = equipo_enemigo_pokemones[i]
		validar_pokemon_individual(poke, "ENEMIGO", i + 1)

	print("=====================================")
	print("✅ Validación completada")

## Validar un Pokémon individual
func validar_pokemon_individual(pokemon, tipo_entrenador: String, numero: int):
	if pokemon == null:
		print("❌ %s %d: Pokémon es null" % [tipo_entrenador, numero])
		return

	print("🔸 %s %d: %s (Nv.%d)" % [tipo_entrenador, numero, pokemon.nombre_interno, pokemon.nivel])

	# Verificar sexo
	var sexo_info = ""
	if pokemon.sexo != null:
		match pokemon.sexo:
			"M":
				sexo_info = "♂️ Masculino"
			"F":
				sexo_info = "♀️ Femenino"
			"SIN_SEXO":
				sexo_info = "🚫 Sin sexo"
			_:
				sexo_info = "❓ Desconocido (%s)" % pokemon.sexo
	else:
		sexo_info = "❌ Sin sexo definido"
	print("   👤 Sexo: %s" % sexo_info)

	# Verificar tipos
	var tipos_info = ""
	if pokemon.tipo_1 != null and pokemon.tipo_1 != "":
		tipos_info = pokemon.tipo_1
		if pokemon.tipo_2 != null and pokemon.tipo_2 != "":
			tipos_info += "/" + pokemon.tipo_2
	else:
		tipos_info = "❌ Sin tipos definidos"
	print("   🏷️ Tipos: %s" % tipos_info)

	# Verificar que tenga stats básicos
	if pokemon.estad_ps_actual != null and pokemon.estad_ps != null:
		var salud_porcentaje = float(pokemon.estad_ps_actual) / float(pokemon.estad_ps) * 100
		print("   💚 Salud: %d/%d (%.1f%%)" % [pokemon.estad_ps_actual, pokemon.estad_ps, salud_porcentaje])

	# Verificar movimientos
	if pokemon.movimientos != null and pokemon.movimientos.size() > 0:
		print("   ⚔️ Movimientos: %d" % pokemon.movimientos.size())
		for i in range(min(pokemon.movimientos.size(), 4)):
			var mov = pokemon.movimientos[i]
			if typeof(mov) == TYPE_STRING:
				print("     - %s" % mov)
			elif typeof(mov) == TYPE_DICTIONARY and mov.has("nombre"):
				print("     - %s" % mov.nombre)
	else:
		print("   ⚠️ Sin movimientos definidos")

	# Verificar sprite
	var sprite_path = construir_ruta_sprite_segura(pokemon.nombre_interno, tipo_entrenador == "ENEMIGO", false)
	if ResourceLoader.exists(sprite_path):
		print("   🎨 Sprite: ✅ Disponible")
	else:
		print("   🎨 Sprite: ⚠️ Faltante (se usará placeholder)")

## Verificar sprites disponibles para equipos de batalla
func verificar_sprites_equipos():
	print("\n🎨 VERIFICANDO SPRITES DE EQUIPOS:")
	print("==================================")

	var sprites_ok = 0
	var sprites_faltantes = 0

	# Verificar equipo jugador
	print("👤 EQUIPO JUGADOR:")
	for i in range(equipo_jugador_pokemones.size()):
		var poke = equipo_jugador_pokemones[i]
		if poke == null:
			print("   %d. ❌ Pokémon nulo en posición %d" % [i+1, i])
			sprites_faltantes += 1
			continue

		var resultado = verificar_sprite_individual(poke.nombre_interno, false)
		if resultado:
			sprites_ok += 1
		else:
			sprites_faltantes += 1
		print("   %d. %s: %s" % [i+1, poke.nombre_interno, "✅" if resultado else "⚠️ placeholder"])

	# Verificar equipo enemigo
	print("🤖 EQUIPO ENEMIGO:")
	for i in range(equipo_enemigo_pokemones.size()):
		var poke = equipo_enemigo_pokemones[i]
		if poke == null:
			print("   %d. ❌ Pokémon nulo en posición %d" % [i+1, i])
			sprites_faltantes += 1
			continue

		var resultado = verificar_sprite_individual(poke.nombre_interno, true)
		if resultado:
			sprites_ok += 1
		else:
			sprites_faltantes += 1
		print("   %d. %s: %s" % [i+1, poke.nombre_interno, "✅" if resultado else "⚠️ placeholder"])

	print("==================================")
	print("📊 RESUMEN SPRITES:")
	print("   ✅ Disponibles: %d" % sprites_ok)
	print("   ⚠️ Placeholders: %d" % sprites_faltantes)
	if sprites_faltantes == 0:
		print("   🎉 ¡Todos los sprites están disponibles!")

## Verificar sprite individual
func verificar_sprite_individual(nombre_pokemon: String, es_frente: bool) -> bool:
	var sprite_path = construir_ruta_sprite_segura(nombre_pokemon, es_frente, false)
	return ResourceLoader.exists(sprite_path)

## Crear equipo para batalla salvaje con un solo Pokémon específico.
## `snapshot` es el dict completo del autogenerador (IVs, naturaleza, movimientos,
## etc.); vacío en batallas normales de juego, poblado desde el editor de pruebas.
func crear_equipo_salvaje(nombre_interno: String, nivel: int, snapshot: Dictionary = {}) -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []

	if proveedor_datos.existe_pokemon(nombre_interno):
		var pokemon: BasePokemon = BasePokemon.new(nombre_interno, nivel, "salvaje")

		if pokemon == null:
			print("❌ Error: No se pudo crear BasePokemon salvaje para %s, usando Rhydon" % nombre_interno)
			pokemon = BasePokemon.new("RHYDON", nivel, "salvaje")

		if pokemon != null:
			if not snapshot.is_empty():
				pokemon.aplicar_snapshot(snapshot)
			equipo.append(pokemon)
			print("✅ Pokémon salvaje creado: %s nivel %d" % [pokemon.nombre_interno, nivel])
		else:
			print("❌ Error crítico: No se pudo crear ningún Pokémon salvaje")
	else:
		print("❌ Pokémon salvaje %s no encontrado, usando Rhydon por defecto" % nombre_interno)
		var pokemon: BasePokemon = BasePokemon.new("RHYDON", nivel, "salvaje")
		if pokemon != null:
			equipo.append(pokemon)
		else:
			print("❌ Error crítico: No se pudo crear Pokémon por defecto")

	return equipo

## Crear equipo desde un objeto DatosEntrenador
func crear_equipo_desde_entrenador(entrenador: DatosEntrenador) -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []

	print("📋 Creando equipo para entrenador: %s" % entrenador.nombre)

	for i in range(entrenador.pokemon.size()):
		var pokemon_data = entrenador.pokemon[i]
		var nombre_interno = pokemon_data.nombre_interno
		var nivel = pokemon_data.nivel

		if proveedor_datos.existe_pokemon(nombre_interno):
			var pokemon: BasePokemon = BasePokemon.new(nombre_interno, nivel, entrenador.clase_entrenador)

			# Validar que el constructor no devolvió null
			if pokemon == null:
				print("❌ Error: No se pudo crear BasePokemon para %s" % nombre_interno)
				continue

			# Asignar objeto si tiene
			if not pokemon_data.objeto.is_empty():
				pokemon.objeto = pokemon_data.objeto

			# Movimientos por nivel + fijos del entrenador (ver MovimientosEntrenador).
			MovimientosEntrenador.aplicar(pokemon, pokemon_data.movimientos)

			equipo.append(pokemon)
			print("✅ Agregado: %s nivel %d" % [nombre_interno, nivel])
		else:
			print("⚠️ Pokémon %s no encontrado en BD, se omitirá" % nombre_interno)

	# Si no se pudo crear ningún Pokémon, agregar uno por defecto
	if equipo.size() == 0:
		print("❌ No se pudo crear equipo para entrenador, usando Pokémon por defecto")
		var pokemon: BasePokemon = BasePokemon.new("RHYDON", 25, entrenador.clase_entrenador)
		if pokemon != null:
			equipo.append(pokemon)
		else:
			print("❌ Error crítico: No se pudo crear Pokémon por defecto para entrenador")

	print("📝 Equipo del entrenador completado: %d Pokémon" % equipo.size())
	return equipo

## ============================================================================
## FUNCIONES DE PRUEBA PARA EJECUCIÓN INDIVIDUAL
## ============================================================================

## Detecta si estamos ejecutando la escena individualmente para activar modo prueba.
func _detectar_modo_prueba():
	if not auto_iniciar_prueba or get_tree().current_scene != self:
		modo_prueba = false
		return

	# Verificar si tenemos acceso a los singleton principales
	var tiene_sistema_guardado = has_node("/root/SistemaGuardado")
	var nodo_administrador_mapa = Singleton.obtener_nodo("Admin")

	if not tiene_sistema_guardado or not nodo_administrador_mapa:
		print("🧪 [BATALLA] Modo de prueba detectado - Ejecutando escena individualmente")
		modo_prueba = true
		_inicializar_datos_prueba()
	else:
		print("🎮 [BATALLA] Modo normal - Datos disponibles desde el juego")
		modo_prueba = false

## Inicializa todos los datos necesarios para probar la batalla individualmente.
func _inicializar_datos_prueba():

	print("🧪 [BATALLA] Inicializando datos de prueba...")

	# Esperar un frame para que el árbol de nodos esté completo
	await get_tree().process_frame

	# 1. Crear/inicializar SistemaGuardado si no existe
	_inicializar_sistema_guardado_prueba()

	# 2. Preparar datos según el modo de prueba
	match hacer_prueba:
		ModoPrueba.BATALLA_SALVAJE:
			_crear_datos_salvaje_prueba()
		_:
			_crear_datos_entrenador_prueba()

	# 3. Iniciar la batalla automáticamente
	_iniciar_batalla_prueba()

## Crea un SistemaGuardado temporal con datos mínimos para la prueba.
func _inicializar_sistema_guardado_prueba():
	var sistema_guardado = get_node_or_null("/root/SistemaGuardado")

	if not sistema_guardado:
		print("⚠️ [BATALLA-PRUEBA] SistemaGuardado no disponible - Creando datos temporales")
		# Si no hay SistemaGuardado, crear datos básicos temporales
		_crear_equipo_jugador_temporal()
	else:
		print("✅ [BATALLA-PRUEBA] SistemaGuardado disponible")
		sistema_guardado.cargar_partida()
		# Verificar que tenga un equipo válido
		var equipo = sistema_guardado.get_equipo()
		if equipo.size() == 0:
			print("⚠️ [BATALLA-PRUEBA] Equipo vacío - Creando equipo de prueba")
			sistema_guardado.crear_equipo_de_prueba()

	SistemaGuardado.datos_vivos.opciones.imagen_tipo = 13

## Crea un equipo temporal para el jugador cuando no hay SistemaGuardado.
func _crear_equipo_jugador_temporal():
	print("🎲 [BATALLA-PRUEBA] Creando equipo temporal para el jugador")

	# Crear pokémon directamente usando la clase BasePokemon
	var treecko = BasePokemon.new("TREECKO", 5, "ASH")
	var mudkip = BasePokemon.new("MUDKIP", 5, "ASH")
	var torchic = BasePokemon.new("TORCHIC", 5, "ASH")

	# Asignar al equipo temporal
	equipo_jugador_pokemones = [treecko, mudkip, torchic]
	print("✅ [BATALLA-PRUEBA] Equipo temporal creado: %d pokémon" % equipo_jugador_pokemones.size())

## Crea los datos del entrenador con ID=1 y los configura para la batalla.
func _crear_datos_entrenador_prueba():
	print("👨‍💼 [BATALLA-PRUEBA] Creando datos del entrenador ID=1 (RICKY)")

	# Cargar entrenador usando DatabaseManager
	var entrenador: DatosEntrenador = null

	if DatabaseManager:
		entrenador = DatabaseManager.get_entrenador(1)

	if not entrenador:
		print("⚠️ [BATALLA-PRUEBA] No se pudo cargar entrenador desde DB - Creando manualmente")
		entrenador = _crear_entrenador_manual()

	# Configurar datos de batalla en Singleton
	# Usar valor numérico 1 que corresponde a ENTRENADOR_RUTA según el enum
	datos_prueba = {
		"tipo": Singleton.TipoBatalla.ENTRENADOR,
		"tema_grafico": Singleton.TemaBatalla.EDIFICIO_1,
		"tema_grafico_frente": Singleton.TemaBatallaFrente.BASICO,
		# "tema_grafico": Singleton.TemaBatalla.AGUA_PANTANOSA,
		# "tema_grafico_frente": Singleton.TemaBatallaFrente.AGUA_BAJA,
		"entrenador": entrenador,
		"puede_huir": true,
		"permite_captura": false,
		"comentario": "¡Patitas para qué las quiero!"
	}

	print("✅ [BATALLA-PRUEBA] Datos del entrenador configurados: %s" % entrenador.nombre)

## Crea los datos para una batalla de prueba contra un Pokémon salvaje.
func _crear_datos_salvaje_prueba():
	print("🌿 [BATALLA-PRUEBA] Configurando batalla salvaje de prueba (RALTS Nv.5)")
	datos_prueba = {
		"tipo": Singleton.TipoBatalla.SALVAJE,
		"tema_grafico": Singleton.TemaBatalla.HIERBA_ALTA,
		"tema_grafico_frente": Singleton.TemaBatallaFrente.HIERBA_ALTA,
		"pokemon_salvaje": { "nombre_interno": "RALTS", "nivel": 5 },
		"puede_huir": true,
		"permite_captura": true,
	}
	print("✅ [BATALLA-PRUEBA] Datos salvaje configurados")

## Crea manualmente los datos del entrenador ID=1 basado en el JSON.
func _crear_entrenador_manual() -> DatosEntrenador:
	var entrenador = DatosEntrenador.new()

	# Datos del entrenador ID=1 desde lista_entrenadores.json
	entrenador.clase_entrenador = "CAZABICHOS"
	entrenador.nombre = "RICKY"
	entrenador.sexo = "M"
	entrenador.num_sprite = 12
	entrenador.ratio_dinero = 4
	entrenador.musica_id = "batalla_lider_gimnasio"
	entrenador.objetos = []

	# Agregar sus pokémon (2 WURMPLE de nivel 4)
	entrenador.agregar_pokemon("WURMPLE", 4)
	entrenador.agregar_pokemon("WURMPLE", 4)

	return entrenador

enum ModoPrueba {BATALLA_SIMPLE, BATALLA_SALVAJE, SHADER}
var hacer_prueba: ModoPrueba = ModoPrueba.BATALLA_SALVAJE

## Inicia la batalla de prueba usando los datos configurados.
func _iniciar_batalla_prueba():
	print("⚔️ [BATALLA-PRUEBA] Iniciando batalla de prueba...")

	match hacer_prueba:
		ModoPrueba.BATALLA_SIMPLE:
			print("🧪 [BATALLA-PRUEBA] Modo: Batalla simple")
			# Esperar un poco más para que todo esté listo
			await get_tree().create_timer(0.5).timeout

			saltar_animaciones = false
			print("Valor de saltar_animaciones: ", saltar_animaciones)

			# Iniciar la batalla con transición
			_iniciar_batalla_con_transicion(datos_prueba, Callable(self, "_on_batalla_prueba_finalizada"))

			print("🎮 [BATALLA-PRUEBA] ¡Batalla iniciada! Jugador vs RICKY (CAZABICHOS)")

		ModoPrueba.BATALLA_SALVAJE:
			print("🧪 [BATALLA-PRUEBA] Modo: Batalla salvaje")
			await get_tree().create_timer(0.5).timeout
			saltar_animaciones = false
			_iniciar_batalla_con_transicion(datos_prueba, Callable(self, "_on_batalla_prueba_finalizada"))
			print("🎮 [BATALLA-PRUEBA] ¡Batalla salvaje iniciada!")

		ModoPrueba.SHADER:
			print("🧪 [BATALLA-PRUEBA] Modo: Shader de batalla (sin iniciar batalla)")
			datos_prueba["tema_grafico"] = Singleton.TemaBatalla.HIERBA_ALTA
			datos_batalla = datos_prueba
			# Activar shader de batalla y salir
			_aplicar_texturas_basicas()
			_configurar_batalla_sin_animaciones()
			visible = true
			intro_controller.probar_shader()

		_:
			print("⚠️ [BATALLA-PRUEBA] Modo desconocido, usando Batalla simple por defecto")

## Callback cuando la batalla de prueba finaliza.
func _on_batalla_prueba_finalizada(resultado: int):
	print("🏁 [BATALLA-PRUEBA] Batalla finalizada con resultado: %d" % resultado)
	# match resultado:
	# 	BATALLA_GANADA:
	# 		print("🎉 ¡Has ganado la batalla de prueba!")
	# 	BATALLA_PERDIDA:
	# 		print("😞 Has perdido la batalla de prueba.")
	# 	BATALLA_HUIDA:
	# 		print("🏃‍♂️ Has huido de la batalla de prueba.")
	# 	_:
	# 		print("❓ Resultado desconocido.")

## Función de logging para depuración
func loggear(message: String):
	print("[⚙️⚔️Batalla] %s" % message)

## ============================================================================
## SISTEMA DE TEXTO DE BATALLA
## ============================================================================

func _msje_intro_poke_salvaje() -> void:
	# sub_8010278: el salvaje grita al terminar de deslizarse a su sitio.
	reproducir_grito(poke_enemigo)
	# sub_8033018: el variocolor destella antes del anuncio (bc_8013568 espera a su controlador).
	var destellos: Node2D = iniciar_destellos_variocolor(slot_rival)
	if destellos != null:
		destellos.terminado.connect(_anunciar_poke_salvaje, CONNECT_ONE_SHOT)
	else:
		_anunciar_poke_salvaje()

func _anunciar_poke_salvaje() -> void:
	mostrar_texto_batalla("¡Un %s salvaje!" % poke_enemigo.nombre, false)

## Disparado por el Call Method Track de la animación "2. Jugador lanza
## pokeball" a t=0.62. Arranca la animación de caída de la Pokéball en el
## AnimationPlayer secundario `pkb_anim` ("cae_pokeball_y_sale_pokemon"),
## que ahora cubre toda la secuencia: caída/rebote de la Pokéball
## (visible/frame/activo_lanzamiento/progreso/velocidad_rotacion), aparición
## del Pokémon (disparada a su vez por `_iniciar_aparicion_pokemon_jugador`,
## más abajo) e ingreso del cuadro de PS. `_enviar_pokemon_jugador`
## (battle_intro_controller.gd) espera a que termine `pkb_anim` antes de
## llamar a `fase_input()`.
func _iniciar_caida_pokeball() -> void:
	pkb_anim.play(&"Pkb/cae_pokeball_y_sale_pokemon")

## Disparado por el Call Method Track de "cae_pokeball_y_sale_pokemon"
## (`pkb_anim`) a t=0.8, cuando la Pokéball aterriza. Prepara la posición
## inicial del Pokémon del jugador — depende de la especie enviada
## (`obtener_offset_pokemon`), así que no se puede expresar como keyframes
## fijos — y anima solo esa posición con un tween propio. La escala y la
## silueta del Pokémon las dispara `slot_jugador.reproducir_aparicion()`, que
## reproduce la animación local "aparicion" del propio slot (desacoplada del
## timeline global: ver nota en `battle_slot.gd`); la iluminación y el
## cuadro de PS, al ser elementos compartidos del campo/UI y no del slot,
## siguen como tracks de esta misma animación.
func _iniciar_aparicion_pokemon_jugador() -> void:
	var offset_especie := obtener_offset_pokemon(poke_jugador.nombre_interno, true)
	var pos_inicial := poke_ball_jugador.position + BattleIntroController.OFFSET_APARICION_JUGADOR + offset_especie
	slot_jugador.configurar_aparicion(pos_inicial, BattleIntroController.COLOR_SILUETA_JUGADOR)
	slot_jugador.reproducir_aparicion()
	var tween_posicion := create_tween()
	tween_posicion.tween_property(slot_jugador.sprite_pokemon, "position", offset_especie, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _mostrar_mensaje(mensaje: String = "", instantaneo: bool = true, callback: Callable = Callable()):
	presentacion.mostrar_texto(mensaje, instantaneo, callback)

## Muestra texto en la caja de texto con la velocidad configurada
func mostrar_texto_batalla(texto: String, instantaneo: bool = false):
	await presentacion.mostrar_texto(texto, instantaneo)

func _mostrar_texto_y_esperar_confirmacion(texto: String, instantaneo: bool = false) -> void:
	await mostrar_texto_batalla(texto, instantaneo)
	await esperar_confirmacion_texto()

## Espera a que el jugador confirme el texto en la caja de batalla. Solo await sin callback.
func esperar_confirmacion_texto(mostrar_cursor: bool = true) -> void:
	await presentacion.esperar_confirmacion(mostrar_cursor)

func get_turn_count() -> int:
	return contador_turnos

func get_enemy_pokemon():
	return poke_enemigo

func get_player_pokemon():
	return poke_jugador

func get_enemy_team() -> Array:
	return equipo_enemigo_pokemones

## Limpia la caja de texto
func limpiar_texto_batalla():
	presentacion.limpiar_texto()

func aplicar_offset(pos_base: Vector2, es_jugador: bool = true) -> Vector2:
	var posicion_final = pos_base
	var pokemon_name = ""
	if es_jugador and poke_jugador:
		pokemon_name = poke_jugador.nombre_interno
	elif not es_jugador and poke_enemigo:
		pokemon_name = poke_enemigo.nombre_interno
	else:
		print("⚠️ [BATALLA] No se pudo determinar el Pokémon para aplicar offset.")

	# Aplicar offset si existe. Esta función se conserva para posiciones
	# globales auxiliares, como las partículas; el sprite usa
	# `aplicar_offset_a_slot()` para recibirlo localmente.
	var offset := obtener_offset_pokemon(pokemon_name, es_jugador)
	if pos_poke.has(pokemon_name):
		posicion_final += offset
		print("📍 [BATALLA] Aplicado offset %s a %s: %s" % [offset, pokemon_name, "jugador" if es_jugador else "enemigo"])
	else:
		print("⚠️ [BATALLA] No se encontraron posiciones para: %s" % pokemon_name)

	return posicion_final

## Función para aplicar offsets guardados en batalla normal
func aplicar_offset_pokemon(sprite: Sprite2D, pokemon_name: String, es_jugador: bool = true):
	# Verificar que las posiciones están cargadas
	if pos_poke.is_empty():
		print("⚠️ [BATALLA] Posiciones no cargadas, cargando desde archivo...")
		_cargar_json_positions()

	# Verificar que existe el Pokémon
	if not pos_poke.has(pokemon_name):
		print("⚠️ [BATALLA] No se encontraron posiciones para: %s" % pokemon_name)
		return

	# Se establece, no se acumula, para que repetir la configuración del
	# Pokémon no lo desplace varias veces.
	var offset := obtener_offset_pokemon(pokemon_name, es_jugador)
	sprite.position = offset
	print("📍 [BATALLA] Aplicado offset %s a %s: %s" % [offset, pokemon_name, "jugador" if es_jugador else "enemigo"])
