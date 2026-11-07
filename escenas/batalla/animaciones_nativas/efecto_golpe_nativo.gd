extends EfectoMovimientoNativo
class_name EfectoGolpeNativo
## Componentes reutilizables de las familias de golpes (lote C y siguientes): cada uno es un
## método que se llama desde una pista de método del AnimationPlayer y describe la intención
## («embestida de 16 px en 4 frames», «hit splat en (0, -8) durante 10 frames», «tinte del
## fondo a negro 10/16 durante 4 frames»…). Los desplazamientos que se solapan se suman por
## capas; las sacudidas usan las de EfectoMovimientoNativo.
##
## Convenciones: los frames son de 60 Hz contados desde la clave (el frame de la clave es el
## 0). Las posiciones y desplazamientos se escriben para el caso «ataca el jugador» y se
## reflejan en x cuando ataca el rival (`direccion`); los giros, en radianes de pantalla, igual.
## Escenas que lo usan: golpes_contacto.tscn, multigolpe.tscn.

## Plantillas ocultas de la escena: hit splat semitransparente (mezcla GBA) y opaco.
@onready var plantilla_golpe: Sprite2D = get_node_or_null(^"Golpe") as Sprite2D
@onready var plantilla_golpe_opaco: Sprite2D = get_node_or_null(^"GolpeOpaco") as Sprite2D
## Material de semitransparencia GBA (mezcla_gba.gdshader) para los sprites de efecto con
## objMode 1 cuando el script usa setalpha.
@export var material_mezcla: ShaderMaterial
## Con el rival atacando, sprite_efecto() (y los volteos de disparo(), recorrido() y ciclo_sprite()) voltean
## la imagen en horizontal, como el caso jugador reflejado. En el original solo la voltean los callbacks que
## miran el lado: las escenas que lo traducen así (R2, §27) lo ponen a false y escriben el volteo de esos
## pocos en su animación «_rival». Por defecto (true) no cambia nada.
@export var voltear_imagen_con_lado: bool = true

const SHADER_BRILLO: Shader = preload("res://escenas/batalla/animaciones_nativas/brillo_metalico.gdshader")

## Rol -> [sprite, escala original] mientras escalar() lo deforma.
var _escalas: Dictionary = {}
## Rol -> [sprite, material original] mientras lleva el material del brillo metálico.
var _materiales_brillo: Dictionary = {}
## Rol (&"atacante"/&"defensor") -> {capa: Vector2}.
var _capas: Dictionary = {&"atacante": {}, &"defensor": {}}


## Multigolpe: si la escena tiene «<animación>_par» e «<animación>_impar», elige por el turno
## (gAnimMoveTurn par/impar, como choosetwoturnanim).
func reproducir() -> void:
	var rama: StringName = StringName("%s_%s" % [nombre_animacion, "par" if posmod(turno, 2) == 0 else "impar"])
	if reproductor.has_animation(rama):
		nombre_animacion = rama
	super.reproducir()


## Hit splat (gBasicHitSplatSpriteTemplate y variantes) en `ancla` (&"atacante", &"defensor"
## o &"defensor_base") + `posicion`, durante `frames`. `parpadeo`: se ve un frame sí y otro no,
## empezando oculto (83DB538). `mezcla`: semitransparente (setalpha 12, 8).
func golpe(ancla: StringName, posicion: Vector2, escala: float, frames: int, parpadeo: bool = false, mezcla: bool = true) -> void:
	var plantilla: Sprite2D = plantilla_golpe if mezcla or plantilla_golpe_opaco == null else plantilla_golpe_opaco
	var copia: Sprite2D = _instanciar_plantilla(plantilla) as Sprite2D
	copia.position = to_local(_marca(ancla).global_position) + Vector2(posicion.x * direccion, posicion.y)
	copia.scale = Vector2(escala, escala)
	copia.visible = not parpadeo
	var paso: Callable = func(i: int) -> void:
		if parpadeo:
			copia.visible = i % 2 == 1
	_cada_frame(frames, paso, copia.queue_free)


## Sprite quieto de una plantilla de la escena (`plantilla`: nodo oculto, p. ej. «Puno») en
## `ancla` + `posicion` durante `frames` (AnimBasicFistOrFoot, sub_80D9B48).
func sprite_fijo(plantilla: NodePath, ancla: StringName, posicion: Vector2, frames: int) -> void:
	var copia: Node2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Node2D
	copia.position = to_local(_marca(ancla).global_position) + Vector2(posicion.x * direccion, posicion.y)
	if direccion < 0.0 and copia is Sprite2D:
		(copia as Sprite2D).flip_h = not (copia as Sprite2D).flip_h
	var nada: Callable = func(_i: int) -> void:
		pass
	_cada_frame(frames, nada, copia.queue_free)


## Sprite que va en línea recta de `ancla` + `desde` a `ancla` + `hasta` en `frames` (el
## cuerno de sub_80CE670). Se refleja con el lado. `voltear_v`: además, volteado en vertical (el
## cuerno del rival usa la matriz 24 del original, volteo horizontal y vertical).
func proyectil(plantilla: NodePath, ancla: StringName, desde: Vector2, hasta: Vector2, frames: int, voltear_v: bool = false) -> void:
	var copia: Node2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Node2D
	var origen: Vector2 = to_local(_marca(ancla).global_position)
	var a: Vector2 = origen + _reflejar(desde)
	var b: Vector2 = origen + _reflejar(hasta)
	if direccion < 0.0 and copia is Sprite2D:
		(copia as Sprite2D).flip_h = not (copia as Sprite2D).flip_h
	if voltear_v and copia is Sprite2D:
		(copia as Sprite2D).flip_v = not (copia as Sprite2D).flip_v
	copia.position = a
	var mover: Callable = func(i: int) -> void:
		copia.position = a.lerp(b, minf(1.0, (i + 1.0) / frames)).floor()
	_cada_frame(frames, mover, copia.queue_free)


## Sprite de efecto genérico (puños, pies, garras, mandíbulas, cortes…): copia la plantilla
## `plantilla` en `desde` y la mantiene `vida` frames. Los puntos son [ancla, posición] o
## [ancla_x, posición, ancla_y] (x de una marca e y de otra, como hace a veces el original con
## las coordenadas 2/3 y 0/1). Opciones (todas
## opcionales, en frames de 60 Hz):
##   "espera": frames quieto antes de moverse; "mover": frames de recorrido lineal hasta
##   `hasta`; "pausa" + "volver": tras llegar, espera y vuelve a `desde` (o a `desde` +
##   "volver_a");
##   "velocidad"/"aceleracion": Vector2 en px/frame (trayectoria parabólica desde `desde`);
##   "arco"/"arco_vuelta": altura en px de un medio seno sobre la ida / la vuelta (negativa =
##   hacia arriba); "giro_por_frame": giro continuo en radianes por frame;
##   "onda_x"/"onda_y": [amplitud, paso por frame en unidades de 256 por vuelta] (Sin del
##   original); "orbita": [radio_x, radio_y, fase inicial, paso] (Sin en x y Cos en y);
##   "zoom": animación afín del sprite como [[escala_x, escala_y, 0]] inicial (en 1/256) seguida
##   de pasos [dx, dy, frames] sumados por frame (AFFINEANIMCMD_FRAME);
##   "cuadros" + "duraciones": fotogramas de la hoja (Sprite2D con vframes) y cuántos frames
##   dura cada uno (se queda en el último); "cuadro": fotograma fijo; "giro": giro fijo
##   (radianes, caso jugador); "voltear": refleja la imagen; "escala"; "mezcla": semitransparente
##   como la GBA; "parpadeo": [desde_frame, cada]: a partir de ese frame se oculta y muestra
##   cada `cada` frames; "conmutar": frames en los que cambia la visibilidad; "aparecer" /
##   "desaparecer": frames de fundido de opacidad al principio / al final; "subprioridad": ver
##   _prioridad(); "fijo": coordenadas de pantalla sin reflejar con el lado (desplazamientos x,
##   velocidades, ondas, órbita, giros y volteo), para los callbacks del original que suman x sin
##   mirar el lado del atacante (dientes, tajos, garras…);
##   "fase_y": fase inicial de "onda_y" (en unidades de 256 por vuelta; 64 = coseno).
func sprite_efecto(plantilla: NodePath, desde: Array, hasta: Array, vida: int, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	var fijo: bool = bool(opciones.get("fijo", false))
	# Signo x de los desplazamientos: el lado del atacante o, con "fijo", siempre el del jugador.
	var dx: float = 1.0 if fijo else direccion
	var a: Vector2 = _punto(desde, fijo)
	var b: Vector2 = _punto(hasta, fijo) if not hasta.is_empty() else a
	var espera: int = int(opciones.get("espera", 0))
	var mover: int = int(opciones.get("mover", 0))
	var pausa: int = int(opciones.get("pausa", 0))
	var vuelta: int = int(opciones.get("volver", 0))
	var c: Vector2 = a + _reflejar(opciones.get("volver_a", Vector2.ZERO), fijo)
	var velocidad: Vector2 = _reflejar(opciones.get("velocidad", Vector2.ZERO), fijo)
	var aceleracion: Vector2 = _reflejar(opciones.get("aceleracion", Vector2.ZERO), fijo)
	var onda_x: Array = opciones.get("onda_x", [])
	var onda_y: Array = opciones.get("onda_y", [])
	var fase_y: float = float(opciones.get("fase_y", 0.0))
	var orbita: Array = opciones.get("orbita", [])
	var zoom: Array = _zoom_afin(opciones.get("zoom", []))
	var arco: float = float(opciones.get("arco", 0.0))
	var arco_vuelta: float = float(opciones.get("arco_vuelta", 0.0))
	var giro_por_frame: float = float(opciones.get("giro_por_frame", 0.0))
	var cuadros: Array = opciones.get("cuadros", [])
	var duraciones: Array = opciones.get("duraciones", [])
	var parpadeo: Array = opciones.get("parpadeo", [])
	var conmutar: Array = opciones.get("conmutar", [])
	var aparecer: int = int(opciones.get("aparecer", 0))
	var desaparecer: int = int(opciones.get("desaparecer", 0))
	if opciones.has("cuadro"):
		copia.frame = int(opciones.cuadro)
	if bool(opciones.get("voltear", false)) != (dx < 0.0 and voltear_imagen_con_lado):
		copia.flip_h = not copia.flip_h
	if bool(opciones.get("voltear_v", false)):
		copia.flip_v = not copia.flip_v
	copia.rotation = float(opciones.get("giro", 0.0)) * dx
	copia.scale = Vector2.ONE * float(opciones.get("escala", 1.0))
	if bool(opciones.get("mezcla", false)) and material_mezcla != null:
		copia.material = material_mezcla
	_prioridad(copia, opciones)
	copia.position = a
	var paso: Callable = func(i: int) -> void:
		var p: Vector2 = a
		if velocidad != Vector2.ZERO or aceleracion != Vector2.ZERO:
			var n: float = i + 1.0
			p = a + velocidad * n + aceleracion * (n * (n - 1.0) / 2.0)
		elif mover > 0 and i >= espera:
			var t: int = i - espera
			if t < mover:
				var k: float = (t + 1.0) / mover
				p = a.lerp(b, k) + Vector2(0.0, floorf(sin(PI * k) * arco))
			elif vuelta > 0 and t >= mover + pausa:
				var k2: float = minf(1.0, (t - mover - pausa + 1.0) / vuelta)
				p = b.lerp(c, k2) + Vector2(0.0, floorf(sin(PI * k2) * arco_vuelta))
			else:
				p = b
		if onda_x.size() == 2:
			p.x += floorf(sin(TAU * fmod(float(onda_x[1]) * i, 256.0) / 256.0) * float(onda_x[0])) * dx
		if onda_y.size() == 2:
			p.y += floorf(sin(TAU * fmod(float(onda_y[1]) * i + fase_y, 256.0) / 256.0) * float(onda_y[0]))
		if orbita.size() == 4:
			var fase: float = TAU * fmod(float(orbita[2]) + float(orbita[3]) * i, 256.0) / 256.0
			p += Vector2(floorf(sin(fase) * float(orbita[0])) * dx, floorf(cos(fase) * float(orbita[1])))
		if not zoom.is_empty():
			copia.scale = zoom[mini(i, zoom.size() - 1)] * float(opciones.get("escala", 1.0))
		copia.position = p.floor()
		if giro_por_frame != 0.0:
			copia.rotation = (float(opciones.get("giro", 0.0)) + giro_por_frame * (i + 1)) * dx
		if not cuadros.is_empty():
			var acumulado: int = 0
			for k: int in cuadros.size():
				acumulado += int(duraciones[k]) if k < duraciones.size() else 1
				if i < acumulado or k == cuadros.size() - 1:
					copia.frame = int(cuadros[k])
					break
		if parpadeo.size() == 2 and i >= int(parpadeo[0]):
			copia.visible = int((i - int(parpadeo[0])) / int(parpadeo[1])) % 2 == 1
		if conmutar.has(i):
			copia.visible = not copia.visible
		if aparecer > 0 or desaparecer > 0:
			var alfa: float = 1.0
			if aparecer > 0 and i < aparecer:
				alfa = float(i) / aparecer
			if desaparecer > 0 and i >= vida - desaparecer:
				alfa = minf(alfa, float(vida - i) / desaparecer)
			copia.modulate.a = alfa
	paso.call(0)
	_cada_frame(vida, paso, copia.queue_free)


## Orden de dibujo respecto a los battlers según la subprioridad OAM del original (opción
## "subprioridad" = [con el jugador atacando, con el rival atacando]): el battler del jugador
## tiene 30 y el del rival 40 (GetBattlerSpriteSubpriority) y menos va delante. Sin la opción, o
## por debajo de 30, el sprite va delante de los dos (como siempre).
## §37: con un tercer elemento (variantes contra el aliado, ver generar_golpes.subprioridad()) el sprite va detrás de
## todos los battlers.
func _prioridad(copia: CanvasItem, opciones: Dictionary) -> void:
	var sub: Array = opciones.get("subprioridad", [])
	if sub.size() >= 3:
		if int(sub[2]) == 1:
			var z_min: int = 1 << 30
			for sprite: Sprite2D in [sprite_atacante, sprite_defensor]:
				if is_instance_valid(sprite):
					z_min = mini(z_min, z_absoluto(sprite))
			for sprite: Variant in sprites_por_posicion.values():
				if is_instance_valid(sprite):
					z_min = mini(z_min, z_absoluto(sprite as CanvasItem))
			if z_min < 1 << 30:
				copia.z_as_relative = false
				copia.z_index = z_min - 1
		return
	if sub.size() < 2:
		return
	var s: int = int(sub[0] if direccion > 0.0 else sub[1])
	if s < 30 or not is_instance_valid(sprite_atacante) or not is_instance_valid(sprite_defensor):
		return
	var jugador: Sprite2D = sprite_atacante if direccion > 0.0 else sprite_defensor
	var rival: Sprite2D = sprite_defensor if direccion > 0.0 else sprite_atacante
	var z_jugador: int = z_absoluto(jugador)
	var z_rival: int = z_absoluto(rival)
	copia.z_as_relative = false
	if s >= 40:
		copia.z_index = mini(z_jugador, z_rival) - 1
	elif z_jugador > z_rival:
		copia.z_index = z_jugador - 1
	else:
		# Con los dos battlers en la misma capa (slots) no cabe un valor entre ambos: lo que
		# importa es que quede delante del rival (38 < 40), no detrás de los dos.
		copia.z_index = maxi(z_jugador, z_rival) + 1


## Pulso de tinte (AnimTask_BlendMonInAndOut): el `rol` se tiñe hacia `color` de 1/16 en
## 1/16 cada `cada` frames hasta `maximo` dieciseisavos y vuelve a 0; `veces` pulsos.
func pulso_tinte(rol: StringName, color: Color, maximo: int, cada: int, veces: int = 1) -> void:
	var pasos: int = 2 * maximo
	_cada_frame(pasos * veces * cada, func(i: int) -> void:
		if i == 0 or i % cada != 0:
			return
		var k: int = (i / cada - 1) % pasos + 1
		fijar_tinte(rol, color, (k if k <= maximo else pasos - k) / 16.0))


## Brillo metálico (sub_80E0A4C, Garra Metal y Cola Férrea): el `rol` pasa a gris y le
## cruzan franjas claras que avanzan `velocidad` px por frame durante `frames`. Con
## `restaurar` vuelve a su color al acabar; si no, se queda gris hasta restaurar_paleta().
func brillo_metalico(rol: StringName, frames: int, velocidad: float = 4.0, restaurar: bool = true) -> void:
	var material: ShaderMaterial = _material_brillo(rol)
	if material == null:
		return
	material.set_shader_parameter(&"gris", 1.0)
	material.set_shader_parameter(&"brillo", 1.0)
	var paso: Callable = func(i: int) -> void:
		material.set_shader_parameter(&"desplazamiento", velocidad * i)
	var fin: Callable = func() -> void:
		material.set_shader_parameter(&"brillo", 0.0)
		if restaurar:
			restaurar_paleta(rol)
	_cada_frame(frames, paso, fin)


## Devuelve al battler su material original tras brillo_metalico() (sub_80E0E24).
func restaurar_paleta(rol: StringName) -> void:
	if not _materiales_brillo.has(rol):
		return
	var par: Array = _materiales_brillo[rol]
	if is_instance_valid(par[0]):
		(par[0] as Sprite2D).material = par[1]
	_materiales_brillo.erase(rol)


## Temblor (83DB428 sobre gSpriteCoordOffset): los battlers de `roles` se desplazan
## `desplazamiento` y vuelven, alternando cada `periodo` frames, `veces` cambios. En la ROM
## (Garra Metal) solo se ve en el defensor.
func temblor_pantalla(roles: Array, desplazamiento: Vector2, periodo: int, veces: int) -> void:
	_cada_frame(periodo * veces, func(i: int) -> void:
		var activo: bool = i < periodo * veces and int(i / periodo) % 2 == 0
		for rol: Variant in roles:
			_fijar_capa(StringName(rol), &"temblor", desplazamiento if activo else Vector2.ZERO))


func _material_brillo(rol: StringName) -> ShaderMaterial:
	rol = _rol_efectivo(rol)    # §35: compañeros (sin battler, nada)
	if rol == &"":
		return null
	var sprite: Sprite2D = sprite_de(rol)
	if not is_instance_valid(sprite):
		return null
	if not _materiales_brillo.has(rol):
		_materiales_brillo[rol] = [sprite, sprite.material]
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER_BRILLO
		sprite.material = material
	return (_materiales_brillo[rol] as Array)[0].material as ShaderMaterial


func _restaurar_sprites() -> void:
	for rol: StringName in _materiales_brillo.keys():
		restaurar_paleta(rol)
	for par: Array in _escalas.values():
		if is_instance_valid(par[0]):
			(par[0] as Sprite2D).scale = par[1]
	_escalas.clear()
	super._restaurar_sprites()


## Escala afín del battler (AnimTask_ScaleMonAndRestore y animaciones afines de tarea):
## `pasos` = [[dx, dy, frames], ...] en unidades de 1/256 sumadas por frame desde 256; la
## escala es 256 / valor (obj_id_set_rotscale pasa el valor tal cual a la matriz: menos es más
## grande) alrededor del centro del sprite. `restaurar`: vuelve a 1 al acabar.
func escalar(rol: StringName, pasos: Array, restaurar: bool = true) -> void:
	var valores: Array = _zoom_afin([[256, 256, 0]] + pasos)
	rol = _rol_efectivo(rol)    # §35: compañeros (sin battler, nada)
	var sprite: Sprite2D = sprite_de(rol) if rol != &"" else null
	if not is_instance_valid(sprite):
		return
	if not _escalas.has(rol):
		_escalas[rol] = [sprite, sprite.scale]
	var original: Vector2 = (_escalas[rol] as Array)[1]
	var centro: Vector2 = sprite.get_rect().get_center() * original
	var aplicar: Callable = func(i: int) -> void:
		var v: Vector2 = valores[mini(i + 1, valores.size() - 1)] if i < valores.size() - 1 or not restaurar else Vector2.ONE
		var k: Vector2 = Vector2(1.0 / v.x, 1.0 / v.y)
		sprite.scale = original * k
		_fijar_capa(rol, &"escala", (centro - centro * k).floor())
	_cada_frame(valores.size() - 1, aplicar)


## Contoneo (sub_812E568, Encanto): se inclina hasta `giro` (rad, caso jugador) y se desplaza
## `desplazamiento` px en `cuarto` frames, pasa al lado contrario en 2 * `cuarto` y vuelve en
## `cuarto`; `veces` contoneos. Compensa la altura del giro como el original.
func contoneo(rol: StringName, giro: float, desplazamiento: float, cuarto: int, veces: int) -> void:
	var ciclo: int = 4 * cuarto
	_cada_frame(ciclo * veces, func(i: int) -> void:
		if i >= ciclo * veces:
			_fijar_giro(rol, 0.0, false)
			_fijar_capa(rol, &"contoneo", Vector2.ZERO)
			return
		var k: int = i % ciclo + 1
		var f: float = float(k) / cuarto if k <= cuarto else (1.0 - float(k - cuarto) / cuarto if k <= 3 * cuarto else float(k - 3 * cuarto) / cuarto - 1.0)
		_fijar_giro(rol, giro * f, true)
		_fijar_capa(rol, &"contoneo", Vector2(floorf(desplazamiento * f * direccion), 0.0)))


## Vaivén senoidal (AnimTask_SwayMon): x (o |y|) = sen(fase) * `amplitud`, con la fase
## avanzando `paso` / 65536 de vuelta por frame, durante `semiciclos` medios ciclos. En vertical
## (R4, §29) el battler del lado del jugador baja y el del lado del rival sube.
func oscilar(rol: StringName, amplitud: float, paso: int, semiciclos: int, vertical: bool = false) -> void:
	var frames: int = ceili(semiciclos * 32768.0 / paso)
	var abajo: bool = (rol == &"atacante") == (direccion > 0.0)
	_cada_frame(frames, func(i: int) -> void:
		var fase: int = (paso * (i + 1)) % 65536
		# R4 (§29): en media vuelta sin() da ~1e-16, no 0, y con el rival (amplitud negada) floorf() daba -1 px
		# donde el original (gSineTable[128] = 0) da 0: el «redondeo» del lado rival de R1.
		var s: float = 0.0 if i >= frames or fase % 32768 == 0 else sin(TAU * fase / 65536.0)
		# R1: el original niega la amplitud con el rival atacando y redondea hacia abajo ya con el signo.
		var v: float = floorf(s * amplitud * direccion)
		_fijar_capa(rol, &"oscilar", Vector2(0.0, absf(v) if abajo else -absf(v)) if vertical else Vector2(v, 0.0)))


## Dobles (sub_80CE7E0, Doble Equipo): `copias` copias semitransparentes y oscurecidas del
## atacante que oscilan en x con amplitud y velocidad crecientes y luego decrecientes
## (seno de un índice que avanza 1 cada 2 frames hasta 64), con fases separadas media vuelta.
func dobles(copias: int = 2, oscuridad: float = 11.0 / 16.0) -> void:
	var plantilla: Sprite2D = get_node_or_null(^"Estela") as Sprite2D
	if plantilla == null or not is_instance_valid(sprite_atacante):
		return
	var lista: Array = []
	for k: int in copias:
		var copia: Sprite2D = _instanciar_plantilla(plantilla) as Sprite2D
		for propiedad: StringName in [&"texture", &"centered", &"offset", &"flip_h", &"flip_v", &"hframes", &"vframes", &"frame", &"region_enabled", &"region_rect", &"scale"]:
			copia.set(propiedad, sprite_atacante.get(propiedad))
		copia.global_position = sprite_atacante.global_position
		copia.modulate = Color(1.0 - oscuridad, 1.0 - oscuridad, 1.0 - oscuridad)
		lista.append([copia, copia.position, 128.0 * k])
	var paso: Callable = func(i: int) -> void:
		var indice: int = mini(i / 2 + 1, 64)
		var s: float = sin(TAU * indice / 256.0) * 256.0
		for e: Array in lista:
			e[2] = fmod(float(e[2]) + int(s / 13.0), 256.0)
			(e[0] as Sprite2D).position = (e[1] as Vector2) + Vector2(floorf(sin(TAU * float(e[2]) / 256.0) * int(s / 6.0)), 0.0)
	var fin: Callable = func() -> void:
		for e: Array in lista:
			if is_instance_valid(e[0]):
				(e[0] as Node).queue_free()
	_cada_frame(130, paso, fin)


## Pone el battler en gris (sub_80E0E24 con 0 / sub_8079108) hasta restaurar_paleta().
func gris(rol: StringName) -> void:
	var material: ShaderMaterial = _material_brillo(rol)
	if material != null:
		material.set_shader_parameter(&"gris", 1.0)
		material.set_shader_parameter(&"brillo", 0.0)


## Lista de escalas por frame a partir de [[x, y, 0], [dx, dy, frames], ...] (1/256).
static func _zoom_afin(pasos: Array) -> Array:
	if pasos.is_empty():
		return []
	var actual: Vector2 = Vector2(float(pasos[0][0]), float(pasos[0][1]))
	var resultado: Array = [actual / 256.0]
	for k: int in range(1, pasos.size()):
		for _n: int in int(pasos[k][2]):
			actual += Vector2(float(pasos[k][0]), float(pasos[k][1]))
			resultado.append(actual / 256.0)
	return resultado


func _punto(p: Array, fijo: bool = false) -> Vector2:
	if StringName(p[0]) == &"pantalla":
		# Origen en la esquina del campo; cuando ataca el rival, en la esquina opuesta.
		return Vector2(tamano_campo.x if direccion < 0.0 and not fijo else 0.0, 0.0) + _reflejar(p[1], fijo)
	var x: Vector2 = to_local(_marca(StringName(p[0])).global_position)
	var y: Vector2 = to_local(_marca(StringName(p[2])).global_position) if p.size() > 2 else x
	return Vector2(x.x, y.y) + _reflejar(p[1], fijo)


func _marca(ancla: StringName) -> Marker2D:
	# §35: también las anclas de los compañeros (marca_de()); cualquier otra, la del defensor (como antes).
	return marca_de(ancla)


## Embestida de ida y vuelta (DoHorizontalLunge / DoVerticalDip): `desplazamiento` en `frames`,
## quieto `espera` frames y vuelta en otros `frames`.
func embestida(rol: StringName, desplazamiento: Vector2, frames: int, espera: int = 2) -> void:
	var total: int = 2 * frames + espera
	_cada_frame(total, func(i: int) -> void:
		var k: float = (i + 1.0) / frames if i < frames else (1.0 if i < frames + espera else maxf(0.0, (total - i - 1.0) / frames))
		_fijar_capa(rol, &"embestida", _reflejar(desplazamiento) * k))


## Deslizamiento lineal hasta `destino` respecto a la posición base (SlideMonToOffset).
func deslizar(rol: StringName, destino: Vector2, frames: int) -> void:
	# Paso en 1/256 de píxel truncado, como InitSpriteDataForLinearTranslation.
	var paso: Vector2 = (_reflejar(destino) * 256.0 / frames)
	paso = Vector2(int(paso.x), int(paso.y))
	_cada_frame(frames - 1, func(i: int) -> void:
		_fijar_capa(rol, &"desliz", (paso * (i + 1) / 256.0).floor()))


## Vuelta lineal a la posición base desde donde esté el battler (SlideMonToOriginalPos).
func volver(rol: StringName, frames: int) -> void:
	rol = _rol_efectivo(rol)    # §35: compañeros
	if rol == &"":
		return
	var inicio: Dictionary = (_capas.get(rol, {}) as Dictionary).duplicate()
	_cada_frame(frames, func(i: int) -> void:
		for capa: StringName in inicio:
			if capa == &"giro":
				continue
			var desde: Vector2 = inicio[capa]
			# Paso en 1/256 de píxel truncado (SlideMonToOriginalPos); en el último frame, 0.
			var paso: Vector2 = Vector2(int(-desde.x * 256.0 / frames), int(-desde.y * 256.0 / frames))
			_fijar_capa(rol, capa, Vector2.ZERO if i >= frames else desde + (paso * (i + 1) / 256.0).floor()))


## Elipse que empieza y acaba en la posición base (AnimTask_TranslateMonElliptical): radios
## `radio`, `vueltas` vueltas de `frames_vuelta` frames. `reflejar`: el sentido se invierte
## cuando ataca el rival (variante RespectSide).
func elipse(rol: StringName, radio: Vector2, vueltas: int, frames_vuelta: int, reflejar: bool = true, saltar: int = 0) -> void:
	# `saltar`: frames de la elipse que ya habrían pasado (la tarea empieza antes que la escena).
	var total: int = vueltas * frames_vuelta - saltar
	_cada_frame(total - 1, func(j: int) -> void:
		var i: int = j + saltar
		var a: float = TAU * float(i) / frames_vuelta
		# R1: con RespectSide el original niega el radio y Sin() redondea ya con el signo (1 px con el rival).
		var x: float = floorf(sin(a) * radio.x * (direccion if reflejar else 1.0))
		_fijar_capa(rol, &"elipse", Vector2(x, radio.y - floorf(cos(a) * radio.y)) if j < total - 1 else Vector2.ZERO))


## Carrerilla (AnimTask_WindUpLunge): retrocede `retroceso` px en `frames` con un arco de
## `altura` px, espera y embiste `avance` px en `frames_avance`. Se queda en el destino.
func carrerilla(rol: StringName, retroceso: float, altura: float, frames: int, espera: int, avance: float, frames_avance: int) -> void:
	_cada_frame(frames + espera + frames_avance - 1, func(i: int) -> void:
		var x: float
		var y: float = 0.0
		if i < frames:
			x = retroceso * (i + 1.0) / frames
			y = floorf(sin(PI * i / frames) * altura)
		elif i < frames + espera:
			x = retroceso
		else:
			x = retroceso + avance * (i - frames - espera + 1.0) / frames_avance
		_fijar_capa(rol, &"desliz", Vector2(floorf(x * direccion), y)))    # signo antes de redondear, como el original


## Temblor que se hunde (AnimTask_ShakeAndSinkMon): alterna 0, -a, 0, a… cada `periodo` frames
## y baja `velocidad` px por frame durante `frames`.
func hundir(rol: StringName, amplitud: float, periodo: int, velocidad: float, frames: int) -> void:
	_cada_frame(frames - 1, func(i: int) -> void:
		# La posición inicial (+a) la pisa la primera tarea antes de verse: se empieza en 0.
		var fase: int = (int(i / periodo) + 1) % 4
		var x: float = [amplitud, 0.0, -amplitud, 0.0][fase]
		_fijar_capa(rol, &"desliz", Vector2(x, floorf(velocidad * (i + 1)))))


## Vaivén asimétrico (sub_80A9058): +`a` / -`b` en x (o `a` / 0 en y), cambiando en este
## frame y después cada `periodo` frames, `veces` cambios (el último vuelve a 0). `fijo`: en pantalla, sin
## reflejar con el lado (sub_80A9058 suma x tal cual, R1).
func vaiven(rol: StringName, a: float, b: float, periodo: int, veces: int, en_y: bool = false, fijo: bool = false) -> void:
	_cada_frame(periodo * (veces - 1), func(i: int) -> void:
		if i % periodo != 0:
			return
		var k: int = i / periodo
		var valor: Vector2 = Vector2.ZERO
		if k < veces - 1:
			valor = (Vector2(0.0, a) if k % 2 == 0 else Vector2.ZERO) if en_y else Vector2((a if k % 2 == 0 else -b) * (1.0 if fijo else direccion), 0.0)
		_fijar_capa(rol, &"vaiven", valor))


## Giro del battler de `desde` a `hasta` (radianes de pantalla, caso jugador) en `frames`;
## `ida_y_vuelta` vuelve a `desde` en otros `frames`. `compensar`: lo baja |sen| * 32 px
## como sub_8078F9C para que no flote. `restaurar`: al final vuelve a 0.
func girar(rol: StringName, desde: float, hasta: float, frames: int, ida_y_vuelta: bool = false, compensar: bool = true, restaurar: bool = true) -> void:
	var total: int = frames * (2 if ida_y_vuelta else 1)
	_cada_frame(total, func(i: int) -> void:
		var angulo: float
		if i >= total and restaurar:
			angulo = 0.0
		elif i < frames or not ida_y_vuelta:
			angulo = lerpf(desde, hasta, minf(1.0, (i + 1.0) / frames))
		else:
			angulo = lerpf(hasta, desde, minf(1.0, (i - frames + 1.0) / frames))
		_fijar_giro(rol, angulo, compensar))


## Balanceo amortiguado (Azote, sub_812E860), en unidades de giro de la GBA (65536 = vuelta):
## oscila entre ±`amplitud` a `velocidad` por frame; desde el frame `frames_libres` la amplitud
## baja `amortiguacion` por frame (mínimo `minima`) durante `pasos` frames y después vuelve a 0.
## Se desplaza en x una unidad por cada 64 de giro, en sentido contrario. El original no mira el lado:
## giro y desplazamiento son los mismos en pantalla ataque quien ataque (medido con el rival, R1).
func balanceo(rol: StringName, amplitud: int, velocidad: int, frames_libres: int, amortiguacion: int, minima: int, pasos: int) -> void:
	var estado: Dictionary = {"giro": 0, "sube": true, "amplitud": amplitud}
	var total: int = frames_libres + pasos + 1
	_cada_frame(total, func(i: int) -> void:
		if i >= total:
			_fijar_giro(rol, 0.0, false)
			_fijar_capa(rol, &"balanceo", Vector2.ZERO)
			return
		var a: int = estado.amplitud
		var r: int = int(estado.giro) + (velocidad if estado.sube else -velocidad)
		# Rebote del original: al pasarse del límite se recoloca con el resto de dividir por
		# 2a (con el truncado de C), lo que a veces cambia de lado de golpe.
		if estado.sube and r >= a or not estado.sube and r <= -a:
			var diff: int = a - r
			var div: int = int(diff / float(2 * a))
			var resto: int = diff - div * 2 * a
			if div % 2 == 0:
				r = a - resto if estado.sube else resto - a
				estado.sube = not estado.sube
			else:
				r = resto - a if estado.sube else a - resto
		estado.giro = r
		# _fijar_giro() y la base reflejan el giro con `direccion`: se compensa para dejarlo fijo en pantalla.
		_fijar_giro(rol, -TAU * r / 65536.0 * direccion, true)
		_fijar_capa(rol, &"balanceo", Vector2(-float(int(r / 64.0)), 0.0))
		if i >= frames_libres - 1:
			estado.amplitud = maxi(minima, a - amortiguacion))


## Tinte de paleta del `rol` (&"atacante", &"defensor" o &"fondo") de `desde` a `hasta`
## (0..1) hacia `color`, en escalones de `escalon` cada `cada` frames.
func tinte(rol: StringName, color: Color, desde: float, hasta: float, escalon: float = 0.125, cada: int = 1) -> void:
	var pasos: int = ceili(absf(hasta - desde) / escalon)
	fijar_tinte(rol, color, desde)
	_cada_frame(pasos * cada, func(i: int) -> void:
		if i > 0 and i % cada == 0:
			fijar_tinte(rol, color, move_toward(desde, hasta, escalon * (i / cada))))


## Destello (83DB3DC): `roles` a `cantidad` hacia `color`; cada `periodo` frames alterna con
## `cantidad_2` hacia `color_2`, `veces` cambios; después todo a 0.
func destello(roles: Array, color: Color, cantidad: float, periodo: int, veces: int, color_2: Color = Color.BLACK, cantidad_2: float = 0.0) -> void:
	var aplicar: Callable = func(c: Color, k: float) -> void:
		for rol: Variant in roles:
			fijar_tinte(StringName(rol), c, k)
	aplicar.call(color, cantidad)
	_cada_frame(periodo * (veces + 1), func(i: int) -> void:
		if i == 0 or i % periodo != 0:
			return
		var k: int = i / periodo
		if k > veces:
			aplicar.call(Color.BLACK, 0.0)
		elif k % 2 == 1:
			aplicar.call(color_2, cantidad_2)
		else:
			aplicar.call(color, cantidad))


## Estela de Ataque Rápido (sub_80E2DD8): `copias` copias semitransparentes del atacante, una
## cada `intervalo` frames, cada una visible `vida` frames donde estaba el atacante.
func estela(copias: int, intervalo: int, vida: int) -> void:
	var plantilla: Sprite2D = get_node_or_null(^"Estela") as Sprite2D
	if plantilla == null:
		return
	_cada_frame((copias - 1) * intervalo, func(i: int) -> void:
		if i % intervalo != 0:
			return
		var copia: Sprite2D = _instanciar_plantilla(plantilla) as Sprite2D
		for propiedad: StringName in [&"texture", &"centered", &"offset", &"flip_h", &"flip_v", &"hframes", &"vframes", &"frame", &"region_enabled", &"region_rect", &"scale"]:
			copia.set(propiedad, sprite_atacante.get(propiedad))
		copia.global_position = sprite_atacante.global_position
		copia.visible = false
		var mostrar: Callable = func(j: int) -> void:
			copia.visible = j > 0
		_cada_frame(vida, mostrar, copia.queue_free))


func _reflejar(v: Vector2, fijo: bool = false) -> Vector2:
	return v if fijo else Vector2(v.x * direccion, v.y)


func _fijar_capa(rol: StringName, capa: StringName, valor: Vector2) -> void:
	if _es_rol_extra(rol):
		# §35: compañeros (rol canónico; sin battler, nada).
		rol = _rol_efectivo(rol)
		if rol == &"":
			return
	elif rol != &"atacante":
		rol = &"defensor"
	if not _capas.has(rol):
		_capas[rol] = {}
	var capas: Dictionary = _capas[rol]
	capas[capa] = valor
	var total: Vector2 = Vector2.ZERO
	for v: Vector2 in capas.values():
		total += v
	if rol == &"atacante":
		desplazamiento_atacante = total
	elif rol == &"defensor":
		desplazamiento_defensor = total
	else:
		fijar_desplazamiento_extra(rol, total)


func _fijar_giro(rol: StringName, angulo: float, compensar: bool) -> void:
	var efectivo: StringName = _rol_efectivo(rol) if _es_rol_extra(rol) else rol
	if efectivo == &"":
		return
	if efectivo == &"atacante":
		giro_atacante = angulo   # la base lo refleja con `direccion`
	elif efectivo == &"defensor" or not _es_rol_extra(efectivo):
		giro_defensor = angulo * direccion
	else:
		fijar_giro_extra(efectivo, angulo * direccion)    # §35: compañero, como el defensor
	_fijar_capa(rol, &"giro", Vector2(0.0, (absi(roundi(sin(angulo) * 256.0)) >> 3) if compensar else 0.0))
