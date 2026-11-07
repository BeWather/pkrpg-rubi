extends EfectoMovimientoNativo
## Vuelo (Move_FLY). vuelo.tscn tiene «carga» (_81D0480) y «ataque» (_81D0498).
## Carga (gBattleAnimSpriteTemplate_83DA450, sub_80DA300/sub_80DA348): el
## atacante se oculta y una sombra redonda se deforma en su centro y sube
## acelerando hasta salir por arriba. Ataque (83DA468, sub_80DA38C/sub_80DA410):
## la sombra entra por la esquina superior del lado del atacante, cruza hacia
## el defensor a velocidad constante (1/20 del recorrido por frame) y, cuando
## sale de la pantalla, el atacante vuelve a verse. La visibilidad del atacante
## pasa por fijar_visible_atacante() (BattleHiddenProjection en batalla).

const ESPERA_SUBIDA: int = 13
const ACELERACION: int = 336
const FRAMES_ATAQUE: int = 20

@onready var plantilla_sombra: Sprite2D = $PlantillaSombra


## Pista de método: la sombra de la carga.
func lanzar_sombra_carga() -> void:
	var sombra: Sprite2D = _instanciar_plantilla(plantilla_sombra) as Sprite2D
	var centro: Vector2 = marca_atacante.position.floor()
	# gSpriteAffineAnim_83DA3FC: ancho 0x10 -> 0x100, alto 0x100 -> 0x60, luego se estira.
	var escalas: Array[Vector2] = escalas_afines(Vector2(0x10, 0x100), [[0x28, 0, 6], [0, -0x20, 5], [-0x10, 0x20, 10]])
	var estado: Dictionary = {"velocidad": 0, "altura": 0}
	var paso: Callable = func(i: int) -> void:
		sombra.scale = escalas[mini(i, escalas.size() - 1)]
		if i > ESPERA_SUBIDA:
			estado.velocidad += ACELERACION
			estado.altura += estado.velocidad >> 8
		sombra.position = centro - Vector2(0, estado.altura)
		if sombra.position.y < -32.0:
			sombra.visible = false
	_cada_frame(40, paso, sombra.queue_free)


## Pista de método: la sombra del ataque. Hace reaparecer al atacante al salir.
func lanzar_sombra_ataque() -> void:
	var sombra: Sprite2D = _instanciar_plantilla(plantilla_sombra) as Sprite2D
	# Esquina de entrada: (-32, -32) con el jugador; (272, -32) con el rival.
	var inicio: Vector2 = Vector2(-32.0 if direccion > 0.0 else 272.0, -32.0)
	var destino: Vector2 = marca_defensor.position.floor()
	# Punto fijo 8.8 de InitAnimLinearTranslation.
	var velocidad: Vector2 = Vector2(int((destino.x - inicio.x) * 256.0 / FRAMES_ATAQUE), int((destino.y - inicio.y) * 256.0 / FRAMES_ATAQUE))
	# Afín 0 (+50) con el jugador y 1 (-40) con el rival: giro antihorario positivo en la GBA.
	sombra.rotation = -TAU * (50.0 if direccion > 0.0 else -40.0) / 256.0
	var estado: Dictionary = {"fuera": false}
	var paso: Callable = func(i: int) -> void:
		if estado.fuera:
			return
		sombra.position = (inicio + (velocidad * i / 256.0)).floor()
		# Pantalla de la GBA (240x160): sale cuando x + 32 no cabe en 0..304 o y > 160.
		if sombra.position.x + 32.0 > 304.0 or sombra.position.x + 32.0 < 0.0 or sombra.position.y > 160.0:
			estado.fuera = true
			sombra.visible = false
			fijar_visible_atacante(true)
	_cada_frame(60, paso, sombra.queue_free)
