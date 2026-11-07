class_name EstuchePokecubos
extends RefCounted
## CAJA POKéCUBOS: los 40 huecos de `gSaveBlock1.pokeblocks` (POKEBLOCKS_COUNT,
## include/constants/global.h:43). Un hueco vacío es `null` aquí (color 0 en el decomp).
##
## Orden: Rubí NO tiene ordenación automática (la de Esmeralda no existe). Solo hay:
## - el modo mover de SELECT, que intercambia dos huecos (sub_810C23C, src/pokeblock.c:775-791)
##   → `intercambiar()`;
## - el compactado de huecos vacíos hacia el final, al abrir la caja y tras TIRAR
##   (sub_810BC98, src/pokeblock.c:513-529) → `compactar()`, que conserva el orden.
## Dar de comer o lanzar en la Zona Safari borran el hueco sin compactar
## (PokeblockClearIfExists) → `quitar()`; la caja compacta al volver a abrirse.
##
## Se guarda en `EstructuraGuardado.pokecubos` (ver SistemaGuardado.obtener_estuche_pokecubos).

const CAPACIDAD: int = 40

var _huecos: Array[Pokecubo] = []


func _init() -> void:
	_huecos.resize(CAPACIDAD)


## Estuche desde `to_dict()`. Un diccionario vacío o sin `huecos` (partidas antiguas)
## da un estuche vacío.
static func from_dict(d: Dictionary) -> EstuchePokecubos:
	var estuche := EstuchePokecubos.new()
	var huecos: Variant = d.get("huecos", [])
	if huecos is Array:
		var lista: Array = huecos
		for i in mini(lista.size(), CAPACIDAD):
			if lista[i] is Dictionary:
				var cubo: Pokecubo = Pokecubo.from_dict(lista[i])
				if not cubo.esta_vacio():
					estuche._huecos[i] = cubo
	return estuche


## {"huecos": [40 × (dict de Pokecubo | null)]}, en la posición de cada hueco.
func to_dict() -> Dictionary:
	var huecos: Array = []
	for cubo in _huecos:
		huecos.append(cubo.to_dict() if cubo != null else null)
	return {"huecos": huecos}


## GetFirstFreePokeblockSlot: índice del primer hueco vacío, -1 si está lleno.
func primer_hueco_libre() -> int:
	for i in CAPACIDAD:
		if _huecos[i] == null:
			return i
	return -1


func esta_lleno() -> bool:
	return primer_hueco_libre() == -1


func esta_vacio() -> bool:
	return cantidad() == 0


## Número de cubos guardados.
func cantidad() -> int:
	var n: int = 0
	for cubo in _huecos:
		if cubo != null:
			n += 1
	return n


## GivePokeblock: guarda una copia de `cubo` en el primer hueco libre. Devuelve el
## índice o -1 si el estuche está lleno (o el cubo es nulo o vacío).
func agregar(cubo: Pokecubo) -> int:
	if cubo == null or cubo.esta_vacio():
		return -1
	var indice: int = primer_hueco_libre()
	if indice >= 0:
		_huecos[indice] = cubo.duplicar()
	return indice


## Cubo del hueco `indice` (la instancia guardada, no una copia), o null si está vacío
## o fuera de rango.
func obtener(indice: int) -> Pokecubo:
	if indice < 0 or indice >= CAPACIDAD:
		return null
	return _huecos[indice]


## PokeblockClearIfExists: vacía el hueco sin compactar. Devuelve el cubo quitado o
## null si el hueco ya estaba vacío.
func quitar(indice: int) -> Pokecubo:
	var cubo: Pokecubo = obtener(indice)
	if cubo != null:
		_huecos[indice] = null
	return cubo


## TIRAR (sub_810C540…sub_810C668): quita el cubo y compacta. true si había cubo.
func tirar(indice: int) -> bool:
	var habia: bool = quitar(indice) != null
	if habia:
		compactar()
	return habia


## sub_810BC98: mueve los huecos vacíos al final conservando el orden de los cubos.
func compactar() -> void:
	var cubos: Array[Pokecubo] = []
	for cubo in _huecos:
		if cubo != null:
			cubos.append(cubo)
	_huecos.fill(null)
	for i in cubos.size():
		_huecos[i] = cubos[i]


## Modo mover de SELECT (sub_810C23C): intercambia dos huecos (vacíos incluidos).
## false si algún índice está fuera de rango.
func intercambiar(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= CAPACIDAD or b >= CAPACIDAD:
		return false
	var tmp: Pokecubo = _huecos[a]
	_huecos[a] = _huecos[b]
	_huecos[b] = tmp
	return true


## ClearPokeblocks (partida nueva).
func vaciar() -> void:
	_huecos.fill(null)


## Copia de los 40 huecos (null = vacío), para listarlos en la UI.
func huecos() -> Array[Pokecubo]:
	return _huecos.duplicate()
