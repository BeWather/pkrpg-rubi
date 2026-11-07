@tool
## npc_presidente_club.gd
## PRESIDENTE del CLUB FAN de CIUDAD PORTUAL (pokeruby
## SlateportCity_PokemonFanClub_EventScript_Chairman: lock + faceplayer, según
## VAR_SLATEPORT_FAN_CLUB_STATE):
## - estado 0: presentación y examina al POKéMON líder (el primero que no sea un HUEVO);
## - estado 1: cuenta los PAÑUELOS ya entregados (si son los 5, pasa al estado 2); si no,
##   «¿Qué tal está creciendo tu POKéMON?» y lo examina;
## - estado 2: «no me queda nada más que darte».
## Examinar: «Ajá… Muy bien…» y, para cada PAÑUELO aún no entregado, la condición del líder
## (CheckLeadMonCool/Beauty/Cute/Smart/Tough: >= 200). Rubí evalúa DUREZA, INGENIO, DULZURA,
## BELLEZA y CARISMA y se queda con la última que se cumple: gana CARISMA > BELLEZA > DULZURA >
## INGENIO > DUREZA. Sin ninguna, «dale más POKéCUBOS»; con una, «¡Tu {especie} está creciendo a
## un ritmo impresionante!», el PAÑUELO (checkitemspace: sin sitio, «tienes la MOCHILA llena» y
## sin bandera) y la explicación del color.
## CARISMA, BELLEZA, DULZURA, INGENIO y DUREZA (`BasePokemon`) no las sube aún ningún sistema
## (concursos y POKéCUBOS no existen): hasta entonces siempre sale «dale más POKéCUBOS».
## Las banderas de estado se guardan como `club_portual_presidente_conocido` (estado >= 1) y
## `club_portual_panuelos_completos` (estado 2).
## Bloqueo del jugador y diálogo: patrón de npc_reportero_museo.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const CintaEsfuerzo = preload("res://scripts/npc/npc_cinta_esfuerzo.gd")

const TEXTO_PRESENTACION: String = "PORTUAL_CLUB_PRESIDENTE_PRESENTACION"
const TEXTO_CRECE: String = "PORTUAL_CLUB_PRESIDENTE_CRECE"
const TEXTO_NADA_MAS: String = "PORTUAL_CLUB_PRESIDENTE_NADA_MAS"
const TEXTO_VEO: String = "PORTUAL_CLUB_PRESIDENTE_VEO"
const TEXTO_MAS_POKECUBOS: String = "PORTUAL_CLUB_PRESIDENTE_MAS_POKECUBOS"
const TEXTO_SIN_SITIO: String = "PORTUAL_CLUB_PRESIDENTE_SIN_SITIO"
const TEXTO_IMPRESIONANTE: String = "PORTUAL_CLUB_PRESIDENTE_IMPRESIONANTE"

## VAR_SLATEPORT_FAN_CLUB_STATE: 0 → sin banderas, 1 → conocido, 2 → completos.
const BANDERA_CONOCIDO: String = "club_portual_presidente_conocido"
const BANDERA_COMPLETOS: String = "club_portual_panuelos_completos"
## CheckLeadMon*: la condición del POKéMON líder debe llegar a 200.
const CONDICION_MINIMA: int = 200
## En el orden de prioridad del guion (el primero que se cumple gana).
const PANUELOS: Array[Dictionary] = [
	{"objeto": "PANUELOROJO", "condicion": "carisma", "bandera": "club_portual_panuelo_rojo_recibido",
		"texto": "PORTUAL_CLUB_PRESIDENTE_ROJO"},
	{"objeto": "PANUELOAZUL", "condicion": "belleza", "bandera": "club_portual_panuelo_azul_recibido",
		"texto": "PORTUAL_CLUB_PRESIDENTE_AZUL"},
	{"objeto": "PANUELOROSA", "condicion": "dulzura", "bandera": "club_portual_panuelo_rosa_recibido",
		"texto": "PORTUAL_CLUB_PRESIDENTE_ROSA"},
	{"objeto": "PANUELOVERDE", "condicion": "ingenio", "bandera": "club_portual_panuelo_verde_recibido",
		"texto": "PORTUAL_CLUB_PRESIDENTE_VERDE"},
	{"objeto": "PANUELOAMARILLO", "condicion": "dureza", "bandera": "club_portual_panuelo_amarillo_recibido",
		"texto": "PORTUAL_CLUB_PRESIDENTE_AMARILLO"},
]


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	await _guion()
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _guion() -> void:
	if SistemaGuardado.get_flag(BANDERA_COMPLETOS):
		await _mensaje(tr(TEXTO_NADA_MAS))  # NoMoreScarves
		return
	if not SistemaGuardado.get_flag(BANDERA_CONOCIDO):
		SistemaGuardado.set_flag(BANDERA_CONOCIDO, true)  # ChairmanFirstAssessment
		await _mensaje(tr(TEXTO_PRESENTACION))
	else:
		if panuelos_recibidos() >= PANUELOS.size():  # ReceivedAllScarves
			SistemaGuardado.set_flag(BANDERA_COMPLETOS, true)
			await _mensaje(tr(TEXTO_NADA_MAS))
			return
		await _mensaje(tr(TEXTO_CRECE))  # ChairmanTryAssessPokemon
	await _examinar_lider()


## ChairmanAssessLeadMon.
func _examinar_lider() -> void:
	await _mensaje(tr(TEXTO_VEO), true)
	var lider: BasePokemon = CintaEsfuerzo.pokemon_lider(SistemaGuardado.get_equipo())
	var panuelo: Dictionary = panuelo_para(lider)
	if panuelo.is_empty():
		await _mensaje(tr(TEXTO_MAS_POKECUBOS), true)  # NoHighConditions
		return
	var objeto: String = str(panuelo["objeto"])
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, 1)
	if not bool(resultado.get("exito", false)):
		await _mensaje(tr(TEXTO_SIN_SITIO), true)  # NoRoomForScarf
		return
	SistemaGuardado.set_flag(str(panuelo["bandera"]), true)
	await _mensaje(tr(TEXTO_IMPRESIONANTE).replace("{especie}", lider.nombre), true)
	await mostrar_objeto_recibido(objeto)
	continuar_dialogo(tr(str(panuelo["texto"])), true, _mensaje_terminado.emit)
	await _mensaje_terminado


## PAÑUELO que toca dar al líder (ninguno si `lider` es null o no llega a 200 en ninguna
## condición de un PAÑUELO que aún no se ha entregado): {} = «dale más POKéCUBOS».
static func panuelo_para(lider: BasePokemon) -> Dictionary:
	if lider == null:
		return {}
	for panuelo in PANUELOS:
		if SistemaGuardado.get_flag(str(panuelo["bandera"])):
			continue
		if int(lider.get(str(panuelo["condicion"]))) >= CONDICION_MINIMA:
			return panuelo
	return {}


static func panuelos_recibidos() -> int:
	var total: int = 0
	for panuelo in PANUELOS:
		if SistemaGuardado.get_flag(str(panuelo["bandera"])):
			total += 1
	return total


## Escribe un mensaje y espera el botón. `continuar` lo encadena en el cuadro ya abierto
## (varios msgbox seguidos sin cerrar); sin él se abre uno nuevo.
func _mensaje(texto: String, continuar: bool = false) -> void:
	if continuar:
		continuar_dialogo(texto, true, _mensaje_terminado.emit)
	else:
		nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
