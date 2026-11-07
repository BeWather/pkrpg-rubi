extends Node2D
class_name PantallaCondicionPokecubo

## Pantalla de condición para dar un POKéCUBO (pokeruby src/use_pokeblock.c, que
## reutiliza la vista de condición del POKéNAV de src/pokenav.c).
##
## Muestra el pentágono de condición (CARISMA, BELLEZA, DULZURA, INGENIO, DUREZA) del
## Pokémon elegido, su sprite y su nombre, y a la derecha una POKé BALL por Pokémon del
## equipo que no sea HUEVO (sub_81370A4) más SALIR. ARRIBA/ABAJO cambian de Pokémon, B
## o A en SALIR vuelven al estuche y A sobre un Pokémon pregunta «X recibe un
## POKéCUBO. ¿De acuerdo?». Con SÍ:
## - brillo 255 → «No comerá nada más...» (sub_8137058) y el cubo no se gasta;
## - si no, escena de comer (EscenaComerPokecubo), vuelta a esta pantalla, espera de
##   A/B, el pentágono crece hasta la condición nueva con «MÁS» sobre las que subieron
##   y un mensaje por condición («¡El carisma ha mejorado!»…) o «¡Nada ha cambiado!»;
##   tras el último, el cubo se borra del estuche (PokeblockClearIfExists) y se vuelve.
##
## Simplificado respecto a Rubí: sin destellos de brillo alrededor del Pokémon ni
## cambio animado de Pokémon (desplazamiento de la vista); el pentágono es un
## Polygon2D semitransparente en vez de la ventana por líneas de la GBA.

signal terminado

enum Modo { OCUPADO, LISTA, PREGUNTA, NO_COME, ESPERA_COMIDA, MENSAJES }

## sub_80F55AC: centro del pentágono y radio por valor (gUnknown_083E4890).
const CENTRO: Vector2i = Vector2i(0x9B, 0x5B)
const RADIOS: PackedByteArray = [
	4, 5, 6, 7, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 13,
	13, 14, 14, 14, 14, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 17,
	17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19,
	19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21,
	21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 23, 23, 23,
	23, 23, 23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24,
	24, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 26, 26, 26,
	26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27,
	27, 27, 27, 27, 27, 27, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28,
	28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29,
	29, 29, 29, 29, 29, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
	30, 30, 30, 30, 30, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31,
	31, 31, 31, 31, 31, 31, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
	32, 32, 32, 32, 32, 32, 32, 32, 33, 33, 33, 33, 33, 33, 33, 33,
	33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 34, 34, 34, 34, 34,
	34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 35,
]
## Claves de «¡X ha mejorado!» en el orden de ReglasCondicion.CONDICIONES.
const CLAVES_MEJORA: Array[String] = [
	"POKECUBOS_MEJORA_CARISMA", "POKECUBOS_MEJORA_DUREZA", "POKECUBOS_MEJORA_INGENIO",
	"POKECUBOS_MEJORA_DULZURA", "POKECUBOS_MEJORA_BELLEZA",
]
## gUnknown_08406158: centro del sprite «MÁS» de cada condición (mismo orden).
const POS_SUBIO: Array[Vector2] = [
	Vector2(0x9C, 0x1E), Vector2(0x75, 0x35), Vector2(0x75, 0x70), Vector2(0xC5, 0x70), Vector2(0xC5, 0x35),
]
## sub_80F33A8: POKé BALLS en (226, 20·i + 8) y SALIR en (222, 128).
const POS_BALL: Vector2 = Vector2(226, 8)
const PASO_BALL: float = 20.0
const MAX_EQUIPO: int = 6
## Fotogramas de la transformación del pentágono (sub_80F5504) y de espera antes del
## primer mensaje (sub_81369CC, caso 4).
const FOTOGRAMAS_MORPH: int = 10
const FOTOGRAMAS_ESPERA_MENSAJE: int = 17
## sub_81371DC: «MÁS» sube 2 px seis fotogramas, baja seis y desaparece a los 61.
const FOTOGRAMAS_SUBIO: int = 61
const FOTOGRAMA: float = 1.0 / 60.0
const RUTA_COMER: String = "res://UI/pokecubos/escena_comer_pokecubo.tscn"

@onready var poly_pentagono: Polygon2D = $Pentagono
@onready var spr_pokemon: PokemonSprite = $Pokemon
@onready var lb_nombre: Label = $Nombre
@onready var nd_balls: Node2D = $Balls
@onready var spr_salir: Sprite2D = $Salir
@onready var nd_subio: Node2D = $Subio
@onready var nd_ventana: NinePatchRect = $Ventana
@onready var lb_mensaje: Label = $Ventana/Texto
@onready var nd_si_no: NinePatchRect = $SiNo
@onready var nd_cursor_si_no: Control = $SiNo/Cursor

var estuche: EstuchePokecubos = null
var indice_cubo: int = -1
var cubo: Pokecubo = null
## Pokémon que se pueden elegir (equipo sin HUEVOS, en orden).
var candidatos: Array[BasePokemon] = []
## Índice en `candidatos`; == candidatos.size() en SALIR.
var seleccion: int = 0
var modo: Modo = Modo.OCUPADO
var indice_si_no: int = 0
## Resultado de la última comida y mensajes pendientes.
var resultado: ReglasCondicion.Resultado = null
var mensajes: Array[String] = []
## Escena de comer abierta (para pruebas).
var escena_comer: EscenaComerPokecubo = null


func _ready() -> void:
	nd_ventana.visible = false
	nd_si_no.visible = false
	for spr: Node in nd_subio.get_children():
		(spr as Sprite2D).visible = false


## Abre la pantalla para el cubo `indice` del estuche. Se llama con la pantalla
## oscurecida.
func abrir(estuche_cubos: EstuchePokecubos, indice: int, equipo: Array = []) -> void:
	estuche = estuche_cubos
	indice_cubo = indice
	cubo = estuche.obtener(indice)
	candidatos.clear()
	var miembros: Array = equipo if not equipo.is_empty() else SistemaGuardado.get_equipo()
	for miembro: Variant in miembros:
		var pokemon: BasePokemon = miembro as BasePokemon
		if pokemon != null and not pokemon.huevo:
			candidatos.append(pokemon)
	seleccion = 0
	_pintar()
	visible = true
	await Singleton.transicion("aclarar")
	modo = Modo.LISTA


func en_salir() -> bool:
	return seleccion >= candidatos.size()


func pokemon_actual() -> BasePokemon:
	return null if en_salir() else candidatos[seleccion]


# ─── Entrada ─────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	match modo:
		Modo.LISTA:
			if event.is_action_pressed("btn_arriba", true):
				mover_seleccion(-1)
			elif event.is_action_pressed("btn_abajo", true):
				mover_seleccion(1)
			elif event.is_action_pressed("btn_accion"):
				Singleton.play_sound.emit("SE_SELECT")
				if en_salir():
					salir()
				else:
					preguntar()
			elif event.is_action_pressed("btn_cancelar"):
				Singleton.play_sound.emit("SE_SELECT")
				salir()
			else:
				return
		Modo.PREGUNTA:
			if event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
				var nuevo: int = 1 - indice_si_no
				if nuevo != indice_si_no:
					indice_si_no = nuevo
					Singleton.play_sound.emit("SE_SELECT")
					_colocar_cursor_si_no()
			elif event.is_action_pressed("btn_accion"):
				Singleton.play_sound.emit("SE_SELECT")
				responder(indice_si_no == 0)
			elif event.is_action_pressed("btn_cancelar"):
				Singleton.play_sound.emit("SE_SELECT")
				responder(false)
			else:
				return
		Modo.NO_COME:
			if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
				_cerrar_ventana()
				modo = Modo.LISTA
			else:
				return
		Modo.ESPERA_COMIDA:
			if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
				mostrar_resultado()
			else:
				return
		Modo.MENSAJES:
			if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
				siguiente_mensaje()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()


# ─── Lista ───────────────────────────────────────────────────────────────────

## ARRIBA/ABAJO (sub_80F5060): pasa al Pokémon anterior/siguiente, con vuelta.
func mover_seleccion(direccion: int) -> void:
	var total: int = candidatos.size() + 1
	var nuevo: int = posmod(seleccion + direccion, total)
	if nuevo == seleccion:
		return
	seleccion = nuevo
	Singleton.play_sound.emit("SE_SELECT")
	_pintar()


## sub_8136BB8: «X recibe un POKéCUBO. ¿De acuerdo?» con SÍ/NO.
func preguntar() -> void:
	var pokemon: BasePokemon = pokemon_actual()
	if pokemon == null:
		return
	_mostrar_ventana(tr("POKECUBOS_DAR_PREGUNTA").replace("{pokemon}", pokemon.get_nombre_mostrar()))
	indice_si_no = 0
	nd_si_no.visible = true
	_colocar_cursor_si_no()
	modo = Modo.PREGUNTA


## SÍ/NO de la pregunta (sub_8136C40). Con SÍ y brillo 255, «No comerá nada más...».
func responder(si: bool) -> void:
	nd_si_no.visible = false
	_cerrar_ventana()
	if not si:
		modo = Modo.LISTA
		return
	var pokemon: BasePokemon = pokemon_actual()
	if not ReglasCondicion.puede_comer(pokemon):
		_mostrar_ventana(tr("POKECUBOS_NO_COME"))
		modo = Modo.NO_COME
		return
	dar_de_comer()


## sub_8136808 → CB2_PreparePokeblockFeedScene → sub_8136174: escena de comer y
## vuelta a esta pantalla esperando A/B.
func dar_de_comer() -> void:
	modo = Modo.OCUPADO
	var pokemon: BasePokemon = pokemon_actual()
	await Singleton.transicion("oscurecer")
	escena_comer = (load(RUTA_COMER) as PackedScene).instantiate() as EscenaComerPokecubo
	get_parent().add_child(escena_comer)
	visible = false
	await escena_comer.reproducir(pokemon, cubo)
	if is_instance_valid(escena_comer):
		escena_comer.queue_free()
	escena_comer = null
	visible = true
	await Singleton.transicion("aclarar")
	modo = Modo.ESPERA_COMIDA


## sub_81369CC casos 2-4: aplica el cubo, hace crecer el pentágono, muestra «MÁS»
## sobre las condiciones que subieron y el primer mensaje.
func mostrar_resultado() -> void:
	modo = Modo.OCUPADO
	var pokemon: BasePokemon = pokemon_actual()
	var antes: Array[int] = _condiciones(pokemon)
	resultado = ReglasCondicion.dar_de_comer(pokemon, cubo)
	mensajes.clear()
	for c in ReglasCondicion.CONDICIONES.size():
		if resultado.condiciones_subidas.has(ReglasCondicion.CONDICIONES[c]):
			mensajes.append(tr(CLAVES_MEJORA[c]))
			_animar_subio(c)
	if mensajes.is_empty():
		mensajes.append(tr("POKECUBOS_NADA_CAMBIO"))
	if is_inside_tree():
		await _animar_pentagono(antes, _condiciones(pokemon))
		await _esperar_fotogramas(FOTOGRAMAS_ESPERA_MENSAJE)
	else:
		_pintar_pentagono(_condiciones(pokemon))
	_mostrar_ventana(mensajes.pop_front())
	modo = Modo.MENSAJES


## sub_8136D00: siguiente «¡X ha mejorado!»; tras el último se gasta el cubo y se
## vuelve al estuche.
func siguiente_mensaje() -> void:
	if not mensajes.is_empty():
		_mostrar_ventana(mensajes.pop_front())
		return
	modo = Modo.OCUPADO
	if resultado != null and resultado.comio:
		estuche.quitar(indice_cubo)
	salir()


## sub_8136B44: fundido a negro y vuelta al estuche.
func salir() -> void:
	modo = Modo.OCUPADO
	await Singleton.transicion("oscurecer")
	visible = false
	terminado.emit()


# ─── Dibujo ──────────────────────────────────────────────────────────────────

func _pintar() -> void:
	var pokemon: BasePokemon = pokemon_actual()
	spr_pokemon.visible = pokemon != null
	if pokemon != null:
		PokemonSprite.configurar_desde_pokemon(spr_pokemon, pokemon)
		lb_nombre.text = "%s/Nv%d" % [pokemon.get_nombre_mostrar(), pokemon.nivel]
		_pintar_pentagono(_condiciones(pokemon))
	else:
		lb_nombre.text = ""
		_pintar_pentagono([0, 0, 0, 0, 0])
	poly_pentagono.visible = pokemon != null
	for i in MAX_EQUIPO:
		var ball: Sprite2D = nd_balls.get_node("Ball%d" % i) as Sprite2D
		ball.visible = i < candidatos.size()
		# La elegida se ve en color y adelantada; el resto, apagadas.
		ball.frame = 0 if i == seleccion else 1
		ball.position = POS_BALL + Vector2(-4 if i == seleccion else 0, PASO_BALL * i)
	spr_salir.position = Vector2(222, 128) + Vector2(-4 if en_salir() else 0, 0)
	spr_salir.modulate = Color.WHITE if en_salir() else Color(1, 1, 1, 0.6)


func _condiciones(pokemon: BasePokemon) -> Array[int]:
	var valores: Array[int] = []
	for campo: StringName in ReglasCondicion.CONDICIONES:
		valores.append(int(pokemon.get(campo)) if pokemon != null else 0)
	return valores


## sub_80F55AC: vértices del pentágono (CARISMA arriba, DUREZA arriba a la izquierda,
## INGENIO abajo a la izquierda, DULZURA abajo a la derecha, BELLEZA arriba a la
## derecha) con el radio de gUnknown_083E4890 para cada condición.
static func vertices_pentagono(condiciones: Array) -> PackedVector2Array:
	var puntos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var r: int = RADIOS[clampi(int(condiciones[0]), 0, 255)]
	puntos[0] = Vector2(CENTRO.x, CENTRO.y - r)
	var angulo: int = 0x40
	var hueco: int = 0
	for i in range(1, 5):
		angulo += 0x33
		hueco -= 1
		if hueco < 0:
			hueco = 4
		if hueco == 2:
			angulo += 1
		angulo &= 0xFF
		r = RADIOS[clampi(int(condiciones[i]), 0, 255)]
		var x: int = ((r * _tabla_seno(angulo + 0x40)) >> 8) + CENTRO.x
		var y: int = CENTRO.y - ((r * _tabla_seno(angulo)) >> 8)
		if hueco <= 2 and (r != 0x20 or hueco != 2):
			x = ((r * _tabla_seno(angulo + 0x40)) >> 8) + CENTRO.x + 1
		puntos[hueco] = Vector2(x, y)
	# Hueco 0 CARISMA, 4 DUREZA, 3 INGENIO, 2 DULZURA, 1 BELLEZA. Se devuelven en el
	# orden de ReglasCondicion.CONDICIONES, que recorre el pentágono en un solo sentido.
	return PackedVector2Array([puntos[0], puntos[4], puntos[3], puntos[2], puntos[1]])


static func _tabla_seno(indice: int) -> int:
	return int(roundf(256.0 * sin(TAU * float(indice & 0xFF) / 256.0)))


func _pintar_pentagono(condiciones: Array) -> void:
	poly_pentagono.polygon = vertices_pentagono(condiciones)


## sub_80F5550 / sub_80F555C: interpolación de los vértices hasta la condición nueva.
func _animar_pentagono(antes: Array[int], despues: Array[int]) -> void:
	var desde: PackedVector2Array = vertices_pentagono(antes)
	var hasta: PackedVector2Array = vertices_pentagono(despues)
	for f in range(1, FOTOGRAMAS_MORPH + 1):
		var t: float = float(f) / FOTOGRAMAS_MORPH
		var puntos := PackedVector2Array()
		for k in desde.size():
			puntos.append(desde[k].lerp(hasta[k], t).round())
		poly_pentagono.polygon = puntos
		await _esperar_fotogramas(1)


## sub_8137138 / sub_81371DC: «MÁS» sobre la condición `c`.
func _animar_subio(c: int) -> void:
	var spr: Sprite2D = nd_subio.get_child(c) as Sprite2D
	spr.position = POS_SUBIO[c]
	spr.visible = true
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(spr, "position:y", POS_SUBIO[c].y - 12, 6 * FOTOGRAMA)
	tween.tween_property(spr, "position:y", POS_SUBIO[c].y, 6 * FOTOGRAMA)
	tween.tween_interval((FOTOGRAMAS_SUBIO - 12) * FOTOGRAMA)
	tween.tween_callback(spr.hide)


func _mostrar_ventana(texto: String) -> void:
	lb_mensaje.text = FormateadorLigaduras.formatear(texto)
	nd_ventana.visible = true


func _cerrar_ventana() -> void:
	nd_ventana.visible = false
	lb_mensaje.text = ""


func _colocar_cursor_si_no() -> void:
	nd_cursor_si_no.position = Vector2(7, 7 + 16 * indice_si_no)


func _esperar_fotogramas(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
