extends EfectoMovimientoNativo
## Bote (Move_BOUNCE). bote.tscn tiene «carga» (_81D04E9) y «ataque» (_81D04FD).
## Carga (gBattleAnimSpriteTemplate_83DA568, sub_80DB194): el atacante se
## oculta y una sombra redonda se deforma en su centro hasta desaparecer.
## Ataque (83DA594, sub_80DB1F4): una sombra estrecha (ancho 0xA0) cae sobre
## el defensor a 10 px por frame, rebota a la misma velocidad y, al salir por
## arriba, el atacante vuelve a verse.

const VELOCIDAD: int = 10

@onready var plantilla_sombra: Sprite2D = $PlantillaSombra


## Pista de método: la sombra de la carga (gSpriteAffineAnim_83DA534).
func lanzar_sombra_carga() -> void:
	var sombra: Sprite2D = _instanciar_plantilla(plantilla_sombra) as Sprite2D
	sombra.position = marca_atacante.position.floor()
	var escalas: Array[Vector2] = escalas_afines(Vector2(0x10, 0x100), [[0x28, 0, 6], [0, -0x20, 5], [-0x14, 0, 7], [-0x14, -0x14, 5]])
	var paso: Callable = func(i: int) -> void:
		sombra.scale = escalas[mini(i, escalas.size() - 1)].max(Vector2.ZERO)
	_cada_frame(escalas.size(), paso, sombra.queue_free)


## Pista de método: la sombra del ataque. Hace reaparecer al atacante al salir.
func lanzar_sombra_ataque() -> void:
	var sombra: Sprite2D = _instanciar_plantilla(plantilla_sombra) as Sprite2D
	sombra.scale = Vector2(0xA0 / 256.0, 1.0)
	var base: Vector2 = marca_defensor.position.floor()
	var estado: Dictionary = {"desplazamiento": -base.y - 32.0, "bajando": true, "fuera": false}
	var paso: Callable = func(i: int) -> void:
		if estado.fuera:
			return
		if i > 0:
			if estado.bajando:
				estado.desplazamiento += VELOCIDAD
				if estado.desplazamiento >= 0.0:
					estado.bajando = false
			else:
				estado.desplazamiento -= VELOCIDAD
				if base.y + estado.desplazamiento < -32.0:
					estado.fuera = true
					sombra.visible = false
					fijar_visible_atacante(true)
		sombra.position = base + Vector2(0.0, estado.desplazamiento)
	_cada_frame(40, paso, sombra.queue_free)
