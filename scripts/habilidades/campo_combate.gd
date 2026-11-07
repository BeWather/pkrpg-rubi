class_name CampoCombate
extends RefCounted

## Fotografía del campo que necesitan las habilidades: clima y Pokémon activos
## de cada lado (1 en SIMPLE, 2 en DOBLE). Es un dato puro: no toca la escena.
## `batalla.gd` lo construye con `crear_campo_habilidades()`.

## Optional domain resolver: volatile battle state remains outside party data.
var combatiente_de: Callable
var clima: int = 0
var activos_jugador: Array[BasePokemon] = []
var activos_enemigo: Array[BasePokemon] = []
var screen_timers: Array[Dictionary]=[] # Accepted side snapshot, never a scene owner.


static func nuevo(clima_actual: int, jugador: Array, enemigo: Array) -> CampoCombate:
	var campo := CampoCombate.new()
	campo.clima = clima_actual
	for p in jugador:
		if p is BasePokemon:
			campo.activos_jugador.append(p)
	for p in enemigo:
		if p is BasePokemon:
			campo.activos_enemigo.append(p)
	return campo


## Todos los Pokémon en el campo (también los debilitados que aún ocupan hueco).
func todos() -> Array[BasePokemon]:
	var resultado: Array[BasePokemon] = []
	resultado.append_array(activos_jugador)
	resultado.append_array(activos_enemigo)
	return resultado


## 0 = jugador, 1 = enemigo, -1 = no está en el campo.
func lado_de(pokemon: BasePokemon) -> int:
	if activos_jugador.has(pokemon):
		return 0
	if activos_enemigo.has(pokemon):
		return 1
	return -1


## Rivales vivos de `pokemon`.
func rivales_de(pokemon: BasePokemon) -> Array[BasePokemon]:
	var lado := lado_de(pokemon)
	var origen: Array[BasePokemon] = activos_enemigo if lado == 0 else activos_jugador
	var resultado: Array[BasePokemon] = []
	for p in origen:
		if p != null and p.estad_ps_actual > 0:
			resultado.append(p)
	return resultado


## true si algún Pokémon del campo tiene la habilidad `clave`
## (ABILITYEFFECT_FIELD_SPORT: cuenta a todos, también al propio y al rival).
func hay_habilidad(clave: String) -> bool:
	for p in todos():
		if HabilidadesCombate.de(p) == clave:
			return true
	return false


## Clima que de verdad se aplica: ACLIMATACIÓN y BUCLE AIRE lo anulan
## (WEATHER_HAS_EFFECT).
func clima_efectivo() -> int:
	if hay_habilidad(HabilidadesCombate.ACLIMATACION) or hay_habilidad(HabilidadesCombate.BUCLEAIRE):
		return 0
	return clima
