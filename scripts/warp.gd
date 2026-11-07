@tool
extends Sprite2D
class_name Warp

enum TipoWarp {
	ESCALERAS = 0,
	SALIDAS = 1,
	PUERTAS = 2,
	## Arena caliente del GIMNASIO de LAVACALDA (MB_LAVARIDGE_GYM_1F_WARP): al pisarla
	## el jugador se hunde entre ceniza y cae al sótano (la misma celda de la planta
	## de abajo, en la misma escena).
	HUECOS = 3,
	## Géiser del sótano del GIMNASIO de LAVACALDA (MB_LAVARIDGE_GYM_B1F_WARP): el
	## agua lanza al jugador hacia arriba y reaparece saltando fuera de la arena.
	GEISERES = 4,
}
const GRUPOS = ["Escaleras", "Salidas", "Puertas", "Huecos", "Geiseres"]

## Capa de datos donde aplicar: -1 todas, >=0 solo capa especificada
@export var capa_datos: int = -1
## Tipo: 'Escaleras', 'Salidas', 'Puertas'
@export var tipo_warp: TipoWarp = TipoWarp.ESCALERAS

var coord_celda: Vector2i = Vector2i.ZERO:		# Coordenada en tiles
	set(value):
		coord_celda = value
		if is_inside_tree():
			position = Vector2(value.x * 16 + 8, value.y * 16 + 6)
			update_configuration_warnings()

## Gráficos, sonido y variante de comportamiento del tipo seleccionado.
@export var estilo_warp: Singleton.EstiloWarp = Singleton.EstiloWarp.NINGUNA
## Clave del diccionario de los mapas precargados
@export var ruta_mapa_destino: String = ""
## Vector2 con las coordenadas destino medida en tiles
@export var posicion_destino: Vector2 = Vector2.ZERO
## Cómo mira el jugador al llegar: FIJA usa `direccion`; MANTENER conserva la
## dirección con la que entró (escaleras de Rubí); INVERTIR la da la vuelta.
enum ModoDireccion {
	FIJA,
	MANTENER,
	INVERTIR,
}
@export var modo_direccion: ModoDireccion = ModoDireccion.FIJA
## Dirección en la que mira el jugador al pasar la escalera (modo FIJA). (0, 0)
## conserva la dirección, como MANTENER. En SALIDAS indica además hacia dónde hay
## que pulsar para salir y orienta la flecha (por defecto, abajo).
@export var direccion: Vector2 = Vector2.ZERO
## Indica que debe dar un paso al pasar la escalera
@export var dar_paso: bool = false
## Capa de datos (layer_id) en la que aparece el jugador; -1 conserva la actual. Para
## llegadas a una celda elevada (elevación 4 de Rubí sobre una capa_datos 1).
@export var capa_destino: int = -1
## Sonido (clave de Singleton) al saltar este warp; por defecto el de las escaleras (SE_EXIT).
## Las plataformas de teletransporte de la GUARIDA (MB_AQUA_HIDEOUT_WARP) usan SE_WARP_IN.
@export var sonido_salida: StringName = &"puerta_salida"
## Sonido al llegar a este warp desde otro (vacío = ninguno). Las plataformas de la GUARIDA
## suenan SE_WARP_OUT al aparecer el jugador encima.
@export var sonido_llegada: StringName = &""
## Cerrada con llave: la celda no se puede pisar ni el warp salta por caminar hacia él.
## Solo entra un guion, con AdministradorMapa.iniciar_transicion_centro(warp), o el
## jugador cuando un evento la deje abierta (con_llave = false). Llegar a ella por
## otro warp sí se puede.
@export var con_llave: bool = false

var jugador: Node2D
var nodo_administrador: Node2D

var animacion = null
var flecha_salida = null
## Ya sonó `sonido_llegada` para la llegada actual (se rearma al salir de la celda).
var _llegada_sonada: bool = false
@export var editor_icon: String = "res://graficos/editor/editor_tile_warp.png"

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		# Agregar nodo de colision cuadrado de 16x16 pixeles
		var collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.extents = Vector2(8, 8)
		collision_shape.shape = shape
		add_child(collision_shape)

		_preparar_icono_editor()

	coord_celda = Vector2i(floor(position.x / 16), floor(position.y / 16))
	print("TileEscalera ", position, "|", coord_celda, ": clave diccionario mapas: ", ruta_mapa_destino, " ", posicion_destino)
	print("Tipo Warp: ", GRUPOS[tipo_warp])
	add_to_group(GRUPOS[tipo_warp])
	if tipo_warp == TipoWarp.PUERTAS and not Engine.is_editor_hint():
		var escena := Singleton.escena_estilo_warp(estilo_warp)
		if escena != null:
			animacion = escena.instantiate()
			animacion.visible = false
			add_child(animacion)

# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		coord_celda = Vector2i(round((position.x - 8) / 16), round((position.y - 6) / 16))
		position = Vector2(coord_celda.x * 16 + 8, coord_celda.y * 16 + 6)
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_limpiar_icono_editor()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_preparar_icono_editor()

## Icono de editor: el propio nodo es el Sprite2D, así todo su rect de 16x16 es
## clicable en el lienzo (un Sprite2D hijo sin owner lo ignora el editor).
func _preparar_icono_editor() -> void:
	texture = load(editor_icon)
	centered = true
	z_index = 1000
	modulate = Color(1, 1, 1, 0.8)

## Quita el icono antes de guardar para que no acabe serializado en la escena.
func _limpiar_icono_editor() -> void:
	texture = null
	z_index = 0
	modulate = Color.WHITE

func es_servicio() -> bool:
	return tipo_warp == TipoWarp.PUERTAS and estilo_warp in [Singleton.EstiloWarp.SERVICIO_COMBATE, Singleton.EstiloWarp.SERVICIO_INTERCAMBIO, Singleton.EstiloWarp.SERVICIO_RECORDS]

func identificador_servicio() -> StringName:
	match estilo_warp:
		Singleton.EstiloWarp.SERVICIO_COMBATE: return &"combate"
		Singleton.EstiloWarp.SERVICIO_INTERCAMBIO: return &"intercambio"
		Singleton.EstiloWarp.SERVICIO_RECORDS: return &"records"
	return &""

func es_puerta_animada() -> bool:
	return tipo_warp == TipoWarp.PUERTAS and (Singleton.SCN_PUERTAS.has(estilo_warp) or es_servicio())

func es_escalera_automatica() -> bool:
	return tipo_warp == TipoWarp.ESCALERAS and estilo_warp in [Singleton.EstiloWarp.ESCALERA_CENTRO_SUBIR, Singleton.EstiloWarp.ESCALERA_CENTRO_BAJAR]

## HUECOS y GEISERES: los mueve el coordinador (TransicionCentro) con su animación propia.
func es_hueco() -> bool:
	return tipo_warp == TipoWarp.HUECOS

func es_geiser() -> bool:
	return tipo_warp == TipoWarp.GEISERES

func es_warp_de_gimnasio() -> bool:
	return es_hueco() or es_geiser()

func usa_coordinador() -> bool:
	return tipo_warp == TipoWarp.SALIDAS or es_puerta_animada() or es_escalera_automatica() or es_warp_de_gimnasio()

## Convención authored: el TileMapLayer EscaleraCentro de esta planta es hermano
## del warp; planta_alta distingue subida/bajada. No se construyen tiles en runtime.
func obtener_efecto_escalera() -> EscaleraCentro:
	if not es_escalera_automatica() or get_parent() == null:
		return null
	var alta := estilo_warp == Singleton.EstiloWarp.ESCALERA_CENTRO_BAJAR
	for nodo in get_parent().get_children():
		if nodo is EscaleraCentro and nodo.planta_alta == alta:
			return nodo
	return null

## Las correderas eléctricas (Centro Pokémon, tiendas, gimnasios, concursos
## y centro comercial) comparten el sonido de apertura SE_SLIDING_DOOR.
func sonido_puerta() -> StringName:
	if estilo_warp in [
		Singleton.EstiloWarp.PUERTA_CENTRO_POKEMON,
		Singleton.EstiloWarp.PUERTA_GIMNASIO,
		Singleton.EstiloWarp.PUERTA_CONCURSO,
		Singleton.EstiloWarp.PUERTA_CENTRO_COMERCIAL,
		Singleton.EstiloWarp.PUERTA_CC_ASCENSOR,
	] or es_servicio():
		return &"SE_SLIDING_DOOR"
	return &"puerta_entrada"

func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if es_escalera_automatica() and obtener_efecto_escalera() == null:
		avisos.append("Falta un hermano EscaleraCentro de la planta correspondiente (planta_alta).")
	if tipo_warp != TipoWarp.PUERTAS and estilo_warp in [Singleton.EstiloWarp.SERVICIO_COMBATE, Singleton.EstiloWarp.SERVICIO_INTERCAMBIO, Singleton.EstiloWarp.SERVICIO_RECORDS]:
		avisos.append("Los estilos de servicio requieren Tipo Warp = Puertas.")
	return avisos

func _process(_delta):
	# En editor: animar icono del editor y no ejecutar lógica runtime
	if Engine.is_editor_hint():
		var t = Time.get_ticks_msec() / 1000.0
		modulate.a = 0.6 + 0.4 * (sin(t * 2.0) * 0.5 + 0.5) # oscila entre 0.6 y 1.0
		return

	# Si no se ha asignado el jugador, buscarlo
	if jugador == null:
		# Sin AdministradorMapa (escenas sueltas, tests) no hay nada que vigilar.
		nodo_administrador = get_tree().root.get_node_or_null("AdministradorMapa")
		if nodo_administrador == null:
			return
		jugador = nodo_administrador.jugador
	else:
		# Solo actúa el warp del mapa actual: el Overworld mantiene cargados los
		# mapas adyacentes con sus warps.
		var mapa_actual: Node = nodo_administrador.get("mapa_actual")
		if mapa_actual == null or not mapa_actual.is_ancestor_of(self):
			return
		if nodo_administrador.transicion_centro_activa():
			return

		# Celda del jugador en el mismo sistema que coord_celda (local al padre del
		# warp). El jugador vive en mapa/NPCs, así que se parte de su posición
		# global: vale también para mapas desplazados dentro del Overworld.
		var coord := (get_parent() as Node2D).to_local(jugador.global_position)
		var celda_jugador := Vector2i(floor(coord.x / 16), floor(coord.y / 16))
		if celda_jugador == coord_celda:
			if tipo_warp in [TipoWarp.ESCALERAS, TipoWarp.PUERTAS]:
				# Como en Rubí, solo salta al llegar con un paso: si el jugador
				# apareció aquí por otro warp, tiene que salir y volver a entrar.
				if jugador.has_method("esta_en_celda_de_llegada_warp") and jugador.esta_en_celda_de_llegada_warp():
					if sonido_llegada != &"" and not _llegada_sonada:
						_llegada_sonada = true
						Singleton.emit_signal("play_sound", String(sonido_llegada))
				elif nodo_administrador.coneccion == 0 and not con_llave:
					if usa_coordinador():
						if es_escalera_automatica() \
								and not jugador.paso_en_curso and jugador.llego_caminando_a_warp(mapa_actual, coord_celda):
								nodo_administrador.iniciar_transicion_centro(self)
						return
					jugador.no_control = true
					#jugador.no_controlar(0.5)
					if !jugador.paso_en_curso:
						# DoWarp: escaleras, cuevas y puertas sin animación (MB_NON_ANIMATED_DOOR)
						# suenan SE_KAIDAN (SE_EXIT); SE_DOOR es solo de las puertas animadas.
						Singleton.emit_signal("play_sound", String(sonido_salida))
						if capa_destino >= 0:
							nodo_administrador.conectar_escalera(ruta_mapa_destino, posicion_destino, direccion_llegada(), dar_paso, false, {}, capa_destino)
						else:
							nodo_administrador.conectar_escalera(ruta_mapa_destino, posicion_destino, direccion_llegada(), dar_paso)
			elif es_warp_de_gimnasio():
				# MB_LAVARIDGE_GYM_*_WARP: como las escaleras de Rubí, solo salta al llegar
				# caminando; quien aparece aquí por otro warp (la caída, el géiser) tiene
				# que salir de la celda y volver a pisarla.
				if jugador.has_method("esta_en_celda_de_llegada_warp") and jugador.esta_en_celda_de_llegada_warp():
					pass
				elif nodo_administrador.coneccion == 0 and not jugador.paso_en_curso \
						and jugador.llego_caminando_a_warp(mapa_actual, coord_celda):
					nodo_administrador.iniciar_transicion_centro(self)
			elif tipo_warp == TipoWarp.SALIDAS:
				# sub_8059D60: la flecha solo se ve si el jugador mira hacia la salida.
				if jugador.facing_direction == direccion_salida():
					if flecha_salida == null:
						flecha_salida = Singleton.animacion_flecha_salida.instantiate()
						flecha_salida.position = position + direccion_salida() * 16
						_orientar_flecha_salida(flecha_salida)
						flecha_salida.add_to_group("FlechaSalida")
						nodo_administrador.add_child(flecha_salida)
				else:
					_quitar_flecha_salida()
		else:
			_llegada_sonada = false
			_quitar_flecha_salida()


## Lo llama el jugador al terminar un paso sobre este warp. Devuelve true si salta:
## solo los que el coordinador mueve al pisarlos (huecos, géiseres, escaleras mecánicas).
func activar_al_pisar(jugador_paso: Node2D, admin: Node2D) -> bool:
	if not es_warp_de_gimnasio() and not es_escalera_automatica():
		return false
	jugador = jugador_paso
	nodo_administrador = admin
	return admin.iniciar_transicion_centro(self)

func abrir_puerta():
	if es_puerta_animada() and not es_servicio() and not con_llave:
		nodo_administrador.iniciar_transicion_centro(self)

func salida():
	if nodo_administrador == null:
		nodo_administrador = get_tree().root.get_node("AdministradorMapa")
	# Las SALIDAS se activan sin paso: respaldo de la entrada exterior con el
	# último paso del jugador (el gancho de inicio de paso ya la cubre si entró
	# en esta celda caminando).
	if jugador != null and jugador.has_method("registrar_entrada_exterior_por_salida"):
		jugador.registrar_entrada_exterior_por_salida(self)
	nodo_administrador.iniciar_transicion_centro(self)

## Devuelve true si esta puerta consumió el intento antes del paso manual. Con llave
## no lo consume: el paso sigue y choca (Character._celda_del_mapa_bloquea).
func intentar_entrada(jugador_entrada: Node2D, admin: Node2D, movimiento: Vector2) -> bool:
	if not es_puerta_animada() or con_llave:
		return false
	jugador = jugador_entrada
	nodo_administrador = admin
	if movimiento == Vector2.UP and not es_servicio():
		admin.iniciar_transicion_centro(self)
	# Servicio: siempre consume el intento, sin conceder acceso por caminar al tile.
	return true

## Solo el backend del servicio puede autorizar y preparar la entrada. Sin backend
## no hay destinos ficticios ni export bool que abra estas puertas en gameplay.
func solicitar_servicio(autorizar: Callable, preparar: Callable) -> bool:
	if not es_servicio() or not autorizar.is_valid() or not preparar.is_valid() or nodo_administrador == null:
		return false
	if not autorizar.call(identificador_servicio()):
		return false
	return nodo_administrador.iniciar_transicion_centro(self, preparar)

func animar_puerta(nombre: StringName) -> void:
	if animacion == null:
		return
	animacion.visible = true
	animacion.play(nombre)
	await animacion.animation_finished
	if nombre == &"cerrar_puerta":
		animacion.visible = false

func establecer_abierta() -> void:
	if animacion != null:
		animacion.visible = true
		# pause conserva el cuadro; stop lo rebobina al primero.
		if animacion.sprite_frames.has_animation(&"abierta"):
			animacion.play(&"abierta")
		else:
			animacion.play(&"abrir_puerta")
			animacion.frame = animacion.sprite_frames.get_frame_count(&"abrir_puerta") - 1
		animacion.pause()

## Dirección que recibe el teletransporte; Vector2.ZERO conserva la del jugador.
func direccion_llegada() -> Vector2:
	match modo_direccion:
		ModoDireccion.MANTENER:
			return Vector2.ZERO
		ModoDireccion.INVERTIR:
			if jugador == null or not ("facing_direction" in jugador):
				return Vector2.ZERO
			return -Vector2(jugador.get("facing_direction"))
	return direccion

## Dirección en la que hay que pulsar para activar la SALIDA. Con `direccion` sin
## configurar (0, 0) se asume hacia abajo, como las puertas de interiores.
func direccion_salida() -> Vector2:
	return direccion if direccion != Vector2.ZERO else Vector2.DOWN

func _quitar_flecha_salida() -> void:
	if flecha_salida:
		flecha_salida = null
		for node in get_tree().get_nodes_in_group("FlechaSalida"):
			node.queue_free()

func _orientar_flecha_salida(flecha: Node2D) -> void:
	# La textura base apunta hacia abajo; angle_to calcula el giro necesario
	# para llevar DOWN a la dirección de salida.
	flecha.rotation = Vector2.DOWN.angle_to(direccion_salida().normalized())
