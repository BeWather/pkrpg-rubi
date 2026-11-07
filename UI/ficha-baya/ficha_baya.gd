extends Node2D
class_name FichaBaya

## Pantalla VER FICHA de una baya (pokeruby: src/berry_tag_screen.c).
## Muestra número, nombre, tamaño, firmeza, sabores y descripción de la baya
## seleccionada en la mochila. ARRIBA/ABAJO pasan a la baya anterior/siguiente
## del bolsillo (como Ruby) y A o B cierran la ficha.

## Se emite ya con la pantalla oscurecida. `indice` es la baya mostrada al
## cerrar, para que la mochila mueva su cursor ahí (Ruby hace lo mismo).
signal ficha_cerrada(indice: int)

## Posición del primer círculo de sabor (PICANTE); los demás van cada 40 px.
const MARCADOR_ORIGEN: Vector2 = Vector2(32, 83)
const MARCADOR_PASO_X: float = 40.0
## Columnas de la tabla Bayas en el orden de la ficha.
const SABORES: Array[String] = ["picante", "seco", "dulce", "amargo", "acido"]
const TEXTO_FIRMEZA: Dictionary = {
	"MUY_BLANDA": "Muy blanda",
	"BLANDA": "Blanda",
	"DURA": "Dura",
	"MUY_DURA": "Muy dura",
	"DURISIMA": "Superdura",
}
const TEXTO_DESCONOCIDO: String = "(?)"
## Cambio de baya: la ficha sale por arriba/abajo y entra por el lado opuesto
## (Ruby desplaza la capa de la ficha de 16 en 16 px).
const DESPLAZAMIENTO_CAMBIO: float = 160.0
const DURACION_CAMBIO: float = 0.13

@onready var nd_fe_fondo: Sprite2D = $"Fe-fondo"
@onready var nd_ma_fondo: Sprite2D = $"Ma-fondo"
@onready var nd_titulo: Sprite2D = $"FichaBayaTitulo"
@onready var nd_ficha: Sprite2D = $"ficha-frente"
@onready var lb_id: Label = $"ficha-frente/id"
@onready var lb_nombre: Label = $"ficha-frente/nombre"
@onready var lb_tamano: Label = $"ficha-frente/tamaño"
@onready var lb_dureza: Label = $"ficha-frente/dureza"
@onready var lb_descripcion: Label = $"ficha-frente/descripcion"
@onready var spr_baya: AnimatedSprite2D = $"ficha-frente/baya"
@onready var spr_marcador: Sprite2D = $"ficha-frente/marcador"

## Items del bolsillo de bayas (diccionarios de la mochila, con nombre_interno).
var _bayas: Array[Dictionary] = []
var _indice: int = 0
## Un círculo por sabor; se muestran los de sabor > 0.
var _marcadores: Array[Sprite2D] = []
## Bloquea la entrada durante transiciones y animaciones.
var _ocupado: bool = true
var _posicion_ficha: Vector2 = Vector2.ZERO


func _ready() -> void:
	_posicion_ficha = nd_ficha.position
	# El título queda por encima de la ficha cuando ésta se desplaza.
	nd_titulo.z_index = 1
	_crear_marcadores()
	_aplicar_fondo_por_sexo()

	# Ejecutada como escena principal (F6): escalar y mostrar todas las bayas.
	if get_tree().current_scene == self:
		scale = Vector2(4, 4)
		abrir(_todas_las_bayas(), 0)


## Muestra la ficha de `bayas[indice]` y aclara la pantalla. Se llama con la
## pantalla ya oscurecida.
func abrir(bayas: Array, indice: int) -> void:
	_bayas.clear()
	for baya in bayas:
		if baya is Dictionary:
			_bayas.append(baya)
	_indice = clampi(indice, 0, maxi(0, _bayas.size() - 1))
	_mostrar_baya()
	visible = true
	await Singleton.transicion("aclarar")
	_ocupado = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _ocupado:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("btn_arriba", true):
		_cambiar_baya(-1)
	elif event.is_action_pressed("btn_abajo", true):
		_cambiar_baya(1)
	elif event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
		_cerrar()
	else:
		return
	get_viewport().set_input_as_handled()


# ─── Contenido ───────────────────────────────────────────────────────────────

func _mostrar_baya() -> void:
	var item: Dictionary = _bayas[_indice] if _indice < _bayas.size() else {}
	var objeto: Dictionary = {}
	if not item.is_empty():
		objeto = DatabaseManager.obtener_datos_objeto(str(item.get("nombre_interno", "")))
	var datos: Dictionary = {}
	if not objeto.is_empty():
		datos = DatabaseManager.obtener_datos_baya(int(objeto.get("id", -1)))

	# Bayas sin fila en la tabla Bayas (4ª gen): campos desconocidos y frame 0.
	var numero: int = int(datos.get("numero", 0))
	lb_id.text = "%02d" % numero if numero > 0 else "--"
	var nombre: String = str(objeto.get("nombre", item.get("nombre", "")))
	lb_nombre.text = FormateadorLigaduras.formatear(_nombre_sin_baya(nombre))

	var tamano_mm: int = int(datos.get("tamano", 0))
	var tamano: String = TEXTO_DESCONOCIDO
	if tamano_mm > 0:
		tamano = "%d,%d cm" % [tamano_mm / 10, tamano_mm % 10]
	lb_tamano.text = "TAM. /   " + tamano
	lb_dureza.text = "DUR. /   " + str(TEXTO_FIRMEZA.get(str(datos.get("firmeza", "")), TEXTO_DESCONOCIDO))

	var lineas: PackedStringArray = []
	for clave: String in ["descripcion_1", "descripcion_2"]:
		var linea: String = str(datos.get(clave, "")).strip_edges()
		if not linea.is_empty():
			lineas.append(linea)
	lb_descripcion.text = FormateadorLigaduras.formatear("\n".join(lineas))

	# El frame 0 del sprite está vacío; el frame N es la baya número N.
	spr_baya.frame = clampi(numero, 0, spr_baya.sprite_frames.get_frame_count(spr_baya.animation) - 1)

	for i in range(SABORES.size()):
		_marcadores[i].visible = int(datos.get(SABORES[i], 0)) > 0


## "BAYA MELOC" → "MELOC" (la ficha muestra el nombre sin "BAYA", como Ruby).
func _nombre_sin_baya(nombre: String) -> String:
	var limpio: String = nombre.strip_edges()
	if limpio.to_upper().begins_with("BAYA "):
		return limpio.substr(5)
	return limpio


func _crear_marcadores() -> void:
	spr_marcador.visible = false
	for i in range(SABORES.size()):
		var marcador := spr_marcador.duplicate() as Sprite2D
		marcador.name = "marcador_%s" % SABORES[i]
		marcador.position = MARCADOR_ORIGEN + Vector2(MARCADOR_PASO_X * i, 0)
		marcador.visible = false
		nd_ficha.add_child(marcador)
		_marcadores.append(marcador)


func _aplicar_fondo_por_sexo() -> void:
	var sexo: String = "M"
	if SistemaGuardado and SistemaGuardado.datos_vivos:
		sexo = str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M"))
	nd_fe_fondo.visible = sexo == "F"
	nd_ma_fondo.visible = sexo != "F"


## Todas las bayas de la tabla Bayas en orden (sólo para probar la escena suelta).
func _todas_las_bayas() -> Array:
	var bayas: Array = []
	var consulta: String = "SELECT o.nombre_interno FROM Bayas b JOIN Objetos o ON o.id = b.objeto_id ORDER BY b.numero"
	if DatabaseManager.ejecutar_consulta(consulta):
		for fila in DatabaseManager.obtener_resultados():
			bayas.append({"nombre_interno": fila["nombre_interno"]})
	return bayas


# ─── Navegación y cierre ─────────────────────────────────────────────────────

func _cambiar_baya(direccion: int) -> void:
	var nuevo: int = _indice + direccion
	if nuevo < 0 or nuevo >= _bayas.size():
		return
	_ocupado = true
	Singleton.emit_signal("play_sound", "cursor_menu")
	# ABAJO: la ficha sale por arriba y la siguiente entra por abajo.
	var fuera: Vector2 = _posicion_ficha - Vector2(0, DESPLAZAMIENTO_CAMBIO * direccion)
	var tween := create_tween()
	tween.tween_property(nd_ficha, "position", fuera, DURACION_CAMBIO)
	await tween.finished
	_indice = nuevo
	_mostrar_baya()
	nd_ficha.position = _posicion_ficha + Vector2(0, DESPLAZAMIENTO_CAMBIO * direccion)
	tween = create_tween()
	tween.tween_property(nd_ficha, "position", _posicion_ficha, DURACION_CAMBIO)
	await tween.finished
	_ocupado = false


func _cerrar() -> void:
	_ocupado = true
	Singleton.emit_signal("play_sound", "cursor_menu")
	await Singleton.transicion("oscurecer")
	ficha_cerrada.emit(_indice)
