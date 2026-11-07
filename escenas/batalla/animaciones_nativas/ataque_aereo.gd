extends EfectoMovimientoNativo
## Ataque Aéreo (Move_SKY_ATTACK). ataque_aereo.tscn tiene «carga» (_81CB5A0:
## fondo y atacante a negro 12/16, temblor y destello blanco del atacante) y
## «ataque» (_81CB68E: fadetobg 18 con scroll, el atacante se vuelve blanco y
## se desvanece, el pájaro cruza hacia el defensor y el atacante reaparece).
## Las pistas llevan fundidos, tintes y opacidad; aquí viven el temblor, el
## pájaro y el scroll del fondo.

## sub_80E3A58(-2304, 768, 1, -1): píxeles por frame del scroll del fondo con
## el atacante del jugador (se niega si ataca el rival).
@export var velocidad_fondo: Vector2 = Vector2(-9, 3)
## Frames de scroll transcurridos (pista lineal).
@export var frames_fondo: float = 0.0:
	set(valor):
		frames_fondo = valor
		if fondo != null:
			fondo.desplazamiento = (velocidad_fondo * floorf(valor) * direccion)

@onready var plantilla_pajaro: Sprite2D = $PlantillaPajaro


## Pista de método: sub_80E1864(0, 2, 16), temblor horizontal del atacante.
## Cada 2 frames: 16 veces +3/-2 y después 4 veces cada amplitud 4, 3, 2 y 1.
func temblar_atacante() -> void:
	var valores: Array[int] = []
	for u: int in 16:
		valores.append(3 if u % 2 == 0 else -2)
	for amplitud: int in [4, 3, 2, 1]:
		for u: int in 4:
			valores.append(amplitud / 2 + amplitud % 2 if u % 2 == 0 else -(amplitud / 2))
	var paso: Callable = func(i: int) -> void:
		if i >= 2 and i % 2 == 0:
			var u: int = i / 2 - 1
			_fijar_sacudida(&"atacante", Vector2(valores[u] if u < valores.size() else 0, 0))
	_cada_frame(valores.size() * 2 + 2, paso)


## Pista de método: el pájaro (gBattleAnimSpriteTemplate_83DA65C) sale del
## atacante hacia el defensor a 1/12 de la distancia por frame (punto fijo de
## 4 bits) hasta salir de la pantalla, girado en la dirección del vuelo.
func lanzar_pajaro() -> void:
	var pajaro: Sprite2D = _instanciar_plantilla(plantilla_pajaro) as Sprite2D
	var inicio: Vector2 = marca_atacante.position.floor()
	var destino: Vector2 = marca_defensor.position.floor()
	var paso_fijo: Vector2 = Vector2(int((destino.x - inicio.x) * 16.0) / 12, int((destino.y - inicio.y) * 16.0) / 12)
	pajaro.rotation = atan2(paso_fijo.y, paso_fijo.x) + PI / 2.0
	var limite: Rect2 = Rect2(-45.0, -45.0, tamano_campo.x + 90.0, tamano_campo.y + 42.0)
	var paso: Callable = func(i: int) -> void:
		pajaro.position = ((inicio * 16.0 + paso_fijo * i) / 16.0).floor()
		if not limite.has_point(pajaro.position):
			pajaro.visible = false
	_cada_frame(30, paso, pajaro.queue_free)


## Concurso: BG_FLYING_CONTESTS y sub_80E3A58(2304, 768, 0, -1); con la dirección del rival solo cambia la y.
func _al_configurar() -> void:
	if concurso:
		fondo.imagen.texture = load(RUTA_FONDO_VUELO_CONCURSO) as Texture2D
		velocidad_fondo.y = -velocidad_fondo.y
