extends EfectoCuracionNativo
class_name EfectoFondoNativo
## Componentes de fondo de las animaciones nativas (§22 de documentacion/piloto_animaciones_nativas.md).
## Lo usan las escenas de la familia fondo_movimiento que genera generar_fondos.py. Son llamadas de
## alto nivel con parámetros legibles; nada emula registros de la GBA:
##
## - cambiar_fondo(): fadetobg / restorebg como fundido de la capa de fondo (el fondo y el suelo de la
##   batalla bajan a negro en 16 pasos, se cambia la imagen y vuelven en 16).
## - ciclar_fondo() / desplazar_fondo() / parar_fondo(): tareas que animan el fondo propio (ciclo de
##   paleta ya horneado en una hoja de fotogramas y scroll en píxeles por frame).
## - mostrar_capa() / quitar_capa(): capa superpuesta (BG1/BG2 del original) con textura, scroll,
##   repetición, mezcla con el campo, ondulación por fila y ventana con la silueta de un battler.
## - copiar_battler(): copia del battler en una capa (monbg) para ondularlo por filas o mezclarlo;
##   el original se oculta mientras tanto (opacidad 0 en su material temporal).
##
## Todas las coordenadas son del campo (240 x 160) y se escriben para «ataca el jugador».

## Nombre -> CapaFondoNativa activa (y su BackBufferCopy si mezcla con el campo).
var _capas_fondo: Dictionary = {}
## Identificadores de las tareas de fondo vivas; parar_fondo() las invalida. Un scroll nuevo sustituye
## al anterior (sigue desde donde estaba).
var _tarea_fondo: int = 0
var _tarea_scroll: int = 0
## Cambios de imagen de cambiar_fondo() aún por llegar: cada uno invalidará las tareas vivas al poner la imagen.
var _cambios_fondo: int = 0
## Concurso: las ramas de Taladro y Vuelo llaman a sub_80E3A58 con (2304, 768, 0); la animación del rival lleva
## (2304, -768), así que solo cambia el signo de la y.
var _scroll_concurso: bool = false


## fadetobg / restorebg: funde a negro el fondo de la batalla (o el propio anterior) 1/16 por frame
## durante `pasos` frames, lo mantiene `espera` frames, cambia a la textura de `plantilla` (vacía =
## vuelve el de la batalla) y aclara en `pasos - 1` frames más (medido en la ROM con Confusión: negro
## en el frame 16, imagen nueva al 15/16 en el 20 y del todo en el 35). Los battlers no se funden.
## `plantilla_rival`: la que se usa cuando ataca el rival (fadetobgfromset elige el fondo por el lado del
## objetivo).
func cambiar_fondo(plantilla: NodePath, pasos: int = 16, espera: int = 4, plantilla_rival: NodePath = NodePath("")) -> void:
	if fondo == null:
		return
	if direccion < 0.0 and not plantilla_rival.is_empty():
		plantilla = plantilla_rival
	var nodo: Sprite2D = _plantilla_de_fondo(plantilla)
	var cambio: int = pasos + espera
	_cambios_fondo += 1
	var paso: Callable = func(i: int) -> void:
		if i <= pasos:
			fondo.fijar_velo(Color.BLACK, i / 16.0)
		elif i == cambio:
			_tarea_fondo += 1
			_cambios_fondo -= 1
			# El scroll no se toca: lo fijan las tareas de fondo (centrar_fondo() puede llegar antes del cambio).
			fondo.fotograma = 0
			fondo.fijar_imagen(nodo)
			fondo.mostrar_imagen = nodo != null
		if i >= cambio:
			fondo.fijar_velo(Color.BLACK, maxf(0.0, (cambio + pasos - 1 - i) / 16.0))
	_cada_frame(cambio + pasos - 1, paso)


## Identificador de una tarea de fondo nueva. Si hay un cambio de imagen en marcha, la tarea es del fondo que viene: el
## script la crea tras waitbgfadeout, 2 frames antes de LoadMoveBg, y el cambio no debe invalidarla.
func _id_tarea_fondo() -> int:
	return _tarea_fondo + _cambios_fondo


## La plantilla `ruta`; en concurso, una copia con su BG_*_CONTESTS si lo tiene.
func _plantilla_de_fondo(ruta: NodePath) -> Sprite2D:
	var nodo: Sprite2D = null if ruta.is_empty() else get_node_or_null(ruta) as Sprite2D
	if not concurso or nodo == null or not FONDOS_CONCURSO.has(nodo.name):
		return nodo
	_scroll_concurso = nodo.name in [&"FondoTaladro", &"FondoVuelo"]
	var copia: Sprite2D = nodo.duplicate() as Sprite2D
	copia.texture = load(str(FONDOS_CONCURSO[nodo.name])) as Texture2D
	add_child(copia)
	return copia


## Ciclo del fondo propio (p. ej. sub_812C560, el ciclo de paleta del fondo psíquico, horneado en la
## hoja): avanza un fotograma cada `cada` frames, el primero tras `primero`, hasta parar_fondo().
func ciclar_fondo(cada: int, primero: int = -1) -> void:
	if fondo == null:
		return
	var id: int = _id_tarea_fondo()
	var inicio: int = cada if primero < 0 else primero
	var paso: Callable = func(i: int) -> void:
		if id == _tarea_fondo and i >= inicio and (i - inicio) % cada == 0:
			var total: int = fondo.capa_imagen.fotogramas if fondo.capa_imagen != null else 1
			fondo.fotograma = (fondo.fotograma + 1) % maxi(1, total)
	_cada_frame(FRAMES_TAREA, paso)


## Scroll continuo del fondo propio a `velocidad` píxeles por frame (en el frame k el contenido está
## desplazado floor(k · velocidad) más donde estaba, como la suma en 1/256 de sub_80E3A58), hasta
## parar_fondo() o el siguiente desplazar_fondo().
func desplazar_fondo(velocidad: Vector2) -> void:
	if fondo == null:
		return
	if _scroll_concurso:
		velocidad.y = -velocidad.y
	_tarea_scroll += 1
	var id: int = _id_tarea_fondo()
	var id_scroll: int = _tarea_scroll
	var inicial: Vector2 = fondo.desplazamiento
	var paso: Callable = func(i: int) -> void:
		if id == _tarea_fondo and id_scroll == _tarea_scroll:
			fondo.desplazamiento = inicial + (velocidad * i).floor()
	_cada_frame(FRAMES_TAREA, paso)


## Coloca el fondo propio con su punto `punto` (píxeles de la textura) sobre el centro del battler `rol`
## (sub_80E1BB0 de Fisura); se queda así hasta parar_fondo().
func centrar_fondo(rol: StringName, punto: Vector2) -> void:
	if fondo == null:
		return
	var marca: Marker2D = marca_atacante if rol == &"atacante" else marca_defensor
	fondo.desplazamiento = (punto - marca.position).floor()


## Acaba las tareas del fondo (setarg 7, -1 del original): el ciclo se queda donde está y el scroll
## vuelve a 0.
func parar_fondo() -> void:
	_tarea_fondo += 1
	if fondo != null:
		fondo.desplazamiento = Vector2.ZERO


## Muestra una capa superpuesta a partir de la plantilla `plantilla` (CapaFondoNativa o Sprite2D
## oculto de la escena). Opciones (todas opcionales):
## - "nombre": para quitar_capa() o volver a usarla (por defecto el de la plantilla);
## - "detras": entre el fondo de la batalla y los battlers (por defecto, encima de los battlers y
##   debajo de los sprites de efecto);
## - "desplazamiento": scroll inicial; "velocidad": píxeles por frame (floor(k · v));
## - "mezcla": [eva, evb] (fracciones) como REG_BLDALPHA; "alfa": [[frame, eva, evb], ...] cambios
##   de la mezcla por claves (escalones); "opacidad": opacidad normal si no hay mezcla;
## - "onda": ondulación por fila, {"amplitud": px, "periodo": filas por ciclo, "fase": filas,
##   "paso": fase que avanza por frame, "filas": [desde, hasta], "extra_ciclo": n (suma k % n píxeles en
##   el sentido del signo, el vaivén de Paranormal), "frames": duración (después, sin onda),
##   "amplitudes": [[frame, px], ...] cambios de amplitud por claves (Danza Dragón)};
## - "ventana": &"atacante" / &"defensor": solo dentro de la silueta de ese battler;
## - "fotogramas": [cada, primero]: avanza la hoja de la plantilla cada `cada` frames;
## - "vida": frames hasta quitarla (0 = hasta quitar_capa() o el final);
## - "rival": plantilla que se usa cuando ataca el rival (la textura depende del lado del objetivo);
## - "reflejar": la velocidad en x se invierte cuando ataca el rival.
func mostrar_capa(plantilla: NodePath, opciones: Dictionary = {}) -> void:
	# §36: la textura depende del lado del objetivo, no del atacante: contra el aliado, el del atacante. En individual
	# (y en dobles sin aliado) es lo mismo que «ataca el rival».
	var objetivo_en_jugador: bool = posicion_defensor % 2 == 0 if doble else direccion < 0.0
	if objetivo_en_jugador and opciones.has("rival"):
		plantilla = NodePath(str(opciones.rival))
	var base: Sprite2D = get_node_or_null(plantilla) as Sprite2D
	if base == null or not _configurado or _terminado:
		return
	var nombre: StringName = StringName(opciones.get("nombre", base.name))
	quitar_capa(nombre)
	var capa: CapaFondoNativa = CapaFondoNativa.new()
	capa.name = nombre
	capa.texture = load(str(FONDOS_CONCURSO[base.name])) as Texture2D if concurso and FONDOS_CONCURSO.has(base.name) else base.texture
	capa.fotogramas = base.vframes
	var copia_mezcla: BackBufferCopy = null
	var mezcla: Array = opciones.get("mezcla", [])
	var claves_alfa: Array = opciones.get("alfa", [])
	if not mezcla.is_empty() or not claves_alfa.is_empty():
		copia_mezcla = BackBufferCopy.new()
		copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	if bool(opciones.get("detras", false)) and fondo != null:
		if copia_mezcla != null:
			fondo.add_child(copia_mezcla)
		fondo.add_child(capa)
	else:
		if copia_mezcla != null:
			add_child(copia_mezcla)
			move_child(copia_mezcla, 0)
		add_child(capa)
		move_child(capa, 1 if copia_mezcla != null else 0)
	capa.preparar(tamano_campo)
	capa.desplazamiento = opciones.get("desplazamiento", Vector2.ZERO)
	if not mezcla.is_empty():
		capa.mezcla_gba = true
		capa.eva = float(mezcla[0])
		capa.evb = float(mezcla[1])
	capa.opacidad = float(opciones.get("opacidad", 1.0))
	if opciones.has("ventana"):
		var sprite: Sprite2D = sprite_atacante if StringName(opciones.ventana) == &"atacante" else sprite_defensor
		capa.fijar_ventana(sprite)
	_capas_fondo[nombre] = [capa, copia_mezcla]
	_efectos.append(capa)
	if copia_mezcla != null:
		_efectos.append(copia_mezcla)
	_animar_capa(capa, opciones)


## Quita la capa `nombre` si está.
func quitar_capa(nombre: StringName) -> void:
	if not _capas_fondo.has(nombre):
		return
	for nodo: Variant in _capas_fondo[nombre]:
		if is_instance_valid(nodo):
			(nodo as Node).queue_free()
	_capas_fondo.erase(nombre)


## Cambia la mezcla de una capa ya visible: [[frame, eva, evb], ...] desde este frame.
func mezclar_capa(nombre: StringName, claves: Array) -> void:
	if _capas_fondo.has(nombre) and is_instance_valid((_capas_fondo[nombre] as Array)[0]):
		_animar_capa((_capas_fondo[nombre] as Array)[0], {"alfa": claves})


## monbg con efectos de fondo: copia el battler `rol` en una capa que lo sigue y oculta el original.
## Opciones: "onda" (como en mostrar_capa(), filas locales del sprite), "margen" (píxeles libres a
## cada lado para la onda, 16 por defecto), "mezcla" y "alfa" (como en mostrar_capa()), "vida".
func copiar_battler(rol: StringName, opciones: Dictionary = {}) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not _configurado or _terminado or not is_instance_valid(sprite):
		return
	var nombre: StringName = StringName(opciones.get("nombre", "copia_" + str(rol)))
	quitar_capa(nombre)
	var capa: CapaFondoNativa = CapaFondoNativa.new()
	capa.name = nombre
	var copia_mezcla: BackBufferCopy = null
	if opciones.has("mezcla") or opciones.has("alfa"):
		copia_mezcla = BackBufferCopy.new()
		copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copia_mezcla)
		move_child(copia_mezcla, 0)
	add_child(capa)
	move_child(capa, 1 if copia_mezcla != null else 0)
	# Debajo de los sprites de efecto y a la altura del battler (la escena está encima de los dos).
	capa.z_as_relative = false
	capa.z_index = z_absoluto(sprite)
	if copia_mezcla != null:
		copia_mezcla.z_as_relative = false
		copia_mezcla.z_index = capa.z_index
	capa.copiar_sprite(sprite, int(opciones.get("margen", 16)))
	var mezcla: Array = opciones.get("mezcla", [])
	if not mezcla.is_empty():
		capa.mezcla_gba = true
		capa.eva = float(mezcla[0])
		capa.evb = float(mezcla[1])
	_capas_fondo[nombre] = [capa, copia_mezcla]
	_efectos.append(capa)
	if copia_mezcla != null:
		_efectos.append(copia_mezcla)
	var material: ShaderMaterial = _material_nativo(rol)
	if material != null:
		material.set_shader_parameter(&"alfa", 0.0)
	_animar_capa(capa, opciones)
	var vida: int = int(opciones.get("vida", 0))
	if vida > 0:
		_cada_frame(vida, func(_i: int) -> void: pass, soltar_battler.bind(rol))


## Deshace copiar_battler(): quita la copia y vuelve a mostrar el original.
func soltar_battler(rol: StringName) -> void:
	quitar_capa(StringName("copia_" + str(rol)))
	var material: ShaderMaterial = _material_nativo(rol)
	if material != null:
		material.set_shader_parameter(&"alfa", alfa_atacante if rol == &"atacante" else 1.0)


## Battler semitransparente durante `frames` (objMode 1 del original: se mezcla con lo de debajo con
## los valores de setalpha). Aproximación: opacidad eva / (eva + evb), exacta si suman 1.
func semitransparente(rol: StringName, eva: float, evb: float, frames: int) -> void:
	var material: ShaderMaterial = _material_nativo(rol)
	if material == null:
		return
	material.set_shader_parameter(&"alfa", eva / maxf(0.001, eva + evb))
	var fin: Callable = func() -> void:
		if is_instance_valid(material):
			material.set_shader_parameter(&"alfa", alfa_atacante if rol == &"atacante" else 1.0)
	_cada_frame(frames, func(_i: int) -> void: pass, fin)


## Copia semitransparente del battler `rol` (duplicate_obj_of_side_rel2move_in_transparent_mode o el
## propio sprite con objMode 1 del original) que se escala alrededor de su centro: `escalas` = factor por
## frame (1 = su tamaño; después del último, la copia desaparece). El original no se toca. Opciones:
## "mezcla": [eva, evb] fijos; "alfa": [[frame, eva, evb], ...] cambios por claves; "detras": por
## detrás del battler (subprioridad + 1), por defecto encima.
func eco_battler(rol: StringName, escalas: Array, opciones: Dictionary = {}) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not _configurado or _terminado or not is_instance_valid(sprite):
		return
	var copia_mezcla: BackBufferCopy = BackBufferCopy.new()
	copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var capa: CapaFondoNativa = CapaFondoNativa.new()
	add_child(copia_mezcla)
	add_child(capa)
	var z: int = z_absoluto(sprite) + (-1 if bool(opciones.get("detras", false)) else 0)
	for nodo: CanvasItem in [copia_mezcla, capa]:
		nodo.z_as_relative = false
		nodo.z_index = z
	_efectos.append(copia_mezcla)
	_efectos.append(capa)
	capa.copiar_sprite(sprite, 0)
	capa.mezcla_gba = true
	var mezcla: Array = opciones.get("mezcla", [0.5, 0.5])
	capa.eva = float(mezcla[0])
	capa.evb = float(mezcla[1])
	var claves: Array = opciones.get("alfa", [])
	# Referencia débil: la capa puede liberarse (quitar_capa) mientras sigue el Tween.
	var ref: WeakRef = weakref(capa)
	var paso: Callable = func(i: int) -> void:
		var c: CapaFondoNativa = ref.get_ref() as CapaFondoNativa
		if c == null:
			return
		var e: float = float(escalas[mini(i, escalas.size() - 1)])
		c.escala_copia = Vector2(e, e)
		for clave: Array in claves:
			if int(clave[0]) == i:
				c.eva = float(clave[1])
				c.evb = float(clave[2])
	var fin: Callable = func() -> void:
		for nodo: Node in [capa, copia_mezcla]:
			if is_instance_valid(nodo):
				nodo.queue_free()
	_cada_frame(escalas.size(), paso, fin)


## Estela de copias del battler `rol`: durante `frames` frames, cada `cada` frames, una copia quieta
## donde está el battler, visible `vida` frames. Opciones: "tinte": [color, cantidad] (BlendPalette de
## la paleta de las copias), "mezcla": [eva, evb] (semitransparentes como la GBA), "detras": por
## detrás del battler (por defecto, encima), "desplazamientos": [Vector2, ...] desplazamiento de cada
## copia respecto al battler (caso jugador; se refleja en x con el lado).
func estela_battler(rol: StringName, frames: int, cada: int, vida: int, opciones: Dictionary = {}) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not _configurado or _terminado or not is_instance_valid(sprite):
		return
	var tinte: Array = opciones.get("tinte", [])
	var mezcla: Array = opciones.get("mezcla", [])
	var z: int = z_absoluto(sprite) + (-1 if bool(opciones.get("detras", false)) else 0)
	var desplazamientos: Array = opciones.get("desplazamientos", [])
	var paso: Callable = func(i: int) -> void:
		if i % cada != 0 or not is_instance_valid(sprite):
			return
		var k: int = i / cada
		var nodos: Array[CanvasItem] = []
		if not mezcla.is_empty():
			var copia_mezcla: BackBufferCopy = BackBufferCopy.new()
			copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			nodos.append(copia_mezcla)
		var capa: CapaFondoNativa = CapaFondoNativa.new()
		nodos.append(capa)
		for nodo: CanvasItem in nodos:
			add_child(nodo)
			_efectos.append(nodo)
			nodo.z_as_relative = false
			nodo.z_index = z
		capa.copiar_sprite(sprite, 0)
		capa.fijar_en_sitio()
		if k < desplazamientos.size():
			var d: Vector2 = desplazamientos[k]
			capa.global_position += Vector2(d.x * direccion, d.y)
		if not tinte.is_empty():
			capa.tinte_color = tinte[0]
			capa.tinte_cantidad = float(tinte[1])
		if not mezcla.is_empty():
			capa.mezcla_gba = true
			capa.eva = float(mezcla[0])
			capa.evb = float(mezcla[1])
		var quitar: Callable = func() -> void:
			for nodo: CanvasItem in nodos:
				if is_instance_valid(nodo):
					nodo.queue_free()
		_cada_frame(vida, func(_j: int) -> void: pass, quitar)
	_cada_frame(frames, paso)


## Frames que dura como mucho una tarea de fondo sin fin propio (la escena acaba antes).
const FRAMES_TAREA: int = 1200


func _animar_capa(capa: CapaFondoNativa, opciones: Dictionary) -> void:
	var velocidad: Vector2 = opciones.get("velocidad", Vector2.ZERO)
	if bool(opciones.get("reflejar", false)):
		velocidad.x *= direccion
	var inicial: Vector2 = capa.desplazamiento
	var claves: Array = opciones.get("alfa", [])
	var onda: Dictionary = opciones.get("onda", {})
	var hoja: Array = opciones.get("fotogramas", [])
	var vida: int = int(opciones.get("vida", 0))
	if not onda.is_empty():
		capa.onda_amplitud = float(onda.get("amplitud", 0.0))
		capa.onda_periodo = float(onda.get("periodo", 32.0))
		capa.onda_fase = float(onda.get("fase", 0.0))
		var filas: Array = onda.get("filas", [-100000, 100000])
		capa.onda_filas = Vector2(float(filas[0]), float(filas[1]))
	if not claves.is_empty():
		capa.mezcla_gba = true
	# Referencia débil: la capa puede liberarse (quitar_capa) mientras sigue el Tween.
	var ref: WeakRef = weakref(capa)
	var nombre: StringName = capa.name
	var paso: Callable = func(i: int) -> void:
		var c: CapaFondoNativa = ref.get_ref() as CapaFondoNativa
		if c == null:
			return
		if velocidad != Vector2.ZERO:
			c.desplazamiento = inicial + (velocidad * i).floor()
		for clave: Array in claves:
			if int(clave[0]) == i:
				c.eva = float(clave[1])
				c.evb = float(clave[2])
		if not onda.is_empty():
			c.onda_fase = float(onda.get("fase", 0.0)) + float(onda.get("paso", 0.0)) * i
			if onda.has("extra_ciclo"):
				c.onda_extra = i % int(onda.extra_ciclo)
			for clave: Array in onda.get("amplitudes", []):
				if int(clave[0]) == i:
					c.onda_amplitud = float(clave[1])
			if onda.has("frames") and i >= int(onda.frames):
				c.onda_amplitud = 0.0
				c.onda_extra = 0.0
		if not hoja.is_empty() and i >= int(hoja[1]) and (i - int(hoja[1])) % int(hoja[0]) == 0:
			c.fotograma = (c.fotograma + 1) % c.fotogramas
		if vida > 0 and i >= vida:
			c.visible = false
	var fin: Callable = func() -> void:
		# Solo si sigue siendo la misma capa (mostrar_capa() con el mismo nombre la sustituye).
		if vida > 0 and _capas_fondo.has(nombre) and (_capas_fondo[nombre] as Array)[0] == ref.get_ref():
			quitar_capa(nombre)
	_cada_frame(vida if vida > 0 else FRAMES_TAREA, paso, fin)
