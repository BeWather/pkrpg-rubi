extends Node2D
class_name VistaCondicionPokenav

## Vista de condición del POKéNAV: pentágono, sprite, nombre y POKé BALLS del equipo.
## ARRIBA/ABAJO cambian de Pokémon; B sale; A sale desde SALIR. Pentágono y
## constantes compartidos con PantallaCondicionPokecubo.

signal cerrada

const POS_SALIR: Vector2 = Vector2(222, 128)
const MAX_DESTELLOS: int = 10

@onready var pentagono: Polygon2D = $Pentagono
@onready var spr_pokemon: PokemonSprite = $Panel/Pokemon
@onready var lb_nombre: Label = $Nombre
@onready var lb_lugar: Label = $Lugar
@onready var lb_naturaleza: Label = $Panel/Naturaleza
@onready var balls: Node2D = $Balls
@onready var spr_salir: Sprite2D = $Salir
@onready var destellos: Node2D = $Panel/Destellos
@onready var anim: AnimationPlayer = $Anim

var candidatos: Array[Dictionary] = []
var seleccion: int = 0
var modo_busqueda: bool = false
var activa: bool = false


func abrir(p_candidatos: Array[Dictionary], p_seleccion: int, p_busqueda: bool) -> void:
	candidatos = p_candidatos
	seleccion = p_seleccion
	modo_busqueda = p_busqueda
	_pintar()
	anim.play(&"panel_entrada")
	await anim.animation_finished
	activa = true


func en_salir() -> bool:
	return seleccion >= candidatos.size()


func _total() -> int:
	return candidatos.size() if modo_busqueda else candidatos.size() + 1


func _input(event: InputEvent) -> void:
	if not activa or not visible or not is_inside_tree():
		return
	if event.is_action_pressed("btn_arriba", true):
		mover(-1)
	elif event.is_action_pressed("btn_abajo", true):
		mover(1)
	elif event.is_action_pressed("btn_cancelar") or (event.is_action_pressed("btn_accion") and en_salir()):
		Singleton.play_sound.emit("SE_SELECT")
		salir()
	else:
		return
	get_viewport().set_input_as_handled()


func mover(direccion: int) -> void:
	var nuevo: int = posmod(seleccion + direccion, _total())
	if nuevo == seleccion:
		return
	seleccion = nuevo
	Singleton.play_sound.emit("SE_SELECT")
	_pintar()


func salir() -> void:
	activa = false
	anim.play(&"panel_salida")
	await anim.animation_finished
	cerrada.emit()


func _pintar() -> void:
	var pokemon: BasePokemon = null if en_salir() else candidatos[seleccion]["pokemon"]
	spr_pokemon.visible = pokemon != null
	pentagono.visible = pokemon != null
	lb_nombre.text = ""
	lb_lugar.text = ""
	lb_naturaleza.text = ""
	if pokemon != null:
		PokemonSprite.configurar_desde_pokemon(spr_pokemon, pokemon)
		lb_nombre.text = "%s/Nv%d" % [pokemon.get_nombre_mostrar(), pokemon.nivel]
		var valores: Array = []
		for campo: StringName in ReglasCondicion.CONDICIONES:
			valores.append(int(pokemon.get(campo)))
		pentagono.polygon = PantallaCondicionPokecubo.vertices_pentagono(valores)
		if modo_busqueda:
			var caja: int = int(candidatos[seleccion]["caja"])
			lb_lugar.text = tr("POKENAV_EQUIPO") if caja < 0 else tr("POKENAV_CAJA").replace("{n}", str(caja + 1))
		elif not pokemon.naturaleza.is_empty():
			lb_naturaleza.text = tr("POKENAV_NATURALEZA").replace("{naturaleza}", pokemon.naturaleza)
	_pintar_destellos(pokemon)
	_pintar_balls()


## sub_80F3D00 (var1 + 1 sprites): brillo 255 → 10 destellos; si no, brillo / 29 + 1.
static func cuantos_destellos(brillo: int) -> int:
	return 10 if brillo >= 255 else brillo / 29 + 1


func _pintar_destellos(pokemon: BasePokemon) -> void:
	var cuantos: int = 0 if pokemon == null else cuantos_destellos(pokemon.brillo)
	for i in MAX_DESTELLOS:
		(destellos.get_child(i) as CanvasItem).visible = i < cuantos


func _pintar_balls() -> void:
	balls.visible = not modo_busqueda
	spr_salir.visible = not modo_busqueda
	if modo_busqueda:
		return
	for i in balls.get_child_count():
		var ball: Sprite2D = balls.get_child(i) as Sprite2D
		ball.visible = i < candidatos.size()
		ball.frame = 0 if i == seleccion else 1
		ball.position = PantallaCondicionPokecubo.POS_BALL + Vector2(-4 if i == seleccion else 0, PantallaCondicionPokecubo.PASO_BALL * i)
	spr_salir.position = POS_SALIR + Vector2(-4 if en_salir() else 0, 0)
	spr_salir.modulate = Color.WHITE if en_salir() else Color(1, 1, 1, 0.6)
