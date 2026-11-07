extends RefCounted
## Orden y filtros de la Pokédex, sin estado ni nodos.
## Basado en SortPokedex y DoPokedexSearch de pokeruby/src/pokedex.c.
##
## Registros de entrada: {numero (Hoenn), nacional, nombre, visto, atrapado,
## tipos (Array[String] con Tipos.nombre de la BD), color (Pokemon.color de la
## BD: "Red", "Blue"...), peso (kg), altura (m), sprite opcional}.
## Cada entrada devuelta añade "numero_mostrado" según el modo.

enum Modo { HOENN, NACIONAL }
enum Orden { NUMERICO, ALFABETICO, MAS_PESADOS, MAS_LIGEROS, MAS_ALTOS, MAS_BAJOS }

## sLetterSearchRanges: índice 0 = CUALQUIERA.
const GRUPOS_INICIAL: Array[String] = ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PQR", "STU", "VWX", "YZ"]
## Índice 0 = CUALQUIERA; el resto es bodyColor 0..9 con el valor de la BD.
const COLORES: Array[String] = ["", "Red", "Blue", "Yellow", "Green", "Black", "Brown", "Purple", "Gray", "White", "Pink"]
## sDexSearchTypeIds sin el tipo ???. Índice 0 = TODOS.
const TIPOS: Array[String] = [
	"", "NORMAL", "LUCHA", "VOLADOR", "VENENO", "TIERRA", "ROCA", "BICHO",
	"FANTASMA", "ACERO", "FUEGO", "AGUA", "PLANTA", "ELECTRICO", "PSIQUICO",
	"HIELO", "DRAGON", "SINIESTRO",
]


## Copia los registros con los campos que usan orden y búsqueda.
## Capturado implica visto. No modifica el array recibido.
static func normalizar(datos: Array[Dictionary]) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for dato in datos:
		var entrada := dato.duplicate(true)
		entrada["numero"] = int(dato.get("numero", 0))
		entrada["nacional"] = int(dato.get("nacional", 0))
		if entrada["numero"] < 1 and entrada["nacional"] < 1:
			continue
		entrada["nombre"] = str(dato.get("nombre", ""))
		entrada["atrapado"] = bool(dato.get("atrapado", false))
		entrada["visto"] = bool(dato.get("visto", false)) or entrada["atrapado"]
		entrada["tipos"] = Array(dato.get("tipos", [])).map(func(t): return str(t).to_upper())
		entrada["color"] = str(dato.get("color", ""))
		entrada["peso"] = float(dato.get("peso", 0.0))
		entrada["altura"] = float(dato.get("altura", 0.0))
		resultado.append(entrada)
	return resultado


## SortPokedex. Numérico rellena huecos (Hoenn desde el 1, Nacional desde el
## primer visto) hasta el último visto; los demás órdenes solo listan vistos
## (alfabético) o capturados (peso y altura), sin huecos.
static func ordenar(datos: Array[Dictionary], modo: int, orden: int) -> Array[Dictionary]:
	var clave := "nacional" if modo == Modo.NACIONAL else "numero"
	var lista: Array[Dictionary] = []
	if orden == Orden.NUMERICO:
		var por_numero: Dictionary = {}
		var primero: int = 0
		var ultimo: int = 0
		for entrada in datos:
			var numero := int(entrada.get(clave, 0))
			if numero < 1:
				continue
			por_numero[numero] = entrada
			if entrada["visto"]:
				primero = numero if primero == 0 else mini(primero, numero)
				ultimo = maxi(ultimo, numero)
		if ultimo == 0:
			return lista
		if modo == Modo.HOENN:
			primero = 1
		for numero in range(primero, ultimo + 1):
			var entrada: Dictionary = por_numero.get(numero, {
				clave: numero, "nombre": "", "visto": false, "atrapado": false,
			})
			lista.append(_con_numero(entrada, clave))
		return lista
	for entrada in datos:
		if int(entrada.get(clave, 0)) < 1:
			continue
		var incluir: bool = entrada["visto"] if orden == Orden.ALFABETICO else entrada["atrapado"]
		if incluir:
			lista.append(_con_numero(entrada, clave))
	# Desempate por número nacional, como las tablas gPokedexOrder_* del decomp.
	match orden:
		Orden.ALFABETICO:
			lista.sort_custom(func(a, b): return _menor(a["nombre"], b["nombre"], a, b))
		Orden.MAS_LIGEROS, Orden.MAS_PESADOS:
			lista.sort_custom(func(a, b): return _menor(a["peso"], b["peso"], a, b))
		Orden.MAS_BAJOS, Orden.MAS_ALTOS:
			lista.sort_custom(func(a, b): return _menor(a["altura"], b["altura"], a, b))
	# Más pesados y más altos recorren la tabla ascendente al revés.
	if orden == Orden.MAS_PESADOS or orden == Orden.MAS_ALTOS:
		lista.reverse()
	return lista


## DoPokedexSearch. Índices de las listas de opciones; 0 = sin filtro.
## Devuelve solo especies vistas; el filtro de tipo exige capturadas.
static func buscar(datos: Array[Dictionary], modo: int, orden: int, inicial: int,
		color: int, tipo_1: int, tipo_2: int) -> Array[Dictionary]:
	var lista := ordenar(datos, modo, orden).filter(func(e): return e["visto"])
	if inicial > 0:
		var letras := GRUPOS_INICIAL[inicial]
		lista = lista.filter(func(e): return not str(e["nombre"]).is_empty() and str(e["nombre"])[0].to_upper() in letras)
	if color > 0:
		lista = lista.filter(func(e): return e.get("color", "") == COLORES[color])
	if tipo_1 > 0 or tipo_2 > 0:
		if tipo_1 == 0:
			tipo_1 = tipo_2
			tipo_2 = 0
		var buscado_1 := TIPOS[tipo_1]
		var buscado_2 := TIPOS[tipo_2]
		lista = lista.filter(func(e): return e["atrapado"] and _coincide_tipo(e.get("tipos", []), buscado_1, buscado_2))
	var resultado: Array[Dictionary] = []
	resultado.assign(lista)
	return resultado


## Un tipo: basta con uno de los dos. Dos tipos: el par exacto en cualquier
## orden; el mismo tipo dos veces solo encuentra especies de tipo único.
static func _coincide_tipo(tipos: Array, buscado_1: String, buscado_2: String) -> bool:
	var propio_1: String = tipos[0] if tipos.size() > 0 else ""
	var propio_2: String = tipos[1] if tipos.size() > 1 and not str(tipos[1]).is_empty() else propio_1
	if buscado_2.is_empty():
		return propio_1 == buscado_1 or propio_2 == buscado_1
	return (propio_1 == buscado_1 and propio_2 == buscado_2) or (propio_1 == buscado_2 and propio_2 == buscado_1)


static func _con_numero(entrada: Dictionary, clave: String) -> Dictionary:
	var copia := entrada.duplicate()
	copia["numero_mostrado"] = int(entrada.get(clave, 0))
	return copia


static func _menor(valor_a: Variant, valor_b: Variant, a: Dictionary, b: Dictionary) -> bool:
	if valor_a != valor_b:
		return valor_a < valor_b
	return _desempate(a) < _desempate(b)


static func _desempate(entrada: Dictionary) -> int:
	return int(entrada.get("nacional", 0)) if int(entrada.get("nacional", 0)) > 0 else int(entrada.get("numero", 0))
