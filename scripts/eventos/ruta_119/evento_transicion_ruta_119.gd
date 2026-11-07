## evento_transicion_ruta_119.gd
## OnTransition de la RUTA 119 (pokeruby Route119_MapScript1_15119B) que no es clima: si el EQUIPO MAGMA ya
## se fue del INSTITUTO METEOROLÓGICO (VAR_WEATHER_INSTITUTE_STATE == 1) los trabajadores pasan de la 2F a la 1F
## (Route119_EventScript_1511B9). Se ejecuta al activarse la ruta (MapaConfiguracion.mapa_activado): al volver
## del INSTITUTO por su puerta, al cruzar un borde y al cargar la partida.
## El clima de entrada tiene su propio selector (SelectorClimaEntrada) y el rival su EventoRivalRuta119.
extends Node2D
class_name EventoTransicionRuta119


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := _mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: ejecutar())


func _mapa() -> MapaConfiguracion:
	var nodo: Node = self
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo as MapaConfiguracion


## setflag HIDE_WEATHER_INSTITUTE_WORKERS_2F + clearflag HIDE_..._1F + VAR_WEATHER_INSTITUTE_STATE = 2.
func ejecutar() -> bool:
	return EventoInstitutoRuta119.pasar_trabajadores_a_la_1f()
