## evento_salon_fama.gd
## SALÓN DE LA FAMA de la LIGA POKéMON (pokeruby EverGrandeCity_HallOfFame/scripts.inc). Se llega desde la
## sala del CAMPEÓN junto a MÁXIMO (objeto 1, (6,16)); el jugador aparece en (7,16).
##
## OnFrame al entrar (VAR_TEMP_1 = 0): los dos suben seis casillas, se miran y MÁXIMO presenta la sala; suben
## cinco más, delay 20, se miran otra vez y MÁXIMO propone grabar el equipo; los dos miran a la máquina,
## delay 20 y … FLDEFF_HALL_OF_FAME_RECORD, delay 40. Después EverGrandeCity_HallOfFame_EventScript_
## SetGameClearFlags y GameClear.
##
## Se graba el equipo en RegistroHallFama, se muestran el HALL de la FAMA y los créditos, y se activan las
## banderas de fin de juego que ya consulta el proyecto (FLAG_SYS_GAME_CLEAR ≡ `SYS_GAME_CLEAR`, que también
## hace de FLAG_HIDE_LILYCOVE_MOTEL_PEOPLE, del CLUB FAN y del ferry; VAR_STEVENS_HOUSE_STATE = 1), se
## reinicia el ALTO MANDO, el punto de curación pasa a la habitación del jugador (setrespawn
## HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F / _MAYS_HOUSE_2F, (4,2)) y se le lleva allí con un
## fundido, como al volver de los créditos.
extends EventoInteriorMalvalona
class_name EventoSalonFama

const MOTIVO_PAUSA: StringName = &"salon_fama"

const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## VAR_STEVENS_HOUSE_STATE (EventoCasaMaximo.CONTADOR_ESTADO).
const CONTADOR_CASA_MAXIMO: String = "algaria_casa_maximo_estado"
## Habitación del jugador: chico en la casa de BRUNO (nodo_casa_1), chica en la de AURA (nodo_casa_2).
const HABITACION_CHICO: String = "nodo_casa_1_piso_2"
const HABITACION_CHICA: String = "nodo_casa_2_piso_2"
const CELDA_HABITACION: Vector2i = Vector2i(4, 2)
const LUGAR_HABITACION: String = "VILLA_RAIZ"
const CELDA_MAXIMO: Vector2i = Vector2i(6, 16)
## EverGrandeCity_HallOfFame_Movement_WalkIntoHallOfFame1 / 2.
const PASOS_TRAMO_1: int = 6
const PASOS_TRAMO_2: int = 5

const SCN_HALL_FAMA: PackedScene = preload("res://UI/hall_fama/pantalla_hall_fama.tscn")
const SCN_CREDITOS: PackedScene = preload("res://UI/creditos/pantalla_creditos.tscn")
const SCN_GRABACION: PackedScene = preload("res://escenas/eventos/grabacion_hall_fama/grabacion_hall_fama.tscn")

const TEXTO_SALA: String = "COLOSALIA_SALON_FAMA_MAXIMO_SALA"
const TEXTO_GRABAR: String = "COLOSALIA_SALON_FAMA_MAXIMO_GRABAR"

@export var maximo: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(por_warp: bool) -> void:
	preparar()
	if por_warp:
		await escena()


func preparar() -> void:
	var steven := nodo(maximo)
	if steven == null or _en_curso:
		return
	colocar(steven, CELDA_MAXIMO)
	mirar(steven, U)


## EverGrandeCity_HallOfFame_EventScript_EnterHallOfFame.
func escena() -> void:
	if not comenzar(_administrador()):
		return
	await esperar_fin_warp(admin)
	var steven := nodo(maximo)
	steven.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	girar_jugador(U)  # OnWarp
	await _subir_juntos(steven, PASOS_TRAMO_1)
	await _mirarse(steven)
	await mensaje(TEXTO_SALA)
	admin.cuadro_dialogo.cerrar()
	await _subir_juntos(steven, PASOS_TRAMO_2)
	await esperar_fotogramas(20)
	await _mirarse(steven)
	await mensaje(TEXTO_GRABAR)
	admin.cuadro_dialogo.cerrar()
	mirar(steven, U)
	girar_jugador(U)
	await esperar_fotogramas(20)
	await _grabar_en_maquina()
	await esperar_fotogramas(40)
	EventoSalonFama.fijar_juego_completado()
	await _pantallas_finales()
	await _volver_a_casa([steven])


## special GameClear: HALL de la FAMA y créditos, cada uno termina con la pantalla en negro.
func _pantallas_finales() -> void:
	var capa: Node = admin.get_node_or_null("Menu")
	if capa == null:
		return
	await oscurecer_pantalla()
	for escena_final: PackedScene in [SCN_HALL_FAMA, SCN_CREDITOS]:
		var pantalla: Node = escena_final.instantiate()
		pantalla.z_index = 2
		capa.add_child(pantalla)
		if pantalla is PantallaHallFama:
			pantalla.call("reproducir", EventoSalonFama.grabar_equipo)
		else:
			pantalla.call("reproducir")
		await pantalla.terminada
		pantalla.queue_free()


## FLDEFF_HALL_OF_FAME_RECORD.
func _grabar_en_maquina() -> void:
	var mapa := obtener_mapa()
	if mapa == null:
		return
	var grabacion: GrabacionHallFama = SCN_GRABACION.instantiate()
	mapa.add_child(grabacion)
	await grabacion.reproducir(SistemaGuardado.get_equipo().size())
	grabacion.queue_free()


## Task_Hof_InitTeamSaveData + Save_WriteData: registra el equipo y guarda. Al continuar la partida
## se aparece en la habitación (SetContinueGameWarpToHealLocation), no en el SALÓN DE LA FAMA.
static func grabar_equipo() -> void:
	RegistroHallFama.registrar(SistemaGuardado.datos_vivos.datos_persistentes, SistemaGuardado.get_equipo())
	var punto := EventoSalonFama.punto_habitacion()
	for clave: String in punto:
		SistemaGuardado.datos_vivos.posicion[clave] = punto[clave]
	SistemaGuardado.guardar_partida(true)


func _subir_juntos(steven: Node2D, pasos: int) -> void:
	var direcciones: Array = []
	for i in pasos:
		direcciones.append(U)
	await en_paralelo([recorrer.bind(steven, direcciones), recorrer_jugador.bind(direcciones)])


func _mirarse(steven: Node2D) -> void:
	mirar(steven, R)
	girar_jugador(L)


## EverGrandeCity_HallOfFame_EventScript_SetGameClearFlags (lo que tiene equivalente) + setrespawn.
static func fijar_juego_completado() -> void:
	SistemaGuardado.set_flag(BANDERA_JUEGO_COMPLETADO, true)
	SistemaGuardado.set_contador(CONTADOR_CASA_MAXIMO, 1)
	EventoSalaAltoMando.reiniciar_alto_mando()
	# ReadyLatiTVEvent: el boletín de LATIOS en la tele del salón, si aún no se emitió.
	if not SistemaGuardado.get_flag(PokemonErrante.BANDERA_LIBERADO):
		SistemaGuardado.set_flag(ProgramacionTV.BANDERA_TV_LATI, true)
	SistemaGuardado.set_punto_curacion(EventoSalonFama.punto_habitacion())


## HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F / _MAYS_HOUSE_2F según el sexo del jugador.
static func punto_habitacion() -> Dictionary:
	var chico := str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M")) == "M"
	return {
		"mapa_actual": HABITACION_CHICO if chico else HABITACION_CHICA,
		"cx": CELDA_HABITACION.x,
		"cy": CELDA_HABITACION.y,
		"capa_datos": 0,
		"nombre_lugar": LUGAR_HABITACION,
	}


## Tras los créditos el juego sigue en la habitación del jugador.
func _volver_a_casa(npcs: Array) -> void:
	var jugador: Node = admin.jugador
	var admin_actual: Node = admin
	var punto := EventoSalonFama.punto_habitacion()
	terminar(true, npcs)
	jugador.end_dialog()
	jugador.no_control = true
	admin_actual.conectar_escalera(str(punto["mapa_actual"]), Vector2(CELDA_HABITACION), Vector2.DOWN)
