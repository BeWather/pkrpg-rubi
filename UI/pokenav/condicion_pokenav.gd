extends Node2D
class_name CondicionPokenav

## Submenú CONDICIÓN del POKéNAV: EQUIPO / BUSCAR / SALIR y búsqueda por rasgo
## (CARISMA, BELLEZA, DULZURA, INGENIO, DUREZA, SALIR). La búsqueda ordena por el
## rasgo todos los Pokémon de equipo y cajas y abre la lista.

signal cerrado

enum Estado { OCUPADO, MENU, BUSQUEDA, LISTA, VISTA }

const CLAVES_MENU: Array[String] = ["POKENAV_DESC_EQUIPO", "POKENAV_DESC_BUSCAR", "POKENAV_DESC_VOLVER"]
const CLAVES_BUSQUEDA: Array[String] = [
	"POKENAV_DESC_BUSCA_CARISMA", "POKENAV_DESC_BUSCA_BELLEZA", "POKENAV_DESC_BUSCA_DULZURA",
	"POKENAV_DESC_BUSCA_INGENIO", "POKENAV_DESC_BUSCA_DUREZA", "POKENAV_DESC_VOLVER",
]
const RASGOS: Array[StringName] = [&"carisma", &"belleza", &"dulzura", &"ingenio", &"dureza"]

@onready var superficie: Node2D = $Superficie
@onready var anim_fondo: AnimationPlayer = $Superficie/Fondo/Anim
@onready var botones_menu: ListaBotonesPokenav = $Superficie/BotonesMenu
@onready var botones_busqueda: ListaBotonesPokenav = $Superficie/BotonesBusqueda
@onready var lista: ListaPokenav = $Superficie/Lista
@onready var lb_descripcion: Label = $Superficie/Descripcion
@onready var caja: Sprite2D = $Superficie/CajaDescripcion
@onready var vista: VistaCondicionPokenav = $Vista
@onready var anim: AnimationPlayer = $Anim

var estado: Estado = Estado.OCUPADO
## Resultado de la búsqueda actual: [{pokemon, caja}].
var resultados: Array[Dictionary] = []


func _ready() -> void:
	botones_menu.seleccion_cambiada.connect(func(i: int) -> void: lb_descripcion.text = tr(CLAVES_MENU[i]))
	botones_busqueda.seleccion_cambiada.connect(func(i: int) -> void: lb_descripcion.text = tr(CLAVES_BUSQUEDA[i]))
	lista.elegida.connect(_on_lista_elegida)
	lista.cancelada.connect(_on_lista_cancelada)
	vista.cerrada.connect(_on_vista_cerrada)
	vista.visible = false
	lista.visible = false
	lb_descripcion.text = ""


func abrir() -> void:
	anim_fondo.play(&"a_lavanda")
	anim.play(&"entrada")
	await anim.animation_finished
	Singleton.play_sound.emit("SE_WIN_OPEN")
	await botones_menu.entrar()
	estado = Estado.MENU


func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	var botones: ListaBotonesPokenav = null
	if estado == Estado.MENU:
		botones = botones_menu
	elif estado == Estado.BUSQUEDA:
		botones = botones_busqueda
	if botones == null:
		return
	if event.is_action_pressed("btn_arriba", true):
		if botones.mover(-1):
			Singleton.play_sound.emit("SE_SELECT")
	elif event.is_action_pressed("btn_abajo", true):
		if botones.mover(1):
			Singleton.play_sound.emit("SE_SELECT")
	elif event.is_action_pressed("btn_accion"):
		Singleton.play_sound.emit("SE_SELECT")
		if estado == Estado.MENU:
			_confirmar_menu()
		else:
			_confirmar_busqueda()
	elif event.is_action_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		if estado == Estado.MENU:
			_volver_al_pokenav()
		else:
			_volver_de_busqueda()
	else:
		return
	get_viewport().set_input_as_handled()


func _confirmar_menu() -> void:
	match botones_menu.indice:
		0:
			_abrir_equipo()
		1:
			_abrir_busqueda()
		_:
			_volver_al_pokenav()


func _confirmar_busqueda() -> void:
	if botones_busqueda.indice >= RASGOS.size():
		_volver_de_busqueda()
	else:
		_buscar(RASGOS[botones_busqueda.indice])


func _abrir_equipo() -> void:
	estado = Estado.OCUPADO
	await botones_menu.salir_con_elegido()
	var equipo: Array[Dictionary] = []
	for dato: Dictionary in DatosPokenav.todos_los_pokemon():
		if int(dato["caja"]) < 0:
			equipo.append(dato)
	superficie.visible = false
	vista.visible = true
	await vista.abrir(equipo, 0, false)
	estado = Estado.VISTA


func _abrir_busqueda() -> void:
	estado = Estado.OCUPADO
	await botones_menu.salir_con_elegido()
	Singleton.play_sound.emit("SE_WIN_OPEN")
	await botones_busqueda.entrar()
	estado = Estado.BUSQUEDA


func _volver_de_busqueda() -> void:
	estado = Estado.OCUPADO
	await botones_busqueda.salir()
	await botones_menu.entrar()
	estado = Estado.MENU


func _volver_al_pokenav() -> void:
	estado = Estado.OCUPADO
	await botones_menu.salir()
	anim_fondo.play(&"a_blanco")
	anim.play(&"salida")
	await anim.animation_finished
	cerrado.emit()


## Ordena de mayor a menor por el rasgo y abre la lista.
func _buscar(campo: StringName) -> void:
	estado = Estado.OCUPADO
	resultados = ordenar_por_rasgo(DatosPokenav.todos_los_pokemon(), campo)
	await botones_busqueda.salir_con_elegido()
	var elementos: Array = []
	for i in resultados.size():
		var pokemon: BasePokemon = resultados[i]["pokemon"]
		elementos.append({"texto": "%d %s" % [i + 1, pokemon.get_nombre_mostrar()], "derecha": "Nv%d" % pokemon.nivel})
	lista.configurar(elementos)
	_mostrar_lista(true)
	await lista.entrar()
	estado = Estado.LISTA


static func ordenar_por_rasgo(pokemon: Array[Dictionary], campo: StringName) -> Array[Dictionary]:
	var salida: Array[Dictionary] = pokemon.duplicate()
	salida.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int((a["pokemon"] as BasePokemon).get(campo)) > int((b["pokemon"] as BasePokemon).get(campo)))
	return salida


func _on_lista_elegida(indice: int) -> void:
	estado = Estado.OCUPADO
	lista.activa = false
	superficie.visible = false
	vista.visible = true
	await vista.abrir(resultados, indice, true)
	estado = Estado.VISTA


func _on_lista_cancelada() -> void:
	estado = Estado.OCUPADO
	await lista.salir()
	_mostrar_lista(false)
	await botones_busqueda.entrar()
	estado = Estado.BUSQUEDA


func _on_vista_cerrada() -> void:
	estado = Estado.OCUPADO
	vista.visible = false
	superficie.visible = true
	if vista.modo_busqueda:
		lista.configurar(lista.elementos, vista.seleccion)
		await lista.entrar()
		estado = Estado.LISTA
	else:
		await botones_menu.entrar()
		estado = Estado.MENU


func _mostrar_lista(mostrar: bool) -> void:
	lista.visible = mostrar
	caja.visible = not mostrar
	lb_descripcion.visible = not mostrar
