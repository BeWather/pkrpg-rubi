@tool
extends Warp
class_name SalidaBaseSecreta

## SALIDAS del jugador existente, con destino resuelto por el contexto del interior.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		super._process(delta)
		return
	var interior: InteriorBaseSecreta = get_parent() as InteriorBaseSecreta
	if interior == null or interior.obtener_contexto().is_empty() or interior.es_vista_previa() or interior.pc_activo():
		return
	if get_node_or_null("/root/AdministradorMapa") == null:
		return
	super._process(delta)


func salida() -> void:
	var interior: InteriorBaseSecreta = get_parent() as InteriorBaseSecreta
	if nodo_administrador == null:
		nodo_administrador = get_node_or_null("/root/AdministradorMapa") as Node2D
	if interior != null and interior.solicitar_salida(nodo_administrador):
		Singleton.emit_signal("play_sound", "puerta_salida")
	elif jugador != null:
		# buscar_salida() ya bloqueó al jugador antes de invocarnos.
		jugador.set("no_control", false)
