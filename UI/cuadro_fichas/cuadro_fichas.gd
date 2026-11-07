extends NinePatchRect
class_name CuadroFichas

## Recuadro con las FICHAS del MONEDERO para el overworld (showcoinsbox /
## updatecoinsbox / hidecoinsbox de pokeruby). Misma caja que CuadroDinero, con la
## etiqueta «FICHAS» a la izquierda y la cifra a la derecha. Lo gestiona
## EventoInteriorMalvalona.mostrar_cuadro_fichas(); aplica el marco de Opciones.

const MenuBoxManager = preload("res://scripts/clases/MenuBoxManager.gd")
const IMAGEN_TIPO_POR_DEFECTO: int = 1
const TEXTO_ETIQUETA: String = "CIUDAD_MALVALONA_ETIQUETA_FICHAS"


func _ready() -> void:
	MenuBoxManager.apply_texture_to_ninepatch(self, _imagen_tipo())
	get_node("Label_Etiqueta").text = tr(TEXTO_ETIQUETA)


## Muestra `cantidad` (con separador de miles).
func establecer_fichas(cantidad: int) -> void:
	# Sin @onready: puede llamarse antes de que el recuadro entre en el árbol.
	get_node("Label_Fichas").text = formatear(cantidad)


## 9999 -> «9.999».
static func formatear(cantidad: int) -> String:
	var digitos := str(cantidad)
	var resultado := ""
	var contador := 0
	for i in range(digitos.length() - 1, -1, -1):
		if contador > 0 and contador % 3 == 0:
			resultado = "." + resultado
		resultado = digitos[i] + resultado
		contador += 1
	return resultado


func _imagen_tipo() -> int:
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return IMAGEN_TIPO_POR_DEFECTO
