extends RefCounted
class_name SeleccionGuardarDecoracion

## sub_8101340/1460/13B8: sprites primero, después primer mueble y apoyos.
## IDs estables del proyecto, nunca índices/flags de object events GBA.
static func seleccionar(colocaciones: Array[Dictionary], cursor: Vector2i, celdas: Dictionary) -> Array[Dictionary]:
	for colocacion: Dictionary in colocaciones:
		if DatosBasesSecretas.decoracion(int(colocacion["decoracion_id"]))["tipo_grafico"] == "sprite" \
			and rectangulo(colocacion, celdas).has_point(cursor):
			return [colocacion.duplicate(true)]
	for colocacion: Dictionary in colocaciones:
		var rect: Rect2i = rectangulo(colocacion, celdas)
		if not rect.has_point(cursor):
			continue
		var grupo: Array[Dictionary] = [colocacion.duplicate(true)]
		for apoyo: Dictionary in colocaciones:
			if DatosBasesSecretas.decoracion(int(apoyo["decoracion_id"]))["tipo_grafico"] == "sprite" \
				and rect.has_point(Vector2i(int(apoyo["x"]), int(apoyo["y"]))):
				grupo.append(apoyo.duplicate(true))
		return grupo
	return []


static func rectangulo(colocacion: Dictionary, celdas: Dictionary) -> Rect2i:
	var id: int = int(colocacion["decoracion_id"])
	var ancla: Vector2i = Vector2i(int(colocacion["x"]), int(colocacion["y"]))
	var tamano: Vector2i = ValidadorDecoracion.tamano_forma(ValidadorDecoracion.forma_decoracion(id))
	# SAND ORNAMENT derrumbado: selección pierde la fila superior; restauración
	# recupera la huella original completa. Activación del efecto sigue en fase 7.
	if id == 41 and int((celdas.get(ancla, {}) as Dictionary).get("metatile_id", -1)) == 0x28C:
		tamano.y -= 1
	return Rect2i(ancla + Vector2i(0, 1 - tamano.y), tamano)
