## seleccion_equipo_torre.gd
## Orden de los participantes de la TORRE BATALLA (gSelectedOrderFromParty, choose_party.c):
## ENTRAR ocupa el primer puesto libre, NO ENTRAR saca al Pokémon y adelanta a los siguientes
## y VALE comprueba el equipo como sub_81220C8.
class_name SeleccionEquipoTorre
extends RefCounted

const TAMANO: int = 3

## PrintPartyMenuPromptText 0x11 / 0x12 / 0x13 de sub_81220C8.
enum Fallo { NINGUNO, FALTAN, MISMA_ESPECIE, MISMO_OBJETO }

## Índices del equipo en el orden en que entran.
var orden: Array[int] = []
## IsMonAllowedInBattleTower por caja.
var admitidos: Array[bool] = []


func _init(admitidos_param: Array[bool] = []) -> void:
	admitidos = admitidos_param.duplicate()


func admitido(indice: int) -> bool:
	return indice >= 0 and indice < admitidos.size() and admitidos[indice]


## Puesto (0-2) del Pokémon o -1 si no participa.
func puesto(indice: int) -> int:
	return orden.find(indice)


## BattleTowerEntryMenuCallback_Enter: false si ya hay tres.
func entrar(indice: int) -> bool:
	if orden.size() >= TAMANO or orden.has(indice):
		return false
	orden.append(indice)
	return true


## BattleTowerEntryMenuCallback_NoEntry.
func quitar(indice: int) -> void:
	orden.erase(indice)


func completa() -> bool:
	return orden.size() >= TAMANO


## Rótulo de la caja (SetupBattleTowerPartyMenu): puesto, PUEDE o NO PUEDE.
func descriptor(indice: int) -> int:
	match puesto(indice):
		0:
			return DatosMaquinas.Descriptor.PRIMERO
		1:
			return DatosMaquinas.Descriptor.SEGUNDO
		2:
			return DatosMaquinas.Descriptor.TERCERO
	return DatosMaquinas.Descriptor.PUEDE if admitido(indice) else DatosMaquinas.Descriptor.NO_PUEDE


## sub_81220C8: tres participantes, sin repetir especie ni objeto (por pares, en orden).
func validar(equipo: Array) -> Fallo:
	if orden.size() < TAMANO:
		return Fallo.FALTAN
	for i in TAMANO - 1:
		var primero: BasePokemon = equipo[orden[i]]
		for j in range(i + 1, TAMANO):
			var otro: BasePokemon = equipo[orden[j]]
			if primero.nombre_interno == otro.nombre_interno:
				return Fallo.MISMA_ESPECIE
			if not primero.objeto.is_empty() and primero.objeto == otro.objeto:
				return Fallo.MISMO_OBJETO
	return Fallo.NINGUNO
