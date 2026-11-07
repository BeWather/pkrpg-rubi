extends EfectoFondoNativo
class_name EfectoCapasNativo
## Componentes de §23 (documentacion/piloto_animaciones_nativas.md): lo que quedaba de la familia
## fondo_movimiento y los tres movimientos que esperaban gráficos. Va en un archivo hermano para que
## efecto_fondo_nativo.gd no crezca sin control; hereda todos los componentes anteriores y añade:
##
## - ruta_arcos(): un sprite que encadena arcos (TranslateAnimArc) con esperas, cambio de fotograma y
##   de lado respecto al defensor en cada tramo, y deja una estela de copias que parpadean (la hoja
##   de Hoja Aguda, sub_80CBDF4).
## - opciones nuevas de disparo(), recorrido() y sprite_estado() (vía _animar_sprite()): "voltear_cuadros" (volteo horizontal por
##   fotograma: la campana de Campana Cura, gSpriteAnim_83D7A08), "tinte_claves" (mezcla de la paleta del
##   sprite por escalones: los fundidos de sub_80E2094 de Rayo Confuso) y "mezcla_claves" (REG_BLDALPHA propio
##   del sprite por escalones, con eva + evb distinto de 16: las sombras de Mismodestino).
## - opción "lazo" de sprite_estado(): desvío en círculo durante unos frames (Viento Hielo).
## - opacidad_battler(): la capa de un battler (monbg) que se desvanece o aparece por dieciseisavos (Finta).
## - copia_battler(): copia de un battler que se queda donde estaba y se desplaza, con mezcla por claves,
##   tinte y ondulación por filas (Pesadilla, Rencor).
## - oscurecer_fuera() y la opción "ventana_foco" de sprite_estado(): oscurecimiento por hardware (REG_BLDY)
##   del campo y los sprites salvo dentro de la silueta de unos sprites que hacen de ventana OBJ (el foco y
##   las manos de Otra Vez y Camelo); la opción "encima_foco" pone un sprite por encima del oscurecimiento.
## - opción "desplazamiento_rival" de mostrar_capa(): scroll inicial propio cuando ataca el rival (Sol Matinal).
## - visibilidad_battler(): oculta o muestra un battler (sub_80E3BDC de Paz Mental).
## - copia_deformada(): copia de un battler en su capa recortada por filas y columnas, estirada en vertical e
##   inclinada, con ondulación, tinte y mezcla por claves: los efectos de scanline sobre BG1/BG2HOFS/VOFS y las
##   ventanas WIN0 de Giro Rápido, Armadura Ácida y Legado.
## - ola(): la ola de Surf y Agua Lodosa (AnimTask_CreateSurfWave): capa con scroll, ciclo de paleta horneado
##   en una hoja, banda de filas visible que crece y mezcla por claves.
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador»
## reflejadas en x según `direccion`. R4 (§29): el volteo de imagen con el lado de ruta_arcos() y de "voltear_cuadros"
## respeta `voltear_imagen_con_lado`, como sprite_efecto().


## Opciones de §23 para disparo(), recorrido() y sprite_estado() (las tres pasan por aquí cada frame).
func _animar_sprite(copia: Sprite2D, opciones: Dictionary, i: int) -> void:
	super._animar_sprite(copia, opciones, i)
	var tinte_claves: Array = opciones.get("tinte_claves", [])
	if tinte_claves.size() == 2:
		if not (copia.material is ShaderMaterial and (copia.material as ShaderMaterial).shader == SHADER_TINTE):
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = SHADER_TINTE
			material.set_shader_parameter(&"color_tinte", tinte_claves[0])
			copia.material = material
		(copia.material as ShaderMaterial).set_shader_parameter(&"cantidad", _escalon_en(tinte_claves[1], i, 0.0))
	var mezcla_claves: Array = opciones.get("mezcla_claves", [])
	if not mezcla_claves.is_empty() and material_mezcla != null:
		if copia.material == null or copia.material == material_mezcla:
			copia.material = material_mezcla.duplicate() as ShaderMaterial
		var m: ShaderMaterial = copia.material as ShaderMaterial
		for clave: Array in mezcla_claves:
			if int(clave[0]) <= i:
				m.set_shader_parameter(&"eva", float(clave[1]))
				m.set_shader_parameter(&"evb", float(clave[2]))
	if i == 0 and bool(opciones.get("ventana_foco", false)):
		# Ventana OBJ: la silueta del sprite deja ver lo que hay debajo sin el oscurecimiento (la copia de la
		# pantalla de antes de oscurecer, ver oscurecer_fuera()).
		var ventana: ShaderMaterial = ShaderMaterial.new()
		ventana.shader = SHADER_VENTANA_FOCO
		copia.material = ventana
		copia.z_as_relative = false
		copia.z_index = _z_foco() + 1
	elif i == 0 and bool(opciones.get("encima_foco", false)):
		copia.z_as_relative = false
		copia.z_index = _z_foco() + 2
	var volteos: Array = opciones.get("voltear_cuadros", [])
	if volteos.is_empty():
		return
	var duraciones: Array = opciones.get("duraciones", [])
	var acumulado: int = 0
	for k: int in volteos.size():
		acumulado += int(duraciones[k]) if k < duraciones.size() else 1
		if i < acumulado or k == volteos.size() - 1:
			copia.flip_h = bool(volteos[k]) != (direccion < 0.0 and voltear_imagen_con_lado)
			break


## Opción "lazo" de sprite_estado(): {"inicio", "frames", "fase", "paso", "radio": [rx, ry]}: durante `frames`
## frames desde `inicio` el sprite se desvía (sen(f) · rx - sen(fase) · rx, cos(f) · ry - cos(fase) · ry) con
## f = fase + paso · j, y después se queda con el último desvío (la vuelta de las bolas de nieve de Viento
## Hielo, AnimSwirlingSnowball_Step3; la ruta suele esperar mientras tanto).
func _trayectoria(opciones: Dictionary, vida: int) -> Array[Vector2]:
	var resultado: Array[Vector2] = super._trayectoria(opciones, vida)
	var lazo: Dictionary = opciones.get("lazo", {})
	if lazo.is_empty():
		return resultado
	var inicio: int = int(lazo.get("inicio", 0))
	var frames: int = int(lazo.get("frames", 0))
	var fase: int = int(lazo.get("fase", 0))
	var paso: int = int(lazo.get("paso", 0))
	var radio: Array = lazo.get("radio", [0, 0])
	var desvio: Callable = func(j: int) -> Vector2:
		var f: float = TAU * posmod(fase + paso * j, 256) / 256.0
		var f0: float = TAU * posmod(fase, 256) / 256.0
		return Vector2(floorf(sin(f) * float(radio[0])) - floorf(sin(f0) * float(radio[0])),
			floorf(cos(f) * float(radio[1])) - floorf(cos(f0) * float(radio[1])))
	for i: int in resultado.size():
		if i >= inicio:
			resultado[i] += desvio.call(mini(i - inicio, frames - 1))
	return resultado


## Sprite que encadena arcos desde `desde` ([ancla, posición]), con la lógica de la tarea del
## original (el primer paso del arco se ve en el frame de la clave). Cada tramo de `tramos` es un diccionario:
## "hasta" ([ancla, posición]), "frames" (pasos del arco), "altura" (px del medio seno; negativa = hacia
## arriba), "cuadro", "voltear" y "detras" (true: por detrás del defensor). Por tramo: los pasos del arco
## (con el fotograma, el volteo y la capa del tramo), un frame quieto al llegar y, salvo en el último,
## `espera` frames quieto (medido en la ROM: 17 frames por tramo con espera 6) (opción "espera", 6 por defecto). Cada arco sale de donde acabó el anterior (el
## paso truncado en 1/256 px puede dejarlo a 1 px del destino, como en el original). En el frame de
## llegada del último tramo el sprite desaparece. Opción "estela": {"cada", "cambios"}: en cada paso y en
## cada llegada deja una copia donde estaba el sprite el frame anterior, con el fotograma de su tramo, que
## cambia de visibilidad cada `cada` frames y desaparece en el cambio `cambios` + 1; las copias alternan
## la fase del parpadeo (sub_80CC358 / sub_80CC408 de Hoja Aguda, sub_80CBDF4).
func ruta_arcos(plantilla: NodePath, desde: Array, tramos: Array, opciones: Dictionary = {}) -> void:
	var base: CanvasItem = get_node(plantilla) as CanvasItem
	var copia: Sprite2D = _instanciar_plantilla(base) as Sprite2D
	var espera: int = int(opciones.get("espera", 6))
	# Posición, tramo y si deja estela, frame a frame.
	var posiciones: Array[Vector2] = []
	var tramo_de: Array[int] = []
	var con_estela: Array[bool] = []
	var actual: Vector2 = _punto(desde)
	var empujar: Callable = func(p: Vector2, k: int, rastro: bool) -> void:
		posiciones.append(p)
		tramo_de.append(k)
		con_estela.append(rastro)
	for k: int in tramos.size():
		var tramo: Dictionary = tramos[k]
		var arco: Array[Vector2] = _tramo_arco(actual, _punto(tramo.hasta), maxi(1, int(tramo.frames)), float(tramo.get("altura", 0.0)))
		for p: Vector2 in arco:
			empujar.call(p, k, true)
		actual = arco.back()
		empujar.call(actual, k, true)
		if k < tramos.size() - 1:
			for _e: int in espera:
				empujar.call(actual, k, false)
	var total: int = posiciones.size()
	var estela: Dictionary = opciones.get("estela", {})
	var contador: Array[int] = [0]
	var aplicar_tramo: Callable = func(sprite: Sprite2D, k: int) -> void:
		var tramo: Dictionary = tramos[k]
		sprite.frame = int(tramo.get("cuadro", 0))
		sprite.flip_h = bool(tramo.get("voltear", false)) != (direccion < 0.0 and voltear_imagen_con_lado)
		_detras_del_defensor(sprite, bool(tramo.get("detras", false)))
	var colocar: Callable = func(i: int) -> void:
		var j: int = mini(i, total - 1)
		copia.position = posiciones[j]
		aplicar_tramo.call(copia, tramo_de[j])
		copia.visible = i < total - 1
		if i >= total or estela.is_empty() or not con_estela[j]:
			return
		var rastro: Sprite2D = _instanciar_plantilla(base) as Sprite2D
		rastro.position = posiciones[maxi(0, j - 1)]
		aplicar_tramo.call(rastro, tramo_de[j])
		var cada: int = int(estela.get("cada", 2))
		var cambios: int = int(estela.get("cambios", 8))
		var fase: int = contador[0] & 1
		contador[0] += 1
		_cada_frame((cambios + 1) * cada - fase, func(m: int) -> void:
			if is_instance_valid(rastro):
				rastro.visible = ((m + fase) / cada) % 2 == 0, rastro.queue_free)
	_cada_frame(total, colocar, copia.queue_free)


## Valor por escalones en el frame `i` de unas claves [[frame, valor], ...] (el de la última clave con
## frame <= i; `inicial` antes de la primera).
static func _escalon_en(claves: Array, i: int, inicial: float) -> float:
	var valor: float = inicial
	for clave: Array in claves:
		if int(clave[0]) <= i:
			valor = float(clave[1])
	return valor


## Opacidad de la capa de un battler (monbg con REG_BLDALPHA, eva + evb = 16: equivale a su opacidad) por
## dieciseisavos: de `desde` a `hasta`, un escalón cada `cada` frames (el primero en el frame `cada`). Se
## queda en `hasta` hasta el final de la escena, que devuelve el material original (sub_80DFC24 /
## sub_80DFD24 de Finta).
func opacidad_battler(rol: StringName, desde: int, hasta: int, cada: int) -> void:
	var material: ShaderMaterial = _material_nativo(rol)
	if material == null:
		return
	var pasos: int = absi(hasta - desde)
	var signo: int = signi(hasta - desde)
	material.set_shader_parameter(&"alfa", desde / 16.0)
	_cada_frame(pasos * cada, func(i: int) -> void:
		if i > 0 and i % cada == 0 and is_instance_valid(material):
			material.set_shader_parameter(&"alfa", (desde + signo * (i / cada)) / 16.0))


## Copia del battler `rol` durante `vida` frames en una capa propia: la copia en sprite de
## duplicate_obj_of_side_rel2move_in_transparent_mode o la de su capa de fondo (monbg). Sale con el
## fotograma y en el sitio del battler en ese frame y no le sigue (no tiembla con él). Opciones:
## "velocidad": px por frame, desplazamiento floor(k · v) desde el frame 1 (sub_8078394, caso jugador);
## "mezcla" / "alfa" ([[frame, eva, evb], ...]) como en mostrar_capa() (con eva + evb distinto de 16 también);
## "tinte": [color, cantidad] (BlendPalette de su paleta); "onda": como en mostrar_capa(), en filas locales
## del sprite (ScanlineEffect_InitWave sobre su capa); "margen": px libres a los lados para la onda;
## "detras": por debajo del battler (por defecto, encima); "ocultar": el original no se ve mientras dura
## (el sprite pasa a la capa de fondo).
func copia_battler(rol: StringName, vida: int, opciones: Dictionary = {}) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not _configurado or _terminado or not is_instance_valid(sprite):
		return
	var nombre: StringName = StringName(opciones.get("nombre", "copia_fija_" + str(rol)))
	quitar_capa(nombre)
	var capa: CapaFondoNativa = CapaFondoNativa.new()
	capa.name = nombre
	var copia_mezcla: BackBufferCopy = null
	if opciones.has("mezcla") or opciones.has("alfa"):
		copia_mezcla = BackBufferCopy.new()
		copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copia_mezcla)
	add_child(capa)
	var z: int = z_absoluto(sprite) + (-1 if bool(opciones.get("detras", false)) else 0)
	for nodo: CanvasItem in [copia_mezcla, capa]:
		if nodo != null:
			nodo.z_as_relative = false
			nodo.z_index = z
	capa.copiar_sprite(sprite, int(opciones.get("margen", 0)))
	capa.fijar_en_sitio()
	var mezcla: Array = opciones.get("mezcla", [])
	if not mezcla.is_empty():
		capa.mezcla_gba = true
		capa.eva = float(mezcla[0])
		capa.evb = float(mezcla[1])
	var tinte: Array = opciones.get("tinte", [])
	if tinte.size() == 2:
		capa.tinte_color = tinte[0]
		capa.tinte_cantidad = float(tinte[1])
	_capas_fondo[nombre] = [capa, copia_mezcla]
	_efectos.append(capa)
	if copia_mezcla != null:
		_efectos.append(copia_mezcla)
	var ocultar: bool = bool(opciones.get("ocultar", false))
	if ocultar:
		var material: ShaderMaterial = _material_nativo(rol)
		if material != null:
			material.set_shader_parameter(&"alfa", 0.0)
	var animacion: Dictionary = opciones.duplicate()
	animacion.erase("velocidad")
	animacion["vida"] = vida
	_animar_capa(capa, animacion)
	var origen: Vector2 = capa.position
	var velocidad: Vector2 = _reflejar(opciones.get("velocidad", Vector2.ZERO))
	var ref: WeakRef = weakref(capa)
	var mover: Callable = func(i: int) -> void:
		var c: CapaFondoNativa = ref.get_ref() as CapaFondoNativa
		if c != null:
			c.position = origen + (velocidad * i).floor()
	var fin: Callable = func() -> void:
		if ocultar:
			var material: ShaderMaterial = _material_nativo(rol)
			if material != null:
				material.set_shader_parameter(&"alfa", alfa_atacante if rol == &"atacante" else 1.0)
	_cada_frame(vida, mover, fin)


const SHADER_VENTANA_FOCO: Shader = preload("res://escenas/batalla/animaciones_nativas/ventana_foco.gdshader")
## Oscurecimiento por hardware activo: [BackBufferCopy, ColorRect] (ver oscurecer_fuera()).
var _oscuro: Array = []


func _z_foco() -> int:
	# Concurso: sub_80E2D78 solo oscurece BG3, sprites y fondo, así que el marco, el texto y las cajas (que aquí tienen
	# un z mayor) quedan fuera; sub_812CC44 saca además de la mezcla los sprites de las cajas (x >= 152) con WIN1.
	return z_absoluto(self) + (0 if concurso else 1)


## Oscurecimiento por hardware fuera de las ventanas (sub_80E2D78: BeginHardwarePaletteFade sobre BG3, OBJ y el
## color de fondo con REG_BLDY): el campo, los battlers y los sprites de efecto (que van por debajo) se oscurecen
## de `desde` a `hasta` dieciseisavos, un escalón en este frame y otro cada `cada` frames. Equivale a un velo negro
## de opacidad y / 16 encima de todo; justo antes se copia la pantalla para que las ventanas (opción
## "ventana_foco" de sprite_estado()) la muestren sin oscurecer. Al volver a 0 el velo se queda transparente.
func oscurecer_fuera(desde: int, hasta: int, cada: int) -> void:
	if not _configurado or _terminado:
		return
	if _oscuro.is_empty() or not is_instance_valid(_oscuro[1]):
		var copia_pantalla: BackBufferCopy = BackBufferCopy.new()
		copia_pantalla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		var velo: ColorRect = ColorRect.new()
		velo.color = Color(0, 0, 0, desde / 16.0)
		velo.size = tamano_campo
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for nodo: CanvasItem in [copia_pantalla, velo]:
			add_child(nodo)
			_efectos.append(nodo)
			nodo.z_as_relative = false
			nodo.z_index = _z_foco()
		_oscuro = [copia_pantalla, velo]
	var velo_actual: ColorRect = _oscuro[1]
	var pasos: int = absi(hasta - desde)
	var signo: int = signi(hasta - desde)
	_cada_frame(pasos * cada, func(i: int) -> void:
		if is_instance_valid(velo_actual) and i % cada == 0:
			velo_actual.color.a = (desde + signo * mini(pasos, i / cada + 1)) / 16.0)


## mostrar_capa() con "desplazamiento_rival": el scroll inicial cuando ataca el rival (el original coloca algunas
## capas en otro sitio según el lado, no en espejo).
func mostrar_capa(plantilla: NodePath, opciones: Dictionary = {}) -> void:
	if direccion < 0.0 and opciones.has("desplazamiento_rival"):
		opciones = opciones.duplicate()
		opciones["desplazamiento"] = opciones.desplazamiento_rival
	super.mostrar_capa(plantilla, opciones)


## Oculta (o vuelve a mostrar) el battler `rol` (invisible del sprite; sub_80E3BDC oculta a todos menos al
## atacante). Opacidad 0 en su material temporal: la escena lo devuelve al acabar.
func visibilidad_battler(rol: StringName, visible_battler: bool) -> void:
	var material: ShaderMaterial = _material_nativo(rol)
	if material != null:
		material.set_shader_parameter(&"alfa", (alfa_atacante if rol == &"atacante" else 1.0) if visible_battler else 0.0)


## Ola de Surf y Agua Lodosa (AnimTask_CreateSurfWave): la hoja `plantilla` (512 x 256 por fotograma) en una capa
## por encima de los battlers, con scroll inicial "desplazamiento" y "velocidad" px por frame (BG1 X/Y), el ciclo de
## paleta horneado en `ciclo` = [primer fotograma, cuántos, cada] (rota cada `cada` frames), solo visible en las
## filas de la banda {"desde", "paso", "hasta", "limite"} (de `desde` crece `paso` filas por frame hasta `limite`; la
## otra punta, fija en `hasta`) y mezclada por "alfa" ([[frame, eva, evb], ...]). Las claves con "_rival" sustituyen
## a las normales cuando ataca el rival (otro mapa de la ola y otra posición en el original).
func ola(plantilla: NodePath, vida: int, opciones: Dictionary) -> void:
	var base: Sprite2D = get_node_or_null(plantilla) as Sprite2D
	if base == null or not _configurado or _terminado:
		return
	var o: Dictionary = opciones.duplicate()
	if direccion < 0.0:
		for clave: String in opciones.keys():
			if clave.ends_with("_rival"):
				o[clave.trim_suffix("_rival")] = opciones[clave]
	var copia_mezcla: BackBufferCopy = BackBufferCopy.new()
	copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var capa: CapaFondoNativa = CapaFondoNativa.new()
	capa.texture = base.texture
	capa.fotogramas = base.vframes
	add_child(copia_mezcla)
	add_child(capa)
	move_child(copia_mezcla, 0)
	move_child(capa, 1)
	_efectos.append(copia_mezcla)
	_efectos.append(capa)
	capa.preparar(tamano_campo)
	capa.mezcla_gba = true
	capa.eva = 0.0
	capa.evb = 1.0
	var ciclo: Array = o.get("ciclo", [0, 1, 1])
	var banda: Dictionary = o.get("banda", {})
	var claves: Array = o.get("alfa", [])
	var inicial: Vector2 = o.get("desplazamiento", Vector2.ZERO)
	var velocidad: Vector2 = o.get("velocidad", Vector2.ZERO)
	var ref: WeakRef = weakref(capa)
	var paso: Callable = func(i: int) -> void:
		var c: CapaFondoNativa = ref.get_ref() as CapaFondoNativa
		if c == null:
			return
		c.fotograma = int(ciclo[0]) + (i / maxi(1, int(ciclo[2]))) % maxi(1, int(ciclo[1]))
		var desde: float = float(banda.get("desde", 0.0)) + float(banda.get("paso", 0.0)) * i
		var limite: float = float(banda.get("limite", desde))
		desde = maxf(desde, limite) if float(banda.get("paso", 0.0)) < 0.0 else minf(desde, limite)
		var hasta: float = float(banda.get("hasta", tamano_campo.y))
		var y0: float = minf(desde, hasta)
		var y1: float = maxf(desde, hasta)
		c.position = Vector2(0.0, y0)
		c.region_rect = Rect2(Vector2.ZERO, Vector2(tamano_campo.x, maxf(0.0, y1 - y0)))
		c.desplazamiento = inicial + velocidad * i + Vector2(0.0, y0)
		for clave: Array in claves:
			if int(clave[0]) == i:
				c.eva = float(clave[1])
				c.evb = float(clave[2])
		c.visible = i < vida
	var fin: Callable = func() -> void:
		for nodo: Node in [capa, copia_mezcla]:
			if is_instance_valid(nodo):
				nodo.queue_free()
	_cada_frame(vida, paso, fin)


## Copia del battler `rol` en su capa (monbg) deformada como el original hace por scanline, durante `vida`
## frames; el original no se ve mientras tanto (salvo "ocultar": false). `claves` = [[frame, {...}], ...] con
## los valores (interpolados linealmente entre claves; los que falten en una clave siguen la anterior):
##   "filas": [desde, hasta]: filas del sprite (0 = arriba) que se ven (las demás, transparentes);
##   "ancho": columnas visibles centradas en el sprite (ventana WIN0);
##   "escala_y": estiramiento vertical con la fila "ancla" (opción, por defecto la de abajo) fija en su sitio;
##   "inclinacion": px: la fila de arriba se desplaza +d en x y la de abajo -d (lineal entre ellas; caso jugador);
##   "tramo_arriba" / "tramo_abajo": con la opción "fuente" = [s0, s1], filas locales en que se ven las filas s0 y s1
##     del sprite (estiramiento por sus dos puntas, sustituye a "escala_y").
## Opciones: "ancla" (fila fija), "tinte": [color, cantidad], "mezcla" o "alfa" ([[frame, eva, evb], ...]) y
## "onda" como en mostrar_capa() (filas locales de la copia), "ocultar" (por defecto true).
func copia_deformada(rol: StringName, vida: int, claves: Array, opciones: Dictionary = {}) -> void:
	var sprite: Sprite2D = sprite_de(rol)
	if not _configurado or _terminado or not is_instance_valid(sprite):
		return
	var nombre: StringName = StringName(opciones.get("nombre", "deformada_" + str(rol)))
	quitar_capa(nombre)
	var capa: CapaFondoNativa = CapaFondoNativa.new()
	capa.name = nombre
	var copia_mezcla: BackBufferCopy = null
	if opciones.has("mezcla") or opciones.has("alfa"):
		copia_mezcla = BackBufferCopy.new()
		copia_mezcla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copia_mezcla)
	add_child(capa)
	for nodo: CanvasItem in [copia_mezcla, capa]:
		if nodo != null:
			nodo.z_as_relative = false
			nodo.z_index = z_absoluto(sprite)
	capa.copiar_sprite(sprite, 0)
	capa.fijar_en_sitio()
	var tamano: Vector2 = CapaFondoNativa.rect_fuente(sprite).size
	var origen: Vector2 = capa.position
	var mezcla: Array = opciones.get("mezcla", [])
	if not mezcla.is_empty():
		capa.mezcla_gba = true
		capa.eva = float(mezcla[0])
		capa.evb = float(mezcla[1])
	var tinte: Array = opciones.get("tinte", [])
	if tinte.size() == 2:
		capa.tinte_color = tinte[0]
		capa.tinte_cantidad = float(tinte[1])
	_capas_fondo[nombre] = [capa, copia_mezcla]
	_efectos.append(capa)
	if copia_mezcla != null:
		_efectos.append(copia_mezcla)
	var ocultar: bool = bool(opciones.get("ocultar", true))
	if ocultar:
		visibilidad_battler(rol, false)
	var animacion: Dictionary = {"vida": vida}
	for clave: String in ["alfa", "onda"]:
		if opciones.has(clave):
			animacion[clave] = opciones[clave]
	_animar_capa(capa, animacion)
	var ancla: float = float(opciones.get("ancla", tamano.y))
	var fuente: Array = opciones.get("fuente", [])
	var ref: WeakRef = weakref(capa)
	var valor: Callable = func(i: int, campo: String, defecto: float) -> float:
		var anterior: Array = []
		for clave: Array in claves:
			var datos: Dictionary = clave[1]
			if not datos.has(campo):
				continue
			if int(clave[0]) <= i:
				anterior = [int(clave[0]), datos[campo]]
			elif not anterior.is_empty():
				var t: float = float(i - int(anterior[0])) / float(int(clave[0]) - int(anterior[0]))
				return lerpf(float(anterior[1]), float(datos[campo]), t)
			else:
				return defecto
		return defecto if anterior.is_empty() else float(anterior[1])
	var filas_en: Callable = func(i: int) -> Vector2:
		var resultado: Vector2 = Vector2(0.0, tamano.y)
		for clave: Array in claves:
			if int(clave[0]) <= i and (clave[1] as Dictionary).has("filas"):
				var f: Array = (clave[1] as Dictionary).filas
				resultado = Vector2(float(f[0]), float(f[1]))
		return resultado
	var paso: Callable = func(i: int) -> void:
		var c: CapaFondoNativa = ref.get_ref() as CapaFondoNativa
		if c == null:
			return
		var filas: Vector2 = filas_en.call(i)
		var r0: float = clampf(filas.x, 0.0, tamano.y)
		var r1: float = clampf(filas.y, r0, tamano.y)
		var ancho: float = clampf(valor.call(i, "ancho", tamano.x), 0.0, tamano.x)
		var c0: float = floorf((tamano.x - ancho) / 2.0)
		var sy: float = valor.call(i, "escala_y", 1.0)
		var d: float = valor.call(i, "inclinacion", 0.0) * direccion
		c.region_rect = Rect2(Vector2.ZERO, Vector2(ancho, r1 - r0))
		c.desplazamiento = Vector2(c0, r0)
		var y0: float = origen.y + ancla + (r0 - ancla) * sy
		if not fuente.is_empty():
			# "tramo": las filas fuente[0] y fuente[1] del sprite se ven en las filas t0 y t1 (locales).
			var t0: float = valor.call(i, "tramo_arriba", float(fuente[0]))
			var t1: float = valor.call(i, "tramo_abajo", float(fuente[1]))
			sy = (t1 - t0) / maxf(1.0, float(fuente[1]) - float(fuente[0]))
			y0 = origen.y + t0 + (r0 - float(fuente[0])) * sy
		var k: float = -2.0 * d / maxf(1.0, tamano.y)
		var x0: float = origen.x + c0 + d + k * r0
		c.transform = Transform2D(Vector2(1.0, 0.0), Vector2(k, sy), Vector2(x0, y0))
		c.visible = i < vida and r1 > r0 and ancho > 0.0
	var fin: Callable = func() -> void:
		if ocultar:
			visibilidad_battler(rol, true)
	_cada_frame(vida, paso, fin)
