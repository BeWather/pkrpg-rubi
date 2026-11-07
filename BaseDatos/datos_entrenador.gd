extends RefCounted
class_name DatosEntrenador

## Datos de un Pokémon perteneciente a un entrenador
class DatosPokemonEntrenador:
	var nombre_interno: String = ""          # Nombre interno del Pokémon (coincide con base de datos)
	var nivel: int = 1                        # Nivel del Pokémon
	var objeto: String = ""                 # Nombre interno del objeto que lleva (opcional)
	var movimientos: Array[String] = []      # Hasta 4 nombres internos de movimientos

	func _init(p_nombre_interno: String = "", p_nivel: int = 1, p_objeto: String = "", p_movs: Array = []):
		nombre_interno = p_nombre_interno
		nivel = p_nivel
		objeto = p_objeto
		# Aceptar máximo 4 movimientos y filtrar valores vacíos
		for m in p_movs:
			if typeof(m) == TYPE_STRING and not m.is_empty():
				movimientos.append(m)
				if movimientos.size() >= 4:
					break

	func to_dictionary() -> Dictionary:
		return {
			"nombre_interno": nombre_interno,
			"nivel": nivel,
			"objeto": objeto,
			"movimientos": movimientos.duplicate()
		}

	## Permite crear desde diccionario (compatibilidad)
	static func desde_dictionary(data: Dictionary) -> DatosPokemonEntrenador:
		var inst = DatosPokemonEntrenador.new()
		if data.has("nombre_interno"):
			inst.nombre_interno = str(data["nombre_interno"])
		else:
			inst.nombre_interno = ""
		if data.has("nivel"):
			inst.nivel = int(data["nivel"])
		else:
			inst.nivel = 1
		if data.has("objeto"):
			inst.objeto = str(data["objeto"])
		else:
			inst.objeto = ""
		if data.has("movimientos") and data["movimientos"] is Array:
			for m in data["movimientos"]:
				if typeof(m) == TYPE_STRING and not m.is_empty():
					inst.movimientos.append(m)
					if inst.movimientos.size() >= 4:
						break
		return inst

## Rubí español (rutina en 0x08041170, no está en el decomp): con estas clases
## los mensajes de batalla intercambian los marcadores de clase y nombre, así
## que se lee "SOLDADO EQUIPO MAGMA" y no "EQUIPO MAGMA SOLDADO". Los ADMIN. y
## LÍDER de los equipos conservan el orden normal.
const CLASES_NOMBRE_DELANTE: Array[String] = ["EQUIPO AQUA", "EQUIPO MAGMA"]

## Clase del entrenador
var clase_entrenador: String = "ENTRENADOR"

## Multiplicador de dinero
var ratio_dinero: int = 5

## Índice del sprite del entrenador
var num_sprite: int = 1

## Nombre del entrenador
var nombre: String = "BRENDAN"

## Frase mostrada por el entrenador al ser derrotado dentro de la batalla.
var frase_derrota: String = "..."

## "M" o "F"
var sexo: String = "M"  # "M" o "F"

## Formato de batalla del entrenador: SIMPLE o DOBLE.
var tipo_batalla: String = "SIMPLE"

## Clave del tema musical que suena en la BATALLA (temas_musicales.json).
var musica_id: String = "batalla_entrenador"

## Índice 0-13 del jingle de encuentro en la ROM (TRAINER_ENCOUNTER_MUSIC_*).
## Es el índice, no la clave: la traducción a clave la hace MusicaRubi, igual
## que en la ROM el índice se resuelve contra una tabla de jingles.
var jingle_id: int = 0

## Objetos que lleva el entrenador
var objetos: Array[String] = []

## Lista de Pokémon (subclase tipada) que posee el entrenador
var pokemon: Array[DatosPokemonEntrenador] = []

static func nombre_delante(clase: String) -> bool:
	return CLASES_NOMBRE_DELANTE.has(clase.strip_edges().to_upper())


## "{clase} {nombre}" de los mensajes de batalla, en el orden de la ROM.
static func nombre_con_clase(clase: String, nombre: String) -> String:
	return "%s %s" % ([nombre, clase] if nombre_delante(clase) else [clase, nombre])


## Agrega un Pokémon usando parámetros sueltos
func agregar_pokemon(nombre_interno: String, nivel: int = 1, objeto: String = "", movimientos: Array = []) -> void:
	var p = DatosPokemonEntrenador.new(nombre_interno, nivel, objeto, movimientos)
	pokemon.append(p)

## Agrega un Pokémon desde un diccionario (compatibilidad con formato anterior)
func agregar_pokemon_diccionario(data: Dictionary) -> void:
	var p = DatosPokemonEntrenador.desde_dictionary(data)
	pokemon.append(p)

## Devuelve la lista de Pokémon como diccionarios (para serialización si se requiere)
func get_pokemon_como_diccionarios() -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for p in pokemon:
		salida.append(p.to_dictionary())
	return salida

## Reemplaza la lista actual leyendo diccionarios (e.g. cargando un save legacy)
func set_pokemon_desde_diccionarios(lista: Array) -> void:
	pokemon.clear()
	for d in lista:
		if d is Dictionary:
			agregar_pokemon_diccionario(d)
