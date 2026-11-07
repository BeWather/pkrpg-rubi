class_name EfectosVitaminas
extends RefCounted

## Efecto de las vitaminas (MÁS PS, PROTEÍNA, HIERRO, CARBURANTE, CALCIO y ZINC)
## sobre un Pokémon del equipo, fuera de combate. Funciones estáticas, sin nodos:
## sólo modifican el BasePokemon; el inventario y la UI son cosa de quien llama
## (la pantalla de equipo, como UseMedicine).
##
## Referencia pokeruby:
## - src/data/pokemon/item_effects.h: +10 EV y amistad +5/+3/+2 (Amistad.Evento.VITAMINA).
## - src/pokemon_item_effect.c (PokemonUseItemEffects): topes de EV.
## - src/pokemon_1.c (CalculateMonStats): cómo cambian los PS actuales.
## - src/party_menu.c (IsMedicineIneffective, GetMedicineItemEffectMessage).

const EV_POR_VITAMINA: int = 10
## Tope de EV por estadística que alcanzan las vitaminas.
const EV_MAXIMO_VITAMINA: int = 100
const EV_MAXIMO_TOTAL: int = 510
const ESPECIE_SHEDINJA: String = "SHEDINJA"

## Por nombre_interno de poke.db: EV que sube y clave del nombre de la estadística.
const EFECTOS: Dictionary = {
	"MASPS": {"ev": "ev_ps", "clave": "VITAMINA_PS"},                          # gItemEffect_HPUp
	"PROTEINA": {"ev": "ev_ataque", "clave": "VITAMINA_ATAQUE"},               # gItemEffect_Protein
	"HIERRO": {"ev": "ev_defensa", "clave": "VITAMINA_DEFENSA"},               # gItemEffect_Iron
	"CARBURANTE": {"ev": "ev_velocidad", "clave": "VITAMINA_VELOCIDAD"},       # gItemEffect_Carbos
	"CALCIO": {"ev": "ev_ataque_especial", "clave": "VITAMINA_AT_ESP"},        # gItemEffect_Calcium
	"ZINC": {"ev": "ev_defensa_especial", "clave": "VITAMINA_DF_ESP"},         # gItemEffect_Zinc
}

const CLAVE_SUBIO: String = "VITAMINA_SUBIO"  ## gOtherText_WasRaised


## Resultado de aplicar(): qué pasó y qué mensaje mostrar.
class ResultadoVitamina extends RefCounted:
	## true si el objeto hizo algo: hay que gastarlo.
	var tuvo_efecto: bool = false
	## Mensaje ya traducido y con el nombre sustituido.
	var mensaje: String = ""


## true si `nombre_interno` es una vitamina.
static func es_soportado(nombre_interno: String) -> bool:
	return EFECTOS.has(nombre_interno.to_upper())


## Aplica la vitamina a `poke`. Sin efecto (EV de la estadística en 100, 510 EV en
## total, MÁS PS en SHEDINJA o un huevo) el Pokémon queda igual y el mensaje es
## "No tendrá ningún efecto.".
static func aplicar(nombre_interno: String, poke: BasePokemon) -> ResultadoVitamina:
	var resultado := ResultadoVitamina.new()
	resultado.mensaje = EfectosMedicina.texto(EfectosMedicina.CLAVE_SIN_EFECTO)
	var nombre: String = nombre_interno.to_upper()
	if not EFECTOS.has(nombre) or poke == null or poke.huevo:
		return resultado
	var efecto: Dictionary = EFECTOS[nombre]
	var propiedad: String = str(efecto["ev"])
	# IsMedicineIneffective: SHEDINJA no puede usar MÁS PS.
	if propiedad == "ev_ps" and poke.nombre_interno.to_upper() == ESPECIE_SHEDINJA:
		return resultado
	var ev_actual: int = int(poke.get(propiedad))
	var total: int = _total_ev(poke)
	if total >= EV_MAXIMO_TOTAL or ev_actual >= EV_MAXIMO_VITAMINA:
		return resultado

	var subida: int = mini(mini(EV_POR_VITAMINA, EV_MAXIMO_VITAMINA - ev_actual), EV_MAXIMO_TOTAL - total)
	poke.set(propiedad, ev_actual + subida)
	_recalcular_stats(poke)
	Amistad.ajustar(poke, Amistad.Evento.VITAMINA)

	resultado.tuvo_efecto = true
	resultado.mensaje = EfectosMedicina.texto(CLAVE_SUBIO,
		{"{stat}": EfectosMedicina.texto(str(efecto["clave"])), "{mon}": poke.get_nombre_mostrar()})
	return resultado


static func _total_ev(poke: BasePokemon) -> int:
	return poke.ev_ps + poke.ev_ataque + poke.ev_defensa \
		+ poke.ev_ataque_especial + poke.ev_defensa_especial + poke.ev_velocidad


## CalculateMonStats: los PS actuales suben lo mismo que el máximo; un debilitado
## sigue a 0. _recalcular_stats_con_ivs_actuales los llena, así que se restauran.
static func _recalcular_stats(poke: BasePokemon) -> void:
	var ps_antes: int = poke.estad_ps_actual
	var ps_max_antes: int = poke.estad_ps
	poke._recalcular_stats_con_ivs_actuales()
	poke.estad_ps_actual = mini(ps_antes + poke.estad_ps - ps_max_antes, poke.estad_ps) if ps_antes > 0 else 0
