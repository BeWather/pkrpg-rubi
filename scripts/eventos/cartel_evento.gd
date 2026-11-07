## cartel_evento.gd
## Cartel (bg_event de pokeruby) cuyo `script` no es un simple msgbox: al
## leerlo emite `accionado` y lo resuelve el evento del mapa (reloj de la
## habitación, PC del rival…). Sin nadie escuchando se comporta como un
## Signpost normal (id_texto).
@tool
extends Signpost
class_name CartelEvento

signal accionado(cartel: CartelEvento)


func accionar_cartel() -> void:
	if accionado.get_connections().is_empty():
		super.accionar_cartel()
		return
	accionado.emit(self)
