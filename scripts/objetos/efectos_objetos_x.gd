extends RefCounted
## Objetos de combate de ItemUseInBattle_StatIncrease (ATAQUE X, DEFENSA X, VELOCIDAD X, ESPECIAL X, PRECISIÓN X,
## DIRECTO y PROTEC. ESP.): se aplican al Pokémon activo desde la mochila, sin pasar por la pantalla de equipo.
##
## Referencia pokeruby:
## - src/data/pokemon/item_effects.h (gItemEffectTable): cada X sube 1 nivel.
## - src/pokemon_item_effect.c (PokemonUseItemEffects): sin efecto si ya está al máximo o activo.
## - src/pokemon_3.c (sub_803F378): el mensaje de cada objeto.

const ESTADISTICA_POR_OBJETO: Dictionary = {
	"ATAQUEX": "ataque",
	"DEFENSAX": "defensa",
	"VELOCIDADX": "velocidad",
	"ESPECIALX": "ataque_especial",
	"PRECISIONX": "precision",
}
const DIRECTO: String = "DIRECTO"
const PROTEC_ESP: String = "PROTECESP"
const NIVEL_MAXIMO: int = 6
## ItemUseInBattle_Escape: huyen de un combate salvaje sin tirada, aunque haya trampas.
const OBJETOS_HUIDA: Array[String] = ["POKEMUNECO", "COLASKITTY"]


static func es_huida(nombre_interno: String) -> bool:
	return nombre_interno.to_upper() in OBJETOS_HUIDA


static func es_soportado(nombre_interno: String) -> bool:
	var nombre: String = nombre_interno.to_upper()
	return ESTADISTICA_POR_OBJETO.has(nombre) or nombre == DIRECTO or nombre == PROTEC_ESP


## Aplica el objeto a `poke` y devuelve el mensaje; "" si no tendría efecto (no se gasta).
static func aplicar(nombre_interno: String, poke: BasePokemon, estado: PokemonEnCombate, pantallas: BattleScreenRules) -> String:
	if poke == null or estado == null:
		return ""
	var nombre: String = nombre_interno.to_upper()
	if ESTADISTICA_POR_OBJETO.has(nombre):
		var stat: String = ESTADISTICA_POR_OBJETO[nombre]
		if int(estado.get("mod_" + stat)) >= NIVEL_MAXIMO:
			return ""
		estado.cambiar_modificador(stat, 1)
		return CambioEstadisticaGen3.construir_mensaje_cambio(poke.get_nombre_combate(), stat, 1)
	if nombre == DIRECTO:
		if estado.source_focus_energy:
			return ""
		estado.source_focus_energy = true
		return "¡%s está reuniendo su concentración!" % poke.get_nombre_combate()
	if nombre == PROTEC_ESP and pantallas.produce(poke, "EFFECT_MIST"):
		return "¡Tu equipo está envuelto en NEBLINA!"
	return ""
