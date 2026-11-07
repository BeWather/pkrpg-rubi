@tool
extends RefCounted

## Avisos de un registro de `lista_entrenadores.json`. No bloquean el guardado.
## Las comprobaciones contra `poke.db` llegan como Callables (`nombre -> bool`) para
## poder usarse desde el plugin (sin autoloads) y desde los tests.

const MAX_POKEMON: int = 6
const MAX_MOVIMIENTOS: int = 4


static func validar(
	d: Dictionary,
	existe_especie: Callable,
	existe_movimiento: Callable,
	existe_objeto: Callable,
	ids_repetidos: Dictionary = {}
) -> PackedStringArray:
	var avisos: PackedStringArray = []
	var equipo: Array = d.get("pokemon", [])
	if equipo.is_empty():
		avisos.append("El equipo está vacío.")
	elif equipo.size() > MAX_POKEMON:
		avisos.append("El equipo tiene %d Pokémon (máximo %d)." % [equipo.size(), MAX_POKEMON])
	if str(d.get("tipo_batalla", "SIMPLE")) == "DOBLE" and equipo.size() < 2:
		avisos.append("Un combate DOBLE necesita al menos 2 Pokémon.")
	if ids_repetidos.has(int(d.get("id", 0))):
		avisos.append("El ID %d está repetido." % int(d.get("id", 0)))
	for objeto in d.get("objetos", []):
		var nombre := str(objeto).strip_edges()
		if not nombre.is_empty() and not existe_objeto.call(nombre.to_upper()):
			avisos.append("Objeto de entrenador inexistente: %s." % nombre)
	for i in equipo.size():
		var p: Dictionary = equipo[i]
		var especie := str(p.get("nombre_interno", "")).strip_edges().to_upper()
		var etiqueta := "#%d %s" % [i + 1, especie if not especie.is_empty() else "(sin especie)"]
		if especie.is_empty() or not existe_especie.call(especie):
			avisos.append("%s: especie inexistente." % etiqueta)
		var nivel := int(p.get("nivel", 1))
		if nivel < 1 or nivel > 100:
			avisos.append("%s: nivel %d fuera de 1–100." % [etiqueta, nivel])
		var objeto := str(p.get("objeto", "")).strip_edges()
		if not objeto.is_empty() and not existe_objeto.call(objeto.to_upper()):
			avisos.append("%s: objeto inexistente (%s)." % [etiqueta, objeto])
		var movs: Array = p.get("movimientos", [])
		if movs.size() > MAX_MOVIMIENTOS:
			avisos.append("%s: más de %d movimientos fijos." % [etiqueta, MAX_MOVIMIENTOS])
		for mov in movs:
			var nombre_mov := str(mov).strip_edges()
			if not nombre_mov.is_empty() and not existe_movimiento.call(nombre_mov.to_upper()):
				avisos.append("%s: movimiento inexistente (%s)." % [etiqueta, nombre_mov])
	return avisos


## IDs que aparecen más de una vez en la lista: {id: true}.
static func ids_repetidos(lista: Array) -> Dictionary:
	var vistos := {}
	var repetidos := {}
	for d in lista:
		var id := int(d.get("id", 0))
		if vistos.has(id):
			repetidos[id] = true
		vistos[id] = true
	return repetidos
