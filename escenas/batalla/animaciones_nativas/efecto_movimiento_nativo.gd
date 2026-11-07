extends Node2D
class_name EfectoMovimientoNativo
## Base compartida de las escenas de animación nativa (piloto opt-in, ver
## documentacion/piloto_animaciones_nativas.md). Cada movimiento es una escena
## .tscn con su AnimationPlayer: las pistas animan propiedades de esta escena
## (desplazamientos de los sprites, paneo, visibilidad de efectos) y llaman a
## métodos (emitir_impacto, sacudir, partículas, terminar). `AnimacionEscenaNativa`
## instancia la escena, llama a configurar() y espera `terminado` (fin visual,
## clave `terminar`). La animación sigue hasta su `length` para no cortar el
## audio (el AnimationPlayer detiene sus pistas de audio al acabar) y entonces
## la escena se libera sola.
## Tiempos del original: frames de 60 Hz pasados a segundos. En el juego un
## `delay N` separa los comandos N + 2 frames (medido en la ROM, ver
## documentacion/piloto_animaciones_nativas.md §11.2); placaje.tscn aún usa N.
## En las .tscn se escriben truncados a 4 decimales (6/60 -> 0.0999) para que
## cada clave caiga exactamente en su frame con delta fijo.

signal impacto_visual
signal terminado

const FRAME: float = 1.0 / 60.0
## Escenas en curso; `cancelar_en_slot` las busca cuando un slot cambia de ocupante.
const GRUPO_ACTIVAS: StringName = &"animaciones_nativas_activas"

@export var nombre_animacion: StringName = &"movimiento"
## Movimientos de dos turnos (choosetwoturnanim del original): si no está
## vacío, la animación se elige con `turno % tamaño` (p. ej. [carga, ataque]).
@export var animaciones_por_turno: Array[StringName] = []

## Desplazamiento libre del sprite atacante (píxeles del campo).
@export var desplazamiento_atacante: Vector2 = Vector2.ZERO:
	set(valor):
		desplazamiento_atacante = valor
		_aplicar_desplazamientos()
## Desplazamiento libre del sprite defensor (píxeles del campo).
@export var desplazamiento_defensor: Vector2 = Vector2.ZERO:
	set(valor):
		desplazamiento_defensor = valor
		_aplicar_desplazamientos()
## Avance horizontal del atacante hacia el rival; se refleja según el lado.
@export var avance_atacante: float = 0.0:
	set(valor):
		avance_atacante = valor
		_aplicar_desplazamientos()
## Paneo del sonido: -1 = lado del atacante, +1 = lado del defensor.
@export_range(-1.0, 1.0) var paneo: float = -1.0:
	set(valor):
		paneo = valor
		_aplicar_paneo()
## Giro del atacante (radianes) alrededor del centro del sprite (matriz afín
## de obj_id_set_rotscale); se refleja según el lado.
@export var giro_atacante: float = 0.0:
	set(valor):
		giro_atacante = valor
		_aplicar_desplazamientos()
## Giro del defensor (radianes, sentido de pantalla, sin reflejar por lado)
## alrededor del centro del sprite.
@export var giro_defensor: float = 0.0:
	set(valor):
		giro_defensor = valor
		_aplicar_desplazamientos()
## Mezcla de paleta de cada battler hacia su color (BlendPalette / fundidos de
## paleta del original), animable desde una pista: 0..1 = 0..16 dieciseisavos.
@export_range(0.0, 1.0) var tinte_atacante: float = 0.0:
	set(valor):
		tinte_atacante = valor
		fijar_tinte(&"atacante", color_tinte_atacante, valor)
@export var color_tinte_atacante: Color = Color.WHITE
@export_range(0.0, 1.0) var tinte_defensor: float = 0.0:
	set(valor):
		tinte_defensor = valor
		fijar_tinte(&"defensor", color_tinte_defensor, valor)
@export var color_tinte_defensor: Color = Color.WHITE
## Opacidad del atacante (REG_BLDALPHA con el battler en la capa de fondo).
@export_range(0.0, 1.0) var alfa_atacante: float = 1.0:
	set(valor):
		alfa_atacante = valor
		_aplicar_alfa()

@onready var reproductor: AnimationPlayer = $AnimationPlayer
@onready var marca_atacante: Marker2D = $Atacante
@onready var marca_defensor: Marker2D = $Defensor
@onready var marca_atacante_base: Marker2D = $AtacanteBase
@onready var marca_defensor_base: Marker2D = $DefensorBase
@onready var sonido: AudioStreamPlayer2D = get_node_or_null(^"Sonido") as AudioStreamPlayer2D
## Capa opcional que sustituye u oscurece el fondo (fadetobg / paleta del fondo).
@onready var fondo: FondoMovimientoNativo = get_node_or_null(^"Fondo") as FondoMovimientoNativo

const SHADER_TINTE: Shader = preload("res://escenas/batalla/animaciones_nativas/tinte_battler.gdshader")
const RUTA_FONDO_VUELO_CONCURSO: String = "res://graficos/batalla/animaciones/bg_19.png"
const RUTA_FONDO_RAYO_SOLAR_CONCURSO: String = "res://graficos/batalla/animaciones/bg_26.png"
## Plantilla de fondo de batalla -> BG_*_CONTESTS del original (gBattleAnimBackgroundTable).
const FONDOS_CONCURSO: Dictionary = {
	&"FondoImpactoRival": "res://graficos/batalla/animaciones/bg_06.png",
	&"FondoImpactoJugador": "res://graficos/batalla/animaciones/bg_06.png",
	&"FondoTaladro": "res://graficos/batalla/animaciones/bg_08.png",
	&"FondoGuillotinaRival": "res://graficos/batalla/animaciones/bg_14.png",
	&"FondoGuillotinaJugador": "res://graficos/batalla/animaciones/bg_14.png",
	&"FondoVuelo": RUTA_FONDO_VUELO_CONCURSO,
	# sub_80D23B4 (Cara Susto y Deslumbrar): gBattleAnimBackgroundTilemap_ScaryFaceContest.
	&"CapaCaraRival": "res://graficos/batalla/animaciones/scary_face_contest.png",
	&"CapaCaraJugador": "res://graficos/batalla/animaciones/scary_face_contest.png",
}

var sprite_atacante: Sprite2D
var sprite_defensor: Sprite2D
## Proyección de ocultación del atacante entre turnos (la abre la lógica de
## batalla; la fija el adaptador). Si existe, la visibilidad del atacante se
## escribe solo a través de ella y la batalla decide cuándo se restaura.
var proyeccion_oculta: BattleHiddenProjection
var _visibilidad_propia: bool = false
var _visible_original: bool = true
## Turno del movimiento (MoveAnimationContext.source_move_turn): 0 = carga,
## 1 = ataque. Lo fija el adaptador antes de configurar().
var turno: int = 0
## Rama del script que depende de un dato de batalla (§24: amistad, potencia, daño, clima, contadores…):
## sufijo de la animación («<animación>_<rama>»). Lo fija el adaptador (RamasNativas); vacío = sin rama.
var rama: String = ""
## Datos de batalla de presentación que algunas escenas leen sin ramificar (terreno de Camuflaje, especie
## del defensor de Imitación…). Los pone el adaptador desde MoveAnimationContext; nunca es estado de juego.
var datos: Dictionary = {}
## Animación en la pantalla de concurso (IsContest): usa FONDOS_CONCURSO. Lo fija el adaptador antes de configurar().
var concurso: bool = false
## +1 si el atacante es del lado del jugador (mira a la derecha), -1 si es rival.
var direccion: float = 1.0
var tamano_campo: Vector2 = Vector2(240, 160)
var _origen_atacante: Vector2
var _origen_defensor: Vector2
var _rotacion_atacante: float = 0.0
var _rotacion_defensor: float = 0.0
## Rol (&"atacante"/&"defensor") -> [sprite, material original] mientras el
## sprite lleva el material de tinte/opacidad de la animación.
var _materiales: Dictionary = {}
## Línea de recorte del atacante en coordenadas de la escena (INF = sin recorte).
var _recorte_atacante: float = INF
var _sacudida_atacante: Vector2 = Vector2.ZERO
var _sacudida_defensor: Vector2 = Vector2.ZERO
var _tweens: Array[Tween] = []
var _efectos: Array[CanvasItem] = []
var _configurado: bool = false
var _terminado: bool = false

## §35 (tanda T3): combate doble. El adaptador fija, antes de configurar(), si es un combate doble, las posiciones de la
## GBA del atacante y del defensor (0 jugador izquierda, 1 rival izquierda, 2 jugador derecha, 3 rival derecha) y los
## battlers visibles por posición con sus centros y bases (fijar_dobles()). Con `doble`, reproducir() elige
## «<animación>_d<atacante><defensor>» o «<animación>_doble» / «_doble_rival» si la escena las tiene
## (herramientas/piloto_animaciones_nativas/generar_dobles.py); si no, la de siempre. Sin fijar_dobles() (combate
## individual, comparador en individual) nada cambia.
var doble: bool = false
var posicion_atacante: int = 0
var posicion_defensor: int = 1
## Posición de la GBA -> Sprite2D de cada battler visible (incluidos atacante y defensor).
var sprites_por_posicion: Dictionary = {}
## Posición de la GBA -> [centro, base] en coordenadas del campo (las de las marcas del atacante y del defensor).
var marcas_por_posicion: Dictionary = {}
## Rol canónico (&"posicion_N") -> estado de un battler que no es ni el atacante ni el defensor mientras la escena lo
## mueve: {"sprite", "origen", "rotacion", "desplazamiento", "sacudida", "giro"}.
var _extras: Dictionary = {}
## Marcas creadas para las anclas de los compañeros (ancla -> Marker2D).
var _marcas_extra: Dictionary = {}


## `centro_*`: centro visual del sprite (coordenadas 2/3 del original);
## `base_*`: posición nominal del slot sin offset de especie (coordenadas 0/1).
## Todas en coordenadas locales del padre de esta escena (el campo).
func configurar(sprite_a: Sprite2D, sprite_d: Sprite2D, centro_a: Vector2, centro_d: Vector2,
		base_a: Vector2, base_d: Vector2, atacante_es_jugador: bool, tamano: Vector2) -> void:
	sprite_atacante = sprite_a
	sprite_defensor = sprite_d
	_origen_atacante = sprite_a.position
	_origen_defensor = sprite_d.position
	_rotacion_atacante = sprite_a.rotation
	_rotacion_defensor = sprite_d.rotation
	direccion = 1.0 if atacante_es_jugador else -1.0
	tamano_campo = tamano
	marca_atacante.position = centro_a
	marca_defensor.position = centro_d
	marca_atacante_base.position = base_a
	marca_defensor_base.position = base_d
	# Los hijos de las marcas del atacante se reflejan con el lado (offsets ±x del original).
	marca_atacante.scale.x = direccion
	marca_atacante_base.scale.x = direccion
	_configurado = true
	add_to_group(GRUPO_ACTIVAS)
	# Como en el original (efectos con prioridad OAM 2, cajas de PS con 1): por
	# encima de los battlers y por debajo de la UI de batalla. `Campo` se dibuja
	# antes que la UI, así que basta con el z del battler más alto.
	z_as_relative = false
	z_index = maxi(z_absoluto(sprite_a), z_absoluto(sprite_d))
	# §35: en dobles, también por encima de los compañeros.
	for sprite: Variant in sprites_por_posicion.values():
		if is_instance_valid(sprite):
			z_index = maxi(z_index, z_absoluto(sprite as Sprite2D))
	if fondo != null:
		# Por encima del fondo y del suelo de la batalla, por debajo de los battlers.
		var z_fondo: int = mini(z_absoluto(sprite_a), z_absoluto(sprite_d))
		# §36: por debajo también de los compañeros: en la GBA el fondo del movimiento (BG3) queda bajo todos los battlers.
		# Con el objetivo aliado los dos del lado contrario quedan más atrás que el atacante y el objetivo, y antes los tapaba.
		for sprite: Variant in sprites_por_posicion.values():
			if is_instance_valid(sprite):
				z_fondo = mini(z_fondo, z_absoluto(sprite as Sprite2D))
		fondo.colocar(z_fondo - 1, tamano)
	_aplicar_paneo()
	_colocar_sonidos_fijos()
	_al_configurar()


## Gancho para las subclases (tamaños/posiciones que dependen del campo).
func _al_configurar() -> void:
	pass


## §35: combate doble (lo llama el adaptador antes de configurar()). `battlers`: posición de la GBA -> [sprite, centro,
## base] de cada battler visible del campo (coordenadas del campo, las mismas que las marcas del atacante y del
## defensor). Los compañeros se mueven y se tiñen con los roles &"companero_atacante", &"companero_defensor" y
## &"posicion_N" (ver sprite_de()); al acabar vuelven a su sitio como el atacante y el defensor.
func fijar_dobles(doble_: bool, pos_atacante: int, pos_defensor: int, battlers: Dictionary) -> void:
	doble = doble_
	posicion_atacante = pos_atacante
	posicion_defensor = pos_defensor
	sprites_por_posicion.clear()
	marcas_por_posicion.clear()
	for posicion: Variant in battlers:
		var datos_battler: Array = battlers[posicion]
		if datos_battler.is_empty() or not is_instance_valid(datos_battler[0]):
			continue
		sprites_por_posicion[int(posicion)] = datos_battler[0]
		marcas_por_posicion[int(posicion)] = [datos_battler[1], datos_battler[2]] if datos_battler.size() > 2 else [Vector2.ZERO, Vector2.ZERO]


## Sprite de un rol: &"atacante", &"defensor", §35 &"companero_atacante" / &"companero_defensor" (posición ^ 2 del
## atacante / del defensor, como ANIM_BATTLER_ATK_PARTNER / DEF_PARTNER) y &"posicion_N" (el battler de la posición N
## de la GBA). null si ese battler no está (en individual, los compañeros). Cualquier otro rol, el defensor (lo que
## hacían los componentes antes de §35).
func sprite_de(rol: StringName) -> Sprite2D:
	match rol:
		&"atacante":
			return sprite_atacante
		&"defensor":
			return sprite_defensor
		&"companero_atacante":
			return _sprite_posicion(posicion_atacante ^ 2)
		&"companero_defensor":
			return _sprite_posicion(posicion_defensor ^ 2)
	if str(rol).begins_with("posicion_"):
		return _sprite_posicion(int(str(rol).trim_prefix("posicion_")))
	return sprite_defensor


func _sprite_posicion(posicion: int) -> Sprite2D:
	var sprite: Variant = sprites_por_posicion.get(posicion)
	return sprite as Sprite2D if is_instance_valid(sprite) else null


## §35: el rol que lleva el estado de `rol`: &"atacante" / &"defensor" si su sprite es el del atacante o el del defensor
## (el compañero del defensor de un ataque al aliado es el propio atacante), &"posicion_N" para los demás y &"" si no
## hay battler (el original destruye la tarea). Los roles que no son de battler (&"fondo"…) se devuelven igual.
func _rol_efectivo(rol: StringName) -> StringName:
	if rol == &"atacante" or rol == &"defensor":
		return rol
	if rol != &"companero_atacante" and rol != &"companero_defensor" and not str(rol).begins_with("posicion_"):
		return rol
	var sprite: Sprite2D = sprite_de(rol)
	if sprite == null:
		return &""
	if sprite == sprite_atacante:
		return &"atacante"
	if sprite == sprite_defensor:
		return &"defensor"
	for posicion: Variant in sprites_por_posicion:
		if sprites_por_posicion[posicion] == sprite:
			return StringName("posicion_%d" % int(posicion))
	return &""


## §35: estado de un battler extra (rol canónico &"posicion_N"); lo crea la primera vez con su posición de reposo.
func _extra(rol: StringName) -> Dictionary:
	if rol == &"":
		return {}
	if not _extras.has(rol):
		var sprite: Sprite2D = sprite_de(rol)
		if sprite == null:
			return {}
		_extras[rol] = {"sprite": sprite, "origen": sprite.position, "rotacion": sprite.rotation,
			"desplazamiento": Vector2.ZERO, "sacudida": Vector2.ZERO, "giro": 0.0}
	return _extras[rol]


## §35: desplazamiento libre (suma de capas de los componentes) de un battler que no es atacante ni defensor.
func fijar_desplazamiento_extra(rol: StringName, valor: Vector2) -> void:
	var extra: Dictionary = _extra(_rol_efectivo(rol))
	if extra.is_empty():
		return
	extra["desplazamiento"] = valor
	_aplicar_desplazamientos()


## §35: la inversión de colores del campo (sub_80E2324 → InvertPlttBuffer) solo toca el fondo, el atacante y el
## defensor: en combate doble los compañeros, que quedan bajo la capa que invierte la pantalla, llevan sus colores ya
## invertidos mientras está activa (tinte_battler.gdshader, `invertir`) y se ven con los suyos.
func fijar_preinversion(activa: bool) -> void:
	for posicion: Variant in sprites_por_posicion:
		var sprite: Variant = sprites_por_posicion[posicion]
		if not is_instance_valid(sprite) or sprite == sprite_atacante or sprite == sprite_defensor:
			continue
		var material: ShaderMaterial = _material_nativo(StringName("posicion_%d" % int(posicion)))
		if material != null:
			material.set_shader_parameter(&"invertir", 1.0 if activa else 0.0)


## §35: giro (radianes de pantalla, alrededor del centro del sprite) de un battler que no es atacante ni defensor.
func fijar_giro_extra(rol: StringName, angulo: float) -> void:
	var extra: Dictionary = _extra(_rol_efectivo(rol))
	if extra.is_empty():
		return
	extra["giro"] = angulo
	_aplicar_desplazamientos()


## Marca de un ancla: las de la escena (&"atacante", &"defensor" y sus «_base») y, §35, las de los compañeros
## (&"companero_atacante", &"companero_defensor", &"posicion_N" y sus «_base»), creadas al pedirlas en el centro o la
## base de ese battler (si no está, la del defensor).
func marca_de(ancla: StringName) -> Marker2D:
	match ancla:
		&"atacante":
			return marca_atacante
		&"atacante_base":
			return marca_atacante_base
		&"defensor_base":
			return marca_defensor_base
		&"defensor":
			return marca_defensor
	var texto: String = str(ancla)
	var es_base: bool = texto.ends_with("_base")
	var rol: StringName = StringName(texto.trim_suffix("_base"))
	var sprite: Sprite2D = sprite_de(rol) if rol != &"defensor" else null
	if sprite == null or (rol != &"companero_atacante" and rol != &"companero_defensor" and not texto.begins_with("posicion_")):
		return marca_defensor_base if es_base else marca_defensor
	if sprite == sprite_atacante:
		return marca_atacante_base if es_base else marca_atacante
	if sprite == sprite_defensor:
		return marca_defensor_base if es_base else marca_defensor
	var clave: StringName = StringName("%s%s" % [_rol_efectivo(rol), "_base" if es_base else ""])
	if not _marcas_extra.has(clave):
		var marca: Marker2D = Marker2D.new()
		marca.name = "Marca_%s" % clave
		add_child(marca)
		var posicion: int = int(str(_rol_efectivo(rol)).trim_prefix("posicion_"))
		var puntos: Array = marcas_por_posicion.get(posicion, [Vector2.ZERO, Vector2.ZERO])
		marca.position = puntos[1] if es_base else puntos[0]
		_marcas_extra[clave] = marca
	return _marcas_extra[clave]


func reproducir() -> void:
	if not animaciones_por_turno.is_empty():
		nombre_animacion = animaciones_por_turno[posmod(turno, animaciones_por_turno.size())]
	# §24: ramas del script. «_<rama>» (dato de batalla), «_t<turno>» (jumpifmoveturn) y «_rival» (rama por el
	# lado del atacante). Las escenas anteriores no tienen animaciones con estos sufijos: no cambian.
	var base: String = str(nombre_animacion)
	if rama != "" and reproductor.has_animation(StringName("%s_%s" % [base, rama])):
		nombre_animacion = StringName("%s_%s" % [base, rama])
	elif reproductor.has_animation(StringName("%s_t%d" % [base, turno])):
		nombre_animacion = StringName("%s_t%d" % [base, turno])
	var doble_elegida: StringName = _animacion_doble(nombre_animacion) if doble else &""
	if doble_elegida != &"":
		nombre_animacion = doble_elegida
	elif direccion < 0.0 and reproductor.has_animation(StringName("%s_rival" % nombre_animacion)):
		nombre_animacion = StringName("%s_rival" % nombre_animacion)
	reproductor.animation_finished.connect(_al_acabar_animacion, CONNECT_ONE_SHOT)
	reproductor.play(nombre_animacion)


## §35: variante de combate doble de `nombre` («_d<atacante><defensor>», la de esa pareja de posiciones; si no,
## «_doble_rival» con el rival atacando o «_doble»), o &"" si la escena no la tiene (vale la de individual).
func _animacion_doble(nombre: StringName) -> StringName:
	# §36: con el compañero del atacante o del objetivo ausente u oculto, «_d<A><O>_sin<posiciones>» si la escena la tiene:
	# los originales que miran IsAnimBankSpriteVisible(battler ^ 2) antes de usar el punto medio (Campana Cura, Velo
	# Sagrado, Aromaterapia, Vozarrón, Aire Afilado) vuelven entonces a la geometría de un solo battler.
	var faltan: String = ""
	for posicion: int in [mini(posicion_atacante ^ 2, posicion_defensor ^ 2), maxi(posicion_atacante ^ 2, posicion_defensor ^ 2)]:
		if posicion != posicion_atacante and posicion != posicion_defensor and _sprite_posicion(posicion) == null \
				and not faltan.contains(str(posicion)):
			faltan += str(posicion)
	if not faltan.is_empty():
		var sin_companero: StringName = StringName("%s_d%d%d_sin%s" % [nombre, posicion_atacante, posicion_defensor, faltan])
		if reproductor.has_animation(sin_companero):
			return sin_companero
	var par: StringName = StringName("%s_d%d%d" % [nombre, posicion_atacante, posicion_defensor])
	if reproductor.has_animation(par):
		return par
	var lado: StringName = StringName("%s_doble%s" % [nombre, "_rival" if direccion < 0.0 else ""])
	if reproductor.has_animation(lado):
		return lado
	return &""


## Pista de método: fin visual. Restaura los sprites y emite `terminado`; el
## audio que quede sigue sonando hasta el final de la animación.
func terminar() -> void:
	_finalizar()


## Corta en seco (también el audio): restaura los sprites, emite `terminado`
## y libera la escena.
func cancelar() -> void:
	reproductor.stop()
	_finalizar()
	queue_free()


## Corta las escenas que mueven el sprite de `slot` (nuevo ocupante, KO o salida
## del árbol), como hace la VM con `BattleSubstitutePresentation.retire`: si no,
## al terminar devolverían el sprite a la posición del ocupante anterior.
static func cancelar_en_slot(slot: BattleSlot) -> void:
	if not is_instance_valid(slot) or not slot.is_inside_tree() or not is_instance_valid(slot.sprite_pokemon):
		return
	for nodo: Node in slot.get_tree().get_nodes_in_group(GRUPO_ACTIVAS):
		var efecto: EfectoMovimientoNativo = nodo as EfectoMovimientoNativo
		if efecto == null or efecto.is_queued_for_deletion():
			continue
		# §35: también si mueve a ese battler como compañero.
		if slot.sprite_pokemon in [efecto.sprite_atacante, efecto.sprite_defensor] or slot.sprite_pokemon in efecto.sprites_por_posicion.values():
			efecto.cancelar()


func _al_acabar_animacion(_nombre: StringName) -> void:
	_finalizar()
	queue_free()


## Pista de método: instante visual del golpe.
func emitir_impacto() -> void:
	impacto_visual.emit()


## Pista de método: AnimTask_ShakeMon del original. Aplica el desplazamiento,
## lo alterna con 0 `veces` veces (el primer cambio tras `retardo` frames, los
## siguientes cada `retardo + 1`) y termina en 0.
## `sin_primer_frame`: la tarea creada a mitad de script corre dos veces en su
## primer frame y el desplazamiento inicial no llega a verse (medido en la ROM);
## se pone la clave un frame antes y se omite ese primer frame.
func sacudir(rol: StringName, desplazamiento: Vector2, veces: int, retardo: int = 1, sin_primer_frame: bool = false) -> void:
	var tween: Tween = _crear_tween()
	_fijar_sacudida(rol, Vector2.ZERO if sin_primer_frame else desplazamiento)
	for i: int in veces:
		tween.tween_interval((retardo if i == 0 else retardo + 1) * FRAME)
		var activo: bool = i % 2 == 1 and i < veces - 1
		tween.tween_callback(_fijar_sacudida.bind(rol, desplazamiento if activo else Vector2.ZERO))


## Pista de método: `invisible` del sprite del atacante en el original (lo
## ocultan las animaciones de carga de Vuelo/Bote/Buceo/Excavar y lo muestran
## las de ataque al reaparecer). Con proyección de batalla se escribe a través
## de ella; sin ella (comparador, combates sin ocultación) la escena lo
## restaura al terminar.
func fijar_visible_atacante(valor: bool) -> void:
	if not _configurado or _terminado or not is_instance_valid(sprite_atacante):
		return
	if proyeccion_oculta != null:
		proyeccion_oculta.write(valor)
		return
	if not _visibilidad_propia:
		_visibilidad_propia = true
		_visible_original = sprite_atacante.visible
	sprite_atacante.visible = valor


## Pista de método: AnimTask_ShakeMon2 del original. Aplica `desplazamiento`
## y lo alterna con su opuesto `veces` veces (el primer cambio tras `retardo`
## frames, los siguientes cada `retardo + 1`); el último cambio vuelve a 0.
## `sin_primer_frame`: como en sacudir().
func sacudir_alterna(rol: StringName, desplazamiento: Vector2, veces: int, retardo: int = 1, sin_primer_frame: bool = false) -> void:
	var cambios: Dictionary = {}
	for k: int in range(1, veces + 1):
		cambios[retardo + (k - 1) * (retardo + 1)] = k
	_fijar_sacudida(rol, Vector2.ZERO if sin_primer_frame else desplazamiento)
	var paso: Callable = func(i: int) -> void:
		if cambios.has(i):
			var k: int = cambios[i]
			_fijar_sacudida(rol, Vector2.ZERO if k == veces else (desplazamiento if k % 2 == 0 else -desplazamiento))
	_cada_frame(retardo + (veces - 1) * (retardo + 1), paso)


## Pista de método: AnimTask_ShakeMonInPlace del original. Pasa a
## -`desplazamiento` en este frame y alterna con +`desplazamiento` cada
## `retardo + 1` frames hasta completar `veces` cambios; después vuelve a 0.
func sacudir_en_sitio(rol: StringName, desplazamiento: Vector2, veces: int, retardo: int = 1) -> void:
	_fijar_sacudida(rol, -desplazamiento)
	var paso: Callable = func(i: int) -> void:
		var cambio: int = i / (retardo + 1) + 1
		if i == 0 or i % (retardo + 1) != 0:
			return
		if cambio >= veces:
			_fijar_sacudida(rol, Vector2.ZERO)
		else:
			_fijar_sacudida(rol, desplazamiento if cambio % 2 == 0 else -desplazamiento)
	_cada_frame((veces - 1) * (retardo + 1), paso)


## Pista de método: tarea de mezcla de paleta del original (sub_80E2A38 y
## similares). Lleva el tinte del `rol` (&"atacante", &"defensor" o &"fondo")
## de `desde` a `hasta` dieciseisavos hacia `color`: un paso cada
## `retardo + 1` frames, el primero tras `retardo` frames.
func mezclar_paleta(rol: StringName, color: Color, desde: int, hasta: int, retardo: int = 1) -> void:
	var paso: int = signi(hasta - desde)
	var pasos: int = absi(hasta - desde)
	var aplicar: Callable = func(i: int) -> void:
		if i >= retardo and (i - retardo) % (retardo + 1) == 0:
			fijar_tinte(rol, color, (desde + paso * ((i - retardo) / (retardo + 1))) / 16.0)
	_cada_frame(retardo + pasos * (retardo + 1), aplicar)


## Tiñe un battler (o el fondo) hacia `color` en proporción `cantidad`
## (BlendPalette). Mientras dura la animación el sprite usa un material propio
## (tinte_battler.gdshader) y al terminar recupera el suyo: el shader de
## batalla ignora `modulate`, así que la opacidad (alfa_atacante) también va aquí.
func fijar_tinte(rol: StringName, color: Color, cantidad: float) -> void:
	if not _configurado or _terminado:
		return
	if rol == &"fondo":
		if fondo != null:
			fondo.fijar_velo(color, cantidad)
		return
	rol = _rol_efectivo(rol)
	if rol == &"":
		return
	var material: ShaderMaterial = _material_nativo(rol)
	if material != null:
		material.set_shader_parameter(&"color_tinte", color)
		material.set_shader_parameter(&"cantidad", cantidad)


func _material_nativo(rol: StringName) -> ShaderMaterial:
	var sprite: Sprite2D = sprite_de(rol)
	if not is_instance_valid(sprite):
		return null
	if not _materiales.has(rol):
		_materiales[rol] = [sprite, sprite.material]
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER_TINTE
		sprite.material = material
	return (_materiales[rol] as Array)[0].material as ShaderMaterial if is_instance_valid((_materiales[rol] as Array)[0]) else null


## Recorta el atacante por debajo de la línea `y` del campo (coordenadas de
## esta escena), como la ventana de scanline de Excavar; INF lo desactiva. La
## línea queda fija en el campo aunque el sprite se mueva.
func recortar_atacante(y: float) -> void:
	_recorte_atacante = y
	_aplicar_recorte()


func _aplicar_recorte() -> void:
	if not _configurado or _terminado or not is_instance_valid(sprite_atacante) or is_inf(_recorte_atacante) and not _materiales.has(&"atacante"):
		return
	var material: ShaderMaterial = _material_nativo(&"atacante")
	if material == null:
		return
	var limite: float = 100000.0
	if not is_inf(_recorte_atacante):
		limite = sprite_atacante.to_local(to_global(Vector2(0.0, _recorte_atacante))).y
	material.set_shader_parameter(&"limite_inferior", limite)


## Escalas por frame de una animación afín del original (AFFINEANIMCMD_FRAME):
## `inicial` en unidades de la GBA (0x100 = tamaño normal) y `pasos` como
## [[dx, dy, frames], ...] sumados una vez por frame. Devuelve la escala de
## Godot del frame 0 al último; después se mantiene la última.
static func escalas_afines(inicial: Vector2, pasos: Array) -> Array[Vector2]:
	var escala: Vector2 = inicial
	var resultado: Array[Vector2] = [escala / 256.0]
	for paso: Array in pasos:
		for i: int in int(paso[2]):
			escala += Vector2(paso[0], paso[1])
			resultado.append(escala / 256.0)
	return resultado


## z_index absoluto efectivo de un CanvasItem (suma los relativos de sus padres).
static func z_absoluto(item: CanvasItem) -> int:
	var total: int = 0
	var nodo: Node = item
	while nodo is CanvasItem:
		total += (nodo as CanvasItem).z_index
		if not (nodo as CanvasItem).z_as_relative:
			break
		nodo = nodo.get_parent()
	return total


## Llama `paso(i)` una vez por frame con i = 0..frames (0 en este mismo
## frame), como los callbacks por frame de sprites y tareas del original, y
## al acabar `fin` si se pasa. El retardo de un frame compensa que el primer
## paso de un Tween creado desde el AnimationPlayer se consume en el frame actual.
func _cada_frame(frames: int, paso: Callable, fin: Callable = Callable()) -> void:
	paso.call(0)
	if frames <= 0:
		if fin.is_valid():
			fin.call()
		return
	var ultimo: Array[int] = [0]
	var avanzar: Callable = func(t: float) -> void:
		var i: int = roundi(t)
		while ultimo[0] < i:
			ultimo[0] += 1
			paso.call(ultimo[0])
	var tween: Tween = _crear_tween()
	tween.tween_method(avanzar, 0.0, float(frames), frames * FRAME).set_delay(FRAME)
	if fin.is_valid():
		tween.tween_callback(fin)


## Tween ligado a la escena: se mata al cancelar o liberar.
func _crear_tween() -> Tween:
	var tween: Tween = create_tween()
	_tweens.append(tween)
	return tween


## Duplica una plantilla oculta de la escena (sprite authored en el editor).
func _instanciar_plantilla(plantilla: CanvasItem) -> CanvasItem:
	var copia: CanvasItem = plantilla.duplicate() as CanvasItem
	copia.visible = true
	add_child(copia)
	_efectos.append(copia)
	if copia is AnimatedSprite2D:
		(copia as AnimatedSprite2D).play()
	return copia


func _fijar_sacudida(rol: StringName, valor: Vector2) -> void:
	if rol == &"atacante":
		_sacudida_atacante = valor
	elif not _es_rol_extra(rol):
		_sacudida_defensor = valor    # cualquier otro rol, el defensor (como antes de §35)
	else:
		# §35: compañeros; sin battler, nada (el original destruye la tarea).
		var efectivo: StringName = _rol_efectivo(rol)
		if efectivo == &"":
			return
		if efectivo == &"atacante":
			_sacudida_atacante = valor
		elif efectivo == &"defensor":
			_sacudida_defensor = valor
		else:
			var extra: Dictionary = _extra(efectivo)
			if extra.is_empty():
				return
			extra["sacudida"] = valor
	_aplicar_desplazamientos()


static func _es_rol_extra(rol: StringName) -> bool:
	return rol == &"companero_atacante" or rol == &"companero_defensor" or str(rol).begins_with("posicion_")


func _aplicar_desplazamientos() -> void:
	if not _configurado or _terminado:
		return
	if is_instance_valid(sprite_atacante):
		var posicion: Vector2 = _origen_atacante + desplazamiento_atacante + _sacudida_atacante + Vector2(avance_atacante * direccion, 0.0)
		if giro_atacante != 0.0 or sprite_atacante.rotation != _rotacion_atacante:
			# Gira alrededor del centro del sprite (el de batalla no está centrado).
			var giro: float = giro_atacante * direccion
			var centro: Vector2 = sprite_atacante.get_rect().get_center() * sprite_atacante.scale
			sprite_atacante.rotation = _rotacion_atacante + giro
			posicion += centro - centro.rotated(giro)
		sprite_atacante.position = posicion
		if not is_inf(_recorte_atacante):
			_aplicar_recorte()
	if is_instance_valid(sprite_defensor):
		var posicion_d: Vector2 = _origen_defensor + desplazamiento_defensor + _sacudida_defensor
		if giro_defensor != 0.0 or sprite_defensor.rotation != _rotacion_defensor:
			var centro_d: Vector2 = sprite_defensor.get_rect().get_center() * sprite_defensor.scale
			sprite_defensor.rotation = _rotacion_defensor + giro_defensor
			posicion_d += centro_d - centro_d.rotated(giro_defensor)
		sprite_defensor.position = posicion_d
	_aplicar_extras()


## §35: posición (y giro) de los compañeros que la escena mueve.
func _aplicar_extras() -> void:
	for extra: Dictionary in _extras.values():
		var sprite: Sprite2D = extra.sprite
		if not is_instance_valid(sprite) or sprite == sprite_atacante or sprite == sprite_defensor:
			continue
		var posicion: Vector2 = (extra.origen as Vector2) + (extra.desplazamiento as Vector2) + (extra.sacudida as Vector2)
		var giro: float = float(extra.giro)
		if giro != 0.0 or sprite.rotation != float(extra.rotacion):
			var centro: Vector2 = sprite.get_rect().get_center() * sprite.scale
			sprite.rotation = float(extra.rotacion) + giro
			posicion += centro - centro.rotated(giro)
		sprite.position = posicion


func _aplicar_alfa() -> void:
	if not _configurado or _terminado or not is_instance_valid(sprite_atacante):
		return
	var material: ShaderMaterial = _material_nativo(&"atacante")
	if material != null:
		material.set_shader_parameter(&"alfa", alfa_atacante)


## Reproductores de audio con paneo fijo (playsewithpan / playse del original):
## «SonidoAtacante» en el lado del atacante, «SonidoDefensor» en el del
## defensor y cualquier otro distinto de «Sonido» en el centro.
func _colocar_sonidos_fijos() -> void:
	for hijo: Node in get_children():
		if hijo is AudioStreamPlayer2D and hijo != sonido:
			var lado: float = 0.0
			if str(hijo.name).ends_with("Defensor"):
				lado = direccion
			elif str(hijo.name).ends_with("Atacante"):
				lado = -direccion
			(hijo as AudioStreamPlayer2D).position = Vector2(tamano_campo.x * (0.5 + 0.5 * lado), tamano_campo.y * 0.5)


func _aplicar_paneo() -> void:
	if not _configurado or not is_instance_valid(sonido):
		return
	# Mismo criterio que la VM: el paneo ±1 va a los bordes del campo.
	sonido.position = Vector2(tamano_campo.x * (0.5 + paneo * direccion * 0.5), tamano_campo.y * 0.5)


func _restaurar_sprites() -> void:
	if is_instance_valid(sprite_atacante):
		sprite_atacante.position = _origen_atacante
		sprite_atacante.rotation = _rotacion_atacante
		if _visibilidad_propia:
			sprite_atacante.visible = _visible_original
	if is_instance_valid(sprite_defensor):
		sprite_defensor.position = _origen_defensor
		sprite_defensor.rotation = _rotacion_defensor
	# §35: los compañeros que se movieron vuelven a su sitio.
	for extra: Dictionary in _extras.values():
		var sprite_extra: Sprite2D = extra.sprite
		if is_instance_valid(sprite_extra) and sprite_extra != sprite_atacante and sprite_extra != sprite_defensor:
			sprite_extra.position = extra.origen
			sprite_extra.rotation = extra.rotacion
	_extras.clear()
	# Devuelve su material a cada sprite (solo si sigue teniendo el nuestro).
	for par: Array in _materiales.values():
		var sprite: Variant = par[0]
		if is_instance_valid(sprite) and (sprite as Sprite2D).material is ShaderMaterial 				and ((sprite as Sprite2D).material as ShaderMaterial).shader == SHADER_TINTE:
			(sprite as Sprite2D).material = par[1]
	_materiales.clear()
	if fondo != null:
		fondo.visible = false


func _finalizar() -> void:
	if _terminado:
		return
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	# Efectos que seguían en vuelo: sin sus Tweens se quedarían congelados.
	for efecto: Variant in _efectos:
		if is_instance_valid(efecto):
			(efecto as Node).queue_free()
	_efectos.clear()
	if _configurado:
		_restaurar_sprites()
	_terminado = true
	terminado.emit()


func _exit_tree() -> void:
	# Liberada a medias (cambio de escena, cancelación externa): no dejar sprites movidos.
	if not _terminado:
		_finalizar()
