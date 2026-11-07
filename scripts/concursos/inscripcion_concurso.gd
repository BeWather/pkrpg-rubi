class_name InscripcionConcurso
extends RefCounted
## Inscripción en un concurso (src/contest_2.c):
## - `puede_participar()`: CanMonParticipateInContest;
## - `sortear_rivales()`: la parte de Contest_InitAllPokemon que elige 3 rivales;
## - `crear_concursante_jugador()`: Contest_CreatePlayerMon (con el +20 de los PAÑUELOS);
## - `crear_concursantes()`: los 4 concursantes, con el jugador en el índice 3.
## En Rubí el nivel lo fija el vestíbulo y los rivales se sortean al elegir Pokémon.

## Resultado de CanMonParticipateInContest.
enum Resultado {
	## Le falta la cinta del nivel anterior.
	NO_CUMPLE = 0,
	## Tiene exactamente la del nivel anterior.
	PUEDE = 1,
	## Ya tiene la cinta de este nivel: puede volver a participar (con aviso).
	YA_TIENE_CINTA = 2,
	HUEVO = 3,
	DEBILITADO = 4,
}

const INDICE_JUGADOR: int = 3
const NUM_RIVALES: int = 3
const BONUS_PANUELO: int = 20
## ITEM_*_SCARF -> condición que sube (Movimiento.CategoriaConcurso).
const PANUELOS: Dictionary = {
	"PANUELOROJO": Movimiento.CategoriaConcurso.CARISMA,
	"PANUELOAZUL": Movimiento.CategoriaConcurso.BELLEZA,
	"PANUELOROSA": Movimiento.CategoriaConcurso.DULZURA,
	"PANUELOVERDE": Movimiento.CategoriaConcurso.INGENIO,
	"PANUELOAMARILLO": Movimiento.CategoriaConcurso.DUREZA,
}


## CanMonParticipateInContest.
static func puede_participar(pokemon: BasePokemon, categoria: int, nivel: int) -> Resultado:
	if pokemon.huevo:
		return Resultado.HUEVO
	if pokemon.estad_ps_actual == 0:
		return Resultado.DEBILITADO
	var cinta: int = pokemon.nivel_cinta_concurso(categoria)
	if cinta > nivel:
		return Resultado.YA_TIENE_CINTA
	if cinta == nivel:
		return Resultado.PUEDE
	return Resultado.NO_CUMPLE


## sub_80F9C00: rótulo de la caja del equipo (DatosMaquinas.Descriptor).
static func descriptor_equipo(pokemon: BasePokemon, categoria: int, nivel: int) -> int:
	match puede_participar(pokemon, categoria, nivel):
		Resultado.PUEDE, Resultado.YA_TIENE_CINTA:
			return DatosMaquinas.Descriptor.PUEDE
	return DatosMaquinas.Descriptor.NO_PUEDE


## Contest_InitAllPokemon: 3 rivales distintos del nivel y la categoría, sorteados con
## Random() % candidatos y sin reemplazo.
static func sortear_rivales(datos: DatosConcurso, nivel: int, categoria: int,
		aleatorio: AleatorioConcurso) -> Array[ConcursanteConcurso]:
	var candidatos: Array[int] = datos.rivales_para(nivel, categoria)
	var rivales: Array[ConcursanteConcurso] = []
	for i in NUM_RIVALES:
		if candidatos.is_empty():
			break
		var r: int = aleatorio.modulo(candidatos.size())
		rivales.append(ConcursanteConcurso.desde_rival(datos.rival(candidatos[r])))
		candidatos.remove_at(r)
	return rivales


## Contest_CreatePlayerMon.
static func crear_concursante_jugador(pokemon: BasePokemon, datos: DatosConcurso, entrenador: String,
		grafico: String = "") -> ConcursanteConcurso:
	var c := ConcursanteConcurso.new()
	c.es_jugador = true
	c.especie = pokemon.nombre_interno
	c.mote = pokemon.get_nombre_mostrar()
	c.entrenador = entrenador
	c.grafico = grafico
	c.ia_flags = 0
	c.movimientos = [0, 0, 0, 0]
	for i in mini(pokemon.movimientos.size(), 4):
		var mov: Movimiento = pokemon.movimientos[i]
		if mov != null:
			c.movimientos[i] = datos.numero_movimiento(mov.get_nombre_interno())
	var condiciones: Array[int] = [pokemon.carisma, pokemon.belleza, pokemon.dulzura, pokemon.ingenio, pokemon.dureza]
	if PANUELOS.has(pokemon.objeto):
		var categoria: int = PANUELOS[pokemon.objeto]
		condiciones[categoria] = mini(condiciones[categoria] + BONUS_PANUELO, 255)
	c.carisma = condiciones[0]
	c.belleza = condiciones[1]
	c.dulzura = condiciones[2]
	c.ingenio = condiciones[3]
	c.dureza = condiciones[4]
	c.brillo = pokemon.brillo
	c.personalidad = pokemon.personalidad
	c.ot_id = pokemon.entrenador_id
	c.shiny = pokemon.shiny
	return c


## Los 4 concursantes del concurso: 3 rivales sorteados y el jugador en el índice 3.
static func crear_concursantes(pokemon: BasePokemon, categoria: int, nivel: int, datos: DatosConcurso,
		aleatorio: AleatorioConcurso, entrenador: String, grafico: String = "") -> Array[ConcursanteConcurso]:
	var concursantes: Array[ConcursanteConcurso] = sortear_rivales(datos, nivel, categoria, aleatorio)
	concursantes.append(crear_concursante_jugador(pokemon, datos, entrenador, grafico))
	return concursantes
