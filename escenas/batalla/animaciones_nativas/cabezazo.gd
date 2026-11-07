extends EfectoMovimientoNativo
## Cabezazo (Move_SKULL_BASH). cabezazo.tscn tiene «carga» (_81CB399: dos
## veces retroceso de 24 px, inclinación de ida y vuelta y avance) y «ataque»
## (_81CB3E6: retroceso, inclinación, temblor, embestida, destello del fondo,
## estrella de impacto y sacudidas). Todo es declarativo salvo la inclinación:
## el original gira el sprite con su matriz afín (obj_id_set_rotscale) y lo
## baja |c| >> 3 píxeles (sub_8078F9C) para que no parezca que flota.

## Giro en unidades del original (65536 = vuelta completa), positivo hacia el
## rival. En la carga (sub_80A8E04) solo se compensa la altura si el atacante
## es del jugador; en el ataque (sub_80CDAC8) siempre.
@export var giro_carga: int = 0:
	set(valor):
		giro_carga = valor
		_girar(valor, direccion > 0.0)
@export var giro_ataque: int = 0:
	set(valor):
		giro_ataque = valor
		_girar(valor, true)


func _girar(giro: int, compensar_altura: bool) -> void:
	var angulo: float = TAU * giro / 65536.0
	giro_atacante = angulo
	# |c| de la matriz afín (seno en punto fijo 8.8) desplazado 3 bits.
	var altura: int = absi(roundi(sin(angulo) * 256.0)) >> 3 if compensar_altura else 0
	desplazamiento_atacante = Vector2(0.0, altura)
