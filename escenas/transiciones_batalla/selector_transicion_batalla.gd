## Elección de la transición de fase 2 como en battle_setup.c de pokeruby
## (GetWildBattleTransition / GetTrainerBattleTransition). Funciones puras: el
## llamador aporta el contexto (mapa, niveles, entrenador).
class_name SelectorTransicionBatalla
extends RefCounted

## GetBattleTransitionTypeByMap: fila de las tablas.
const TIPO_NORMAL: int = 0
const TIPO_CUEVA: int = 1
## Overworld_GetFlashLevel() > 0: mapa oscuro, se haya usado Destello o no.
const TIPO_OSCURO: int = 2
const TIPO_AGUA: int = 3

## gBattleTransitionTable_Wild: [rival más débil, rival igual o más fuerte].
const TABLA_SALVAJE: Array[Array] = [
	[CatalogoTransicionesBatalla.CORTES, CatalogoTransicionesBatalla.FUNDIDO_BLANCO],
	[CatalogoTransicionesBatalla.RELOJ, CatalogoTransicionesBatalla.CUADRICULA],
	[CatalogoTransicionesBatalla.DESENFOQUE, CatalogoTransicionesBatalla.CUADRICULA],
	[CatalogoTransicionesBatalla.OLA, CatalogoTransicionesBatalla.ONDAS],
]
## gBattleTransitionTable_Trainer.
const TABLA_ENTRENADOR: Array[Array] = [
	[CatalogoTransicionesBatalla.ESTELA_POKEBALLS, CatalogoTransicionesBatalla.FRAGMENTOS],
	[CatalogoTransicionesBatalla.SACUDIDA, CatalogoTransicionesBatalla.POKEBALL_GIGANTE],
	[CatalogoTransicionesBatalla.DESENFOQUE, CatalogoTransicionesBatalla.CUADRICULA],
	[CatalogoTransicionesBatalla.REMOLINO, CatalogoTransicionesBatalla.ONDAS],
]

## TRAINER_CLASS_ELITE_FOUR / TRAINER_CLASS_CHAMPION (DatosEntrenador.clase_entrenador).
const CLASE_ALTO_MANDO: String = "ALTO MANDO"
const CLASE_CAMPEON: String = "CAMPEÓN"
## TRAINER_SIDNEY, TRAINER_PHOEBE, TRAINER_GLACIA, TRAINER_DRAKE → su mugshot.
const MUGSHOTS_ALTO_MANDO: Dictionary[int, StringName] = {
	261: CatalogoTransicionesBatalla.MUGSHOT_SIXTO,
	262: CatalogoTransicionesBatalla.MUGSHOT_FATIMA,
	263: CatalogoTransicionesBatalla.MUGSHOT_NIVEA,
	264: CatalogoTransicionesBatalla.MUGSHOT_DRACON,
}

## Terrenos (EscenarioBatalla.Terreno) que BattleSetup_GetTerrain solo da con el
## jugador sobre agua surfeable o bajo el agua
## (MetatileBehavior_IsSurfableWaterOrUnderwater).
const TERRENOS_AGUA: Array[int] = [
	EscenarioBatalla.Terreno.AGUA,
	EscenarioBatalla.Terreno.ESTANQUE,
	EscenarioBatalla.Terreno.BAJO_AGUA,
]


## GetBattleTransitionTypeByMap, con el mismo orden de prioridad.
static func tipo_por_mapa(mapa_oscuro: bool, en_agua: bool, subterraneo: bool, submarino: bool) -> int:
	if mapa_oscuro:
		return TIPO_OSCURO
	if en_agua:
		return TIPO_AGUA
	if subterraneo:
		return TIPO_CUEVA
	if submarino:
		return TIPO_AGUA
	return TIPO_NORMAL


## El terreno ya resuelto del combate (DatosInicioBatalla.terreno) indica si la
## casilla del jugador es agua surfeable.
static func terreno_es_agua(terreno: int) -> bool:
	return TERRENOS_AGUA.has(terreno)


## GetWildBattleTransition: el nivel del primer rival contra el del primer
## Pokémon del jugador que puede combatir.
static func para_salvaje(tipo: int, nivel_rival: int, nivel_jugador: int) -> StringName:
	return _columna(TABLA_SALVAJE, tipo, nivel_rival < nivel_jugador)


## GetTrainerBattleTransition. `suma_rival` y `suma_jugador` son las sumas de
## niveles de los primeros N (2 si es combate doble, 1 si no).
static func para_entrenador(tipo: int, entrenador_id: int, clase: String, suma_rival: int, suma_jugador: int) -> StringName:
	var clase_normalizada := clase.strip_edges().to_upper()
	if clase_normalizada == CLASE_ALTO_MANDO:
		return MUGSHOTS_ALTO_MANDO.get(entrenador_id, CatalogoTransicionesBatalla.MUGSHOT_MAXIMO)
	if clase_normalizada == CLASE_CAMPEON:
		return CatalogoTransicionesBatalla.MUGSHOT_MAXIMO
	return _columna(TABLA_ENTRENADOR, tipo, suma_rival < suma_jugador)


## GetSumOfPlayerPartyLevel: niveles de los primeros `n` que pueden combatir
## (ni huevos ni debilitados).
static func suma_niveles_jugador(equipo: Array, n: int) -> int:
	var suma := 0
	var restantes := n
	for pokemon in equipo:
		if restantes <= 0:
			break
		if pokemon is BasePokemon and (pokemon as BasePokemon).puede_combatir():
			suma += (pokemon as BasePokemon).nivel
			restantes -= 1
	return suma


## GetSumOfEnemyPartyLevel: niveles de los primeros min(n, tamaño) del rival.
static func suma_niveles_rival(equipo_rival: Array, n: int) -> int:
	var suma := 0
	for i in mini(n, equipo_rival.size()):
		var pokemon: Variant = equipo_rival[i]
		if pokemon is BasePokemon:
			suma += (pokemon as BasePokemon).nivel
	return suma


static func _columna(tabla: Array[Array], tipo: int, rival_mas_debil: bool) -> StringName:
	var fila: Array = tabla[clampi(tipo, 0, tabla.size() - 1)]
	return fila[0] if rival_mas_debil else fila[1]
