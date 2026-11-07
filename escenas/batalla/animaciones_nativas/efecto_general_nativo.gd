extends EfectoEspecialNativo
class_name EfectoGeneralNativo
## Componentes de §32 (documentacion/piloto_animaciones_nativas.md): las animaciones que no son de movimiento
## (gBattleAnims_General, gBattleAnims_StatusConditions y gBattleAnims_Special del original: subida y bajada de
## estadísticas, problemas de estado, clima que continúa, objetos, Drenadoras, ataques futuros…). Va en un archivo
## hermano para que efecto_especial_nativo.gd no crezca; hereda todos los componentes anteriores y añade:
##
## - mascara_estadistica(): la máscara de flechas que sube o baja dentro de la silueta del battler (sub_807BB88 →
##   sub_80E3338 / sub_80E3704: BG1 en la ventana OBJ del battler, mezcla que sube, se mantiene y baja). El
##   sentido, la paleta (la estadística) y el sonido salen del argumento de la animación (`datos.argumento`, el
##   mismo que la VM recibe como source_general_argument); la duración (normal o grande) la elige la rama.
## - parar_sonidos(): `stopsound` del script (corta los efectos de sonido en curso).
## - Atacante = defensor (animaciones de estado y las generales que la batalla lanza sobre un solo battler): los
##   desplazamientos y el tinte de los dos papeles se suman sobre el mismo sprite en vez de pisarse.
## - §33: intercambio_sustituto() (sub_814151C: el battler sale de la pantalla, cambia entre muñeco y Pokémon y vuelve;
##   las imágenes, de `datos.sustituto`), robo_carrera() (AnimTask_SnatchOpposingMonMove) y robo_companero()
##   (AnimTask_SnatchPartnerMove). Ninguno confirma la imagen nueva: lo hace el llamador, como con la VM.
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador» reflejadas en x
## según `direccion`.

## Texturas de la máscara (las mismas que usa la VM): flechas que suben (1) o bajan (2), paleta 1..8.
const RUTA_MASCARA: String = "res://graficos/batalla/animaciones/stat_mask_%d_pal_%d.png"
## Paleta de la máscara por estadística (ATK, DEF, VEL, AT. ESP., DEF. ESP., PRECISIÓN, EVASIÓN, varias): la
## que carga sub_80E3338 (gBattleStatMask*_Pal) para el r2 de cada argumento de sub_807BB88.
const PALETA_MASCARA: Array[int] = [2, 1, 4, 7, 8, 3, 6, 5]
const SONIDO_SUBE: AudioStream = preload("res://Audio/SE/PRSFX- Stat Up.wav")
const SONIDO_BAJA: AudioStream = preload("res://Audio/SE/PRSFX- Stat Down.wav")


## Máscara de estadística sobre el atacante (sub_80E3338 / sub_80E3704): capa BG1 con la textura de flechas
## dentro de su silueta, que se desplaza 3 px por frame (hacia arriba si sube, hacia abajo si baja; la de bajar
## empieza con BG1_X = 64) y se mezcla con eva = n / 16, evb = (16 - n) / 16: n sube 1 cada 2 frames hasta 10
## (13 si es grande), se queda 20 (30) frames y baja igual. El primer frame solo prepara (la tarea se crea y
## cambia de función); el sonido suena con la preparación. `plantilla`: Sprite2D oculto de la escena cuya
## textura se cambia por la de la estadística.
func mascara_estadistica(plantilla: NodePath) -> void:
	var datos_mascara: Array = RamasNativas.decodificar_estadistica(int(datos.get("argumento", 15)))
	var base: Sprite2D = get_node_or_null(plantilla) as Sprite2D
	if datos_mascara.is_empty() or base == null or not _configurado or _terminado:
		return
	var baja: bool = bool(datos_mascara[1])
	var grande: bool = bool(datos_mascara[2])
	var textura: Texture2D = load(RUTA_MASCARA % [2 if baja else 1, PALETA_MASCARA[int(datos_mascara[0])]]) as Texture2D
	if textura != null:
		base.texture = textura
	var pico: int = 13 if grande else 10
	var espera: int = 30 if grande else 20
	# Frame 0: sub_807BB88 / sub_80E32E0; frame 1: sub_80E3338 (prepara y suena) y desde el siguiente sub_80E3704
	# (scroll cada frame; la mezcla cambia cada 2 frames). La capa se crea ya en la clave: su paso k se ve k + 1
	# frames después (EfectoMovimientoNativo._cada_frame()), así que el primer escalón va en k = 1 (frame 2 del
	# original, medido en la ROM) y los demás cada 2.
	var alfa: Array = [[0, 0.0, 1.0]]
	var t: int = -1
	for n: int in range(1, pico + 1):
		t += 2
		alfa.append([t, n / 16.0, (16 - n) / 16.0])
	t += espera
	for n: int in range(pico - 1, -1, -1):
		t += 2
		alfa.append([t, n / 16.0, (16 - n) / 16.0])
	mostrar_capa(plantilla, {"nombre": "MascaraEstadistica", "ventana": &"atacante",
		"desplazamiento": Vector2(64 if baja else 0, 0), "velocidad": Vector2(0, -3 if baja else 3),
		"mezcla": [0.0, 1.0], "alfa": alfa, "vida": t + 1})
	var reproductor_sonido: AudioStreamPlayer2D = get_node_or_null(^"SonidoAtacante") as AudioStreamPlayer2D
	if reproductor_sonido != null:
		reproductor_sonido.stream = SONIDO_BAJA if baja else SONIDO_SUBE
		reproductor_sonido.play()


## Saltos del scroll de una capa ya visible (mostrar_capa()): [[frame, Vector2], ...] desde este frame; en cada
## clave la capa pasa a ese desplazamiento (BG1_X / BG1_Y que la tarea cambia de golpe: la luz de Deseo Oculto).
func desplazar_capa(nombre: StringName, claves: Array) -> void:
	if claves.is_empty():
		return
	_cada_frame(int(claves.back()[0]), func(i: int) -> void:
		if not _capas_fondo.has(nombre):
			return
		var capa: CapaFondoNativa = (_capas_fondo[nombre] as Array)[0] as CapaFondoNativa
		if not is_instance_valid(capa):
			return
		for clave: Array in claves:
			if int(clave[0]) == i:
				capa.desplazamiento = clave[1])


## `stopsound` del original: corta los efectos de sonido que sigan sonando.
func parar_sonidos() -> void:
	for hijo: Node in get_children():
		if hijo is AudioStreamPlayer2D:
			(hijo as AudioStreamPlayer2D).stop()


## Atacante = defensor: un solo material de tinte para los dos papeles (si no, el segundo guardaría el primero
## como «original» y lo devolvería al acabar).
func _material_nativo(rol: StringName) -> ShaderMaterial:
	if rol == &"defensor" and _mismo_battler():
		rol = &"atacante"
	return super._material_nativo(rol)


## Atacante = defensor: los desplazamientos y sacudidas de los dos papeles se suman sobre el mismo sprite (la
## base escribe la posición del defensor después de la del atacante y la pisaría).
func _aplicar_desplazamientos() -> void:
	if not _mismo_battler():
		super._aplicar_desplazamientos()
		return
	if not _configurado or _terminado:
		return
	var posicion: Vector2 = _origen_atacante + desplazamiento_atacante + _sacudida_atacante \
		+ Vector2(avance_atacante * direccion, 0.0) + desplazamiento_defensor + _sacudida_defensor
	var giro: float = giro_atacante * direccion + giro_defensor
	if giro != 0.0 or sprite_atacante.rotation != _rotacion_atacante:
		var centro: Vector2 = sprite_atacante.get_rect().get_center() * sprite_atacante.scale
		sprite_atacante.rotation = _rotacion_atacante + giro
		posicion += centro - centro.rotated(giro)
	sprite_atacante.position = posicion


## Atacante = defensor: la subprioridad OAM ("subprioridad" = [con el jugador atacando, con el rival atacando]) se
## mide contra el battler que hay (jugador 30, rival 40): por debajo de 30 delante; de 30 a 39 detrás del jugador y
## delante del rival; desde 40 detrás de los dos. La base supone que el defensor es el otro battler.
func _prioridad(copia: CanvasItem, opciones: Dictionary) -> void:
	if not _mismo_battler():
		super._prioridad(copia, opciones)
		return
	var sub: Array = opciones.get("subprioridad", [])
	if sub.size() < 2:
		return
	var s: int = int(sub[0] if direccion > 0.0 else sub[1])
	var detras: bool = s >= 40 or (s >= 30 and direccion > 0.0)
	if detras:
		copia.z_as_relative = false
		copia.z_index = z_absoluto(sprite_atacante) - 1


func _mismo_battler() -> bool:
	return is_instance_valid(sprite_atacante) and sprite_atacante == sprite_defensor


# --- §33: sustituto y Snatch -----------------------------------------------------------------------------------

static var _posiciones_battlers: PosicionesBattlersJSON
## Imagen del atacante antes de que intercambio_sustituto() le pusiera otra durante la escena (vacía = la suya).
var _imagen_original: Dictionary = {}


## La imagen que deja un intercambio se ve en el propio battler hasta el final de la escena (Snatch sigue moviéndolo:
## la carrera y la vuelta al muñeco); los pies se quedan donde estaban (capa «imagen»). Al acabar, _restaurar_sprites()
## le devuelve la suya antes de que el llamador confirme la nueva.
func _imagen_temporal(imagen: Dictionary) -> void:
	if _imagen_original.is_empty():
		_imagen_original = _propiedades_imagen(sprite_atacante)
	var pies_antes: float = sprite_atacante.get_rect().end.y * sprite_atacante.scale.y
	_aplicar_imagen(sprite_atacante, imagen)
	var pies_despues: float = sprite_atacante.get_rect().end.y * sprite_atacante.scale.y
	var previo: Vector2 = (_capas[&"atacante"] as Dictionary).get(&"imagen", Vector2.ZERO)
	_fijar_capa(&"atacante", &"imagen", previo + Vector2(0.0, pies_antes - pies_despues))
	visibilidad_battler(&"atacante", true)


static func _propiedades_imagen(sprite: Sprite2D) -> Dictionary:
	return {"texture": sprite.texture, "flip_h": sprite.flip_h, "hframes": sprite.hframes, "vframes": sprite.vframes,
		"frame": sprite.frame, "region_enabled": sprite.region_enabled, "region_rect": sprite.region_rect}


static func _aplicar_imagen(sprite: Sprite2D, imagen: Dictionary) -> void:
	sprite.texture = imagen.get("texture", sprite.texture)
	sprite.region_enabled = bool(imagen.get("region_enabled", false))
	sprite.region_rect = imagen.get("region_rect", Rect2())
	sprite.hframes = int(imagen.get("hframes", 1))
	sprite.vframes = int(imagen.get("vframes", 1))
	sprite.frame = int(imagen.get("frame", 0))
	sprite.flip_h = bool(imagen.get("flip_h", sprite.flip_h))


func _restaurar_sprites() -> void:
	if not _imagen_original.is_empty() and is_instance_valid(sprite_atacante):
		_aplicar_imagen(sprite_atacante, _imagen_original)
	_imagen_original = {}
	super._restaurar_sprites()


## Frames de una tarea que suma `paso` px por frame a x2 hasta que x + x2 + 32 sale de 0..304 (la comparación sin
## signo del original: por la derecha o, en negativo, por la izquierda).
static func _frames_salida(x: int, paso: int) -> int:
	var x2: int = 0
	for k: int in range(1, 1000):
		x2 += paso
		if x + x2 + 32 > 304 or x + x2 + 32 < 0:
			return k
	return 1000


## Pone en `copia` la imagen `imagen` ({"texture", "flip_h", "hframes", "vframes", "frame", "region_enabled",
## "region_rect"}) con los pies donde estaban (como BattleOwnedAppearanceLease.finalize() al confirmarla).
func _poner_imagen(copia: Sprite2D, imagen: Dictionary) -> void:
	var pies: Vector2 = copia.to_global(Vector2(0.0, copia.get_rect().end.y))
	_aplicar_imagen(copia, imagen)
	copia.global_position += pies - copia.to_global(Vector2(0.0, copia.get_rect().end.y))


## Sustituto ↔ Pokémon (sub_814151C): el battler sale de la pantalla hacia su lado 5 px por frame (data[0] += 0x500),
## cambia de imagen fuera (refresh_graphics_maybe: el Pokémon con `a_pokemon`, si no el muñeco) y vuelve 5 px por
## frame hasta x2 = 0. Las dos imágenes vienen en `datos.sustituto` (el adaptador las lee del estado de presentación,
## AparienciaNativa.imagenes_sustituto()). Lo que se mueve es una copia; el battler se oculta y al acabar la escena
## vuelve con su imagen: la nueva la confirma el llamador (BattleSubstituteActionCoordinator,
## BattleSubstitutePresentation.restore_bound()), como cuando la VM se cancela. `tras_desvanecer`: después de
## General_SubstituteFade los tiles del muñeco ya están borrados: sale en blanco y vuelve el Pokémon.
func intercambio_sustituto(a_pokemon: bool, tras_desvanecer: bool) -> void:
	if not is_instance_valid(sprite_atacante) or not _configurado or _terminado:
		return
	var imagenes: Dictionary = datos.get("sustituto", {})
	var nueva: Dictionary = imagenes.get("pokemon" if a_pokemon else "sustituto", {})
	if nueva.get("texture") == null:
		nueva = {"texture": sprite_atacante.texture} if a_pokemon else \
			{"texture": TEXTURA_SUSTITUTO_ESPALDA if direccion > 0.0 else TEXTURA_SUSTITUTO_FRENTE}
	# El jugador sale por la izquierda y el rival por la derecha.
	var paso: int = -5 if direccion > 0.0 else 5
	var salida: int = _frames_salida(roundi(marca_atacante_base.position.x), paso)
	var copia: Sprite2D = _copia_de(sprite_atacante, z_absoluto(sprite_atacante))
	copia.visible = not tras_desvanecer
	visibilidad_battler(&"atacante", false)
	var origen: Array[Vector2] = [copia.position]
	_alargar(2 * salida)
	_cada_frame(2 * salida, func(i: int) -> void:
		if not is_instance_valid(copia):
			return
		var x2: int = paso * mini(i + 1, salida) if i <= salida else paso * (2 * salida - i)
		if i == salida:
			copia.position = origen[0] + Vector2(x2, 0.0)
			_poner_imagen(copia, nueva)
			origen[0] = copia.position - Vector2(x2, 0.0)
		elif i == salida + 1:
			copia.visible = true
		copia.position = origen[0] + Vector2(x2, 0.0)
		if i == 2 * salida:
			# De vuelta en su sitio: el battler pasa a enseñar la imagen nueva y la copia sobra.
			copia.visible = false
			_imagen_temporal(nueva))


## Textura de la especie del battler `rol` vista desde `lado` (PosicionesBattlersJSON.LADO_*): la especie la pone el
## adaptador en `datos` ("especie_atacante") o sale de la textura del battler.
func _textura_especie(rol: StringName, lado: StringName) -> Texture2D:
	var sprite: Sprite2D = sprite_de(rol)
	var especie: String = _especie(rol)
	var brillante: bool = is_instance_valid(sprite) and sprite.texture != null and "-shiny/" in sprite.texture.resource_path
	var ruta: String = LienzoBattlers.ruta_sprite(especie, lado, brillante)
	return load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null


func _especie(rol: StringName) -> String:
	var sprite: Sprite2D = sprite_de(rol)
	var especie: String = str(datos.get("especie_" + str(rol), ""))
	if especie.is_empty() and is_instance_valid(sprite) and sprite.texture != null:
		especie = sprite.texture.resource_path.get_file().get_basename()
	return especie


## Desfase del sprite de `especie` en `lado` (battle_positions.json): el que la batalla pasa en `datos.offset_copia`
## o, sin batalla (comparador), el del archivo.
func _offset_especie(especie: String, lado: StringName) -> Vector2:
	if datos.has("offset_copia"):
		return datos.offset_copia
	if _posiciones_battlers == null:
		_posiciones_battlers = PosicionesBattlersJSON.new()
		_posiciones_battlers.cargar()
	return Vector2(_posiciones_battlers.obtener(especie).get(lado, Vector2i.ZERO))


## Snatch contra el otro lado (AnimTask_SnatchOpposingMonMove): el que roba sale corriendo hacia el rival 8 px por
## frame hasta salir de la pantalla; una copia suya (su especie vista desde el lado del objetivo, en el sitio del
## objetivo, detrás de él si roba el jugador y delante si roba el rival) cruza la pantalla 8 px por frame desde el
## borde contrario (x = 272 o -32); después el que roba entra por el borde de su lado (x = -32 o 272) y vuelve a su
## sitio. Las cuentas son las de la tarea con las posiciones de los battlers (coordenadas 0/1 de las marcas).
func robo_carrera() -> void:
	if not is_instance_valid(sprite_atacante) or not is_instance_valid(sprite_defensor) or not _configurado or _terminado:
		return
	var lado: int = 1 if direccion > 0.0 else -1
	var x: int = roundi(marca_atacante_base.position.x)
	var x_objetivo: int = roundi(marca_defensor_base.position.x)
	var salida: int = _frames_salida(x, 8 * lado)
	var inicio_copia: int = 272 if lado > 0 else -32
	var cruce: int = _frames_salida(inicio_copia, -8 * lado)
	var lejos: int = (x + 32) if lado > 0 else (272 - x)
	var vuelta: int = ceili(lejos / 8.0)
	var total: int = salida + cruce + 1 + vuelta
	var lado_objetivo: StringName = PosicionesBattlersJSON.LADO_ENEMIGO if lado > 0 else PosicionesBattlersJSON.LADO_JUGADOR
	var textura: Texture2D = _textura_especie(&"atacante", lado_objetivo)
	var offset: Vector2 = _offset_especie(_especie(&"atacante"), lado_objetivo)
	var slot_objetivo: Node2D = sprite_defensor.get_parent() as Node2D
	var estado: Dictionary = {"copia": null, "origen": Vector2.ZERO}
	_alargar(total)
	_cada_frame(total, func(i: int) -> void:
		var x2: int = 8 * lado * mini(i + 1, salida)
		if i == salida and textura != null and slot_objetivo != null:
			var copia: Sprite2D = _copia_de(sprite_defensor, z_absoluto(sprite_defensor) + (-1 if lado > 0 else 1))
			copia.texture = textura
			copia.region_enabled = false
			copia.hframes = 1
			copia.vframes = 1
			copia.frame = 0
			copia.global_position = slot_objetivo.to_global(offset)
			estado.origen = copia.position + Vector2(inicio_copia - x_objetivo, 0.0)
			copia.position = estado.origen
			estado.copia = copia
		elif i > salida and i <= salida + cruce and estado.copia != null:
			(estado.copia as Sprite2D).position = estado.origen + Vector2(-8 * lado * (i - salida), 0.0)
		elif i == salida + cruce + 1:
			if estado.copia != null and is_instance_valid(estado.copia):
				(estado.copia as Sprite2D).visible = false
			x2 = -lejos * lado
		elif i > salida + cruce + 1:
			x2 = -lejos * lado + 8 * lado * (i - salida - cruce - 1)
			if x2 * lado >= 0:
				x2 = 0
		_fijar_capa(&"atacante", &"robo", Vector2(x2, 0.0)))


## Snatch hacia el compañero (AnimTask_SnatchPartnerMove, solo en dobles): el que roba va `velocidad` px por frame hasta
## la x del objetivo y vuelve a la suya.
func robo_companero(velocidad: int) -> void:
	if not is_instance_valid(sprite_atacante) or not _configurado or _terminado:
		return
	var xa: int = roundi(marca_atacante_base.position.x)
	var xt: int = roundi(marca_defensor_base.position.x)
	var paso: int = velocidad if xa <= xt else -velocidad
	var valores: Array[int] = []
	var x2: int = 0
	while true:
		x2 += paso
		valores.append(x2)
		if (paso > 0 and xa + x2 >= xt) or (paso < 0 and xa + x2 <= xt) or valores.size() > 200:
			break
	valores.append(x2)
	while true:
		x2 -= paso
		valores.append(x2)
		if (paso > 0 and x2 <= 0) or (paso < 0 and x2 >= 0) or valores.size() > 400:
			break
	valores.append(0)
	_alargar(valores.size() - 1)
	_cada_frame(valores.size() - 1, func(i: int) -> void:
		_fijar_capa(&"atacante", &"robo", Vector2(valores[mini(i, valores.size() - 1)], 0.0)))
