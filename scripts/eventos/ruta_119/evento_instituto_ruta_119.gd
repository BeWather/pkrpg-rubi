## evento_instituto_ruta_119.gd
## Guiones del INSTITUTO METEOROLÓGICO de la RUTA 119 (pokeruby data/maps/
## Route119_WeatherInstitute_1F y _2F). Las dos plantas comparten escena: la 1F ocupa y = 0..12 y
## la 2F va 18 filas más abajo (la escalera (17,1) de la 2F es la (17,19) de la escena).
##
## ESTADO (VAR_WEATHER_INSTITUTE_STATE), derivado de banderas:
##   0  el EQUIPO MAGMA ocupa el edificio: 5 soldados, música de equipo malo (MUS_EVIL_TEAM,
##      GetLocationMusic) y los científicos acorralados al fondo de la 2F, con el que da el
##      CASTFORM junto a ellos en (1,6). El niño de la 1F, recién despierto, está quieto en (0,5).
##   1  vencida CAROLA: los soldados se han ido y el científico espera en (4,6).
##   2  al salir a la RUTA 119 (Route119_EventScript_1511B9, OnTransition de la ruta) los
##      trabajadores de la 2F desaparecen y aparecen los de la 1F.
## El paso 1 → 2 lo hace EventoTransicionRuta119 (Eventos de la RUTA 119) cuando la ruta se activa, que es
## lo que ocurre al salir del edificio por la puerta: `pasar_trabajadores_a_la_1f()`.
##
## CAROLA (objeto 3 de la 2F, TRAINER_WEATHER_INSTITUTE_GRUNT_5 = TRAINER_COURTNEY_1 en Rubí): combate de
## evento. Al vencerla se retira todo el EQUIPO MAGMA, el científico avanza y da el CASTFORM
## (Nv. 25, AGUA MÍSTICA); sin sitio en el equipo se repite hablándole (goto_if_set
## FLAG_RECEIVED_CASTFORM). Los otros cuatro soldados son entrenadores normales.
## CAMAS (1F, bg_events (0..1, 2..3)): descansar cura al equipo (Common_EventScript_OutOfCenterPartyHeal).
extends EventoGuionizado
class_name EventoInstitutoRuta119

const MOTIVO_PAUSA: StringName = &"instituto_ruta_119"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

## TRAINER_COURTNEY_1 (el TRAINER_SHELLY_1 de Zafiro).
const ENTRENADOR_CAROLA: int = 599
const MUSICA_EQUIPO: String = "EQUIPO_MAGMA_APARECE"  # MUS_EVIL_TEAM
## MUS_RUSTBORO: el tema de las escenas del INSTITUTO y de la CASA.
const MUSICA_NORMAL: String = "CIUDAD_FERRICA"
const MUSICA_COMBATE: String = "EQUIPO_AQUA_MAGMA_BATALLA"
const TEMA_CURACION: String = "POKEMON_RECUPERADOS"
const ESPECIE_CASTFORM: String = "CASTFORM"
const NIVEL_CASTFORM: int = 25
const OBJETO_CASTFORM: String = "AGUAMISTICA"
## Origen REGALO de SistemaGuardado.agregar_pokemon_al_equipo.
const ORIGEN_REGALO: int = 3
const MAX_EQUIPO: int = 6
## Filas que separan la 2F de su posición en Rubí.
const DESPLAZAMIENTO_2F: int = 18
## Dónde espera el científico de la 2F según el estado (setobjectxyperm 5).
const CELDA_CIENTIFICO_ESTADO_0 := Vector2i(1, 6 + DESPLAZAMIENTO_2F)
const CELDA_CIENTIFICO_ESTADO_1 := Vector2i(4, 6 + DESPLAZAMIENTO_2F)
## Dónde está el niño de la 1F: junto a la cama en el estado 0 (setobjectxyperm 5, 0, 5 +
## setobjectmovementtype 5, FACE_RIGHT); si no, su objeto de Rubí (14,11) WANDER_AROUND (1,1).
const CELDA_NINO_ESTADO_0 := Vector2i(0, 5)
const CELDA_NINO := Vector2i(14, 11)
const RANGO_NINO := Vector2i(1, 1)

## FLAG_HIDE_EVIL_TEAM_WEATHER_INSTITUTE (activa: el EQUIPO MAGMA se ha ido).
const BANDERA_EQUIPO_FUERA: String = "ruta_119_instituto_equipo_fuera"
## Inversa de FLAG_HIDE_WEATHER_INSTITUTE_WORKERS_1F.
const BANDERA_TRABAJADORES_1F: String = "ruta_119_instituto_trabajadores_1f"
## FLAG_HIDE_WEATHER_INSTITUTE_WORKERS_2F.
const BANDERA_TRABAJADORES_2F_OCULTOS: String = "ruta_119_instituto_trabajadores_2f_ocultos"
const BANDERA_CASTFORM: String = "ruta_119_castform_recibido"

const T := "RUTA119_INSTITUTO_"
const TEXTO_CAROLA_INI: String = T + "CAROLA_INI"
const TEXTO_CAROLA_FIN: String = T + "CAROLA_FIN"
const TEXTO_CIENTIFICO_GRACIAS: String = T + "CIENTIFICO_GRACIAS"
const TEXTO_CIENTIFICO_SIN_SITIO: String = T + "CIENTIFICO_SIN_SITIO"
const TEXTO_CIENTIFICO_LLUVIA: String = T + "CIENTIFICO_LLUVIA"
const TEXTO_CASTFORM_RECIBIDO: String = T + "CASTFORM_RECIBIDO"
const TEXTO_CASTFORM_INFO: String = T + "CASTFORM_INFO"
const TEXTO_CAMA: String = T + "CAMA"

const R := Vector2.RIGHT

@export var carola: NodePath
@export var cientifico: NodePath
@export var nino: NodePath
## Los cinco soldados (visibles solo mientras el EQUIPO MAGMA ocupa el edificio).
@export var soldados: Array[NodePath] = []
## Los cuatro bg_event de cama (CartelEvento).
@export var camas: Array[NodePath] = []
@export var trabajadores_1f: Array[NodePath] = []
@export var trabajadores_2f: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
var _musica_normal: String = ""


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc_carola := get_node_or_null(carola)
	if npc_carola != null and npc_carola.has_signal("hablado"):
		npc_carola.hablado.connect(_on_carola)
	var npc_cientifico := get_node_or_null(cientifico)
	if npc_cientifico != null and npc_cientifico.has_signal("hablado"):
		npc_cientifico.hablado.connect(_on_cientifico)
	for ruta in camas:
		var cama := get_node_or_null(ruta)
		if cama is CartelEvento:
			cama.accionado.connect(_on_cama)
	preparar()


## Route119_EventScript_1511B9 (OnTransition de la ruta con VAR_WEATHER_INSTITUTE_STATE == 1): los
## trabajadores de la 2F desaparecen, aparecen los de la 1F y el estado pasa a 2. Devuelve si cambió algo.
static func pasar_trabajadores_a_la_1f() -> bool:
	if estado() != 1:
		return false
	SistemaGuardado.set_flag(BANDERA_TRABAJADORES_2F_OCULTOS, true)
	SistemaGuardado.set_flag(BANDERA_TRABAJADORES_1F, true)
	return true


## VAR_WEATHER_INSTITUTE_STATE 0, 1 o 2.
static func estado() -> int:
	if not SistemaGuardado.get_flag(BANDERA_EQUIPO_FUERA):
		return 0
	return 2 if SistemaGuardado.get_flag(BANDERA_TRABAJADORES_1F) else 1


## OnTransition de las dos plantas: el científico y el niño en su sitio y la música de equipo malo.
func preparar() -> void:
	var npc_cientifico := get_node_or_null(cientifico) as Node2D
	var actual := estado()
	if npc_cientifico != null and actual < 2:
		npc_cientifico.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
		npc_cientifico.rango = Vector2i.ZERO
		colocar(npc_cientifico, CELDA_CIENTIFICO_ESTADO_0 if actual == 0 else CELDA_CIENTIFICO_ESTADO_1)
	_colocar_nino()
	var mapa := obtener_mapa()
	if mapa != null:
		if _musica_normal.is_empty():
			# Si otro guion ya cambió el tema (recarga del evento), el normal es el de la escena.
			_musica_normal = MUSICA_NORMAL if mapa.musica_mapa == MUSICA_EQUIPO else mapa.musica_mapa
		if actual == 0:
			mapa.musica_mapa = MUSICA_EQUIPO  # IsInfiltratedWeatherInstitute


## Route119_WeatherInstitute_1F_EventScript_163C41. Las dos plantas comparten escena: sin OnTransition al
## bajar a la 1F, el guion de CAROLA lo devuelve a su sitio al irse el EQUIPO MAGMA.
func _colocar_nino() -> void:
	var npc_nino := get_node_or_null(nino) as Node2D
	if npc_nino == null:
		return
	var ocupado := estado() == 0
	npc_nino.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA if ocupado else TipoMovimiento.PASEAR_RANGO
	npc_nino.rango = Vector2i.ZERO if ocupado else RANGO_NINO
	colocar(npc_nino, CELDA_NINO_ESTADO_0 if ocupado else CELDA_NINO)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## lock + faceplayer: false si ya hay un guion en curso o no hay administrador.
func _empezar_con(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	return true


## ============================================================================
## CAROLA
## ============================================================================

## Route119_WeatherInstitute_2F_EventScript_163D2A (trainerbattle_single con continuación).
func _on_carola(npc: Node2D) -> void:
	if not _empezar_con(npc):
		return
	await mensaje(TEXTO_CAROLA_INI)
	var resultado := await combatir(ENTRENADOR_CAROLA, MUSICA_COMBATE)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	# Route119_WeatherInstitute_2F_EventScript_163D45.
	await mensaje(TEXTO_CAROLA_FIN)
	admin.cuadro_dialogo.cerrar()  # closemessage
	_restaurar_musica_del_mapa()  # fadedefaultbgm
	await oscurecer_pantalla()
	SistemaGuardado.set_flag(BANDERA_EQUIPO_FUERA, true)  # VAR_WEATHER_INSTITUTE_STATE 1 + setflag HIDE_EVIL_TEAM
	actualizar_visibilidad()  # removeobject 1, 2, 3 (y los de la 1F)
	_colocar_nino()
	await aclarar_pantalla()
	var npc_cientifico := get_node_or_null(cientifico) as Node2D
	if npc_cientifico == null:
		terminar(false, [npc])
		return
	await recorrer(npc_cientifico, [R, R, R])  # Route119_WeatherInstitute_2F_Movement_163DC8
	npc_cientifico.mirar_jugador()
	await _dar_castform(npc_cientifico)


## Los soldados y los trabajadores según las banderas (removeobject / clearflag).
func actualizar_visibilidad() -> void:
	for ruta in soldados + trabajadores_1f + trabajadores_2f:
		var npc := get_node_or_null(ruta)
		if npc != null and npc.has_method("aplicar_bandera_ocultar"):
			npc.aplicar_bandera_ocultar()


func _restaurar_musica_del_mapa() -> void:
	var mapa := obtener_mapa()
	if mapa != null and not _musica_normal.is_empty():
		mapa.musica_mapa = _musica_normal
	restaurar_musica_mapa()


## ============================================================================
## CIENTÍFICO (CASTFORM)
## ============================================================================

## Route119_WeatherInstitute_2F_EventScript_163DCC.
func _on_cientifico(npc: Node2D) -> void:
	if not _empezar_con(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_CASTFORM):
		await mensaje(TEXTO_CIENTIFICO_LLUVIA)  # 163DBE
		terminar(false, [npc])
		return
	await _dar_castform(npc)


## Route119_WeatherInstitute_2F_EventScript_163D7A: sin sitio no se marca y se repite.
func _dar_castform(npc: Node2D) -> void:
	await mensaje(TEXTO_CIENTIFICO_GRACIAS)
	if SistemaGuardado.get_equipo().size() >= MAX_EQUIPO:
		await mensaje(TEXTO_CIENTIFICO_SIN_SITIO)  # 163DB4
		terminar(false, [npc])
		return
	await mensaje_con_fanfarria(TEXTO_CASTFORM_RECIBIDO, FANFARRIA_OBJETO)
	var seccion := ""
	if admin.has_method("obtener_seccion_lugar_actual"):
		seccion = str(admin.obtener_seccion_lugar_actual())
	if SistemaGuardado.agregar_pokemon_al_equipo(ESPECIE_CASTFORM, NIVEL_CASTFORM, "", ORIGEN_REGALO, seccion):
		(SistemaGuardado.get_equipo().back() as BasePokemon).objeto = OBJETO_CASTFORM
	SistemaGuardado.set_flag(BANDERA_CASTFORM, true)
	await mensaje(TEXTO_CASTFORM_INFO)
	terminar(false, [npc])


## ============================================================================
## CAMAS
## ============================================================================

## Route119_WeatherInstitute_1F_EventScript_163C83 (lockall).
func _on_cama(_cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	await mensaje(TEXTO_CAMA)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await oscurecer_pantalla()  # Common_EventScript_OutOfCenterPartyHeal
	await fanfarria(TEMA_CURACION, true)
	SistemaGuardado.curar_equipo_completo()
	await aclarar_pantalla()
	terminar()
