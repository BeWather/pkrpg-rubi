extends Node2D
class_name EscenaComerPokecubo

## Escena de dar de comer un POKéCUBO (pokeruby src/pokeblock_feed.c).
##
## Secuencia (sub_8147CC8, a 60 fotogramas por segundo):
## 1. El Pokémon hace la animación de su naturaleza (sNatureToMonPokeblockAnim /
##    sMonPokeblockAnims: desplazamientos con senos y cosenos más, en algunas, un giro).
## 2. El TUBO (girado hacia el Pokémon) se inclina (sSpriteAffineAnim_8412148).
## 3. 14 fotogramas después sale el cubo en parábola hacia el Pokémon
##    (SpriteCB_ThrownPokeblock) y, 12 más tarde, el Pokémon salta hacia él
##    (sub_8148078) con su grito en lo alto del salto.
## 4. 16 fotogramas después, «X se comió un Y (con ganas / sin ganas).» según la
##    ganancia de la naturaleza (Task_PrintAtePokeblockText); con A se oscurece.
##
## No toca el Pokémon ni el estuche: solo es la animación. `reproducir()` se llama
## con la pantalla oscurecida y termina con la pantalla oscurecida otra vez.

signal terminada

const FOTOGRAMA: float = 1.0 / 60.0
## PokeblockFeed_CreatePokeSprite / sub_81480B4 / CreatePokeblockSprite.
const POS_POKEMON: Vector2 = Vector2(48, 80)
const POS_TUBO: Vector2 = Vector2(188, 100)
const POS_CUBO: Vector2 = Vector2(174, 84)
## Fotogramas tras el fin de la animación de naturaleza (casos 255, 269, 281 y 297
## de sub_8147CC8, contados desde 255).
const ESPERA_TUBO: int = 1
const ESPERA_CUBO: int = 14
const ESPERA_SALTO: int = 12
const ESPERA_TEXTO: int = 16
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"

## Primera fila de sMonPokeblockAnims y animación afín de cada naturaleza (orden
## canónico 0-24, sNatureToMonPokeblockAnim).
const ANIM_NATURALEZA: Array = [
	[0, 0], [3, 0], [4, 1], [5, 0], [10, 0], [13, 0], [15, 0], [16, 2], [18, 0], [19, 0],
	[20, 0], [25, 0], [27, 3], [28, 0], [29, 0], [33, 4], [36, 0], [37, 0], [39, 0], [42, 0],
	[45, 0], [46, 5], [47, 6], [48, 0], [53, 0],
]
## sMonPokeblockAnims: [ángulo, paso, amp_sen, amp_cos, duración, Δamp, destino_x,
## destino_y, inicio_suavizado, fin].
const ANIMS: Array = [
	[0, 4, 0, 8, 24, 0, 0, 0, 12, 0], [0, 4, 0, 16, 24, 0, 0, 0, 12, 0], [0, 4, 0, 32, 32, 0, 0, 0, 16, 1],
	[0, 3, 6, 0, 48, 0, 0, 0, 24, 1],
	[64, 16, -24, 0, 32, 0, 0, 0, 0, 1],
	[0, 4, 8, 0, 16, 0, -8, 0, 0, 0], [0, 0, 0, 0, 16, 0, 0, 0, 0, 0], [0, 4, 8, 0, 16, 0, -8, 0, 0, 0],
	[0, 0, 0, 0, 16, 0, 0, 0, 0, 0], [0, 4, -16, 0, 4, 0, 16, 0, 0, 1],
	[0, 3, 6, 0, 12, 0, 0, 0, 6, 0], [0, 3, -6, 0, 12, 0, 0, 0, 6, 0], [0, 16, 16, 0, 45, 1, 0, 0, 0, 1],
	[0, 16, 0, 24, 32, 0, 0, 0, 16, 0], [0, 16, 0, 23, 32, 0, 0, 0, 16, 1],
	[0, 0, 0, 0, 80, 0, 0, 0, 0, 1],
	[0, 2, 8, 0, 32, 0, 0, 0, 0, 0], [0, 2, -8, 0, 32, 0, 0, 0, 0, 1],
	[0, 32, 2, 1, 48, 1, 0, 0, 24, 1],
	[0, 2, 16, 16, 128, 0, 0, 0, 0, 1],
	[0, 2, -8, 0, 48, 0, -24, 0, 0, 0], [0, 0, 0, 0, 8, 0, 0, 0, 0, 0], [64, 32, 2, 0, 36, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 8, 0, 0, 0, 0, 0], [0, 2, 8, 0, 48, 0, 24, 0, 0, 1],
	[64, 24, 16, 0, 32, 0, 0, 0, 0, 0], [0, 28, 2, 1, 32, 1, 0, 0, 16, 1],
	[0, 0, 0, 0, 32, 0, 0, 0, 0, 1],
	[64, 16, -16, 2, 48, 0, 0, 0, 32, 1],
	[0, 12, -8, 4, 24, 0, 8, 0, 12, 0], [0, 12, 8, 8, 24, 0, -16, 0, 12, 0],
	[0, 12, -8, 16, 24, 0, 16, 0, 12, 0], [0, 12, 8, 28, 24, 0, -8, 0, 12, 1],
	[0, 0, 0, 0, 8, 0, 0, 0, 0, 0], [64, 16, -4, 0, 32, 0, 0, 0, 0, 0], [0, 0, 0, 0, 8, 0, 0, 0, 0, 1],
	[128, 4, 0, 8, 64, 0, 0, 0, 0, 1],
	[0, 2, 16, 0, 48, 0, 0, 0, 0, 0], [128, 2, 16, 0, 48, 0, 0, 0, 0, 1],
	[0, 2, -4, 0, 48, 0, -48, 0, 0, 0], [0, 0, 0, 0, 80, 0, 0, 0, 0, 0], [0, 2, 8, 0, 24, 0, 48, 0, 0, 1],
	[64, 4, 64, 58, 52, 0, -88, 0, 0, 0], [0, 0, 0, 0, 80, 0, 0, 0, 0, 0], [0, 24, 80, 0, 32, 0, 88, 0, 0, 1],
	[0, 2, 16, 4, 64, 0, 0, 0, 0, 1],
	[0, 0, 0, 0, 32, 0, 0, 0, 0, 1],
	[0, 0, 0, 0, 42, 0, 0, 0, 0, 1],
	[0, 4, 0, 8, 24, 0, 0, 0, 12, 0], [0, 0, 0, 0, 12, 0, 0, 0, 0, 0], [0, 4, 0, 12, 24, 0, 0, 0, 12, 0],
	[0, 0, 0, 0, 12, 0, 0, 0, 0, 0], [0, 4, 0, 4, 24, 0, 0, 0, 12, 1],
	[0, 4, 16, 12, 64, 0, 0, 0, 0, 0], [0, -4, 16, 12, 64, 0, 0, 0, 0, 1],
]
## sSpriteAffineAnimTable_8412050[1..6]: giros del Pokémon como pares
## (unidades por fotograma con 256 = vuelta, fotogramas).
const GIROS: Array = [
	[],
	[[12, 1], [0, 30], [-12, 1]],
	[[1, 16], [-1, 32], [1, 16]],
	[[-1, 8], [0, 16], [1, 8]],
	[[-1, 8], [0, 32], [1, 8]],
	[[-1, 4], [0, 24], [1, 4]],
	[[1, 24], [0, 16], [-12, 2]],
]
## sSpriteAffineAnim_8412148 (el TUBO, ya volteado): +8·4, pausa 8, −16·3 y vuelta a 0.
const GIRO_TUBO: Array = [[8, 4], [0, 8], [-16, 3]]

@onready var spr_pokemon: PokemonSprite = $Pokemon
@onready var spr_tubo: Sprite2D = $Tubo
@onready var spr_cubo: Sprite2D = $Cubo
@onready var nd_ventana: NinePatchRect = $Ventana
@onready var lb_texto: Label = $Ventana/Texto

var pokemon: BasePokemon = null
var cubo: Pokecubo = null
## Texto mostrado al final (para pruebas).
var texto_final: String = ""
var _esperando_tecla: bool = false
var _reproductor_grito: AudioStreamPlayer = null


func _ready() -> void:
	spr_cubo.visible = false
	lb_texto.text = ""


## Reproduce la escena entera para `pokemon_comedor` y `cubo_dado`.
func reproducir(pokemon_comedor: BasePokemon, cubo_dado: Pokecubo) -> void:
	preparar(pokemon_comedor, cubo_dado)
	await Singleton.transicion("aclarar")
	await _animar_naturaleza()
	await _esperar_fotogramas(ESPERA_TUBO)
	_animar_tubo()
	await _esperar_fotogramas(ESPERA_CUBO)
	_lanzar_cubo()
	await _esperar_fotogramas(ESPERA_SALTO)
	_saltar_pokemon()
	await _esperar_fotogramas(ESPERA_TEXTO)
	await _mostrar_texto()
	await Singleton.transicion("oscurecer")
	terminada.emit()


## Coloca el Pokémon, el TUBO y el cubo, y prepara el texto final.
func preparar(pokemon_comedor: BasePokemon, cubo_dado: Pokecubo) -> void:
	pokemon = pokemon_comedor
	cubo = cubo_dado
	PokemonSprite.configurar_desde_pokemon(spr_pokemon, pokemon)
	# PokeblockFeed_CreatePokeSprite: casi todas las especies se muestran volteadas
	# (mirando al TUBO); el proyecto no guarda el `noFlip` de gBaseStats.
	spr_pokemon.flip_h = true
	spr_pokemon.position = POS_POKEMON
	spr_pokemon.rotation = 0.0
	spr_tubo.position = POS_TUBO
	spr_tubo.rotation = 0.0
	spr_cubo.frame = clampi(cubo.color - 1, 0, spr_cubo.hframes - 1)
	texto_final = texto_comio(pokemon, cubo)
	lb_texto.text = ""


## gContestStatsText_NormallyAte / HappilyAte / DisdainfullyAte según PokeblockGetGain.
static func texto_comio(pokemon_comedor: BasePokemon, cubo_dado: Pokecubo) -> String:
	var ganancia: int = ReglasCondicion.ganancia(ReglasCondicion.indice_naturaleza(pokemon_comedor), cubo_dado)
	var clave: String = "POKECUBOS_COMIO"
	if ganancia > 0:
		clave = "POKECUBOS_COMIO_CON_GANAS"
	elif ganancia < 0:
		clave = "POKECUBOS_COMIO_SIN_GANAS"
	return TranslationServer.translate(clave) \
		.replace("{pokemon}", pokemon_comedor.get_nombre_mostrar()) \
		.replace("{pokecubo}", TranslationServer.translate(cubo_dado.clave_nombre()))


## Desplazamientos (x2, y2) fotograma a fotograma de la animación de la naturaleza
## `indice_nat` (sub_8148540 + sub_8148710 + sub_814862C + sub_81485CC).
static func trayectoria_naturaleza(indice_nat: int) -> Array[Vector2i]:
	var puntos: Array[Vector2i] = []
	var fila_anim: int = int(ANIM_NATURALEZA[clampi(indice_nat, 0, 24)][0])
	var actual := Vector2i.ZERO
	for _i in 8:
		var fa: Array = (ANIMS[fila_anim] as Array).duplicate()
		var duracion: int = int(fa[4])
		var xs: Array[int] = []
		var ys: Array[int] = []
		xs.resize(duracion)
		ys.resize(duracion)
		var base_x: int = actual.x - _seno(int(fa[0]), int(fa[2]))
		var base_y: int = actual.y - _coseno(int(fa[0]), int(fa[3]))
		var invertido: bool = false
		var angulo: int = int(fa[0])
		var amp_cos: int = int(fa[3])
		for k in duracion:
			var r5: int = (absi(int(fa[5])) + amp_cos) & 0xFFFF
			amp_cos = r5
			if int(fa[2]) < 0:
				invertido = true
			var extra: int = r5 / 256
			if invertido:
				xs[k] = _seno(angulo, int(fa[2]) - extra) + base_x
				ys[k] = _coseno(angulo, amp_cos - extra) + base_y
			else:
				xs[k] = _seno(angulo, int(fa[2]) + extra) + base_x
				ys[k] = _coseno(angulo, amp_cos + extra) + base_y
			angulo = (angulo + int(fa[1])) & 0xFF
		# sub_814862C: los últimos fotogramas convergen hacia el destino.
		var inicio: int = int(fa[8])
		var tramo: int = duracion - inicio
		var destino := Vector2i(actual.x + int(fa[6]), actual.y + int(fa[7]))
		if tramo > 0:
			for i in tramo - 1:
				var dx: int = xs[inicio + i] - destino.x
				var dy: int = ys[inicio + i] - destino.y
				xs[inicio + i] -= _div_c(dx * (i + 1), tramo)
				ys[inicio + i] -= _div_c(dy * (i + 1), tramo)
			xs[inicio + tramo - 1] = destino.x
			ys[inicio + tramo - 1] = destino.y
		for k in duracion:
			puntos.append(Vector2i(xs[k], ys[k]))
		if duracion > 0:
			actual = puntos[puntos.size() - 1]
		if int(fa[9]) == 1:
			break
		fila_anim += 1
	return puntos


static func _seno(angulo: int, amplitud: int) -> int:
	return (_tabla_seno(angulo) * amplitud) >> 8


static func _coseno(angulo: int, amplitud: int) -> int:
	return (_tabla_seno(angulo + 64) * amplitud) >> 8


## gSineTable: seno en Q8 de 256 pasos por vuelta.
static func _tabla_seno(indice: int) -> int:
	return int(roundf(256.0 * sin(TAU * float(indice & 0xFF) / 256.0)))


## División entera de C (trunca hacia cero).
static func _div_c(a: int, b: int) -> int:
	var q: int = absi(a) / absi(b)
	return q if (a >= 0) == (b >= 0) else -q


# ─── Pasos ───────────────────────────────────────────────────────────────────

func _animar_naturaleza() -> void:
	var indice_nat: int = ReglasCondicion.indice_naturaleza(pokemon)
	var giro: int = int(ANIM_NATURALEZA[indice_nat][1])
	if giro > 0:
		_girar(spr_pokemon, GIROS[giro], -1.0 if spr_pokemon.flip_h else 1.0)
	# sub_814825C: un fotograma de preparación y otro de arranque antes del primero.
	await _esperar_fotogramas(2)
	for punto: Vector2i in trayectoria_naturaleza(indice_nat):
		spr_pokemon.position = POS_POKEMON + Vector2(punto)
		await _esperar_fotogramas(1)


func _animar_tubo() -> void:
	var tween: Tween = _girar(spr_tubo, GIRO_TUBO, -1.0)
	tween.tween_property(spr_tubo, "rotation", 0.0, 0.0)


## Lanza el cubo (SpriteCB_ThrownPokeblock): x −4 y y + d con d de −12 a 9.
func _lanzar_cubo() -> void:
	spr_cubo.position = POS_CUBO
	spr_cubo.visible = true
	var d: int = -12
	while d != 10:
		await _esperar_fotogramas(1)
		spr_cubo.position += Vector2(-4, d)
		d += 1
	spr_cubo.visible = false


## sub_8148044 / sub_8148078: el Pokémon salta hacia el cubo (x +4, y + d con d de
## −8 a 8) y grita cuando d llega a 0.
func _saltar_pokemon() -> void:
	spr_pokemon.position = POS_POKEMON
	var d: int = -8
	while d != 9:
		await _esperar_fotogramas(1)
		spr_pokemon.position += Vector2(4, d)
		d += 1
		if d == 0:
			_reproducir_grito()


func _mostrar_texto() -> void:
	lb_texto.text = texto_final
	lb_texto.visible_characters = 0
	var total: int = lb_texto.get_total_character_count()
	while lb_texto.visible_characters < total:
		await _esperar_fotogramas(1)
		lb_texto.visible_characters += 1
	lb_texto.visible_characters = -1
	# PAUSE_UNTIL_PRESS.
	_esperando_tecla = true
	while _esperando_tecla:
		await get_tree().process_frame


func _input(event: InputEvent) -> void:
	if not _esperando_tecla:
		return
	if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
		_esperando_tecla = false
		get_viewport().set_input_as_handled()


## Giro afín: pares (Δ por fotograma en 1/256 de vuelta, fotogramas). `signo` −1
## convierte el sentido antihorario de la GBA al horario de Godot.
func _girar(nodo: Node2D, pasos: Array, signo: float) -> Tween:
	var tween := create_tween()
	var angulo: float = nodo.rotation
	for paso: Array in pasos:
		angulo += signo * float(int(paso[0]) * int(paso[1])) * TAU / 256.0
		tween.tween_property(nodo, "rotation", angulo, int(paso[1]) * FOTOGRAMA)
	return tween


func _reproducir_grito() -> void:
	if pokemon == null or pokemon.numero_nacional <= 0:
		return
	var ruta: String = RUTA_GRITO % pokemon.numero_nacional
	if not ResourceLoader.exists(ruta):
		return
	if not is_instance_valid(_reproductor_grito):
		_reproductor_grito = AudioStreamPlayer.new()
		add_child(_reproductor_grito)
	_reproductor_grito.stream = load(ruta) as AudioStream
	_reproductor_grito.play()


func _esperar_fotogramas(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
