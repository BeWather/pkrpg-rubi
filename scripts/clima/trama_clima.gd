class_name TramaClima
extends RefCounted

## Rejilla de teselas que cubre un lienzo lógico, incluida la tesela del borde.
static func obtener_teselas(origen: Vector2, lado: float, tamano: Vector2) -> Array[Vector2]:
	var teselas: Array[Vector2] = []
	if lado <= 0.0:
		return teselas
	var y := origen.y - lado
	while y < tamano.y:
		var x := origen.x - lado
		while x < tamano.x:
			teselas.append(Vector2(x, y))
			x += lado
		y += lado
	return teselas
