@tool
extends HBoxContainer
class_name FilaResumenEncuentro
## Fila del resumen por especie: probabilidad total sumando todos sus slots.

@onready var _icono: TextureRect = %Icono
@onready var _nombre: Label = %Nombre
@onready var _niveles: Label = %Niveles
@onready var _porcentaje: Label = %Porcentaje
@onready var _barra: ProgressBar = %Barra


func configurar(catalogo: CatalogoPokemon, entrada: Dictionary) -> void:
	var interno: String = str(entrada.get("nombre_interno", ""))
	var visible_nombre: String = catalogo.nombre_visible(interno)
	_icono.texture = catalogo.icono(interno if catalogo.es_valida(interno) else "")
	_nombre.text = visible_nombre if not visible_nombre.is_empty() else interno
	var nivel_min: int = int(entrada.get("nivel_min", 1))
	var nivel_max: int = int(entrada.get("nivel_max", nivel_min))
	_niveles.text = "Nv. %d" % nivel_min if nivel_min == nivel_max else "Nv. %d–%d" % [nivel_min, nivel_max]
	var porcentaje: float = float(entrada.get("porcentaje", 0.0))
	_porcentaje.text = ModeloEncuentros.formatear_porcentaje(porcentaje)
	_barra.value = porcentaje
