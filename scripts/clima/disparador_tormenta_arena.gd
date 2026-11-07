@tool
class_name DisparadorTormentaArena
extends "res://scripts/clima/disparador_clima_persistente.gd"

## Fachada del evento de tormenta de arena sobre DisparadorClimaPersistente. Fija
## por código el clima, la transición y la música del desierto, y solo expone el id
## del evento y las zonas de activación y desactivación.

const CLIMA_TORMENTA_ARENA: DefinicionClima = preload("res://recursos/clima/tormenta_arena.tres")
## Propiedades fijadas por la fachada: ni se muestran ni se guardan. La zona de
## llegada no se usa en el desierto (se entra siempre por sus bordes).
const PROPIEDADES_FIJAS: Array[StringName] = [
	&"clima_objetivo",
	&"duracion_transicion",
	&"tema_musica",
	&"zona_tiles_llegada",
]


func _init() -> void:
	super._init()
	clima_objetivo = CLIMA_TORMENTA_ARENA
	duracion_transicion = 1.0
	tema_musica = "RUTA_111_DESIERTO"


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if StringName(property.name) in PROPIEDADES_FIJAS:
		property.usage = PROPERTY_USAGE_NONE
