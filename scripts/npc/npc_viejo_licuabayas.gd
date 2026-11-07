@tool
## npc_viejo_licuabayas.gd
## Viejo de los vestíbulos de CONCURSOS (pokeruby `SlateportCity_ContestLobby_EventScript_MasterM`
## → `VerdanturfTown_ContestLobby_EventScript_BerryBlendWithNPC`: lock, faceplayer).
## Guion: `texto_intro`; si el jugador tiene alguna BAYA (PlayerHasBerries) dice
## `texto_con_bayas` y termina (la LICUABAYAS se usa desde la máquina: EventoMaquinaLicuabayas).
## Sin BAYAS es el regalo diario de FLAG_DAILY_RECEIVED_BERRY_FALLARBOR (compartida por
## los cuatro vestíbulos): `texto_ya_recibido` si ya lo dio hoy; si no, `texto_regalo`,
## una BAYA MELOC (ITEM_PECHA_BERRY), «¡Obtuvo X!» y `texto_despues`.
## Hereda el contador diario, la entrega y el bloqueo de npc_regalo_diario.gd.
extends "res://scripts/npc/npc_regalo_diario.gd"

## Bolsillo de BAYAS de la mochila (BD: bolsillo 4, mochila 0-4 → 3).
const BOLSILLO_BAYAS: int = 3

## Mensaje de presentación, antes de comprobar las BAYAS.
@export var texto_intro: String = ""
## Si el jugador lleva alguna BAYA.
@export var texto_con_bayas: String = ""


## PlayerHasBerries: alguna BAYA con cantidad > 0 en la mochila.
static func jugador_tiene_bayas() -> bool:
	var datos = SistemaGuardado.datos_vivos
	if datos == null or typeof(datos.mochila) != TYPE_DICTIONARY or not datos.mochila.has("bolsillos"):
		return false
	var bolsillo: Dictionary = datos.mochila.bolsillos.get(str(BOLSILLO_BAYAS), {})
	for objeto in bolsillo.get("items", []):
		if int(objeto.get("cantidad", 0)) > 0:
			return true
	return false


func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	await _mostrar_mensaje(texto_intro)
	if jugador_tiene_bayas():
		await _mostrar_mensaje(texto_con_bayas)
	elif regalo_entregado_hoy():
		await _mostrar_mensaje(texto_ya_recibido)
	else:
		await _mostrar_mensaje(texto_regalo)
		if entregar_regalo():
			await mostrar_objeto_recibido(objeto_entregado)
			await _mostrar_mensaje(texto_despues)
		else:
			await _mostrar_mensaje(texto_mochila_llena)
	_finalizar()
