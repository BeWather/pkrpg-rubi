@tool
extends AnimatedSprite2D

# --- TRAYECTORIAS DE VUELO (dirigibles desde el AnimationPlayer) ---
# Tres curvas Bézier cuadráticas (inicio → control → fin). El punto de control
# fija las pendientes: la curva SALE del inicio apuntando al control y LLEGA al
# fin viniendo desde el control. Control a la misma altura que el inicio =
# salida horizontal (pendiente suave); control cerca de la vertical del fin =
# llegada muy inclinada.
#
# Receta en el AnimationPlayer (todo se previsualiza en el editor, @tool):
#   1. Track discreta sobre `trayectoria`: ESCAPE / LLEVAR / ENTRAR al iniciar el vuelo
#      y NINGUNA al terminar (deja el nodo libre para otros tracks).
#   2. Track continua sobre `progreso` de 0.0 → 1.0: define el ritmo del
#      vuelo (con transiciones se le da easing).
#   Posición y escala las calcula el script: no hace falta animarlas.

enum Trayectoria {
	NINGUNA, ## El nodo queda libre (position/scale no se tocan).
	ESCAPE,  ## Despega desde el jugador y escapa por la esquina superior izquierda.
	LLEVAR,  ## Cruza de derecha a izquierda llevándose al jugador.
	ENTRAR,  ## Baja en picada desde arriba hasta la pokéball en la mano del jugador.
}

## Interruptor del efecto. ESTE setter (junto con `progreso`) es el único que
## aplica la curva: así la previsualización del AnimationPlayer funciona, pero
## el editor no muta position/scale al recargar el script.
@export var trayectoria: Trayectoria = Trayectoria.NINGUNA:
	set(valor):
		trayectoria = valor
		_aplicar_trayectoria()
		_redibujar_guia()

## Progreso del vuelo: 0.0 = inicio, 1.0 = fin. Se anima con un track
## continuo, pero también se puede arrastrar en el inspector para probar.
@export_range(0.0, 1.0, 0.001) var progreso: float = 0.0:
	set(valor):
		progreso = valor
		_aplicar_trayectoria()
		_redibujar_guia()

## Dibuja en el editor las guías de las trayectorias (verde = escape,
## celeste = llevar, naranja = entrar; punto blanco = inicio, amarillo =
## control, rojo = fin).
## Se ve aunque el nodo esté oculto.
@export var mostrar_guia_editor: bool = false:
	set(valor):
		mostrar_guia_editor = valor
		_redibujar_guia()

# Coordenadas en el espacio del padre (mismo sistema que `position`).
@export_group("Escape")
@export var escape_inicio: Vector2 = Vector2(0, -8):
	set(valor):
		escape_inicio = valor
		_redibujar_guia()
@export var escape_control: Vector2 = Vector2(-100, -8):
	set(valor):
		escape_control = valor
		_redibujar_guia()
@export var escape_fin: Vector2 = Vector2(-150, -110):
	set(valor):
		escape_fin = valor
		_redibujar_guia()
@export var escape_escala_inicio: Vector2 = Vector2(0.1, 0.1)
@export var escape_escala_fin: Vector2 = Vector2(1.0, 1.0)

@export_group("Llevar")
@export var llevar_inicio: Vector2 = Vector2(150, -40):
	set(valor):
		llevar_inicio = valor
		_redibujar_guia()
## Con el control en (0, 24) la curva pasa por (0, -8) a mitad de recorrido.
@export var llevar_control: Vector2 = Vector2(0, 24):
	set(valor):
		llevar_control = valor
		_redibujar_guia()
@export var llevar_fin: Vector2 = Vector2(-150, -40):
	set(valor):
		llevar_fin = valor
		_redibujar_guia()
@export var llevar_escala_inicio: Vector2 = Vector2(1.0, 1.0)
@export var llevar_escala_fin: Vector2 = Vector2(1.0, 1.0)

@export_group("Entrar")
## Borde superior de la pantalla, 16 px a la derecha del centro.
@export var entrar_inicio: Vector2 = Vector2(16, -86):
	set(valor):
		entrar_inicio = valor
		_redibujar_guia()
## Casi en la vertical de ambos extremos: bajada muy empinada de principio a fin.
@export var entrar_control: Vector2 = Vector2(-4, -40):
	set(valor):
		entrar_control = valor
		_redibujar_guia()
## Pokéball en la mano del jugador (frame 4 de `otras:mov_campo`).
@export var entrar_fin: Vector2 = Vector2(-10, -12):
	set(valor):
		entrar_fin = valor
		_redibujar_guia()
@export var entrar_escala_inicio: Vector2 = Vector2(1.0, 1.0)
@export var entrar_escala_fin: Vector2 = Vector2(0.1, 0.1)

# --- PASAJERO (el sprite del jugador que el Pokémon se lleva) ---
# Track discreta sobre `llevar_pasajero`: false en 0, true en el instante en
# que el Pokémon y el jugador se juntan. Mientras está en true el pasajero
# sigue al Pokémon manteniendo `pasajero_desfase` (pasajero − Pokémon, ambos
# en el espacio del padre). El desfase es fijo (no se captura al vuelo) para
# que el resultado no dependa de a qué tiempo se salte al hacer scrub.
@export_group("Pasajero")
## Nodo que se engancha. Debe compartir padre con este nodo.
@export var ruta_pasajero: NodePath = ^"../otras"
## position del pasajero − position del Pokémon mientras va enganchado.
@export var pasajero_desfase: Vector2 = Vector2.ZERO
## Pon la animación en el instante del enganche y pulsa el botón: guarda en
## `pasajero_desfase` la distancia actual entre ambos.
@export_tool_button("Capturar desfase actual") var boton_capturar_desfase := capturar_desfase
@export var llevar_pasajero: bool = false:
	set(valor):
		llevar_pasajero = valor
		_seguir_pasajero()

## Punto de una Bézier cuadrática para t ∈ [0, 1].
static func punto_bezier(p0: Vector2, control: Vector2, p1: Vector2, t: float) -> Vector2:
	return p0.lerp(control, t).lerp(control.lerp(p1, t), t)

## Coloca el sprite en el punto de la curva activa para el `progreso` actual
## y aplica la escala interpolada.
func _aplicar_trayectoria() -> void:
	match trayectoria:
		Trayectoria.ESCAPE:
			position = punto_bezier(escape_inicio, escape_control, escape_fin, progreso)
			scale = escape_escala_inicio.lerp(escape_escala_fin, progreso)
		Trayectoria.LLEVAR:
			position = punto_bezier(llevar_inicio, llevar_control, llevar_fin, progreso)
			scale = llevar_escala_inicio.lerp(llevar_escala_fin, progreso)
		Trayectoria.ENTRAR:
			position = punto_bezier(entrar_inicio, entrar_control, entrar_fin, progreso)
			scale = entrar_escala_inicio.lerp(entrar_escala_fin, progreso)

## Se procesa DESPUÉS del AnimationPlayer (prioridad alta): así la posición del
## pasajero gana a los tracks que lo sigan fijando (p. ej. `otras:position`
## mantiene su última clave mientras la animación corre).
const PRIORIDAD_PROCESO := 100

func _ready() -> void:
	process_priority = PRIORIDAD_PROCESO

func _process(_delta: float) -> void:
	_seguir_pasajero()

## Coloca al pasajero sobre el Pokémon manteniendo `pasajero_desfase`.
func _seguir_pasajero() -> void:
	if not llevar_pasajero or not is_inside_tree():
		return
	var pasajero := get_node_or_null(ruta_pasajero) as Node2D
	if pasajero:
		pasajero.position = position + pasajero_desfase

## Guarda en `pasajero_desfase` la distancia actual pasajero − Pokémon.
## En el editor queda registrado con deshacer/rehacer (y marca la escena como
## modificada); en juego se asigna directo.
func capturar_desfase() -> void:
	var pasajero := get_node_or_null(ruta_pasajero) as Node2D
	if pasajero == null:
		push_warning("[POKE_FIELD] No se encontró el pasajero en '%s'" % ruta_pasajero)
		return
	var nuevo: Vector2 = pasajero.position - position
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		var deshacer = Engine.get_singleton(&"EditorInterface").get_editor_undo_redo()
		deshacer.create_action("Capturar desfase del pasajero")
		deshacer.add_do_property(self, &"pasajero_desfase", nuevo)
		deshacer.add_undo_property(self, &"pasajero_desfase", pasajero_desfase)
		deshacer.commit_action()
	else:
		pasajero_desfase = nuevo

# --- GUÍA DEL EDITOR ---
# No se dibuja en _draw() del sprite: el nodo suele estar oculto (visible =
# false fuera de las animaciones) y con z_index -1 quedaría tapado por
# MoveFieldParticle. Se usa un canvas item propio colgado del PADRE, con z alto:
# se ve siempre y sus coordenadas ya son las del padre (las de `position`).
const Z_GUIA := 1000
var _guia_ci: RID

func _enter_tree() -> void:
	_redibujar_guia()

func _exit_tree() -> void:
	_liberar_guia()

func _redibujar_guia() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var padre := get_parent() as CanvasItem
	if not mostrar_guia_editor or padre == null:
		_liberar_guia()
		return
	if not _guia_ci.is_valid():
		_guia_ci = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(_guia_ci, padre.get_canvas_item())
		RenderingServer.canvas_item_set_z_as_relative_to_parent(_guia_ci, false)
		RenderingServer.canvas_item_set_z_index(_guia_ci, Z_GUIA)
	RenderingServer.canvas_item_clear(_guia_ci)
	_dibujar_curva(escape_inicio, escape_control, escape_fin, Color(0.35, 1.0, 0.55, 0.9))
	_dibujar_curva(llevar_inicio, llevar_control, llevar_fin, Color(0.35, 0.8, 1.0, 0.9))
	_dibujar_curva(entrar_inicio, entrar_control, entrar_fin, Color(1.0, 0.6, 0.2, 0.9))

func _liberar_guia() -> void:
	if _guia_ci.is_valid():
		RenderingServer.free_rid(_guia_ci)
		_guia_ci = RID()

func _dibujar_curva(p0: Vector2, control: Vector2, p1: Vector2, color: Color) -> void:
	var puntos: PackedVector2Array = []
	const PASOS := 32
	for i in range(PASOS + 1):
		puntos.append(punto_bezier(p0, control, p1, float(i) / float(PASOS)))
	# Tangentes de salida y llegada (las "manijas" del control).
	var color_manija := Color(1.0, 1.0, 1.0, 0.35)
	RenderingServer.canvas_item_add_line(_guia_ci, p0, control, color_manija, 1.0)
	RenderingServer.canvas_item_add_line(_guia_ci, control, p1, color_manija, 1.0)
	RenderingServer.canvas_item_add_polyline(_guia_ci, puntos, PackedColorArray([color]), 1.0, true)
	RenderingServer.canvas_item_add_circle(_guia_ci, p0, 2.0, Color.WHITE)
	RenderingServer.canvas_item_add_circle(_guia_ci, control, 2.0, Color.YELLOW)
	RenderingServer.canvas_item_add_circle(_guia_ci, p1, 2.0, Color.RED)
