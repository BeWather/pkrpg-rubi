extends ColorRect

signal pantalla_oscurecida
signal pantalla_aclarada

const TransicionCueva := preload("res://scripts/transitions/cave_transition.gd")
var en_transicion: bool = false

func _ready() -> void:
	color.a = 0  # Inicialmente transparente

func oscurecer(duracion: float = 0.3, blanco: bool = false) -> void:
	en_transicion = true
	var alpha := color.a
	color = Color(1.0, 1.0, 1.0, alpha) if blanco else Color(0.0, 0.0, 0.0, alpha)
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "color:a", 1.0, duracion).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	en_transicion = false
	emit_signal("pantalla_oscurecida")

## Cubre la pantalla de golpe, sin fundido: para relevar a otra capa que ya
## terminó en negro (fin de batalla) sin dejar ni un frame del mapa a la vista.
func cubrir(blanco: bool = false) -> void:
	color = Color.WHITE if blanco else Color.BLACK
	visible = true

func aclarar(duracion: float = 0.3) -> void:
	en_transicion = true
	# Crea un Tween para la transición inversa
	var tween = create_tween()
	tween.tween_property(self, "color:a", 0.0, duracion).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	en_transicion = false
	emit_signal("pantalla_aclarada")


func transicion_cueva(entrando: bool) -> void:
	en_transicion = true
	var efecto := TransicionCueva.new()
	add_child(efecto)
	await efecto.reproducir(entrando)
	color = Color.BLACK if entrando else Color.WHITE
	remove_child(efecto)
	efecto.queue_free()
	en_transicion = false
