@tool
extends MapaConfiguracion

## Se llama en negro, antes de liberar el mapa de origen.
func preparar_origen_warp(mapa: String, celda: Vector2i) -> void:
	if mapa != "ciudad_calagua_centro_comercial":
		return
	var planta := clampi(roundi(-celda.y / 13.0), 0, 4)
	get_node("NPCs/Encargado").iniciar_en_planta(planta)
