## Base de los elementos efímeros de la Licuadora de Bayas (cuenta atrás, marcas
## de acierto, partículas, bayas lanzadas). Toda la secuencia vive en el
## AnimationPlayer de cada escena; las pistas de método llaman a estas funciones.
class_name ElementoLicuadora
extends Node2D

## Pide un efecto de sonido por su clave de `Singleton.se` (o el identificador
## original del decomp si todavía no hay sample). Lo reproduce quien instancia.
signal sonido_solicitado(clave: String)
## La animación llegó a su final.
signal terminado

## Si es true, el nodo se libera al terminar (marcas, partículas, bayas).
@export var liberar_al_terminar := true


func emitir_sonido(clave: String) -> void:
	sonido_solicitado.emit(clave)


func terminar() -> void:
	terminado.emit()
	if liberar_al_terminar:
		queue_free()
