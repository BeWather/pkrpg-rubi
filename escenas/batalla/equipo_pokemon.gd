extends RefCounted
class_name EquipoPokemon

var pokemones: Array[BasePokemon] = []
var max_tamaño: int = 6
var pokemon_actual_indice: int = 0

func _init(tamaño_maximo: int = 6):
	self.max_tamaño = tamaño_maximo

func agregar_pokemon(pokemon: BasePokemon) -> bool:
	if get_tamaño() < max_tamaño:
		pokemones.append(pokemon)
		return true
	return false

func get_pokemon_actual() -> BasePokemon:
	if pokemon_actual_indice < get_tamaño():
		return pokemones[pokemon_actual_indice]
	return null

func get_pokemon_disponibles() -> Array:
	var disponibles = []
	for pokemon in pokemones:
		if pokemon != null and pokemon.puede_combatir():
			disponibles.append(pokemon)
	return disponibles

func cambiar_pokemon(nuevo_indice: int) -> bool:
	if nuevo_indice < get_tamaño() and pokemones[nuevo_indice].puede_combatir():
		pokemon_actual_indice = nuevo_indice
		return true
	return false

func get_siguiente_pokemon_disponible() -> BasePokemon:
	for i in range(get_tamaño()):
		if pokemones[i].puede_combatir():
			pokemon_actual_indice = i
			return pokemones[i]
	return null

func tiene_pokemones_disponibles() -> bool:
	for pokemon in pokemones:
		if pokemon != null and pokemon.puede_combatir():
			return true
	return false

func get_tamaño() -> int:
	var cant: int = 0
	for pokemon in pokemones:
		if pokemon != null:
			cant += 1
	return cant

func esta_lleno() -> bool:
	return get_tamaño() >= max_tamaño

# Para crear equipos de prueba
static func crear_equipo_prueba(nombres_pokemones: Array, nivel: int = 25) -> EquipoPokemon:
	var equipo = EquipoPokemon.new()
	for nombre in nombres_pokemones:
		var pokemon = BasePokemon.new(nombre, nivel, "ENTRENADOR")
		equipo.agregar_pokemon(pokemon)
	return equipo
