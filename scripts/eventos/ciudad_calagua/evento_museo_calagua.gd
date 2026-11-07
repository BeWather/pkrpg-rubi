## evento_museo_calagua.gd
## MUSEO de CIUDAD CALAGUA (pokeruby LilycoveCity_LilycoveMuseum_1F y _2F). Las dos plantas están en una
## sola escena, la 2F apilada encima de la 1F: **Godot (x, y) = Rubí (x, y) en la 1F y (x, y - 18) en la 2F**
## (filas -18..-6; la escalera (16,1) de la 1F lleva a la (13,-17) de la 2F).
##
## 1F - DIRECTOR (objeto 2, GENTLEMAN en (16,2), FACE_DOWN; `lockall` + FacePlayer): «¿Ya has visto nuestra
##      colección de pintura?» con el menú «Pues claro» / «Todavía no» (multichoice 16). «Todavía no» → «no te
##      molesto más». «Pues claro» → «¿también te gusta el arte?» SÍ/NO; NO → «te agradezco que hayas venido»;
##      SÍ → «¿te importaría acompañarme?», sube por la escalera (removeobject: activa
##      FLAG_HIDE_LILYCOVE_MUSEUM_CURATOR) y el jugador le sigue (según hacia dónde mirase: ↑↑, ←↑ o →↑) hasta
##      la 2F (11,8) → Godot (11,-10).
## 2F - OnFrame (VAR_LILYCOVE_MUSEUM_2F_STATE == 0): el DIRECTOR te enseña la SALA DE EXPOSICIONES (tres textos
##      con giros) y el estado pasa a 1. Se dispara al llegar a la 2F (por el DIRECTOR o por la escalera).
## 2F - DIRECTOR (objeto 1): con FLAG_RECEIVED_GLASS_ORNAMENT, «qué alegría verte»; si no, según los cuadros que
##      hay en el museo (CountPlayerMuseumPaintings, aquí las cinco banderas `calagua_museo_cuadro_*`): ninguno →
##      «deseo llenar esta sala»; de 1 a 4 → «gracias a ti esta pintura formará parte de la colección»; los 5 →
##      te da el ADORNO CRISTAL (DECOR_GLASS_ORNAMENT; sin sitio, «no queda sitio» y te lo guarda).
## Los cuadros del museo (bg_events de colores) los pinta el sistema de CONCURSOS, que no existe: sin él las
## banderas `calagua_museo_cuadro_*` nunca se activan, los visitantes extra tampoco aparecen
## (`calagua_museo_visitante_1..4`, `calagua_museo_turistas`) y el DIRECTOR de la 1F sigue en su sitio hasta
## que lo sigues a la 2F. El DIRECTOR de la 2F existe desde el principio.
extends EventoInteriorMalvalona
class_name EventoMuseoCalagua

const MOTIVO_PAUSA: StringName = &"museo_calagua"

## VAR_LILYCOVE_MUSEUM_2F_STATE.
const CONTADOR_ESTADO_2F: String = "calagua_museo_2f_estado"
## FLAG_HIDE_LILYCOVE_MUSEUM_CURATOR (empieza sin activar: el DIRECTOR está en la 1F).
const BANDERA_DIRECTOR_OCULTO: String = "calagua_museo_director_oculto"
## FLAG_RECEIVED_GLASS_ORNAMENT.
const BANDERA_ADORNO: String = "calagua_museo_adorno_recibido"
## FLAG_{COOL,BEAUTY,CUTE,SMART,TOUGH}_PAINTING_MADE (carisma, belleza, dulzura, ingenio, dureza).
const BANDERAS_CUADROS: Array[String] = [
	"calagua_museo_cuadro_carisma", "calagua_museo_cuadro_belleza", "calagua_museo_cuadro_dulzura",
	"calagua_museo_cuadro_ingenio", "calagua_museo_cuadro_dureza",
]
## DECOR_GLASS_ORNAMENT (catálogo de las BASES SECRETAS: ADORNO CRISTAL).
const DECORACION_ADORNO_CRISTAL: int = 44

const ESCENA_MUSEO: String = "ciudad_calagua_museo"
## warp MAP_LILYCOVE_CITY_LILYCOVE_MUSEUM_2F, 255, 11, 8 (con la 2F en y - 18).
const LLEGADA_2F := Vector2(11, 8 - 18)
## Filas de la 2F (13 filas: -18..-6).
const PRIMERA_FILA_2F: int = -18
const ULTIMA_FILA_2F: int = -6
const FOTOGRAMAS_DELAY_16: int = 16

const TEXTO_PRESENTACION: String = "CALAGUA_MUSEO_DIRECTOR_PRESENTACION"
const TEXTO_AUN_NO: String = "CALAGUA_MUSEO_DIRECTOR_AUN_NO"
const TEXTO_PREGUNTA: String = "CALAGUA_MUSEO_DIRECTOR_PREGUNTA"
const TEXTO_NO: String = "CALAGUA_MUSEO_DIRECTOR_NO"
const TEXTO_ACOMPANAR: String = "CALAGUA_MUSEO_DIRECTOR_ACOMPANAR"
const OPCION_CLARO: String = "CALAGUA_MUSEO_OPCION_CLARO"
const OPCION_AUN_NO: String = "CALAGUA_MUSEO_OPCION_AUN_NO"
const TEXTO_SALA: Array[String] = ["CALAGUA_MUSEO_2F_SALA_1", "CALAGUA_MUSEO_2F_SALA_2", "CALAGUA_MUSEO_2F_SALA_3"]
const TEXTO_PIDE: String = "CALAGUA_MUSEO_2F_DIRECTOR_PIDE"
const TEXTO_GRACIAS_CUADRO: String = "CALAGUA_MUSEO_2F_DIRECTOR_GRACIAS_CUADRO"
const TEXTO_ERES_TU: String = "CALAGUA_MUSEO_2F_DIRECTOR_ERES_TU"
const TEXTO_COLECCION: String = "CALAGUA_MUSEO_2F_DIRECTOR_COLECCION"
const TEXTO_REGALO: String = "CALAGUA_MUSEO_2F_DIRECTOR_REGALO"
const TEXTO_GUARDO: String = "CALAGUA_MUSEO_2F_DIRECTOR_GUARDO"
const TEXTO_VISITA: String = "CALAGUA_MUSEO_2F_DIRECTOR_VISITA"
## Los mismos textos de la CASA TRETA: «no queda sitio para X», «obtuvo X», «enviada al PC».
const TEXTO_DECOR_SIN_SITIO: String = "CASA_TRETA_DECOR_SIN_SITIO"
const TEXTO_DECOR_OBTENIDA: String = "CASA_TRETA_DECOR_OBTENIDA"
const TEXTO_DECOR_ENVIADA_PC: String = "CASA_TRETA_DECOR_ENVIADA_PC"

## LilycoveCity_LilycoveMuseum_1F_Movement_FollowCurator{North,West,East}.
static var SEGUIR_NORTE: Array = [U, U]
static var SEGUIR_OESTE: Array = [L, U]
static var SEGUIR_ESTE: Array = [R, U]

@export var director_1f: NodePath
@export var director_2f: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(director_1f, _on_director_1f)
	escuchar(director_2f, _on_director_2f)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


## Cuadros del museo: banderas activas (CountPlayerMuseumPaintings).
static func cuadros() -> int:
	var total: int = 0
	for bandera in BANDERAS_CUADROS:
		if SistemaGuardado.get_flag(bandera):
			total += 1
	return total


## Celda a la que llega el jugador al activarse el mapa; con un warp en curso (mapa_activado llega con el
## telón negro y antes de teletransportarle) cuenta la celda de destino del warp.
func _celda_llegada() -> Vector2i:
	var adm := _administrador()
	var jugador: Node = adm.get("jugador") if adm != null else null
	if jugador == null:
		return Vector2i(-1000, -1000)
	var celda: Vector2i = jugador.pos_celda_act
	if int(adm.get("coneccion")) != 0 and adm.get("coneccion_posicion") is Vector2:
		var destino: Vector2 = adm.get("coneccion_posicion")
		celda = Vector2i(int(floorf(destino.x)), int(floorf(destino.y)))
	return celda


func _on_mapa_activado(_por_warp: bool) -> void:
	var fila := _celda_llegada().y
	if fila >= PRIMERA_FILA_2F and fila <= ULTIMA_FILA_2F and SistemaGuardado.get_contador(CONTADOR_ESTADO_2F) == 0:
		exposicion_en_la_2f()  # map_script_2 VAR_LILYCOVE_MUSEUM_2F_STATE, 0


## OnFrame de la 2F: ShowExhibitHall.
func exposicion_en_la_2f() -> void:
	var director := nodo(director_2f)
	if director == null or not comenzar(_administrador()):
		return
	await esperar_fin_warp(admin)
	director.mirar_jugador()  # Common_Movement_FacePlayer
	girar_jugador(L)  # walk_in_place_fastest_left
	await mensaje(TEXTO_SALA[0])
	mirar(director, U)  # FaceExhibitHall: face_up + delay_16
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	girar_jugador(U)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	await mensaje(TEXTO_SALA[1])
	director.mirar_jugador()
	girar_jugador(L)
	await mensaje(TEXTO_SALA[2])
	SistemaGuardado.set_contador(CONTADOR_ESTADO_2F, 1)
	terminar(false, [director])


## Greeter / Curator de la 1F.
func _on_director_1f(npc: Node2D) -> void:
	if not empezar_con(npc):  # lockall + FacePlayer
		return
	var mirada: Vector2 = admin.jugador.facing_direction  # VAR_FACING (antes de que el DIRECTOR gire hacia él)
	var opciones := PackedStringArray([tr(OPCION_CLARO), tr(OPCION_AUN_NO)])
	if await elegir_opcion(TEXTO_PRESENTACION, opciones) != 0:
		await mensaje(TEXTO_AUN_NO)  # NotYet
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_PREGUNTA):
		await mensaje(TEXTO_NO)  # NotInterested
		terminar(false, [npc])
		return
	await mensaje(TEXTO_ACOMPANAR)
	admin.cuadro_dialogo.cerrar()
	await caminar(npc, U)  # CuratorEnterStairs
	npc.visible = false  # removeobject 2
	SistemaGuardado.set_flag(BANDERA_DIRECTOR_OCULTO, true)
	var pasos: Array = SEGUIR_NORTE
	if mirada == L:
		pasos = SEGUIR_OESTE
	elif mirada == R:
		pasos = SEGUIR_ESTE
	await recorrer_jugador(pasos)
	var adm := _administrador()
	if adm != null and adm.has_method("conectar_escalera"):
		adm.conectar_escalera(ESCENA_MUSEO, LLEGADA_2F, L)  # warp a la 2F (11,8)
	terminar(false, [npc])


## Curator de la 2F.
func _on_director_2f(npc: Node2D) -> void:
	if not empezar_con(npc, false):  # lockall
		return
	if SistemaGuardado.get_flag(BANDERA_ADORNO):
		npc.mirar_jugador()
		await mensaje(TEXTO_VISITA)  # HonorToHaveYouVisit (MSGBOX_NPC)
		terminar(false, [npc])
		return
	var total := cuadros()
	if total >= BANDERAS_CUADROS.size():
		await _gracias_y_adorno(npc)  # ThankPlayer
	elif total >= 1:
		npc.mirar_jugador()
		await mensaje(TEXTO_GRACIAS_CUADRO)  # AddedPainting (MSGBOX_NPC)
	else:
		npc.mirar_jugador()
		await mensaje(TEXTO_PIDE)  # WishToFillExhibit (MSGBOX_NPC)
	terminar(false, [npc])


## ThankPlayer + GiveGlassOrnament.
func _gracias_y_adorno(npc: Node2D) -> void:
	npc.mirar_jugador()
	await mensaje(TEXTO_ERES_TU)
	mirar(npc, U)  # FaceExhibitHall (sin waitmovement)
	await mensaje(TEXTO_COLECCION)
	npc.mirar_jugador()
	await mensaje(TEXTO_REGALO)
	var nombre := tr("BASES_DECOR_%03d_NOMBRE" % DECORACION_ADORNO_CRISTAL)
	var inventario := SistemaGuardado.get_bases_secretas()
	if inventario.agregar_decoracion(DECORACION_ADORNO_CRISTAL) < 0:
		await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": nombre})  # NoRoomForGlassOrnament
		await mensaje(TEXTO_GUARDO)
		admin.cuadro_dialogo.cerrar()
		return
	await mensaje_con_fanfarria(TEXTO_DECOR_OBTENIDA, FANFARRIA_OBJETO, {"{decoracion}": nombre})
	await mensaje(TEXTO_DECOR_ENVIADA_PC, true, {"{decoracion}": nombre})
	SistemaGuardado.set_flag(BANDERA_ADORNO, true)
	admin.cuadro_dialogo.cerrar()
