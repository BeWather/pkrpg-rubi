@tool
## npc_evaluador_amistad.gd
## EVALUADORA DE AMISTAD de la casa de PUEBLO VERDEGAL (pokeruby
## VerdanturfTown_FriendshipRatersHouse_EventScript_FriendshipRater: lock +
## faceplayer). Dice `texto_intro` y, según GetLeadMonFriendshipScore del primer
## POKéMON del equipo que no sea un HUEVO, el texto `textos_resultado[puntuación]`
## (0 = lo detesta … 6 = lo adora). Los textos 1-6 continúan la frase del intro
## («Tu POKéMON... te adora.»), así que van en el mismo cuadro.
## Bloqueo del jugador y diálogo: patrón de npc_campana_alivio.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const CintaEsfuerzo = preload("res://scripts/npc/npc_cinta_esfuerzo.gd")

@export var texto_intro: String = "VERDEGAL_AMISTAD_INTRO"
## Índice = GetLeadMonFriendshipScore (0-6).
@export var textos_resultado: PackedStringArray = PackedStringArray([
	"VERDEGAL_AMISTAD_0", "VERDEGAL_AMISTAD_1", "VERDEGAL_AMISTAD_2", "VERDEGAL_AMISTAD_3",
	"VERDEGAL_AMISTAD_4", "VERDEGAL_AMISTAD_5", "VERDEGAL_AMISTAD_6",
])


## GetLeadMonFriendshipScore: 255 → 6, ≥200 → 5, ≥150 → 4, ≥100 → 3, ≥50 → 2, ≥1 → 1.
static func puntuacion_amistad(felicidad: int) -> int:
	if felicidad >= 255:
		return 6
	if felicidad >= 200:
		return 5
	if felicidad >= 150:
		return 4
	if felicidad >= 100:
		return 3
	if felicidad >= 50:
		return 2
	if felicidad >= 1:
		return 1
	return 0


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
	await _mensaje(texto_intro)
	var lider: BasePokemon = CintaEsfuerzo.pokemon_lider(SistemaGuardado.get_equipo())
	if lider != null:
		var indice := clampi(puntuacion_amistad(int(lider.felicidad)), 0, textos_resultado.size() - 1)
		await _mensaje(textos_resultado[indice])
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _mensaje(clave: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
