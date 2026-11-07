## evento_club_calagua.gd
## CLUB FAN de CIUDAD CALAGUA (pokeruby LilycoveCity_PokemonTrainerFanClub). Escena: `ciudad_calagua_club`
## (Godot = Rubí + (0,0)). Los ocho socios son `npc_evento` y hablan según el estado del club
## (EstadoClubFanCalagua):
## - Estado 0 (aún no eres CAMPEÓN): solo CHICA, AFICIONADO, NINA y HOMBRE (los otros cuatro están ocultos con
##   `bandera_mostrar = SYS_GAME_CLEAR`) y cada uno dice «ANTES».
## - Con la LIGA superada: el club se registra (al_pasar_la_liga), el estado 1 lanza la escena de los
##   primeros fans (OnFrame `MeetFirstFans`) y pasa a 2.
## - Estado 2: cada socio dice su frase según sea o no fan: FAN (y SOLO_FAN si es el único), NORMAL, o
##   SOLO_NO_FAN si es el único que no lo es. Los socios que no son fans se sientan en la mesa lejana
##   (`setobjectxyperm` de OnTransition) y vuelven a su sitio al serlo.
## {STR_VAR_1} (BufferStreakTrainerText) es el ENTRENADOR favorito de cada socio: sin registros de
## combates por cable, el nombre por defecto (PLUBIO, MÁXIMO, ALANA, FÁTIMA, NÍVEA), ya escrito en cada texto.
extends EventoInteriorMalvalona
class_name EventoClubCalagua

const MOTIVO_PAUSA: StringName = &"club_calagua"

## Nodo de la escena → [variable de los guiones de Rubí, sufijo de las claves, celda de la mesa lejana
## (setobjectxyperm), ¿tiene texto «ANTES» (estado 0)?].
const SOCIOS: Dictionary = {
	"Chica": [8, "CHICA", Vector2i(7, 5), true],
	"Aficionado": [9, "AFICIONADO", Vector2i(3, 4), true],
	"Nina": [10, "NINA", Vector2i(7, 2), true],
	"Ninja": [11, "NINJA", Vector2i(5, 5), false],
	"Chico": [12, "CHICO", Vector2i(5, 2), false],
	"Hombre": [13, "HOMBRE", Vector2i(8, 4), true],
	"Mujer": [14, "MUJER", Vector2i(3, 3), false],
	"Anciana": [15, "ANCIANA", Vector2i(8, 3), false],
}
## SetFanMemberPositionsForFirstFanMeeting: socios 2, 4, 5, 7 y 8 (Hombre, Nina, Ninja, Mujer y Anciana).
const SOCIOS_LEJOS_EN_LA_ESCENA: Array[String] = ["Hombre", "Nina", "Ninja", "Mujer", "Anciana"]

const TEXTO_ASOMBRO: String = "CALAGUA_CLUB_ESCENA_ASOMBRO"
const TEXTO_FAN: String = "CALAGUA_CLUB_ESCENA_FAN"

const FOTOGRAMAS_DELAY_8: int = 8

## LilycoveCity_PokemonTrainerFanClub_Movement_*.
static var NINA_MIRA: Array = [L, L, D, D, L, D]
static var HOMBRE_SE_ACERCA: Array = [D, D, D, L, L]
static var NINA_SE_ACERCA: Array = [D]
static var NINA_SE_ESCONDE: Array = [U, U, R]

## Contenedor de los socios (por defecto `NPCs`, hermano del nodo `Eventos`).
@export var contenedor_npc: NodePath = ^"../../NPCs"

## Celda inicial de cada socio (map.json): adonde vuelven los que son fans.
var _casa: Dictionary = {}


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for nombre: String in SOCIOS:
		var socio := socio_nodo(nombre)
		if socio == null:
			continue
		_casa[nombre] = Vector2i(socio.coord)  # celda de map.json (colocar() la cambiará)
		if socio.has_signal("hablado"):
			socio.hablado.connect(_on_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func socio_nodo(nombre: String) -> Node2D:
	var contenedor := get_node_or_null(contenedor_npc)
	return contenedor.get_node_or_null(nombre) as Node2D if contenedor != null else null


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar()
	if EstadoClubFanCalagua.estado() == 1:
		reunion_con_los_primeros_fans()  # OnFrame: map_script_2 VAR_LILYCOVE_FAN_CLUB_STATE, 1


## OnTransition: registra la LIGA (UpdateTrainerFanClubGameClear, que en Rubí hace el SALÓN de la FAMA) y coloca a
## los socios según el estado.
func preparar() -> void:
	if _en_curso:
		return
	if SistemaGuardado.get_flag(EstadoClubFanCalagua.BANDERA_LIGA):
		EstadoClubFanCalagua.al_pasar_la_liga()
	var estado := EstadoClubFanCalagua.estado()
	if estado == 2:
		EstadoClubFanCalagua.actualizar_con_el_tiempo()
	for nombre: String in SOCIOS:
		var socio := socio_nodo(nombre)
		if socio == null or not _casa.has(nombre):
			continue
		var lejos: bool = false
		if estado == 1:
			lejos = nombre in SOCIOS_LEJOS_EN_LA_ESCENA
		elif estado == 2:
			lejos = not EstadoClubFanCalagua.es_fan(int(SOCIOS[nombre][0]))
		colocar(socio, SOCIOS[nombre][2] if lejos else _casa[nombre])


## Clave del texto de un socio ahora mismo (las ramas de cada EventScript_* del club).
func clave_texto(nombre: String) -> String:
	var datos: Array = SOCIOS[nombre]
	var base := "CALAGUA_CLUB_" + str(datos[1]) + "_"
	if EstadoClubFanCalagua.estado() == 0 and bool(datos[3]):
		return base + "ANTES"
	if EstadoClubFanCalagua.es_fan(int(datos[0])):
		return base + ("SOLO_FAN" if EstadoClubFanCalagua.cantidad_fans() == 1 else "FAN")
	if EstadoClubFanCalagua.cantidad_fans() == SOCIOS.size() - 1:
		return base + "SOLO_NO_FAN"
	return base + "NORMAL"


func _on_hablado(npc: Node2D) -> void:
	if not SOCIOS.has(npc.name):
		return
	if not empezar_con(npc):  # lock + faceplayer
		return
	await mensaje(clave_texto(npc.name))
	terminar(false, [npc])


## MeetFirstFans: la CHICA te ve entrar, el HOMBRE se acerca, la NINA corre a mirarte y se esconde.
func reunion_con_los_primeros_fans() -> void:
	var chica := socio_nodo("Chica")
	var nina := socio_nodo("Nina")
	var hombre := socio_nodo("Hombre")
	if chica == null or nina == null or hombre == null or not comenzar(_administrador()):
		return
	await esperar_fin_warp(admin)
	mirar(chica, D)  # walk_in_place_fastest_down
	await mensaje(TEXTO_ASOMBRO)
	admin.cuadro_dialogo.cerrar()
	await en_paralelo([_recorrer.bind(nina, NINA_MIRA, VelocidadPaso.RAPIDO), _acercarse.bind(hombre)])
	girar_jugador(R)
	await mensaje(TEXTO_FAN)
	admin.cuadro_dialogo.cerrar()
	await recorrer(nina, NINA_SE_ACERCA)
	mirar(nina, R)
	girar_jugador(L)
	await saltar_en_sitio(nina, R)  # jump_in_place_right
	await recorrer(nina, NINA_SE_ESCONDE, VelocidadPaso.RAPIDO)
	mirar(nina, D)
	EstadoClubFanCalagua.fijar_estado(2)
	terminar(false, [chica, nina, hombre])


func _recorrer(npc: Node2D, pasos: Array, velocidad: NpcBase.VelocidadPaso = VelocidadPaso.NORMAL) -> void:
	await recorrer(npc, pasos, velocidad)


## FanApproachPlayer: delay_8, walk_in_place_fastest_down y baja tres pasos y va dos a la izquierda.
func _acercarse(npc: Node2D) -> void:
	await esperar_fotogramas(FOTOGRAMAS_DELAY_8)
	mirar(npc, D)
	await recorrer(npc, HOMBRE_SE_ACERCA)
