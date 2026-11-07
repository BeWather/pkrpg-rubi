class_name CarameloRaro
extends RefCounted

## Efecto de CARAMELORARO fuera de combate (`gItemEffect_RareCandy` aplicado por
## `ExecuteTableBasedItemEffect`, `src/pokemon_item_effect.c`):
## - ITEM3_LEVEL_UP: experiencia = la del nivel siguiente y CalculateMonStats
##   (los PS actuales suben lo mismo que el máximo);
## - ITEM4_REVIVE | ITEM4_HEAL_HP con ITEM6_HEAL_HP_LVL_UP: si estaba
##   debilitado, revive con los PS que ganó al subir (mínimo 1);
## - FRIENDSHIP_LOW/MID/HIGH: +5/+3/+2, con los mismos extras que
##   AdjustFriendship (Amistad.Evento.SUBIR_NIVEL).
## La interfaz (mensaje, ventana de estadísticas, movimientos y evolución) la
## pone PantallaEquipoControlador.

const NOMBRE_INTERNO: String = "CARAMELORARO"
const NIVEL_MAXIMO: int = 100
## PlayFanfareByFanfareNum(0) = MUS_LEVEL_UP.
const TEMA_FANFARRIA: String = "LEVEL_UP"


## Aplica el caramelo. Devuelve false (sin efecto) a nivel 100 o con un huevo.
static func aplicar(pokemon: BasePokemon) -> bool:
	if pokemon == null or pokemon.huevo or pokemon.nivel >= NIVEL_MAXIMO:
		return false
	var ps_antes := pokemon.estad_ps_actual
	var ps_max_antes := pokemon.estad_ps
	var ratio := str(DatabaseManager.obtener_datos_pokemon(pokemon.nombre_interno).get("ratio_crecimiento", ""))
	pokemon.experiencia = pokemon.get_exp_nivel(pokemon.nivel + 1, ratio)
	pokemon.subir_nivel()
	if ps_antes <= 0:
		# CalculateMonStats deja a 0 al debilitado; el REVIVE le da gBattleStruct->levelUpHP.
		pokemon.estad_ps_actual = clampi(maxi(pokemon.estad_ps - ps_max_antes, 1), 1, pokemon.estad_ps)
	Amistad.ajustar(pokemon, Amistad.Evento.SUBIR_NIVEL)
	return true
