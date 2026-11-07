@tool
class_name DisparadorCeniza
extends "res://scripts/clima/disparador_clima_persistente.gd"

## Fachada de la ceniza volcánica (Ruta 113) sobre DisparadorClimaPersistente.
## Fija el clima CENIZA con un fundido de 1 s y sin música propia. Solo expone el
## id del evento y las zonas de activación, desactivación y llegada.

const CLIMA_CENIZA: DefinicionClima = preload("res://recursos/clima/ceniza.tres")
## Propiedades fijadas por la fachada: ni se muestran ni se guardan.
const PROPIEDADES_FIJAS: Array[StringName] = [
	&"clima_objetivo",
	&"duracion_transicion",
	&"tema_musica",
]


func _init() -> void:
	super._init()
	clima_objetivo = CLIMA_CENIZA
	duracion_transicion = 1.0
	tema_musica = ""


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if StringName(property.name) in PROPIEDADES_FIJAS:
		property.usage = PROPERTY_USAGE_NONE
