@tool
extends Node2D

# Propiedades del círculo
@export var radius: float = 40.0:  # Radio de 40px = diámetro de 80px
	set(value):
		radius = value
		queue_redraw()
@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color: Color = Color(0.5, 0.5, 0.5, 1.0):  # Gris
	set(value):
		border_color = value
		queue_redraw()
@export var border_width: float = 2.0:
	set(value):
		border_width = value
		queue_redraw()

func _draw():
	# Dibujar el círculo de relleno (blanco)
	draw_circle(Vector2.ZERO, radius, fill_color)
	
	# Dibujar el borde (círculo sin relleno)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, border_color, border_width)
