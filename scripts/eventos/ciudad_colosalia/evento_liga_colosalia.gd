## evento_liga_colosalia.gd
## Vestíbulo de la LIGA POKéMON de CIUDAD COLOSALIA (pokeruby EverGrandeCity_PokemonLeague/scripts.inc).
## La enfermera (enfermera_cp.gd, que fija el punto de curación al entrar: setrespawn
## HEAL_LOCATION_EVER_GRANDE_CITY_POKEMON_LEAGUE) y el dependiente (vendedor_pokeshop.gd) son NPC del mapa;
## este guion lleva a los dos guardias de la puerta del ALTO MANDO (objetos 3 y 4, MAN_4).
##
## - OnTransition sin FLAG_ENTERED_ELITE_FOUR (`colosalia_entrada_alto_mando`): setobjectxyperm 3, 9, 2 y
##   4, 10, 2: los guardias tapan la puerta.
## - EverGrandeCity_PokemonLeague_1F_EventScript_DoorGuard (lockall, sin faceplayer): si el jugador está a
##   un lado (x ≥ 11 o x ≤ 8) baja y se pone delante mirando al norte; «Solo pueden pasar los que tienen
##   todas las MEDALLAS» (sin esperar botón) y delay 75. Sin las MEDALLAS, SE_FAILURE y el aviso. Con ellas
##   los guardias se apartan (izquierda/derecha mirando al sur), delay 10, fanfarria MUS_OBTAIN_BADGE con
##   «Adelante» y FLAG_ENTERED_ELITE_FOUR (moveobjectoffscreen: vuelven a su sitio).
## - Con la bandera puesta, el guardia mira al jugador, dice «Adelante» y vuelve a mirar al sur.
##
## pokeruby comprueba solo FLAG_BADGE06_GET (las otras dos se consiguen antes de llegar por la CALLE
## VICTORIA); aquí se piden las ocho, como dice el propio texto.
extends EventoInteriorMalvalona
class_name EventoLigaColosalia

const MOTIVO_PAUSA: StringName = &"liga_colosalia"

## FLAG_ENTERED_ELITE_FOUR.
const BANDERA_ENTRADA: String = "colosalia_entrada_alto_mando"
## FLAG_SYS_POKEMON_LEAGUE_FLY (`vuelo_zonas_bandera` de COLOSALIA en region_map_metadata.json).
const BANDERA_VUELO_LIGA: String = "SYS_POKEMON_LEAGUE_FLY"
const MEDALLAS_NECESARIAS: int = 8
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
const SONIDO_FALLO: String = "SE_FAILURE"
const FOTOGRAMAS_AVISO: int = 75
const FOTOGRAMAS_TRAS_APARTARSE: int = 10
## Columnas a partir de las que el jugador está a un lado de la puerta.
const COLUMNA_DERECHA: int = 11
const COLUMNA_IZQUIERDA: int = 8

## Celdas de los guardias: las suyas y las de delante de la puerta.
const CELDA_IZQUIERDA: Vector2i = Vector2i(8, 2)
const CELDA_DERECHA: Vector2i = Vector2i(11, 2)
const CELDA_PUERTA_IZQUIERDA: Vector2i = Vector2i(9, 2)
const CELDA_PUERTA_DERECHA: Vector2i = Vector2i(10, 2)

const TEXTO_MEDALLAS: String = "COLOSALIA_LIGA_GUARDIA_MEDALLAS"
const TEXTO_SIN_MEDALLAS: String = "COLOSALIA_LIGA_GUARDIA_SIN_MEDALLAS"
const TEXTO_ADELANTE: String = "COLOSALIA_LIGA_GUARDIA_ADELANTE"

@export var guardia_izquierdo: NodePath
@export var guardia_derecho: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(guardia_izquierdo, _on_guardia)
	escuchar(guardia_derecho, _on_guardia)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: al_entrar())
	colocar_guardias()


## EverGrandeCity_PokemonLeague_1F_OnTransition (cuando el mapa pasa a ser el actual, también al cargar
## partida): setflag FLAG_SYS_POKEMON_LEAGUE_FLY (desde ahora la casilla de arriba de COLOSALIA en el mapa de
## VUELO lleva a la LIGA) y los guardias.
func al_entrar() -> void:
	SistemaGuardado.set_flag(BANDERA_VUELO_LIGA, true)
	colocar_guardias()


func entrada_permitida() -> bool:
	return SistemaGuardado.get_flag(BANDERA_ENTRADA)


## EverGrandeCity_PokemonLeague_1F_EventScript_GuardsBlockDoor.
func colocar_guardias() -> void:
	if _en_curso:
		return
	var izquierdo := nodo(guardia_izquierdo)
	var derecho := nodo(guardia_derecho)
	var abierta := entrada_permitida()
	if izquierdo != null:
		colocar(izquierdo, CELDA_IZQUIERDA if abierta else CELDA_PUERTA_IZQUIERDA)
	if derecho != null:
		colocar(derecho, CELDA_DERECHA if abierta else CELDA_PUERTA_DERECHA)


## EverGrandeCity_PokemonLeague_1F_EventScript_DoorGuard.
func _on_guardia(npc: Node2D) -> void:
	if not empezar_con(npc, false):
		return
	if entrada_permitida():
		npc.mirar_jugador()  # Common_Movement_FacePlayer
		await mensaje(TEXTO_ADELANTE)
		mirar(npc, D)  # Common_Movement_FaceOriginalDirection
		terminar(false, [npc])
		return
	var columna: int = admin.jugador.pos_celda_act.x
	if columna >= COLUMNA_DERECHA:
		await recorrer_jugador([D, L])
		girar_jugador(U)
	elif columna <= COLUMNA_IZQUIERDA:
		await recorrer_jugador([D, R])
		girar_jugador(U)
	await mensaje_sin_boton(TEXTO_MEDALLAS)
	await esperar_fotogramas(FOTOGRAMAS_AVISO)
	if SistemaGuardado.contar_medallas() < MEDALLAS_NECESARIAS:
		Singleton.play_sound.emit(SONIDO_FALLO)
		await mensaje(TEXTO_SIN_MEDALLAS)
		terminar(false, [npc])
		return
	admin.cuadro_dialogo.cerrar()  # closemessage
	var izquierdo := nodo(guardia_izquierdo)
	var derecho := nodo(guardia_derecho)
	await en_paralelo([
		caminar.bind(izquierdo, L, VelocidadPaso.NORMAL, D),
		caminar.bind(derecho, R, VelocidadPaso.NORMAL, D),
	])
	await esperar_fotogramas(FOTOGRAMAS_TRAS_APARTARSE)
	await mensaje_con_fanfarria(TEXTO_ADELANTE, FANFARRIA_MEDALLA)
	SistemaGuardado.set_flag(BANDERA_ENTRADA, true)
	terminar(false, [izquierdo, derecho])
	colocar_guardias()


## message + waitmessage: el texto se escribe y el guion sigue sin esperar al botón (deja el cuadro abierto).
func mensaje_sin_boton(clave: String) -> void:
	var pendiente := [true]
	var cuadro = admin.cuadro_dialogo
	cuadro.mostrar(_texto(clave, {}), false, false, func() -> void: pendiente[0] = false, false, cuadro.esta_activo)
	while pendiente[0]:
		await get_tree().process_frame
