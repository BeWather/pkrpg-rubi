@tool
class_name DefinicionClimaCiclo
extends DefinicionClima

## Clima que cambia de etapa cada día (pokeruby WEATHER_ROUTE119_CYCLE y
## WEATHER_ROUTE123_CYCLE, `sWeatherCycleRoute119` / `sWeatherCycleRoute123` de
## field_weather_effects.c). En Rubí `gSaveBlock1.weatherCycleStage` avanza un paso por
## cada día que pasa (UpdateWeatherPerDay, módulo 4); aquí la etapa sale del día del
## calendario local, `dia % etapas.size()`, igual que los regalos diarios, así que no hace
## falta guardar nada.
##
## Se usa como cualquier otro clima (zona de entrada, DisparadorClimaPorTiles...): el
## ControladorClimaOverworld llama a `resolver()` y aplica la etapa del día.

const SEGUNDOS_DIA: int = 86400

## Climas de cada etapa, en orden. Rubí repite sol, lluvia, tormenta y lluvia (4 etapas).
@export var etapas: Array[DefinicionClima] = []

## Solo pruebas: día fijo (>= 0) en lugar del calendario.
static var dia_forzado: int = -1


## Días enteros desde el 1-1-1970 en hora local (la misma cuenta que npc_regalo_diario).
static func dia_actual() -> int:
	if dia_forzado >= 0:
		return dia_forzado
	var local := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict(local)) / SEGUNDOS_DIA


## Índice de etapa del día `dia` (el de hoy si no se indica).
func indice_etapa(dia: int = -1) -> int:
	if etapas.is_empty():
		return -1
	return posmod(dia_actual() if dia < 0 else dia, etapas.size())


func resolver() -> DefinicionClima:
	var indice := indice_etapa()
	if indice < 0 or etapas[indice] == null:
		return null
	# Una etapa que fuera otro ciclo se resuelve también (sin bucles: no se admite a sí mismo).
	return etapas[indice].resolver() if etapas[indice] != self else null


func obtener_firma_visual() -> Array:
	var firma: Array = [id]
	for etapa: DefinicionClima in etapas:
		firma.append(etapa.obtener_firma_visual() if etapa != null else null)
	return firma


func es_sin_clima() -> bool:
	return false


func obtener_avisos() -> PackedStringArray:
	var avisos := PackedStringArray()
	if String(id).is_empty():
		avisos.append("El clima en ciclo tiene un ID vacío.")
	if etapas.is_empty():
		avisos.append("El clima en ciclo no tiene etapas.")
	for indice: int in range(etapas.size()):
		var etapa: DefinicionClima = etapas[indice]
		if etapa == null:
			avisos.append("La etapa %d está vacía." % indice)
		elif etapa == self:
			avisos.append("La etapa %d es el propio ciclo." % indice)
		else:
			avisos.append_array(etapa.obtener_avisos())
	return avisos
