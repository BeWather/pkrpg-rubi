extends NinePatchRect
class_name CuadroDinero

## Recuadro con el dinero del jugador para el overworld (showmoneybox /
## updatemoneybox / hidemoneybox de pokeruby). Es el mismo cuadro que la tienda
## (UI/comprar/comprar.tscn, nodo «Dinero»), aislado en su propia escena. Lo gestiona
## EventoGuionizado.mostrar_cuadro_dinero(); aplica el marco elegido en Opciones.

const MenuBoxManager = preload("res://scripts/clases/MenuBoxManager.gd")
## Marco por defecto si no hay partida cargada (el mismo que usa la tienda).
const IMAGEN_TIPO_POR_DEFECTO: int = 1


func _ready() -> void:
	MenuBoxManager.apply_texture_to_ninepatch(self, _imagen_tipo())


## Muestra `cantidad` (con separador de miles y «$»).
func establecer_dinero(cantidad: int) -> void:
	# Sin @onready: puede llamarse antes de que el recuadro entre en el árbol.
	get_node("Label_Dinero").text = formatear(cantidad)


## 676883 -> «676.883$», igual que la tienda.
static func formatear(cantidad: int) -> String:
	var digitos := str(cantidad)
	var resultado := ""
	var contador := 0
	for i in range(digitos.length() - 1, -1, -1):
		if contador > 0 and contador % 3 == 0:
			resultado = "." + resultado
		resultado = digitos[i] + resultado
		contador += 1
	return resultado + "$"


func _imagen_tipo() -> int:
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return IMAGEN_TIPO_POR_DEFECTO
