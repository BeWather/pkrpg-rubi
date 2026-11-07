## evento_monte_cenizo.gd
## Guiones del MONTE CENIZO (pokeruby data/maps/MtChimney/scripts.inc y data/scripts/magma_chimney.inc). Las
## celdas de la escena son las de Rubí.
##
## AQUILES (objeto 1, MtChimney_EventScript_1B2C95): lock + faceplayer. La primera vez te pide que detengas
## al EQUIPO MAGMA; después dice la versión corta (FLAG_EVIL_LEADER_PLEASE_STOP). Vuelve a su dirección.
##
## MAGNO (objeto 2, MtChimney_EventScript_1B2CCB): al hablarle, comenta el METEORITO, se gira, se sobresalta
## (SE_PIN + «!»), te cuenta su visión y te combate (trainerbattle_no_intro TRAINER_MAXIE_3; si pierdes, el
## coordinador de derrota te lleva al CENTRO POKéMON y no se activa nada). Si ganas: se despide, fundido a
## negro, desaparecen MAGNO y los MAGMA (FLAG_HIDE_EVIL_TEAM_MT_CHIMNEY), AQUILES aparece en (10,12) (setobjectxyperm
## 1, 10, 12 + addobject: su objeto original (24,19) estaba lejos de la cámara y no existía), camina hasta
## ti por un camino que depende de hacia dónde mirabas (VAR_FACING), te da las gracias y se va. Al final
## desaparece el EQUIPO AQUA y se activa FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY (PROF. COZMO se va de la CASCADA
## METEORO y vuelve a PUEBLO PARDAL).
##
## GALLETERA (objeto 9, MtChimney_EventScript_15CF95): GALLETA LAVA por 200$.
##
## Máquina (bg_event (14,6), MtChimney_EventScript_15D17D): sin vencer al equipo, «almacena energía»; vencido,
## ofrece sacar el METEORITO (una sola vez, FLAG_RECEIVED_METEORITE).
extends EventoGuionizado
class_name EventoMonteCenizo

const MOTIVO_PAUSA: StringName = &"monte_cenizo"
## playse SE_PIN.
const SONIDO_EXCLAMACION: String = "SE_PIN"
## TRAINER_MT_CHIMNEY_GRUNT_3 = TRAINER_MAXIE_3 en Rubí.
const ENTRENADOR_MAXIE: int = 602
const OBJETO_METEORITO: String = "METEORITO"
const OBJETO_GALLETA: String = "GALLETALAVA"
## removemoney 200.
const PRECIO_GALLETA: int = 200

const TEXTO_AQUILES_PRIMERA: String = "MONTE_CENIZO_AQUILES_PRIMERA"
const TEXTO_AQUILES_DESPUES: String = "MONTE_CENIZO_AQUILES_DESPUES"
const TEXTO_AQUILES_GRACIAS: String = "MONTE_CENIZO_AQUILES_GRACIAS"
const TEXTO_MAXIE_PODER: String = "MONTE_CENIZO_MAXIE_PODER"
const TEXTO_MAXIE_DISCURSO: String = "MONTE_CENIZO_MAXIE_DISCURSO"
const TEXTO_MAXIE_ADIOS: String = "MONTE_CENIZO_MAXIE_ADIOS"
const TEXTO_GALLETAS_OFERTA: String = "MONTE_CENIZO_GALLETAS_OFERTA"
const TEXTO_GALLETAS_GRACIAS: String = "MONTE_CENIZO_GALLETAS_GRACIAS"
const TEXTO_GALLETAS_SIN_DINERO: String = "MONTE_CENIZO_GALLETAS_SIN_DINERO"
const TEXTO_GALLETAS_NO: String = "MONTE_CENIZO_GALLETAS_NO"
const TEXTO_MAQUINA_ENERGIA: String = "MONTE_CENIZO_MAQUINA_ENERGIA"
const TEXTO_MAQUINA_SACAR: String = "MONTE_CENIZO_MAQUINA_SACAR"
const TEXTO_MAQUINA_SACADO: String = "MONTE_CENIZO_MAQUINA_SACADO"
const TEXTO_MAQUINA_DEJADO: String = "MONTE_CENIZO_MAQUINA_DEJADO"
const TEXTO_MAQUINA_MUDA: String = "MONTE_CENIZO_MAQUINA_MUDA"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

## setobjectxyperm 1, 10, 12 (AQUILES tras el fundido).
const CELDA_AQUILES_FINAL := Vector2i(10, 12)

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## VAR_FACING 4 (el jugador mira al este desde (12,6)): MtChimney_Movement_15D025 (AQUILES llega) y
## MtChimney_Movement_15D02D (se va).
const AQUILES_LLEGA_ESTE: Array = [U, U, U, U, U, U, R]
const AQUILES_SALE_ESTE: Array = [L, D, D, D, D, D, D, D]
## VAR_FACING 2 (mira al norte desde (13,7)): MtChimney_Movement_15D036 y MtChimney_Movement_15D03E.
const AQUILES_LLEGA_NORTE: Array = [U, U, U, U, U, R, R]
const AQUILES_SALE_NORTE: Array = [L, L, D, D, D, D, D, D, D]

@export var aquiles: NodePath = ^"../../NPCs/Aquiles"
@export var maxie: NodePath = ^"../../NPCs/Maxie"
@export var vendedora: NodePath = ^"../../NPCs/Galletera"
@export var cartel_maquina: NodePath = ^"../../Carteles/CartelMaquina"
## Contenedor de los NPC (para refrescar su visibilidad tras cambiar las banderas HIDE).
@export var npcs: NodePath = ^"../../NPCs"

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_escuchar(aquiles, _on_aquiles)
	_escuchar(maxie, _on_maxie)
	_escuchar(vendedora, _on_vendedora)
	var cartel := get_node_or_null(cartel_maquina)
	if cartel != null and cartel.has_signal("accionado"):
		cartel.accionado.connect(_on_maquina)
	# LavaridgeTown_OnTransition (clearflag FLAG_HIDE_MT_CHIMNEY_PEOPLE si ya se venció al equipo malo): en Rubí hay que pasar
	# por PUEBLO LAVACALDA; aquí basta con volver a cargar el monte (se vuelve a él desde la RUTA 112 o el DESFILADERO, pasando
	# por la estación). Los NPC ya evaluaron sus banderas en su _ready, así que se refrescan.
	if HistoriaMonteCenizo.mostrar_gente_si_toca():
		refrescar_npcs()


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _escuchar(ruta: NodePath, receptor: Callable) -> void:
	var npc := _npc(ruta)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(receptor)


## lock + faceplayer (lockall sin girar con `girar` a false): false si ya hay un guion en curso o no hay administrador
## (el jugador queda libre).
func _empezar(npc: Node2D, girar: bool = true) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	if girar:
		npc.mirar_jugador()  # faceplayer
	return true


## Vuelve a evaluar bandera_ocultar / bandera_mostrar de todos los NPC del mapa (removeobject masivo).
func refrescar_npcs() -> void:
	var contenedor := get_node_or_null(npcs)
	if contenedor == null:
		return
	for hijo in contenedor.get_children():
		if hijo.has_method("aplicar_bandera_ocultar"):
			hijo.aplicar_bandera_ocultar()


## ============================================================================
## AQUILES (MtChimney_EventScript_1B2C95)
## ============================================================================

func _on_aquiles(npc: Node2D) -> void:
	if not _empezar(npc):
		return
	var avisado := SistemaGuardado.get_flag(HistoriaMonteCenizo.BANDERA_AQUILES_AVISADO)
	await mensaje(TEXTO_AQUILES_DESPUES if avisado else TEXTO_AQUILES_PRIMERA)
	mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
	SistemaGuardado.set_flag(HistoriaMonteCenizo.BANDERA_AQUILES_AVISADO, true)
	terminar(false, [npc])


## ============================================================================
## MAGNO (MtChimney_EventScript_1B2CCB)
## ============================================================================

func _on_maxie(npc: Node2D) -> void:
	if not _empezar(npc, false):  # lockall: sigue mirando la máquina
		return
	await escena_maxie(npc)


## Todo el guion desde que se habla con MAGNO. `npc` ya está en INTERACTING y sigue mirando la máquina.
func escena_maxie(npc: Node2D) -> void:
	var jugador: Node = admin.get("jugador")
	var mirada: Vector2 = jugador.facing_direction  # VAR_FACING (antes de que MAGNO se gire)
	await mensaje(TEXTO_MAXIE_PODER)
	npc.mirar_jugador()  # applymovement 2, Common_Movement_FacePlayer
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc)
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	await mensaje(TEXTO_MAXIE_DISCURSO)
	var resultado := await combatir(ENTRENADOR_MAXIE)  # trainerbattle_no_intro
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	await mensaje(TEXTO_MAXIE_ADIOS)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await esperar_fotogramas(30)
	await oscurecer_pantalla()  # fadescreen FADE_TO_BLACK
	# removeobject 2, 3 y 22 + setflag FLAG_HIDE_EVIL_TEAM_MT_CHIMNEY (todos los MAGMA y sus perros).
	SistemaGuardado.set_flag(HistoriaMonteCenizo.BANDERA_MAGMA_FUERA, true)
	refrescar_npcs()
	var jefe_aqua := _npc(aquiles)
	if jefe_aqua != null:
		colocar(jefe_aqua, CELDA_AQUILES_FINAL)  # setobjectxyperm 1, 10, 12
		jefe_aqua.visible = true  # addobject 1 (colocar ya lo deja mirando como su tipo de movimiento, FACE_LEFT)
	await aclarar_pantalla()  # fadescreen FADE_FROM_BLACK
	var al_este := mirada != U  # solo hay dos celdas desde las que se le habla: (12,6) mirando al este y (13,7) al norte
	if jefe_aqua != null:
		await recorrer(jefe_aqua, AQUILES_LLEGA_ESTE if al_este else AQUILES_LLEGA_NORTE)
	girar_jugador(L)  # walk_in_place_fastest_left
	await mensaje(TEXTO_AQUILES_GRACIAS)
	if jefe_aqua != null:
		await recorrer(jefe_aqua, AQUILES_SALE_ESTE if al_este else AQUILES_SALE_NORTE)
		jefe_aqua.visible = false  # removeobject 1
	HistoriaMonteCenizo.marcar_equipo_derrotado()  # FLAG_HIDE_OTHER_TEAM + FLAG_DEFEATED + FLAG_HIDE_PROF_COSMO_*
	refrescar_npcs()
	terminar(false, [jefe_aqua] if jefe_aqua != null else [])


## ============================================================================
## GALLETERA (MtChimney_EventScript_15CF95)
## ============================================================================

func _on_vendedora(npc: Node2D) -> void:
	if not _empezar(npc):
		return
	mostrar_cuadro_dinero()
	if not await preguntar_si_no(TEXTO_GALLETAS_OFERTA):
		await mensaje(TEXTO_GALLETAS_NO)
	elif SistemaGuardado.get_dinero_jugador() < PRECIO_GALLETA:
		await mensaje(TEXTO_GALLETAS_SIN_DINERO)
	else:
		await mensaje(TEXTO_GALLETAS_GRACIAS, false)
		SistemaGuardado.quitar_dinero_jugador(PRECIO_GALLETA)  # removemoney 200
		actualizar_cuadro_dinero()  # updatemoneybox
		if not await dar_objeto(npc, OBJETO_GALLETA):  # giveitem ITEM_LAVA_COOKIE
			SistemaGuardado.dar_dinero_jugador(PRECIO_GALLETA)  # Rubí solo cobra si hay sitio
			actualizar_cuadro_dinero()
			await mensaje(TEXTO_MOCHILA_LLENA)
	ocultar_cuadro_dinero()  # hidemoneybox
	terminar(false, [npc])


## ============================================================================
## MÁQUINA DEL METEORITO (MtChimney_EventScript_15D17D)
## ============================================================================

func _on_maquina(_cartel: Node) -> void:
	if _en_curso or not comenzar(_administrador()):  # lockall
		return
	match HistoriaMonteCenizo.estado_maquina():
		HistoriaMonteCenizo.Maquina.ENERGIA:
			await mensaje(TEXTO_MAQUINA_ENERGIA)
		HistoriaMonteCenizo.Maquina.MUDA:
			await mensaje(TEXTO_MAQUINA_MUDA)
		HistoriaMonteCenizo.Maquina.SACAR:
			if await preguntar_si_no(TEXTO_MAQUINA_SACAR):
				await mensaje(TEXTO_MAQUINA_SACADO, false)
				# giveitem sin NPC: los mensajes de «obtenido» los escribe cualquier NPC del mapa.
				await dar_objeto(_portador_de_mensajes(), OBJETO_METEORITO)
				SistemaGuardado.set_flag(HistoriaMonteCenizo.BANDERA_METEORITO, true)
			else:
				await mensaje(TEXTO_MAQUINA_DEJADO)
	terminar()


## Un NPC del mapa que sepa escribir «¡Obtuvo X!» (dar_objeto lo exige aunque el objeto salga de un cartel).
func _portador_de_mensajes() -> Node2D:
	for ruta: NodePath in [vendedora, maxie, aquiles]:
		var candidato := _npc(ruta)
		if candidato != null and candidato.has_method("mostrar_objeto_recibido"):
			return candidato
	return null
