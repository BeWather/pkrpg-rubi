extends EfectoParticulasNativo
class_name EfectoEstadoNativo
## Componentes de los sub-lotes de §20 (documentacion/piloto_animaciones_nativas.md): otros
## compuestos, problemas de estado, sonido y Golpe Furioso. Va en un archivo hermano para que
## efecto_particulas_nativo.gd no crezca sin control; hereda todos los componentes anteriores y añade:
##
## - sprite_estado(): sprite de efecto con movimientos que sprite_efecto() no cubre: órbita de radio
##   variable (que crece, mengua o va y vuelve como un péndulo), ruta por puntos con esperas, temblor
##   por ciclo, opacidad por claves, tinte fijo y paso por detrás del defensor según la fase.
## - cortina(): banda negra que cubre el fondo desde la izquierda (ventana WIN0 de Sorpresa).
## - ecos(): copias del battler que oscilan alternando su visibilidad (Rastreo).
## - ondular(): oscilación senoidal de un battler en una capa propia (Danza Caos).
## - zigzag(): vaivén triangular de un battler con rebote vertical (Golpe Furioso).
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador»
## reflejadas en x según `direccion`.

## Banda de la cortina (ColorRect), creada al primer uso en la capa de fondo (bajo los battlers).
var _cortina: Array[ColorRect] = []
## Copias de battlers creadas por ecos().
var _ecos: Array[Sprite2D] = []


## Sprite de efecto en `desde` ([ancla, posición] o [ancla_x, posición, ancla_y], como en
## sprite_efecto()) durante `vida` frames. El desplazamiento de cada frame es la suma de:
##   "velocidad" / "aceleracion": Vector2 en px/frame desde el frame "espera" (por defecto 0);
##   "onda_x" / "onda_y": [amplitud, paso, fase]: sen(fase + paso * i) * amplitud;
##   "orbita": {"fase", "paso", "radio": [rx, ry], "crecimiento": [cx, cy], "inicio", "pasos",
##     "rebote"}: x = sen(f) * rx, y = cos(f) * ry con f = fase + paso * k (k = 1 en el primer paso
##     de la órbita) y radio + trunc(crecimiento * k); desde el frame "inicio" y durante "pasos"
##     pasos (después se queda donde acabó); con "rebote" = L, k va y vuelve entre 0 y el paso en
##     que paso * k pasa de L (el péndulo del diablo de Beso Amoroso, sub_80D2ABC);
##   "ruta": [[destino, frames, espera, altura], ...]: tramos rectos (paso truncado en 1/256 px,
##     como TranslateAnimLinear) hasta `destino` (relativo a `desde`), con un medio seno de
##     `altura` px opcional (TranslateAnimArc), y una espera tras cada uno;
##   "temblor": [inicio, cada, [desplazamientos...]]: desde `inicio`, un desplazamiento del ciclo
##     cada `cada` frames.
##   "traslado": [ancla_destino, frames]: recta entre las anclas reales (división entera hacia cero),
##     primer paso en el frame siguiente; conserva el último paso al acabar, como la bolsa de objeto.
## Imagen: "cuadro", "cuadros"/"duraciones" (y "volteos", "tinte_ciclo", ver _animar_sprite()),
## "voltear", "voltear_v", "giro" (rad), "giro_por_frame" durante "giro_frames" frames (0 = siempre),
## "zoom" (como sprite_efecto()), "escala", "mezcla", "tinte": [color, cantidad] fijo, "tintes":
## [[[color, cantidad], ...], cada, inicio] (cambia de tinte cada `cada` frames: paletas de las notas
## de Canto), "subprioridad".
## Pantalla: "fijo" (R3, §28): la posición inicial, el desplazamiento de cada frame, el giro y la imagen no
## se reflejan con el lado (callbacks del original que suman x o giran sin mirar el lado).
## Visibilidad: "oculto_inicio" (frames), "conmutar" (frames en que cambia), "parpadeo": [desde, cada],
## "alfa": [[frame, opacidad], ...] interpolada entre claves (REG_BLDALPHA del sprite), "detras":
## [desde, hasta]: con la fase de la órbita en ese rango (1/256 de vuelta) pasa detrás del defensor.
func sprite_estado(plantilla: NodePath, desde: Array, vida: int, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	var fijo: bool = bool(opciones.get("fijo", false))
	var a: Vector2 = _punto(desde, fijo)
	var traslado: Array = opciones.get("traslado", [])
	var destino: Vector2 = _punto(traslado[0], fijo) if traslado.size() == 2 else a
	if opciones.has("cuadro"):
		copia.frame = int(opciones.cuadro)
	if bool(opciones.get("voltear", false)) != (direccion < 0.0 and voltear_imagen_con_lado and not fijo):
		copia.flip_h = not copia.flip_h
	if bool(opciones.get("voltear_v", false)):
		copia.flip_v = not copia.flip_v
	if bool(opciones.get("mezcla", false)) and material_mezcla != null:
		copia.material = material_mezcla
	var tinte: Array = opciones.get("tinte", [])
	if tinte.size() == 2:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER_TINTE
		material.set_shader_parameter(&"color_tinte", tinte[0])
		material.set_shader_parameter(&"cantidad", float(tinte[1]))
		copia.material = material
	_prioridad(copia, opciones)
	var desplazamientos: Array[Vector2] = _trayectoria(opciones, vida)
	var fases: Array[int] = _fases_orbita(opciones, vida)
	var zoom: Array = _zoom_afin(opciones.get("zoom", []))
	var escala: float = float(opciones.get("escala", 1.0))
	var giro: float = float(opciones.get("giro", 0.0))
	var giro_por_frame: float = float(opciones.get("giro_por_frame", 0.0))
	var giro_frames: int = int(opciones.get("giro_frames", 0))
	var oculto: int = int(opciones.get("oculto_inicio", 0))
	var conmutar: Array = opciones.get("conmutar", [])
	var parpadeo: Array = opciones.get("parpadeo", [])
	var alfas: Array = opciones.get("alfa", [])
	var detras: Array = opciones.get("detras", [])
	var tintes: Array = opciones.get("tintes", [])
	if tintes.size() == 3 and not (copia.material is ShaderMaterial and (copia.material as ShaderMaterial).shader == SHADER_TINTE):
		var material_ciclo: ShaderMaterial = ShaderMaterial.new()
		material_ciclo.shader = SHADER_TINTE
		copia.material = material_ciclo
	copia.scale = Vector2.ONE * escala
	var estado: Dictionary = {"visible": true}
	var colocar: Callable = func(i: int) -> void:
		var k: int = mini(i, vida - 1)
		copia.position = a + _reflejar(desplazamientos[k], fijo)
		if traslado.size() == 2:
			copia.position += _paso_traslado(destino - a, int(traslado[1]), i)
		if not zoom.is_empty():
			copia.scale = zoom[mini(i, zoom.size() - 1)] * escala
		copia.rotation = (giro + giro_por_frame * mini(i + 1, giro_frames if giro_frames > 0 else i + 1)) * (1.0 if fijo else direccion)
		_animar_sprite(copia, opciones, i)
		if conmutar.has(i):
			estado.visible = not bool(estado.visible)
		var ver: bool = bool(estado.visible) and i >= oculto
		if parpadeo.size() == 2 and i >= int(parpadeo[0]):
			ver = ver and int((i - int(parpadeo[0])) / int(parpadeo[1])) % 2 == 1
		copia.visible = ver
		if not alfas.is_empty():
			copia.modulate.a = _alfa_en(alfas, i)
		if tintes.size() == 3:
			var lista: Array = tintes[0]
			var actual: Array = lista[(int(tintes[2]) + i / maxi(1, int(tintes[1]))) % lista.size()]
			var m: ShaderMaterial = copia.material as ShaderMaterial
			m.set_shader_parameter(&"color_tinte", actual[0])
			m.set_shader_parameter(&"cantidad", float(actual[1]))
		if detras.size() == 2 and not fases.is_empty():
			var f: int = fases[k]
			_detras_del_defensor(copia, f >= int(detras[0]) and f <= int(detras[1]))
		_extra_sprite(copia, opciones, i)
	# _cada_frame() ya llama a colocar(0) en este frame (una sola vez: "conmutar" puede incluir el 0).
	_cada_frame(vida, colocar, copia.queue_free)


static func _paso_traslado(delta: Vector2, frames: int, i: int) -> Vector2:
	var n: int = maxi(1, frames)
	var paso: int = clampi(i - 1, 0, n - 1)
	return Vector2(int(delta.x * paso / n), int(delta.y * paso / n))


## Gancho por frame de sprite_estado() para opciones de las clases hijas (aquí no hace nada).
func _extra_sprite(_copia: Sprite2D, _opciones: Dictionary, _i: int) -> void:
	pass


## Desplazamiento de cada frame (caso jugador, sin reflejar) de sprite_estado().
func _trayectoria(opciones: Dictionary, vida: int) -> Array[Vector2]:
	var resultado: Array[Vector2] = []
	var espera: int = int(opciones.get("espera", 0))
	var v: Vector2 = opciones.get("velocidad", Vector2.ZERO)
	var acel: Vector2 = opciones.get("aceleracion", Vector2.ZERO)
	var onda_x: Array = opciones.get("onda_x", [])
	var onda_y: Array = opciones.get("onda_y", [])
	var orbita: Dictionary = opciones.get("orbita", {})
	var ruta: Array[Vector2] = _puntos_ruta(opciones.get("ruta", []), vida)
	var temblor: Array = opciones.get("temblor", [])
	var orbitales: Array[Vector2] = _offsets_orbita(orbita, vida)
	for i: int in vida:
		var p: Vector2 = Vector2.ZERO
		var n: float = maxf(0.0, i + 1.0 - espera)
		if v != Vector2.ZERO or acel != Vector2.ZERO:
			p += v * n + acel * (n * (n - 1.0) / 2.0)
		if onda_x.size() == 3:
			p.x += floorf(sin(TAU * posmod(int(onda_x[2]) + int(float(onda_x[1]) * i), 256) / 256.0) * float(onda_x[0]))
		if onda_y.size() == 3:
			p.y += floorf(sin(TAU * posmod(int(onda_y[2]) + int(float(onda_y[1]) * i), 256) / 256.0) * float(onda_y[0]))
		if not orbitales.is_empty():
			p += orbitales[i]
		if not ruta.is_empty():
			p += ruta[i]
		if temblor.size() == 3 and i >= int(temblor[0]):
			var ciclo: Array = temblor[2]
			p += ciclo[((i - int(temblor[0])) / maxi(1, int(temblor[1]))) % ciclo.size()]
		resultado.append(p.floor())
	if resultado.is_empty():
		resultado.append(Vector2.ZERO)
	return resultado


## Índice k de la órbita en cada frame (0 = aún no ha empezado), con ida y vuelta si hay "rebote".
func _indices_orbita(orbita: Dictionary, vida: int) -> Array[int]:
	var indices: Array[int] = []
	var inicio: int = int(orbita.get("inicio", 0))
	var pasos: int = int(orbita.get("pasos", 0))
	var paso: int = int(orbita.get("paso", 0))
	var rebote: int = int(orbita.get("rebote", 0))
	var k: int = 0
	var sentido: int = 1
	var dados: int = 0
	for i: int in vida:
		if i >= inicio and (pasos <= 0 or dados < pasos):
			k += sentido
			dados += 1
			if rebote > 0:
				if sentido > 0 and posmod(paso * k, 256) > rebote:
					sentido = -1
				elif sentido < 0 and posmod(paso * k, 256) == 0:
					sentido = 1
		indices.append(k)
	return indices


func _fases_orbita(opciones: Dictionary, vida: int) -> Array[int]:
	var orbita: Dictionary = opciones.get("orbita", {})
	var fases: Array[int] = []
	if orbita.is_empty():
		return fases
	for k: int in _indices_orbita(orbita, vida):
		fases.append(posmod(int(orbita.get("fase", 0)) + int(orbita.get("paso", 0)) * k, 256))
	return fases


func _offsets_orbita(orbita: Dictionary, vida: int) -> Array[Vector2]:
	var resultado: Array[Vector2] = []
	if orbita.is_empty():
		return resultado
	var radio: Array = orbita.get("radio", [0, 0])
	var crecimiento: Array = orbita.get("crecimiento", [0, 0])
	var inicio: int = int(orbita.get("inicio", 0))
	var indices: Array[int] = _indices_orbita(orbita, vida)
	for i: int in vida:
		if i < inicio:
			resultado.append(Vector2.ZERO)
			continue
		var k: int = indices[i]
		var f: float = TAU * posmod(int(orbita.get("fase", 0)) + int(orbita.get("paso", 0)) * k, 256) / 256.0
		var rx: float = float(radio[0]) + float(int(float(crecimiento[0]) * k))
		var ry: float = float(radio[1]) + float(int(float(crecimiento[1]) * k))
		resultado.append(Vector2(floorf(sin(f) * rx), floorf(cos(f) * ry)))
	return resultado


## Posición de cada frame de una ruta [[destino, frames, espera], ...]: tramos rectos con el paso de
## InitAnimLinearTranslation (|d| * 256 / frames truncado; el primer paso en el frame siguiente).
func _puntos_ruta(ruta: Array, vida: int) -> Array[Vector2]:
	var resultado: Array[Vector2] = []
	if ruta.is_empty():
		return resultado
	var actual: Vector2 = Vector2.ZERO
	resultado.append(actual)
	for tramo: Array in ruta:
		var destino: Vector2 = tramo[0]
		var n: int = maxi(1, int(tramo[1]))
		var paso: Vector2 = Vector2(int(absf(destino.x - actual.x) * 256.0 / n), int(absf(destino.y - actual.y) * 256.0 / n))
		var signo: Vector2 = Vector2(signf(destino.x - actual.x), signf(destino.y - actual.y))
		var altura: float = float(tramo[3]) if tramo.size() > 3 else 0.0
		for k: int in range(1, n + 1):
			var q: Vector2 = actual + Vector2(signo.x * floorf(k * paso.x / 256.0), signo.y * floorf(k * paso.y / 256.0))
			if altura != 0.0 and k < n:
				# Arco de TranslateAnimArc: medio seno de `altura` a lo largo del tramo.
				q.y += floorf(sin(TAU * float(((k * (0x8000 / n)) >> 8) & 0xFF) / 256.0) * altura)
			resultado.append(q)
		actual = resultado.back()
		for _e: int in int(tramo[2]) if tramo.size() > 2 else 0:
			resultado.append(actual)
	while resultado.size() < vida:
		resultado.append(resultado.back())
	return resultado


## Opacidad en el frame `i` de unas claves [[frame, opacidad], ...] (interpolación lineal).
static func _alfa_en(claves: Array, i: int) -> float:
	if i <= int(claves[0][0]):
		return float(claves[0][1])
	for k: int in range(1, claves.size()):
		if i <= int(claves[k][0]):
			var f0: int = int(claves[k - 1][0])
			var f1: int = int(claves[k][0])
			return lerpf(float(claves[k - 1][1]), float(claves[k][1]), float(i - f0) / maxf(1.0, f1 - f0))
	return float(claves.back()[1])


## Cortina (sub_80D1CD0, Sorpresa): una banda negra sobre el fondo de la batalla (por debajo de los
## battlers, como en la ROM: los battlers siguen viéndose) que avanza `paso` px por frame desde el
## borde izquierdo hasta cubrirlo; cerrada `cerrada` frames más, desaparece y deja el fondo en blanco
## (BlendPalettes del fondo a blanco; lo devuelve el fundido posterior del script). En la ROM el borde
## derecho de la ventana no llega a verse: solo se cierra desde la izquierda (medido).
func cortina(paso: int = 13, cerrada: int = 4) -> void:
	var padre: Node = fondo if fondo != null else self
	if _cortina.is_empty():
		var banda_nueva: ColorRect = ColorRect.new()
		banda_nueva.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banda_nueva.color = Color.BLACK
		banda_nueva.visible = false
		padre.add_child(banda_nueva)
		_cortina.append(banda_nueva)
	var banda: ColorRect = _cortina[0]
	var cierre: int = ceili(tamano_campo.x / 2.0 / paso)
	_cada_frame(cierre + cerrada + 1, func(i: int) -> void:
		if i == 0:
			return
		if i > cierre + cerrada:
			banda.visible = false
			fijar_tinte(&"fondo", Color.WHITE, 1.0)
			return
		banda.visible = true
		banda.position = Vector2.ZERO
		banda.size = Vector2(tamano_campo.x if i >= cierre else float(paso * i), tamano_campo.y))


## Ecos (sub_81316F8, Rastreo): dos copias opacas del `rol` sobre él que oscilan en x
## (cos(fase) * radio con la fase avanzando +`paso` / -`paso` por frame desde 0 y 128) y alternan su
## visibilidad cada 2 frames; tras `frames` frames el radio baja 2 px por frame hasta desaparecer.
func ecos(rol: StringName, radio: int = 24, paso: int = 16, frames: int = 60) -> void:
	var original: Sprite2D = sprite_de(rol)
	var plantilla: Sprite2D = get_node_or_null(^"Estela") as Sprite2D
	if plantilla == null or not is_instance_valid(original):
		return
	var lista: Array = []
	for k: int in 2:
		var copia: Sprite2D = _instanciar_plantilla(plantilla) as Sprite2D
		copia.material = null
		for propiedad: StringName in [&"texture", &"centered", &"offset", &"flip_h", &"flip_v", &"hframes", &"vframes", &"frame", &"region_enabled", &"region_rect", &"scale"]:
			copia.set(propiedad, original.get(propiedad))
		copia.global_position = original.global_position
		copia.visible = k == 0
		_ecos.append(copia)
		lista.append([copia, copia.position, 0 if k == 0 else 128, paso if k == 0 else -paso])
	var total: int = frames + radio / 2 + 1
	_cada_frame(total, func(i: int) -> void:
		var r: int = radio if i < frames else radio - 2 * (i - frames + 1)
		for e: Array in lista:
			var copia: Sprite2D = e[0]
			if not is_instance_valid(copia):
				continue
			if r < 0:
				copia.visible = false
				continue
			if i > 0 and i % 2 == 0:
				copia.visible = not copia.visible
			var f: int = posmod(int(e[2]) + int(e[3]) * (i + 1), 256)
			copia.position = (e[1] as Vector2) + Vector2(floorf(cos(TAU * f / 256.0) * r), 0.0), func() -> void:
		for e: Array in lista:
			if is_instance_valid(e[0]):
				(e[0] as Node).queue_free())


## Oscilación senoidal del `rol` en la capa `capa`: x = sen(paso * (i + 1)) * amplitud (paso en 1/256
## de vuelta por frame) durante `frames`; al acabar vuelve a 0. `reflejar`: con el rival atacando
## se invierte el sentido (AnimTask_TeeterDanceMovement refleja el desplazamiento de x, no el de x2).
func ondular(rol: StringName, capa: StringName, amplitud: float, paso: float, frames: int, reflejar: bool = true) -> void:
	_cada_frame(frames, func(i: int) -> void:
		var x: float = 0.0 if i >= frames else floorf(sin(TAU * fmod(paso * (i + 1), 256.0) / 256.0) * amplitud)
		_fijar_capa(rol, capa, Vector2(x * (direccion if reflejar else 1.0), 0.0)))


## Vaivén triangular (sub_80D0AB8, Golpe Furioso): el `rol` avanza `paso` px por frame durante
## `frames`, retrocede el doble y vuelve, `veces` veces; cada `cada` frames baja y sube `salto` px.
func zigzag(rol: StringName, paso: float, frames: int, veces: int, salto: float, cada: int) -> void:
	var total: int = 4 * frames * veces
	_cada_frame(total, func(i: int) -> void:
		if i >= total:
			_fijar_capa(rol, &"zigzag", Vector2.ZERO)
			return
		var j: int = i % (4 * frames) + 1
		var x: float = paso * (j if j <= frames else (2 * frames - j if j <= 3 * frames else j - 4 * frames))
		var y: float = salto if ((i + 1) / cada) % 2 == 1 else 0.0
		_fijar_capa(rol, &"zigzag", Vector2(x * direccion, y)))


func _restaurar_sprites() -> void:
	for banda: ColorRect in _cortina:
		if is_instance_valid(banda):
			banda.visible = false
	for copia: Sprite2D in _ecos:
		if is_instance_valid(copia):
			copia.queue_free()
	_ecos.clear()
	super._restaurar_sprites()
