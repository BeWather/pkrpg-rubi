extends EfectoMovimientoNativo
## Buceo (Move_DIVE). buceo.tscn tiene «carga» (_81D49B4) y «ataque» (_81D4A09).
## Carga: el atacante se oculta y una sombra redonda (83DA5D8, sub_80DB288)
## se deforma, sube acelerando hasta salir, espera fuera y vuelve a bajar a la
## misma velocidad; al llegar, una columna de agua (83DA614, sub_80DB374) y
## diez gotas (83DA62C, sub_80DB458) salen del atacante. Ataque: columna y
## gotas en el defensor, y después impactos de agua con pares de burbujas
## (_81C9502); al final el atacante vuelve a verse (`visible 0`).
## Gotas y burbujas usan Random() en el original: aquí un generador con
## semilla fija, así que la dispersión se parece pero no es la misma.

const ESPERA_SUBIDA: int = 13
const ACELERACION: int = 336
const ESPERA_FUERA: int = 22

@onready var plantilla_sombra: Sprite2D = $PlantillaSombra
@onready var plantilla_columna: Sprite2D = $PlantillaColumna
@onready var plantilla_gota: Sprite2D = $PlantillaGota
@onready var plantilla_burbuja: Sprite2D = $PlantillaBurbuja
@onready var plantilla_impacto: Sprite2D = $PlantillaImpacto

var _azar: RandomNumberGenerator = RandomNumberGenerator.new()


func _al_configurar() -> void:
	_azar.seed = 291


## Pista de método: la sombra de la carga, de subida y de vuelta.
func lanzar_sombra_carga() -> void:
	var sombra: Sprite2D = _instanciar_plantilla(plantilla_sombra) as Sprite2D
	var centro: Vector2 = marca_atacante.position.floor()
	var escalas: Array[Vector2] = escalas_afines(Vector2(0x10, 0x100), [[0x28, 0, 6], [0, -0x20, 5], [-0x10, 0x20, 10]])
	var estado: Dictionary = {"velocidad": 0, "altura": 0, "fase": 0, "espera": 0}
	var paso: Callable = func(i: int) -> void:
		sombra.scale = escalas[mini(i, escalas.size() - 1)]
		match estado.fase:
			0:
				if i > ESPERA_SUBIDA:
					if centro.y - estado.altura > -32.0:
						estado.velocidad += ACELERACION
						estado.altura += estado.velocidad >> 8
					else:
						estado.fase = 1
						sombra.visible = false
			1:
				estado.espera += 1
				if estado.espera > ESPERA_FUERA:
					estado.fase = 2
			2:
				estado.altura -= estado.velocidad >> 8
				sombra.visible = centro.y - estado.altura > -32.0
				if estado.altura < 0:
					estado.fase = 3
					sombra.visible = false
		sombra.position = centro - Vector2(0, estado.altura)
	_cada_frame(90, paso, sombra.queue_free)


## Pista de método: columna de agua (sub_80DB374) en el atacante o el defensor.
## Escala vertical 256/d con d de 512 a 32 y vuelta (40 por frame); la caja
## afín de 128 px recorta lo que sobra y la base queda fija.
func lanzar_columna(en_defensor: bool) -> void:
	var columna: Sprite2D = _instanciar_plantilla(plantilla_columna) as Sprite2D
	var centro: Vector2 = (marca_defensor if en_defensor else marca_atacante).position.floor()
	var paso: Callable = func(i: int) -> void:
		var d: int = 512 - 40 * mini(i, 12) + 40 * maxi(i - 12, 0)
		var escala: float = 256.0 / d
		var alto_visible: float = minf(64.0, 128.0 / escala)
		columna.region_rect = Rect2(0.0, 32.0 - alto_visible / 2.0, 64.0, alto_visible)
		columna.scale = Vector2(1.0, escala)
		var t2: int = mini(15616 / d + 1, 128)
		columna.position = centro + Vector2(0.0, (64 - t2) / 2)
	_cada_frame(24, paso, columna.queue_free)


## Pista de método: `cantidad` pares de gotas (sub_80DB458) desde la base del
## battler, una hacia cada lado, con velocidad algo aleatoria y gravedad.
func lanzar_gotas(en_defensor: bool, cantidad: int = 5) -> void:
	var origen: Vector2 = (marca_defensor if en_defensor else marca_atacante).position.floor() + Vector2(0, 32)
	for k: int in cantidad * 2:
		var gota: Sprite2D = _instanciar_plantilla(plantilla_gota) as Sprite2D
		var lado: float = -1.0 if k % 2 == 1 else 1.0
		gota.flip_h = lado < 0.0
		var v1: int = _azar.randi() & 0x1FF
		var v2: int = _azar.randi() & 0x7F
		var vx: int = 736 + v1 if v1 % 2 == 1 else 736 - v1
		var estado: Dictionary = {"vy": 896 + v2 if v2 % 2 == 1 else 896 - v2, "pos": Vector2.ZERO}
		var paso: Callable = func(i: int) -> void:
			if i > 0:
				estado.pos += Vector2(lado * (vx >> 8), -(estado.vy >> 8))
				estado.vy -= 32
			gota.position = origen + estado.pos
		_cada_frame(31, paso, gota.queue_free)


## Pista de método: impacto de agua (83DB4D8, afín 1 = 0xD8) en el defensor
## desplazado `y` y su par de burbujas (83D9360, sub_80D4044).
func lanzar_impacto(y: int) -> void:
	var impacto: Sprite2D = _instanciar_plantilla(plantilla_impacto) as Sprite2D
	var centro: Vector2 = marca_defensor.position.floor() + Vector2(0, y)
	impacto.position = centro
	impacto.scale = Vector2.ONE * 0xD8 / 256.0
	var tween_impacto: Tween = _crear_tween()
	tween_impacto.tween_interval(9 * FRAME)
	tween_impacto.tween_callback(impacto.queue_free)
	for k: int in 2:
		var burbuja: Sprite2D = _instanciar_plantilla(plantilla_burbuja) as Sprite2D
		var vx: int = (_azar.randi() & 0xFF) | 0x100
		var vy: int = _azar.randi() & 0x1FF
		if vy > 0xFF:
			vy = 0x100 - vy
		var estado: Dictionary = {"x": 0, "y": 0}
		var paso: Callable = func(i: int) -> void:
			if i > 0:
				estado.x += vx
				estado.y += vy
			var dx: int = estado.x >> 8
			burbuja.position = centro + Vector2(-dx if vx % 2 == 1 else dx, estado.y >> 8)
		_cada_frame(21, paso, burbuja.queue_free)
