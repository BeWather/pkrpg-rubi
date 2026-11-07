extends NinePatchRect

@onready var localizacion = $localizacion
@onready var jugador = $jugador
@onready var medallas = $medallas
@onready var pokedex = $pokedex
@onready var tiempo_juego = $tiempo_juego

var datos_partida: Dictionary = {}

func _ready() -> void:
	print("✅ [CUADRO INFO] READY!")

	# Aplicar textura del menu_box seleccionada en las opciones (si está disponible)
	var img_type = _get_saved_image_type()
	MenuBoxManager.apply_texture_to_ninepatch(self, img_type)

	# Si los datos ya fueron configurados antes de _ready, refrescamos ahora
	if datos_partida:
		print("🔄 [CUADRO INFO] → Dice que hay datos")
		_refrescar_labels()

func _get_saved_image_type() -> int:
	# Leer de forma segura la opción imagen_tipo desde SistemaGuardado
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	# Fallback a variable global
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return 1
	
func configurar_datos(datos: Dictionary):
	print("🔄 [CUADRO INFO:configurar_datos] → Configurando datos de partida")
	datos_partida = datos
	_refrescar_labels()

func _refrescar_labels():
	if not datos_partida:
		return
	if localizacion: localizacion.text = str(datos_partida.get("localizacion", "-"))
	if jugador: jugador.text = str(datos_partida.get("jugador", "-"))
	if medallas: medallas.text = str(datos_partida.get("medallas", 0))
	if pokedex: pokedex.text = str(datos_partida.get("pokedex", 0))
	if tiempo_juego: tiempo_juego.text = str(datos_partida.get("tiempo", "00:00"))
