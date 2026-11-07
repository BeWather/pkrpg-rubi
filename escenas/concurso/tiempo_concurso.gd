class_name TiempoConcurso
extends RefCounted
## Esperas de la pantalla de concurso en frames de la GBA (60 Hz). Con `escala` 0 cada
## espera dura un solo frame del motor: los tests recorren un concurso entero sin
## esperar los tiempos reales.


static func esperar(nodo: Node, frames: float, escala: float) -> void:
	if not nodo.is_inside_tree():
		return
	if escala <= 0.0 or frames <= 0.0:
		await nodo.get_tree().process_frame
		return
	await nodo.get_tree().create_timer(frames / 60.0 * escala).timeout


## Reproduce un efecto de Singleton.se con un reproductor propio del nodo.
static func sonar(nodo: Node, clave: String, tono: float = 1.0) -> void:
	if not nodo.is_inside_tree() or not Singleton.se.has(clave):
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = Singleton.se[clave]
	reproductor.pitch_scale = tono
	nodo.add_child(reproductor)
	reproductor.finished.connect(reproductor.queue_free)
	reproductor.play()
