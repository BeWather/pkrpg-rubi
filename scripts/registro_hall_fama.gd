class_name RegistroHallFama
extends RefCounted
## Registro del HALL de la FAMA (hall_of_fame.c, Task_Hof_InitTeamSaveData). Se escribe dentro de
## `datos_persistentes` para viajar con la partida; hay un máximo de 50 equipos y, al superarlo,
## se descarta el más antiguo. `entradas` es GAME_STAT_ENTERED_HOF (tope 999).

const CLAVE: String = "hall_fama"
const MAX_EQUIPOS: int = 50
const MAX_ENTRADAS: int = 999


## Lo que se conserva de cada POKéMON (struct HallofFameMon más lo que necesita el sprite).
static func entrada_de(pokemon: BasePokemon) -> Dictionary:
	return {
		"nombre_interno": pokemon.nombre_interno,
		"especie": pokemon.nombre,
		"nombre": pokemon.get_nombre_mostrar(),
		"numero_nacional": pokemon.numero_nacional,
		"nivel": pokemon.nivel,
		"sexo": pokemon.sexo,
		"entrenador_id": pokemon.entrenador_id,
		"personalidad": pokemon.personalidad,
		"shiny": pokemon.es_shiny(),
		"huevo": pokemon.huevo,
	}


## Añade el equipo y devuelve su número de entrada.
static func registrar(persistentes: Dictionary, equipo: Array) -> int:
	var registro: Dictionary = _registro(persistentes)
	var entradas: Array = []
	for pokemon: BasePokemon in equipo:
		entradas.append(entrada_de(pokemon))
	var numero: int = mini(int(registro.get("entradas", 0)) + 1, MAX_ENTRADAS)
	registro["entradas"] = numero
	var equipos: Array = registro["equipos"]
	equipos.append({"numero": numero, "pokemon": entradas})
	while equipos.size() > MAX_EQUIPOS:
		equipos.remove_at(0)
	return numero


## Equipos del más antiguo al más reciente.
static func equipos(persistentes: Dictionary) -> Array:
	return _registro(persistentes)["equipos"]


static func _registro(persistentes: Dictionary) -> Dictionary:
	if not (persistentes.get(CLAVE) is Dictionary):
		persistentes[CLAVE] = {"entradas": 0, "equipos": []}
	var registro: Dictionary = persistentes[CLAVE]
	if not (registro.get("equipos") is Array):
		registro["equipos"] = []
	return registro
