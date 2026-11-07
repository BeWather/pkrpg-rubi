## evento_arenque_azuliza.gd
## SR. ARENQUE en el muelle de PUEBLO AZULIZA (pokeruby DewfordTown_EventScript_Briney).
## Va en PUEBLO AZULIZA, con ARENQUE (objeto 2) y su barca (objeto 4).
##
## - Sin FLAG_DELIVERED_STEVEN_LETTER: «¿Has entregado la CARTA? ¿O quieres volver a
##   PETALIA?» (SÍ/NO). SÍ → rumbo a PETALIA; NO → «te espero aquí».
## - Con la CARTA entregada: «¿adónde vamos?» con PETALIA / PORTUAL / SALIR
##   (multichoice 0; cancelar = SALIR).
## - Rumbo a PETALIA (DewfordTown_EventScript_SailToPetalburg): ARENQUE sube a la barca,
##   el jugador también (derecha, arriba) y se oculta; la barca recorre
##   DewfordTown_Movement_SailToPetalburg hasta (12,54) de la RUTA 104; el jugador sube
##   tres casillas por el muelle y pasa a la casa del SR. ARENQUE (warp a (5,4)), donde
##   ARENQUE y PEEKO vuelven a estar.
## - Rumbo a PORTUAL (DewfordTown_EventScript_SailToSlateport): igual hasta la travesía
##   DewfordTown_Movement_SailToSlateport, que acaba en (21,26) de la RUTA 109; el jugador
##   sube tres casillas por el muelle y mira abajo, ARENQUE sale de la barca y sube dos;
##   mensaje según FLAG_DELIVERED_DEVON_GOODS.
extends EventoBarcaArenque
class_name EventoArenqueAzuliza

const TEXTO_VOLVER: String = "AZULIZA_ARENQUE_VOLVER"
const TEXTO_TE_ESPERO: String = "AZULIZA_ARENQUE_TE_ESPERO"
const TEXTO_RUMBO_PETALIA: String = "AZULIZA_ARENQUE_RUMBO_PETALIA"
const TEXTO_ADONDE: String = "AZULIZA_ARENQUE_ADONDE"
const TEXTO_A_PETALIA: String = "AZULIZA_ARENQUE_A_PETALIA"
const TEXTO_LLAMAME: String = "AZULIZA_ARENQUE_LLAMAME"
const OPCION_PETALIA: String = "AZULIZA_ARENQUE_OPCION_PETALIA"
const OPCION_SALIR: String = "AZULIZA_ARENQUE_OPCION_SALIR"
const OPCION_PORTUAL: String = "AZULIZA_ARENQUE_OPCION_PORTUAL"
const TEXTO_A_PORTUAL: String = "AZULIZA_ARENQUE_A_PORTUAL"
const TEXTO_LLEGADA_PORTUAL: String = "AZULIZA_ARENQUE_LLEGADA_PORTUAL"
const TEXTO_LLEGADA_PORTUAL_PIEZAS: String = "AZULIZA_ARENQUE_LLEGADA_PORTUAL_PIEZAS"

const MAPA_CASA: String = "ruta_104_casa"
## warp MAP_ROUTE104_MR_BRINEYS_HOUSE, 255, 5, 4.
const ENTRADA_CASA := Vector2(5, 4)

@export var arenque: NodePath
@export var barca_azuliza: NodePath


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc_arenque := _npc(arenque)
	if npc_arenque != null and npc_arenque.has_signal("hablado"):
		npc_arenque.hablado.connect(_on_arenque_hablado)


func _on_arenque_hablado(npc: Node2D) -> void:
	if not comenzar_con(npc):
		return
	if not SistemaGuardado.get_flag(BANDERA_CARTA):
		if await preguntar_si_no(TEXTO_VOLVER):
			await mensaje(TEXTO_RUMBO_PETALIA)
			await viajar_a_petalia(npc)
			return
		await mensaje(TEXTO_TE_ESPERO)
	else:
		var opciones := PackedStringArray([tr(OPCION_PETALIA), tr(OPCION_PORTUAL), tr(OPCION_SALIR)])
		# El cursor empieza en SALIR (la última opción), como en pokeruby.
		# El menú queda 24 px más a la derecha (CIUDAD PORTUAL lo ensancha hacia la izquierda).
		match await elegir_opcion(TEXTO_ADONDE, opciones, opciones.size() - 1, Vector2(24, 0)):
			0:
				await mensaje(TEXTO_A_PETALIA)
				await viajar_a_petalia(npc)
				return
			1:
				await mensaje(TEXTO_A_PORTUAL)
				await viajar_a_portual(npc)
				return
			_:
				await mensaje(TEXTO_LLAMAME)
	terminar(false, [npc])


## Embarque común: ARENQUE sube (walk_up, removeobject 2), el jugador también
## (DewfordTown_Movement_PlayerBoardBoat) y se oculta, suena MUS_SAILING y la barca de
## AZULIZA se sustituye por la del viaje. Devuelve la posición de salida de la barca.
func _embarcar_en_azuliza(npc_arenque: Node2D) -> Vector2:
	admin.cuadro_dialogo.cerrar()  # closemessage
	await caminar(npc_arenque, Vector2.UP)  # DewfordTown_Movement_BrineyBoardBoat
	npc_arenque.visible = false
	SistemaGuardado.set_flag(BANDERA_ARENQUE_AZULIZA, false)
	await recorrer_jugador([Vector2.RIGHT, Vector2.UP])
	admin.jugador.visible = false
	reproducir_musica(MUSICA_NAVEGAR)
	var npc_barca := _npc(barca_azuliza)
	var origen := posicion_global(obtener_mapa(), BARCA_AZULIZA)
	if npc_barca != null:
		origen = pies_de(npc_barca)
		npc_barca.visible = false  # hideobjectat 4
	SistemaGuardado.set_flag(BANDERA_BARCA_AZULIZA, false)  # setflag FLAG_HIDE_MR_BRINEY_BOAT_DEWFORD
	return origen


## DewfordTown_EventScript_SailToSlateport (el guion ya empezó).
func viajar_a_portual(npc_arenque: Node2D) -> void:
	var origen: Vector2 = await _embarcar_en_azuliza(npc_arenque)
	await navegar(origen, TRAMOS_A_PORTUAL)
	var ruta_109 := buscar_mapa(MAPA_RUTA_109)
	if ruta_109 == null:
		push_warning("[BARCA_ARENQUE] La RUTA 109 no está en el Overworld")
		_terminar_sin_destino()
		return
	# showobjectat LOCALID_PLAYER, MAP_ROUTE109 + DewfordTown_Movement_ExitBoatSlateport.
	pasar_jugador_a(ruta_109, BARCA_RUTA_109, Vector2.UP)
	restaurar_musica_mapa()  # Common_EventScript_StopBrineysBoatMusic
	await recorrer_jugador([Vector2.UP, Vector2.UP, Vector2.UP])
	girar_jugador(Vector2.DOWN)
	var arenque_109 := ruta_109.get_node_or_null(RUTA_ARENQUE_RUTA_109) as Node2D
	if arenque_109 != null:
		colocar(arenque_109, BARCA_RUTA_109)  # setobjectxyperm 2, 21, 26
		arenque_109.visible = true
		await recorrer(arenque_109, [Vector2.UP, Vector2.UP])  # DewfordTown_Movement_BrineyExitBoat
	SistemaGuardado.set_flag(BANDERA_ARENQUE_RUTA_109, true)  # clearflag FLAG_HIDE_MR_BRINEY_ROUTE109
	SistemaGuardado.set_flag(BANDERA_BARCA_RUTA_109, true)  # clearflag FLAG_HIDE_MR_BRINEY_BOAT_ROUTE109
	mostrar_barca(ruta_109.get_node_or_null(RUTA_BARCA_RUTA_109) as Node2D, BARCA_RUTA_109, Vector2.UP)
	liberar_barca_viaje()
	await mensaje(TEXTO_LLEGADA_PORTUAL if SistemaGuardado.get_flag(BANDERA_PIEZAS) else TEXTO_LLEGADA_PORTUAL_PIEZAS)
	terminar(false, [arenque_109] if arenque_109 != null else [])


## DewfordTown_EventScript_SailToPetalburg (el guion ya empezó).
func viajar_a_petalia(npc_arenque: Node2D) -> void:
	var origen: Vector2 = await _embarcar_en_azuliza(npc_arenque)
	await navegar(origen, TRAMOS_A_PETALIA)
	var ruta_104 := buscar_mapa(MAPA_RUTA_104)
	SistemaGuardado.set_flag(BANDERA_BARCA_RUTA_104_OCULTA, false)  # clearflag FLAG_HIDE_MR_BRINEY_BOAT_ROUTE104
	SistemaGuardado.set_flag(BANDERA_ARENQUE_CASA, true)  # clearflag FLAG_HIDE_MR_BRINEY_ROUTE104_HOUSE / PEEKO
	if ruta_104 != null:
		mostrar_barca(ruta_104.get_node_or_null(RUTA_BARCA_RUTA_104) as Node2D, BARCA_RUTA_104, Vector2.UP)
		liberar_barca_viaje()
		# showobjectat LOCALID_PLAYER, MAP_ROUTE104 + DewfordTown_Movement_ExitBoatPetalburg.
		pasar_jugador_a(ruta_104, BARCA_RUTA_104, Vector2.UP)
		restaurar_musica_mapa()  # Common_EventScript_StopBrineysBoatMusic
		await recorrer_jugador([Vector2.UP, Vector2.UP, Vector2.UP])
	else:
		push_warning("[BARCA_ARENQUE] La RUTA 104 no está en el Overworld")
		liberar_barca_viaje()
		admin.jugador.visible = true
		Singleton.foco_camara = admin.jugador
	# warp MAP_ROUTE104_MR_BRINEYS_HOUSE, 255, 5, 4.
	var admin_actual := admin
	terminar(true, [npc_arenque])
	admin_actual.jugador.end_dialog()
	admin_actual.jugador.no_control = true
	admin_actual.conectar_escalera(MAPA_CASA, ENTRADA_CASA, Vector2.DOWN)
