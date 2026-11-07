extends EfectoProyectilNativo
class_name EfectoParticulasNativo
## Componentes de los sub-lotes de proyectil_partículas de §19 (documentacion/
## piloto_animaciones_nativas.md). Va en un archivo hermano para que efecto_proyectil_nativo.gd no
## crezca sin control; hereda todos los componentes anteriores y añade:
##
## - invertir_campo(): inversión de las paletas del fondo y de los battlers (sub_80E2324), que
##   alterna en cada llamada; los sprites de efecto no se invierten.
## - deformar(): escala afín del battler interpolada por tramos (sub_8079C08 / sub_8079C74) con
##   la base del sprite anclada al suelo (sub_8079A64).
## - terremoto(): sacudida horizontal de ±amplitud cada 2 frames que se amortigua (sub_80E1864),
##   del fondo de la batalla o de los battlers.
## - chapoteo(): salto aplastándose y estirándose (AnimTask_Splash).
## - ciclo_tinte(): el battler pasa por una tabla de colores (sub_812FFE4).
## - escalonar() / parpadear(): desplazamiento por escalones y parpadeo de un battler.
## - arco_doble(): sprite que encadena dos arcos (gotas de Hidrochorro).
## - ciclo_sprite(): sprite que repite un ciclo corto de posiciones y fotogramas.
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador»
## reflejadas en x según `direccion`.

const SHADER_INVERSION: Shader = preload("res://escenas/batalla/animaciones_nativas/inversion_campo.gdshader")

## Capa de inversión (ColorRect con inversion_campo.gdshader entre dos BackBufferCopy); se crea
## la primera vez que se invierte, por debajo de los sprites de efecto.
var _inversion: Array[CanvasItem] = []
## Battler -> visibilidad original mientras parpadear() lo oculta y lo muestra.
var _visibles: Dictionary = {}
## §37: estado de la inversión de los battlers y la del fondo (invertir_campo()).
var _battlers_invertidos: bool = false
var _fondo_invertido: bool = false


## Alterna la inversión de colores del campo (fondo y battlers), como cada llamada a
## sub_80E2324(257, 257, 257) con InvertPlttBuffer. Las cajas de PS (UI) no se invierten.
## §37: `battlers` / `fondo_campo` = qué parte alterna. En el original la parte del fondo se pierde si
## un fundido de paleta del fondo está en marcha (lo reescribe desde la paleta sin fundir), y entonces
## fondo y battlers quedan desfasados (Trueno): la capa de pantalla sigue a los battlers y, si el fondo
## no coincide, FondoMovimientoNativo invierte además solo el fondo (dos inversiones = sin invertir).
func invertir_campo(battlers: bool = true, fondo_campo: bool = true) -> void:
	if battlers:
		_battlers_invertidos = not _battlers_invertidos
	if fondo_campo:
		_fondo_invertido = not _fondo_invertido
	if _inversion.is_empty():
		_crear_inversion()
	var activa: bool = _battlers_invertidos
	if (_inversion[1] as ColorRect).visible != activa:
		for capa: CanvasItem in _inversion:
			capa.visible = activa
		fijar_preinversion(activa)    # §35: en dobles los compañeros no se invierten
	if fondo != null:
		fondo.fijar_inversion(_battlers_invertidos != _fondo_invertido)


func _crear_inversion() -> void:
	var previa: BackBufferCopy = BackBufferCopy.new()
	previa.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var capa: ColorRect = ColorRect.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.size = tamano_campo
	var material_capa: ShaderMaterial = ShaderMaterial.new()
	material_capa.shader = SHADER_INVERSION
	capa.material = material_capa
	var posterior: BackBufferCopy = BackBufferCopy.new()
	posterior.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_inversion = [previa, capa, posterior]
	# Primeras hijas: los sprites de efecto (copias añadidas al final) quedan encima, sin invertir.
	for i: int in _inversion.size():
		add_child(_inversion[i])
		move_child(_inversion[i], i)
		_inversion[i].visible = false


## Escala afín del battler `rol` por `tramos` [[x0, y0, x1, y1, frames], ...] en unidades de la
## matriz de la GBA (0x100 = tamaño normal, más = más pequeño): cada tramo va de (x0, y0) a
## (x1, y1) sumando (x1 - x0) / frames truncado por frame y acaba exacto, como sub_8079C74. Un
## tramo con los mismos valores es una pausa. `anclar`: mantiene la base del sprite en el suelo
## (sub_8079A64) mientras interpola (como sub_8079C74: ni en el último frame del tramo ni en las
## pausas, salvo con un sexto elemento `true` en el tramo, que lo ancla siempre: escala fija de
## obj_id_set_rotscale + sub_8079A64). Al terminar el último tramo vuelve a tamaño normal si `restaurar`.
func deformar(rol: StringName, tramos: Array, anclar: bool = true, restaurar: bool = true) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not is_instance_valid(sprite):
		return
	if not _escalas.has(rol):
		_escalas[rol] = [sprite, sprite.scale]
	var original: Vector2 = (_escalas[rol] as Array)[1]
	var centro: Vector2 = sprite.get_rect().get_center() * original
	var base: float = _base_visible(sprite) * original.y
	var valores: Array[Vector2] = []
	var anclados: Array[bool] = []
	for tramo: Array in tramos:
		var actual: Vector2 = Vector2(float(tramo[0]), float(tramo[1]))
		var n: int = maxi(1, int(tramo[4]))
		var paso: Vector2 = Vector2(int((float(tramo[2]) - actual.x) / n), int((float(tramo[3]) - actual.y) / n))
		var interpola: bool = paso != Vector2.ZERO or Vector2(float(tramo[2]), float(tramo[3])) != actual
		var siempre: bool = tramo.size() > 5 and bool(tramo[5])
		for k: int in range(1, n + 1):
			actual = Vector2(float(tramo[2]), float(tramo[3])) if k == n else actual + paso
			valores.append(actual)
			anclados.append(siempre or interpola and k < n)
	var total: int = valores.size()
	_cada_frame(total, func(i: int) -> void:
		var fin: bool = i >= total and restaurar
		var v: Vector2 = Vector2(256.0, 256.0) if fin else valores[mini(i, total - 1)]
		_escala_anclada(rol, sprite, original, centro, base, v, 0.0, anclar and not fin and anclados[mini(i, total - 1)]))


## Aplica la escala afín `v` (unidades de la matriz) al battler alrededor de su centro, con la base
## anclada al suelo (sub_8079A64: y2 = (var - var * 256 / d) / 2, var = alto visible) y `extra_y` px.
func _escala_anclada(rol: StringName, sprite: Sprite2D, original: Vector2, centro: Vector2, base: float, v: Vector2,
		extra_y: float, anclar: bool) -> void:
	var k: Vector2 = Vector2(256.0 / v.x, 256.0 / v.y)
	sprite.scale = original * k
	var ancla: float = floorf(base - minf(base * k.y, 64.0)) if anclar else 0.0
	_fijar_capa(rol, &"escala", (centro - centro * k).floor() + Vector2(0.0, ancla + extra_y))


## Salto con chapoteo (AnimTask_Splash, Chapoteo Lodo): `veces` ciclos de aplastarse (-6/+4 por
## frame, 8 frames) bajando 3, 6… 24 px, estirarse (+10/-10, 8 frames), volver arriba 2 px por
## frame y recuperar la forma (-4/+6, 8 frames), con la base anclada.
func chapoteo(rol: StringName, veces: int) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not is_instance_valid(sprite):
		return
	if not _escalas.has(rol):
		_escalas[rol] = [sprite, sprite.scale]
	var original: Vector2 = (_escalas[rol] as Array)[1]
	var centro: Vector2 = sprite.get_rect().get_center() * original
	var base: float = _base_visible(sprite) * original.y
	var pasos: Array = [[Vector2(256.0, 256.0), 0.0]]
	for _c: int in veces:
		var e: Vector2 = Vector2(256.0, 256.0)
		var d: float = 0.0
		for _k: int in 8:
			e += Vector2(-6.0, 4.0)
			d += 3.0
			pasos.append([e, d])
		for _k: int in 8:
			e += Vector2(10.0, -10.0)
			pasos.append([e, d])
		while d > 0.0:
			d -= 2.0
			pasos.append([e, d])
		pasos.append([e, 0.0])    # el frame en que ve que ya está arriba
		for _k: int in 8:
			e += Vector2(-4.0, 6.0)
			pasos.append([e, 0.0])
		pasos.append([e, 0.0])
	var total: int = pasos.size()
	_cada_frame(total, func(i: int) -> void:
		var p: Array = pasos[i] if i < total else [Vector2(256.0, 256.0), 0.0]
		_escala_anclada(rol, sprite, original, centro, base, p[0], p[1], i < total))


## Ciclo de colores del battler (sub_812FFE4, Imagen): cada frame lo mezcla `cantidad` hacia el
## siguiente color de `colores` durante `frames` frames y luego lo deja como estaba.
func ciclo_tinte(rol: StringName, colores: Array, cantidad: float, frames: int) -> void:
	_cada_frame(frames + 1, func(i: int) -> void:
		if i == 0:
			return
		if i > frames:
			fijar_tinte(rol, Color.BLACK, 0.0)
		else:
			fijar_tinte(rol, colores[(i - 1) % colores.size()], cantidad))


## Distancia del centro del sprite a su última fila visible (px de textura), como (64 - 2 * y_offset) / 2.
func _base_visible(sprite: Sprite2D) -> float:
	var rect: Rect2 = sprite.get_rect()
	var textura: Texture2D = sprite.texture
	if textura == null:
		return rect.size.y / 2.0
	var imagen: Image = textura.get_image()
	if imagen == null:
		return rect.size.y / 2.0
	var region: Rect2i = Rect2i(sprite.region_rect) if sprite.region_enabled else Rect2i(Vector2i.ZERO, imagen.get_size())
	if sprite.hframes > 1 or sprite.vframes > 1:
		var tam: Vector2i = Vector2i(region.size.x / sprite.hframes, region.size.y / sprite.vframes)
		region = Rect2i(region.position + Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * tam, tam)
	var usado: Rect2i = imagen.get_region(region).get_used_rect()
	return float(usado.end.y) - region.size.y / 2.0


## Sacudida amortiguada (sub_80E1864): desde el segundo frame, cada 2 frames alterna + / - en x
## durante `cambios` cambios; después la amplitud baja 1 y da 4 cambios por nivel hasta 0.
## `objetivo`: &"fondo" (gBattle_BG3_X ± amplitud: el fondo de la batalla se ve desplazado al
## revés) o un rol (x2 = +techo(a / 2) / -suelo(a / 2), sub_80E1B10).
func terremoto(objetivo: StringName, amplitud: int, cambios: int) -> void:
	var desplazamiento: Callable = func(a: int, positivo: bool) -> float:
		if objetivo == &"fondo":
			return float(a if positivo else -a)
		return float(a / 2 + (a & 1)) if positivo else -float(a / 2)
	var valores: Array[float] = [0.0, 0.0]
	for k: int in cambios:
		var x: float = desplazamiento.call(amplitud, k % 2 == 0)
		valores.append_array([x, x])
	var a: int = amplitud - 1
	while a > 0:
		for k: int in 4:
			var x2: float = desplazamiento.call(a, k % 2 == 0)
			valores.append_array([x2, x2])
		a -= 1
	valores.append(0.0)
	var total: int = valores.size()
	if objetivo == &"fondo":
		var nodos: Array[Node2D] = _nodos_fondo()
		if nodos.is_empty():
			return
		_cada_frame(total, func(i: int) -> void:
			var x: float = valores[mini(i, total - 1)]
			for nodo: Node2D in nodos:
				if is_instance_valid(nodo):
					nodo.position = (_fondo_movido[nodo] as Vector2) - Vector2(x, 0.0))
	else:
		_cada_frame(total, func(i: int) -> void:
			_fijar_capa(objetivo, &"terremoto", Vector2(valores[mini(i, total - 1)], 0.0)))


## Sprite que hace dos arcos seguidos (TranslateAnimArc): de `desde` a `hasta` en `frames` con
## altura `altura` (px, negativa = hacia arriba) y después `desvio` px más allá en `frames2` con
## `altura2` (gotas de Hidrochorro, sub_80D4B3C / sub_80D4BA4). Sin paso en el frame de la clave
## (StartAnim…: el primero, el frame siguiente). Con `frames2` = 0 solo hay un arco. Opciones:
## "cuadro", "mezcla", "subprioridad"; "lento": [pasos, cada]: los primeros pasos del primer arco
## tardan `cada` frames (la bola de Presa); "giro_por_frame" (radianes, caso jugador) durante
## "giro_frames" frames; "parpadeo_final": [cambios, cada]: al acabar se queda y cambia de
## visibilidad cada `cada` frames; "voltear": [h, v] volteo de pantalla de la imagen (no se refleja con el
## lado; R2, §27: matrixNum |= 24 de las ondas de Aire Afilado con el rival).
func arco_doble(plantilla: NodePath, desde: Array, hasta: Array, frames: int, altura: float, desvio: Vector2,
		frames2: int, altura2: float, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	if opciones.has("cuadro"):
		copia.frame = int(opciones.cuadro)
	if bool(opciones.get("mezcla", false)) and material_mezcla != null:
		copia.material = material_mezcla
	var volteo: Array = opciones.get("voltear", [])
	if volteo.size() == 2:
		copia.flip_h = bool(volteo[0])
		copia.flip_v = bool(volteo[1])
	_prioridad(copia, opciones)
	var a: Vector2 = _punto(desde)
	var b: Vector2 = _punto(hasta)
	var c: Vector2 = b + _reflejar(desvio)
	var posiciones: Array[Vector2] = [a]
	var arco: Array[Vector2] = _tramo_arco(a, b, maxi(1, frames), altura)
	var lento: Array = opciones.get("lento", [])
	for k: int in arco.size():
		var repetir: int = int(lento[1]) if lento.size() == 2 and k < int(lento[0]) else 1
		for _r: int in repetir:
			posiciones.append(arco[k])
	posiciones.append(b)
	if frames2 > 0:
		posiciones.append_array(_tramo_arco(b, c, frames2, altura2))
	var quieto: int = posiciones.size()
	var final: Array = opciones.get("parpadeo_final", [])
	if final.size() == 2:
		for _k: int in int(final[0]) * int(final[1]):
			posiciones.append(posiciones[quieto - 1])
	var total: int = posiciones.size()
	var giro_por_frame: float = float(opciones.get("giro_por_frame", 0.0))
	var giro_frames: int = int(opciones.get("giro_frames", 0))
	var colocar: Callable = func(i: int) -> void:
		copia.position = posiciones[mini(i, total - 1)]
		if giro_por_frame != 0.0:
			copia.rotation = giro_por_frame * mini(i + 1, giro_frames) * direccion
		if final.size() == 2 and i >= quieto:
			copia.visible = ((i - quieto) / int(final[1])) % 2 == 0
	colocar.call(0)
	_cada_frame(total, colocar, copia.queue_free)


## Posiciones de un arco de `n` pasos (paso lineal en 1/256 px truncado y medio seno de `altura`).
static func _tramo_arco(a: Vector2, b: Vector2, n: int, altura: float) -> Array[Vector2]:
	var paso: Vector2 = Vector2(int(absf(b.x - a.x) * 256.0 / n) & ~1, int(absf(b.y - a.y) * 256.0 / n) & ~1)
	var signo: Vector2 = Vector2(signf(b.x - a.x), signf(b.y - a.y))
	var fase: int = 0x8000 / n
	var resultado: Array[Vector2] = []
	for k: int in range(1, n + 1):
		var p: Vector2 = a + Vector2(signo.x * floorf(k * paso.x / 256.0), signo.y * floorf(k * paso.y / 256.0))
		p.y += floorf(sin(TAU * float(((k * fase) >> 8) & 0xFF) / 256.0) * altura)
		resultado.append(p)
	return resultado


## Sprite que repite un ciclo de `pasos` (desplazamientos desde `desde`, uno por frame), con sus
## fotogramas "cuadros" y volteos "volteos" ([h, v]) del mismo largo, empezando en el paso `fase`,
## durante `vida` frames (líneas de viento de Remolino, sub_80DB000 / sub_80DB0A0).
func ciclo_sprite(plantilla: NodePath, desde: Array, vida: int, pasos: Array, fase: int, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	_prioridad(copia, opciones)
	var a: Vector2 = _punto(desde)
	var cuadros: Array = opciones.get("cuadros", [])
	var volteos: Array = opciones.get("volteos", [])
	var n: int = maxi(1, pasos.size())
	var colocar: Callable = func(i: int) -> void:
		var k: int = (fase + i) % n
		copia.position = a + _reflejar(pasos[k])
		if k < cuadros.size():
			copia.frame = int(cuadros[k])
		if k < volteos.size():
			copia.flip_h = bool(volteos[k][0]) != (direccion < 0.0 and voltear_imagen_con_lado)
			copia.flip_v = bool(volteos[k][1])
	colocar.call(0)
	_cada_frame(vida, colocar, copia.queue_free)


## Desplazamiento del battler `rol` en la capa `capa` por escalones: `cambios` = [[frame, Vector2],
## ...] (frames desde la clave, valores absolutos de la capa, caso jugador; se reflejan en x). Entre
## dos cambios se mantiene el último. Para las tareas que fijan x2/y2 en frames sueltos (Salpicar,
## Estallido, el arrastre de Placaje Eléctrico).
func escalonar(rol: StringName, capa: StringName, cambios: Array) -> void:
	var valores: Dictionary = {}
	var ultimo: int = 0
	for c: Array in cambios:
		valores[int(c[0])] = _reflejar(c[1])
		ultimo = maxi(ultimo, int(c[0]))
	_cada_frame(ultimo, func(i: int) -> void:
		if valores.has(i):
			_fijar_capa(rol, capa, valores[i]))


## Parpadeo del battler `rol`: cambia su visibilidad en cada frame de `cambios` (frames desde la
## clave) y al final lo deja visible (sub_80D6E9C de Placaje Eléctrico). Sin proyección de
## ocultación de la batalla; la escena lo restaura al terminar.
func parpadear(rol: StringName, cambios: Array) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not is_instance_valid(sprite):
		return
	var ultimo: int = 0
	for c: Variant in cambios:
		ultimo = maxi(ultimo, int(c))
	if not _visibles.has(sprite):
		_visibles[sprite] = sprite.visible
	_cada_frame(ultimo + 1, func(i: int) -> void:
		if not is_instance_valid(sprite):
			return
		if i > ultimo:
			sprite.visible = true
		elif cambios.has(i):
			sprite.visible = not sprite.visible)


func _restaurar_sprites() -> void:
	for sprite: Variant in _visibles.keys():
		if is_instance_valid(sprite):
			(sprite as Sprite2D).visible = _visibles[sprite]
	_visibles.clear()
	for capa: CanvasItem in _inversion:
		if is_instance_valid(capa):
			capa.visible = false
	super._restaurar_sprites()
