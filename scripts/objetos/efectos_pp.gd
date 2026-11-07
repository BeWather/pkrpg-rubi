class_name EfectosPP
extends RefCounted

## Efectos de los objetos de PP (Objetos.uso_campo = RECUPERAR_PP y MASPP)
## sobre los movimientos de un Pokémon del equipo, dentro y fuera de combate.
## Funciones estáticas, sin nodos: sólo modifican los Movimiento del
## BasePokemon (el combate usa esos mismos objetos); el inventario y la UI son
## cosa de quien llama (la pantalla de equipo).
##
## Referencia pokeruby:
## - src/data/pokemon/item_effects.h (gItemEffectTable): los datos de cada objeto.
## - src/pokemon_item_effect.c (PokemonUseItemEffects): ITEM4_PP_UP, HEAL_PP y PP_MAX.
## - src/party_menu.c (DoPPRecoveryItemEffect, DoPPUpItemEffect, DoRecoverPP,
##   CreateItemUseMoveMenu): cuándo se elige movimiento y qué mensaje sale.

## Valor de "pp" que restaura todos los PP (0x7F del decomp, tope 127).
const PP_TODOS: int = 127
## Más PP aplicables a un movimiento (2 bits de MON_DATA_PP_BONUSES).
const MAS_PP_MAXIMO: int = 3

## Porción de gItemEffectTable para los objetos de PP, por nombre_interno de
## poke.db. Claves:
## - "pp": int — PP que restaura (ITEM4_HEAL_PP); PP_TODOS = hasta el máximo.
## - "un_movimiento": bool — ITEM4_HEAL_PP_ONE: se elige un movimiento; sin él
##   restaura los cuatro (ELIXIR).
## - "mas_pp": int — Más PP que añade al movimiento elegido: 1 (ITEM4_PP_UP)
##   o MAS_PP_MAXIMO (ITEM5_PP_MAX, los pone todos de golpe).
const EFECTOS: Dictionary = {
	"ETER": {"pp": 10, "un_movimiento": true},            # gItemEffect_Ether
	"ETERMAX": {"pp": PP_TODOS, "un_movimiento": true},   # gItemEffect_MaxEther
	"ELIXIR": {"pp": 10},                                 # gItemEffect_Elixir
	"ELIXIRMAX": {"pp": PP_TODOS},                        # gItemEffect_MaxElixir
	"BAYAZANAMA": {"pp": 10, "un_movimiento": true},      # gItemEffect_LeppaBerry
	"MASPP": {"mas_pp": 1},                               # gItemEffect_PPUp
	"MAXPP": {"mas_pp": MAS_PP_MAXIMO},                   # gItemEffect_PPMax
}

## Textos de la ROM española oficial (party_menu.c / strings.c).
const CLAVE_RESTAURAR_QUE_MOV: String = "PP_RESTAURAR_QUE_MOV"  ## OtherText_RestoreWhichMove
const CLAVE_CARGAR_QUE_MOV: String = "PP_CARGAR_QUE_MOV"        ## OtherText_BoostPP
const CLAVE_RESTAURADOS: String = "PP_RESTAURADOS"              ## gOtherText_PPRestored
const CLAVE_SUBIERON: String = "PP_SUBIERON"                    ## gOtherText_PPIncreased


## Resultado de aplicar(): qué pasó y qué mensaje mostrar.
class ResultadoPP extends RefCounted:
	## true si el objeto hizo algo: hay que gastarlo (y, en combate, el turno).
	var tuvo_efecto: bool = false
	## Mensaje ya traducido y con el movimiento sustituido.
	var mensaje: String = ""


## true si `nombre_interno` es un objeto de PP con efecto implementado.
static func es_soportado(nombre_interno: String) -> bool:
	return EFECTOS.has(nombre_interno.to_upper())


## true si hay que elegir un movimiento antes de aplicar el objeto
## (ÉTER, ÉTER MÁX., BAYA ZANAMA, MÁS PP y MÁX. PP).
static func pide_movimiento(nombre_interno: String) -> bool:
	var efecto: Dictionary = EFECTOS.get(nombre_interno.to_upper(), {})
	return bool(efecto.get("un_movimiento", false)) or int(efecto.get("mas_pp", 0)) > 0


## Texto de la pregunta del selector de movimiento ("¿Restaurar qué mov.?" o
## "¿Cargar PP de qué mov.?").
static func texto_pregunta(nombre_interno: String) -> String:
	var efecto: Dictionary = EFECTOS.get(nombre_interno.to_upper(), {})
	return EfectosMedicina.texto(CLAVE_CARGAR_QUE_MOV if int(efecto.get("mas_pp", 0)) > 0 else CLAVE_RESTAURAR_QUE_MOV)


## Aplica el objeto `nombre_interno` a `poke`. `indice_movimiento` es el
## movimiento elegido (se ignora en ELIXIR y ELIXIR MÁX.). Sin efecto el
## Pokémon queda igual y el mensaje es "No tendrá ningún efecto.".
static func aplicar(nombre_interno: String, poke: BasePokemon, indice_movimiento: int = 0) -> ResultadoPP:
	var resultado := ResultadoPP.new()
	resultado.mensaje = EfectosMedicina.texto(EfectosMedicina.CLAVE_SIN_EFECTO)
	var nombre: String = nombre_interno.to_upper()
	if not EFECTOS.has(nombre) or poke == null or poke.huevo:
		return resultado
	var efecto: Dictionary = EFECTOS[nombre]
	var mas_pp: int = int(efecto.get("mas_pp", 0))
	if mas_pp > 0:
		var movimiento: Movimiento = _movimiento(poke, indice_movimiento)
		if movimiento != null and _subir_pp(movimiento, mas_pp):
			resultado.tuvo_efecto = true
			resultado.mensaje = EfectosMedicina.texto(CLAVE_SUBIERON, {"{mov}": movimiento.nombre.to_upper()})
		return resultado

	var cantidad: int = int(efecto.get("pp", 0))
	if bool(efecto.get("un_movimiento", false)):
		var movimiento: Movimiento = _movimiento(poke, indice_movimiento)
		resultado.tuvo_efecto = movimiento != null and _restaurar_pp(movimiento, cantidad)
	else:
		# HEAL_PP sin ITEM4_HEAL_PP_ONE: los cuatro; hay efecto si alguno subió.
		for movimiento: Movimiento in poke.movimientos:
			if movimiento != null and _restaurar_pp(movimiento, cantidad):
				resultado.tuvo_efecto = true
	if resultado.tuvo_efecto:
		resultado.mensaje = EfectosMedicina.texto(CLAVE_RESTAURADOS)
	return resultado


static func _movimiento(poke: BasePokemon, indice: int) -> Movimiento:
	if indice < 0 or indice >= poke.movimientos.size():
		return null
	return poke.movimientos[indice]


## HEAL_PP: con los PP llenos no hay efecto; si no, suben `cantidad` con tope.
static func _restaurar_pp(movimiento: Movimiento, cantidad: int) -> bool:
	if movimiento.pp_act >= movimiento.pp_tot:
		return false
	movimiento.pp_act = mini(movimiento.pp_act + cantidad, movimiento.pp_tot)
	return true


## ITEM4_PP_UP / PP_MAX: con menos de 3 Más PP sube el bonus y los PP actuales
## ganan lo mismo que los totales. MÁS PP además exige más de 4 PP totales
## (data2 > 4); MÁX. PP no lo comprueba.
static func _subir_pp(movimiento: Movimiento, mas_pp: int) -> bool:
	if movimiento.pp_mas >= MAS_PP_MAXIMO:
		return false
	if mas_pp < MAS_PP_MAXIMO and movimiento.pp_tot <= 4:
		return false
	# Sin datos de la BD calcular_pp_totales() dejaría los PP a 0.
	if movimiento.get_max_pp() <= 0:
		return false
	var total_antes: int = movimiento.pp_tot
	movimiento.pp_mas = mini(movimiento.pp_mas + mas_pp, MAS_PP_MAXIMO)
	movimiento.calcular_pp_totales()
	movimiento.pp_act += movimiento.pp_tot - total_antes
	return true
