## evento_casas_calagua.gd
## OnTransition de la CASA de CALAGUA con los cuatro CHICOS (pokeruby LilycoveCity_House3:
## `random 4` + `copyvar VAR_TEMP_1, VAR_RESULT`): cada vez que se entra en el mapa se sortea un
## valor 0-3 y los cuatro chicos (npc_dialogo_por_contador.gd) dicen la frase de ese valor (combates
## múltiples, mezclar récords, LICUABAYAS o CONCURSO). Los chicos y la variable se asignan en la escena.
class_name EventoCasasCalagua
extends Node2D

## Contador de SistemaGuardado que leen los chicos (VAR_TEMP_1).
@export var contador: String = "calagua_casa2_chicos"
## Cantidad de valores posibles (`random 4`).
@export var valores: int = 4

## Sustituye al sorteo (tests): devuelve un valor entre 0 y valores - 1.
var sorteo: Callable = Callable()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := _mapa()
	if mapa != null and mapa.has_signal("mapa_activado"):
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: sortear())
	sortear()


## `random 4` + `copyvar VAR_TEMP_1`.
func sortear() -> int:
	var valor: int = int(sorteo.call()) if sorteo.is_valid() else randi() % maxi(valores, 1)
	SistemaGuardado.set_contador(contador, valor)
	return valor


func _mapa() -> Node:
	var nodo: Node = get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo
