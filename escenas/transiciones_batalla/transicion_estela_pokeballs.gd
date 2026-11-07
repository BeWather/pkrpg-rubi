## B_TRANSITION_POKEBALLS_TRAIL (Phase2_Transition_PokeballsTrail_Func2): cinco
## Poké Balls en filas de 32 px dejando una estela negra. `rand = Random() & 1`
## decide el lado de la primera fila y las demás alternan (rand ^= 1). La
## animación trae los dos patrones completos (PatronA = rand 0, PatronB = rand 1)
## y aquí se muestra uno al azar.
extends TransicionBatalla

@onready var _patron_a: Node2D = $PatronA
@onready var _patron_b: Node2D = $PatronB


func _preparar() -> void:
	elegir_patron(randi() & 1)


func elegir_patron(rand: int) -> void:
	_patron_a.visible = rand == 0
	_patron_b.visible = rand != 0
