@tool
class_name SelectorClimaEntrada
extends Node

## Clima por zona al ENTRAR al mapa (MAP_SCRIPT_ON_TRANSITION de Gen 3, p. ej.
## Route120_OnTransition con getplayerxy). Cuando el mapa pasa a ser el actual
## (carga de partida, cruce de borde, warp, paso a exterior) o se restaura su
## clima, el administrador busca este nodo en el mapa y aplica de inmediato el
## clima de la primera zona que contenga la celda del jugador; si ninguna la
## contiene se usa `clima_inicial` del MapaConfiguracion.
##
## Va como descendiente del mapa (preferiblemente `Eventos/SelectorClimaEntrada`);
## se localiza por el grupo `selector_clima_entrada`. Un mapa debe tener uno solo.

const GRUPO: StringName = &"selector_clima_entrada"

## Se evalúan en orden: gana la primera que contenga la celda.
@export var zonas: Array[ZonaClimaEntrada] = []:
	set(valor):
		zonas = valor
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("update_configuration_warnings")


func _enter_tree() -> void:
	add_to_group(GRUPO)


## Primera zona que contiene `celda` (celda local del mapa), o null.
func resolver(celda: Vector2i) -> ZonaClimaEntrada:
	for zona: ZonaClimaEntrada in zonas:
		if zona != null and zona.contiene(celda):
			return zona
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	for indice: int in range(zonas.size()):
		var zona: ZonaClimaEntrada = zonas[indice]
		if zona == null:
			avisos.append("La zona %d está vacía." % indice)
			continue
		if zona.zonas_tiles.is_empty():
			avisos.append("La zona %d no tiene rectángulos." % indice)
		if zona.clima != null:
			avisos.append_array(zona.clima.obtener_avisos())
		for rect: Rect2i in zona.zonas_tiles:
			if rect.size.x <= 0 or rect.size.y <= 0:
				avisos.append("La zona %d tiene un rectángulo sin área: %s." % [indice, rect])
		for anterior: int in range(indice):
			var otra := zonas[anterior]
			if otra == null:
				continue
			var solapada := false
			for rect: Rect2i in zona.zonas_tiles:
				for otro: Rect2i in otra.zonas_tiles:
					if rect.intersects(otro):
						solapada = true
			if solapada:
				avisos.append("Las zonas %d y %d se solapan: gana la primera." % [anterior, indice])
	return avisos
