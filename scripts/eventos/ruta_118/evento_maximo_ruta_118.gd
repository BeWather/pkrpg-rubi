## evento_maximo_ruta_118.gd
## Encuentro con MÁXIMO en la RUTA 118 (pokeruby Route118_EventScript_150FAE/_150FCE/_150FE4 → _151004, coord_events
## (43,11), (44,11) y (45,11) con VAR_ROUTE118_STATE == 0; contador `ruta118_estado`, empieza en 0). STEVEN = MÁXIMO.
## Godot = Rubí + (0,0).
##
## El jugador mira arriba; MÁXIMO (objeto 19, (44,7)) se alinea con él, baja saltando el saliente de la fila 8, un paso más, habla
## y se va hacia el este hasta (53,10), donde desaparece. El estado pasa a 1 y `ruta118_maximo_oculto` (FLAG_HIDE_STEVEN_ROUTE118,
## que aquí pone removeobject 19) lo deja fuera del mapa.
extends EventoInteriorMalvalona
class_name EventoMaximoRuta118

const MOTIVO_PAUSA: StringName = &"ruta_118_maximo"
const ID_DISPARADOR: StringName = &"maximo"

## VAR_ROUTE118_STATE.
const CONTADOR_ESTADO: String = "ruta118_estado"
## FLAG_HIDE_STEVEN_ROUTE118.
const BANDERA_OCULTO: String = "ruta118_maximo_oculto"
const TEXTO_MAXIMO: String = "RUTA118_MAXIMO"
## playse SE_LEDGE: el mismo sonido que el salto de saliente del jugador (character.gd).
const SONIDO_SALIENTE: String = "SE_DANSA"

## delay 30 y delay_16 de Route118_Movement_15106D.
const FOTOGRAMAS_DELAY_30: int = 30
const FOTOGRAMAS_DELAY_16: int = 16
## Columna del jugador -> pasos a la derecha (Route118_Movement_151071, _15107C y _151086).
const PASOS_AL_IRSE: Dictionary[int, int] = {43: 10, 44: 9, 45: 8}
## Columna de MÁXIMO, donde no hace falta alinearse (Route118_Movement_151069 / _15106B).
const COLUMNA_CENTRAL: int = 44

@export var steven: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == ID_DISPARADOR:
		await encuentro()


## Route118_EventScript_151004. La columna es la x del jugador (43, 44 o 45).
func encuentro() -> void:
	var npc := nodo(steven)
	if npc == null or SistemaGuardado.get_contador(CONTADOR_ESTADO) != 0 or not comenzar(_administrador()):
		return
	var columna: int = admin.jugador.pos_celda_act.x
	if not PASOS_AL_IRSE.has(columna):
		columna = COLUMNA_CENTRAL
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	girar_jugador(U)
	if columna != COLUMNA_CENTRAL:
		await caminar(npc, L if columna < COLUMNA_CENTRAL else R)
	Singleton.play_sound.emit(SONIDO_SALIENTE)
	await caminar(npc, D)  # jump_2_down: el saliente de la fila 8
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	await caminar(npc, D)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	await mensaje(TEXTO_MAXIMO)
	admin.cuadro_dialogo.cerrar()  # closemessage
	var pasos: Array = []
	for i in int(PASOS_AL_IRSE[columna]):
		pasos.append(R)
	await recorrer(npc, pasos)
	SistemaGuardado.set_contador(CONTADOR_ESTADO, 1)
	SistemaGuardado.set_flag(BANDERA_OCULTO, true)  # removeobject 19
	npc.aplicar_bandera_ocultar()
	terminar(false, [npc])
