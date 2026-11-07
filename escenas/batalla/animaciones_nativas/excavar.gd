extends EfectoMovimientoNativo
## Excavar (Move_DIG). excavar.tscn tiene «carga» (_81CB0AB) y «ataque» (_81CB106).
## El original copia el battler a una capa de fondo (monbg_22) y lo hunde con
## una ventana de scanline que borra las líneas por debajo de su base + 32.
## Aquí se mueve el propio sprite y el shader del material temporal lo recorta
## por debajo de esa línea (recortar_atacante()).
## Carga (sub_80E1244(0)): se hunde con un vaivén (data5 = paso + seno >> 4)
## hasta 64 px y queda oculto; montículo de tierra (gDigDirtMoundSpriteTemplate,
## 180 frames) y cinco tandas de cuatro terrones (gDirtPlumeSpriteTemplate,
## AnimFissureDirtPlumeParticle) en arco.
## Ataque (sub_80E149C): vuelve a verse 96 px más abajo y sube 8 px por frame
## hasta su sitio; después, el golpe en el defensor.

@onready var plantilla_monticulo: Sprite2D = $PlantillaMonticulo
@onready var plantilla_terron: Sprite2D = $PlantillaTerron

## Base del atacante (sub_8077FC0, coordenada 1 del original).
func _base_y() -> float:
	return floorf(marca_atacante_base.position.y)


## Pista de método: el montículo (las dos mitades) bajo el atacante.
func poner_monticulo(frames: int) -> void:
	for mitad: int in 2:
		var monticulo: Sprite2D = _instanciar_plantilla(plantilla_monticulo) as Sprite2D
		monticulo.region_rect = Rect2(0, 16 * mitad, 32, 16)
		monticulo.position = Vector2(floorf(marca_atacante_base.position.x) - 16.0 + 32.0 * mitad, _base_y() + 32.0)
		var tween: Tween = _crear_tween()
		tween.tween_interval(frames * FRAME)
		tween.tween_callback(monticulo.queue_free)


## Pista de método: hundir al atacante (sub_80E1284). Al terminar queda oculto.
func hundir_atacante() -> void:
	recortar_atacante(_base_y() + 32.0)
	var estado: Dictionary = {"angulo": 0, "lento": 0, "paso": 0, "fin": false}
	var avanzar: Callable = func(i: int) -> void:
		if estado.fin or i == 0:
			return
		estado.angulo = (estado.angulo + 6) & 0x7F
		estado.lento += 1
		if estado.lento > 2:
			estado.lento = 0
			estado.paso += 1
		var bajada: int = estado.paso + (roundi(sin(TAU * estado.angulo / 256.0) * 256.0) >> 4)
		if bajada > 63:
			estado.fin = true
			fijar_visible_atacante(false)
			desplazamiento_atacante = Vector2.ZERO
			recortar_atacante(INF)
			return
		desplazamiento_atacante = Vector2(0.0, bajada)
	_cada_frame(200, avanzar)


## Pista de método: el atacante sale de debajo. sub_80E14DC lo deja visible
## pero fuera de la pantalla; tras `espera` frames sub_80E1560 lo pone 96 px
## más abajo, recortado por su base + 32, y lo sube 8 px por frame.
func emerger_atacante(espera: int) -> void:
	recortar_atacante(_base_y() + 32.0)
	desplazamiento_atacante = Vector2(0.0, 160.0)
	fijar_visible_atacante(true)
	var subir: Callable = func(i: int) -> void:
		if i < espera:
			return
		desplazamiento_atacante = Vector2(0.0, maxf(96.0 - 8.0 * (i - espera), 0.0))
		if i - espera >= 12:
			recortar_atacante(INF)
	_cada_frame(espera + 12, subir)


## Pista de método: cuatro terrones de una tanda (args de _81CB16A:
## lado, x, y, amplitud del arco, 18 frames).
func lanzar_terrones() -> void:
	for args: Array in [[0, 12, 4, -16], [0, 16, 4, -10], [1, 14, 4, -18], [1, 12, 4, -16]]:
		var terron: Sprite2D = _instanciar_plantilla(plantilla_terron) as Sprite2D
		var lado: float = -1.0 if int(args[0]) == 1 else 1.0
		var inicio: Vector2 = Vector2(floorf(marca_atacante_base.position.x) + 24.0 * lado, _base_y() + 30.0)
		var final: Vector2 = inicio + Vector2(float(args[1]) * lado, float(args[2]))
		var amplitud: float = float(args[3])
		var paso: Callable = func(i: int) -> void:
			var t: float = float(i) / 18.0
			var arco: float = floorf(roundf(sin(PI * t) * 256.0) * amplitud / 256.0)
			terron.position = inicio.lerp(final, t).floor() + Vector2(0.0, arco)
		_cada_frame(18, paso, terron.queue_free)
