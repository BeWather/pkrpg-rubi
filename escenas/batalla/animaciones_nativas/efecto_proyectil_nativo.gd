extends EfectoGolpeNativo
class_name EfectoProyectilNativo
## Componentes de la familia proyectil_partículas (§17 de
## documentacion/piloto_animaciones_nativas.md). Va aparte de EfectoGolpeNativo para que ese
## archivo no crezca sin control; hereda todos sus componentes (golpe, sprite_efecto,
## sacudidas, tinte…) y añade los que solo usan los proyectiles:
##
## - disparo(): proyectil en línea recta o en arco (TranslateAnimLinear / TranslateAnimArc)
##   que puede orientarse según su dirección y rebotar al llegar (Recurrente).
## - trayectoria_trig(): sprite que recorre tramos de seno/coseno (rocas que caen y rebotan,
##   sub_80DCE9C con sub_8078278).
## - temblor_fondo() / vaiven_fondo(): sacudidas del fondo de la batalla (gBattle_BG3_X/Y de
##   sub_80E24B8 y sub_80E26BC).
## - recorrido(): sprite que recorre tramos con velocidad, aceleración y ondas (hojas que caen
##   en vaivén, rocas que caen acelerando) (§18).
## - brillo_tintado(): brillo metálico con el battler mezclado hacia un color (Cola Veneno).
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador»
## reflejadas en x según `direccion`.

## Nodos del campo de batalla que forman el BG3 del original (fondo y suelos). En el
## comparador no existen y temblor_fondo() no hace nada.
const NODOS_FONDO_BATALLA: Array[StringName] = [&"btlFondo", &"btlSueloArriba", &"btlSueloAbajo"]

## Nodo del fondo de batalla -> posición original mientras temblor_fondo() lo mueve.
var _fondo_movido: Dictionary = {}


## Proyectil de `desde` a `hasta` ([ancla, posición] como en sprite_efecto) en `frames`
## pasos, con el paso en 1/256 px truncado como InitAnimLinearTranslation. Opciones:
##   "arco": altura del medio seno de TranslateAnimArc (px; negativa = hacia arriba);
##   "inmediato": el primer paso se da en el frame de la clave (StartAnimLinearTranslation)
##     en vez de en el siguiente (AnimMissileArc, que además empieza oculto);
##   "orientar": gira la imagen (que apunta hacia arriba) hacia donde avanza; con arco, según
##     el último paso (AnimMissileArcStep); sin arco, hacia el destino (AnimTranslateStinger);
##   "giro": giro fijo (radianes, caso jugador); "cuadro"; "mezcla";
##   "rebote": [velocidad_x, altura, frames, giro_por_frame, pausa] al llegar: tras `pausa`
##     frames quieto avanza velocidad_x px por frame y sube y baja un medio seno de `altura`
##     en `frames`, girando (sub_80D0030/sub_80D00B4 de Recurrente);
##   "continuar": frames que sigue avanzando (y el arco, con su fase) tras pasar por `hasta`;
##     desaparece al salir del campo (AnimTranslateLinearSingleSineWave);
##   "parpadeo_al_llegar": con "continuar", el sprite cambia de visibilidad cada frame desde que llega a `hasta`
##     (§36: AnimTranslateLinearSingleSineWave contra un aliado, data[0] = 1; la duración la fija "continuar");
##   "onda_x" / "onda_y": [amplitud, paso, fase] sumadas a cada paso, fase en 1/256 de vuelta
##     antes de avanzar (Danza Pétalo); "voltear_onda": invierte la imagen cuando la fase de
##     onda_x pasa por 0x3B-0x3F o 0xBB-0xBF (sub_80CAE74);
##   "llegada": [espera, parpadeo]: al llegar se queda `espera` frames y parpadea `parpadeo`
##     (sub_812C798 de Púas); con parpadeo 0 solo se queda quieta (Burbuja);
##   "zoom": animación afín del sprite, como en sprite_efecto();
##   "desfase_orientar": con "orientar" sin arco, ángulo de la imagen respecto a la dirección
##     (por defecto PI / 2: la imagen apunta hacia arriba);
##   "fase_detras": [fase, paso]: con la fase (1/256 de vuelta, avanza `paso` por frame) fuera
##     de 64..191 el sprite pasa detrás del defensor (AnimSwirlingFogAnim de Polución);
##   "giro_por_frame"; "cuadros" + "duraciones" (como sprite_efecto); "volteos" y
##     "tinte_ciclo" (ver _animar_sprite()); "oculto_inicio": frames ocultos al empezar (por
##     defecto 0 si es inmediato y 1 si no).
## Vida: `frames` (+1 si no es inmediato) más los frames del rebote o de "continuar".
func disparo(plantilla: NodePath, desde: Array, hasta: Array, frames: int, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	var a: Vector2 = _punto(desde)
	var b: Vector2 = _punto(hasta)
	var n: int = maxi(1, frames)
	var inmediato: bool = bool(opciones.get("inmediato", true))
	var arco: float = float(opciones.get("arco", 0.0))
	var orientar: bool = bool(opciones.get("orientar", false))
	var giro: float = float(opciones.get("giro", 0.0)) * direccion
	var rebote: Array = opciones.get("rebote", [])
	var continuar: int = int(opciones.get("continuar", 0))
	var onda_x: Array = opciones.get("onda_x", [])
	var onda_y: Array = opciones.get("onda_y", [])
	var voltear_onda: bool = bool(opciones.get("voltear_onda", false))
	var parpadeo_al_llegar: bool = bool(opciones.get("parpadeo_al_llegar", false))
	var giro_por_frame: float = float(opciones.get("giro_por_frame", 0.0))
	var llegada: Array = opciones.get("llegada", [])
	var oculto: int = int(opciones.get("oculto_inicio", 0 if inmediato else 1))
	# Paso de InitAnimLinearTranslation: |d| * 256 / n truncado (el bit bajo guarda el signo).
	var paso: Vector2 = Vector2(int(absf(b.x - a.x) * 256.0 / n) & ~1, int(absf(b.y - a.y) * 256.0 / n) & ~1)
	var signo: Vector2 = Vector2(signf(b.x - a.x), signf(b.y - a.y))
	var fase_arco: int = 0x8000 / n
	if opciones.has("cuadro"):
		copia.frame = int(opciones.cuadro)
	if bool(opciones.get("mezcla", false)) and material_mezcla != null:
		copia.material = material_mezcla
	_prioridad(copia, opciones)
	var posicion_en: Callable = func(k: int) -> Vector2:
		var p: Vector2 = a + Vector2(signo.x * floorf(k * paso.x / 256.0), signo.y * floorf(k * paso.y / 256.0))
		if arco != 0.0 and k > 0:
			p.y += floorf(sin(TAU * float(((k * fase_arco) >> 8) & 0xFF) / 256.0) * arco)
		return p
	if orientar and arco == 0.0:
		giro = (b - a).angle() + float(opciones.get("desfase_orientar", PI / 2.0))
	copia.rotation = giro
	var vuelo: int = n + (0 if inmediato else 1)
	var pausa: int = int(rebote[4]) if rebote.size() > 4 else 0
	var total: int = vuelo + (pausa + int(rebote[2]) if rebote.size() >= 4 else 0) + continuar
	if llegada.size() == 2:
		total += int(llegada[0]) + int(llegada[1])
	var estado: Dictionary = {"anterior": a, "fuera": false}
	var zoom: Array = _zoom_afin(opciones.get("zoom", []))
	var fase_detras: Array = opciones.get("fase_detras", [])
	var mover: Callable = func(i: int) -> void:
		var k: int = i + (1 if inmediato else 0)
		if bool(estado.fuera):
			return
		copia.visible = i >= oculto
		_animar_sprite(copia, opciones, i)
		if not zoom.is_empty():
			copia.scale = zoom[mini(i, zoom.size() - 1)]
		if fase_detras.size() == 2:
			_detras_del_defensor(copia, posmod(int(fase_detras[0]) + int(fase_detras[1]) * i - 64, 256) > 0x7F)
		if i < vuelo + continuar and (continuar > 0 or i < vuelo):
			var p: Vector2 = posicion_en.call(k if continuar > 0 else mini(k, n))
			if not onda_x.is_empty() or not onda_y.is_empty():
				var j: int = maxi(0, k - 1)
				if onda_x.size() == 3:
					var fase_x: int = _fase_onda(onda_x, j)
					p.x += floorf(sin(TAU * fase_x / 256.0) * float(onda_x[0])) * direccion
					if voltear_onda and (fase_x - 0x3B) & 0xFF < 5 or voltear_onda and (fase_x - 0xBB) & 0xFF < 5:
						copia.flip_h = not copia.flip_h
				if onda_y.size() == 3:
					p.y += floorf(sin(TAU * _fase_onda(onda_y, j) / 256.0) * float(onda_y[0]))
			if giro_por_frame != 0.0:
				copia.rotation = giro + giro_por_frame * (i + 1) * direccion
			if orientar and arco != 0.0 and p != estado.anterior:
				copia.rotation = (p - (estado.anterior as Vector2)).angle() + PI / 2.0
			estado.anterior = p
			copia.position = p
			if parpadeo_al_llegar and k >= n:
				copia.visible = (k - n) % 2 == 1
			if continuar > 0 and _fuera_del_campo(p):
				estado.fuera = true
				copia.visible = false
		elif llegada.size() == 2:
			# Quieta donde llegó `llegada[0]` frames y después parpadea (cambia cada 2 frames).
			var k2: int = i - vuelo - int(llegada[0])
			copia.visible = k2 < 0 or ((k2 + 1) / 2) % 2 == 0
		elif rebote.size() >= 4 and i >= vuelo + pausa:
			# Rebote desde donde llegó: x avanza, y = medio seno de `altura` en `frames` pasos.
			var j: int = i - vuelo - pausa
			var pasos: int = int(rebote[2])
			copia.position = ((estado.anterior as Vector2) + Vector2(floorf(float(rebote[0]) * (j + 1)) * direccion,
				floorf(sin(PI * float(j) / pasos) * float(rebote[1])))).floor()
			copia.rotation = giro + float(rebote[3]) * (j + 1) * direccion
	mover.call(0)
	_cada_frame(total, mover, copia.queue_free)


## Sprite que recorre `tramos` (diccionarios) uno tras otro desde `desde`. Claves de cada tramo:
##   "frames"; "velocidad" y "aceleracion" (Vector2, px/frame y px/frame², caso jugador);
##   "salto": desplazamiento que se suma al empezar el tramo; "limite_y": tope del
##   desplazamiento acumulado en y (la roca de Tumba Rocas se para al llegar a su sitio);
##   "onda_x" / "onda_y": [amplitud, paso, fase] (sen, fase en 1/256 de vuelta, sin acumular:
##   la onda de un tramo no se arrastra al siguiente); "mover_antes" (por defecto true): el
##   frame muestra la posición después de avanzar; con false, antes.
## Opciones: "oculto_inicio" (frames), "cuadro", "cuadros"/"duraciones", "mezcla", "giro_por_frame",
## "tinte_ciclo", "conmutar" (frames en los que cambia la visibilidad).
func recorrido(plantilla: NodePath, desde: Array, tramos: Array, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	var a: Vector2 = _punto(desde)
	if opciones.has("cuadro"):
		copia.frame = int(opciones.cuadro)
	if bool(opciones.get("mezcla", false)) and material_mezcla != null:
		copia.material = material_mezcla
	_prioridad(copia, opciones)
	var posiciones: Array[Vector2] = []
	var base: Vector2 = Vector2.ZERO
	for tramo: Dictionary in tramos:
		base += _reflejar(tramo.get("salto", Vector2.ZERO))
		var v: Vector2 = _reflejar(tramo.get("velocidad", Vector2.ZERO))
		var acel: Vector2 = _reflejar(tramo.get("aceleracion", Vector2.ZERO))
		var antes: bool = bool(tramo.get("mover_antes", true))
		var onda_x: Array = tramo.get("onda_x", [])
		var onda_y: Array = tramo.get("onda_y", [])
		for j: int in int(tramo.frames):
			var p: Vector2 = a + base.floor()
			base += v
			v += acel
			if tramo.has("limite_y"):
				base.y = minf(base.y, float(tramo.limite_y))
			if antes:
				p = a + base.floor()
			if onda_x.size() == 3:
				p.x += floorf(sin(TAU * ((int(onda_x[2]) + int(onda_x[1]) * j) & 0xFF) / 256.0) * float(onda_x[0])) * direccion
			if onda_y.size() == 3:
				p.y += floorf(sin(TAU * ((int(onda_y[2]) + int(onda_y[1]) * j) & 0xFF) / 256.0) * float(onda_y[0]))
			posiciones.append(p)
	if posiciones.is_empty():
		posiciones.append(a)
	var total: int = posiciones.size()
	var oculto: int = int(opciones.get("oculto_inicio", 0))
	var conmutar: Array = opciones.get("conmutar", [])
	var giro_por_frame: float = float(opciones.get("giro_por_frame", 0.0))
	var colocar: Callable = func(i: int) -> void:
		copia.position = posiciones[mini(i, total - 1)]
		if giro_por_frame != 0.0:
			copia.rotation = giro_por_frame * (i + 1) * direccion
		copia.visible = i >= oculto
		if conmutar.has(i):
			copia.visible = false
		_animar_sprite(copia, opciones, i)
	colocar.call(0)
	_cada_frame(total, colocar, copia.queue_free)


## Sprite que recorre tramos de seno/coseno (sub_8078278): en cada tramo
## [desplazamiento_x, fase, paso, frames, amplitud_x, amplitud_y], primero se suma
## desplazamiento_x a la posición y después, un paso por frame, x = sen(fase) * amplitud_x e
## y = cos(fase) * amplitud_y (fase en 1/256 de vuelta) avanzando `paso`. Entre tramos hay un
## frame quieto (el cambio de callback). El primer paso del primer tramo se da en la clave.
## Opciones: "cuadro", "mezcla".
func trayectoria_trig(plantilla: NodePath, desde: Array, tramos: Array, opciones: Dictionary = {}) -> void:
	var copia: Sprite2D = _instanciar_plantilla(get_node(plantilla) as CanvasItem) as Sprite2D
	var a: Vector2 = _punto(desde)
	if opciones.has("cuadro"):
		copia.frame = int(opciones.cuadro)
	if bool(opciones.get("mezcla", false)) and material_mezcla != null:
		copia.material = material_mezcla
	# Posición de cada frame: un paso por frame y un frame quieto al final de cada tramo.
	var posiciones: Array[Vector2] = []
	var base_x: float = 0.0
	var ultima: Vector2 = a
	for tramo: Array in tramos:
		base_x += float(tramo[0])
		for j: int in int(tramo[3]):
			var fase: float = TAU * fmod(float(tramo[1]) + float(tramo[2]) * j, 256.0) / 256.0
			ultima = a + Vector2((base_x + floorf(sin(fase) * float(tramo[4]))) * direccion, floorf(cos(fase) * float(tramo[5])))
			posiciones.append(ultima)
		posiciones.append(ultima)
	var total: int = posiciones.size()
	var colocar: Callable = func(i: int) -> void:
		copia.position = posiciones[mini(i, total - 1)]
	colocar.call(0)
	_cada_frame(total, colocar, copia.queue_free)


## Sacudida del fondo de la batalla (sub_80E24B8 sobre gBattle_BG3_X/Y): cada `periodo` + 1
## frames el fondo se desplaza `desplazamiento` y vuelve, durante `frames`; al acabar vuelve a
## su sitio. Mueve los nodos de NODOS_FONDO_BATALLA hermanos de esta escena (en batalla real,
## los hijos de «Campo»); los battlers (OBJ) no se mueven, como en el original.
func temblor_fondo(desplazamiento: Vector2, periodo: int, frames: int) -> void:
	var nodos: Array[Node2D] = _nodos_fondo()
	if nodos.is_empty():
		return
	var estado: Dictionary = {"espera": periodo, "activo": false}
	_cada_frame(frames + 1, func(i: int) -> void:
		if i == 0:
			return
		if i <= frames:
			if int(estado.espera) > 0:
				estado.espera = int(estado.espera) - 1
			else:
				estado.espera = periodo
				estado.activo = not bool(estado.activo)
		else:
			estado.activo = false
		for nodo: Node2D in nodos:
			if is_instance_valid(nodo):
				nodo.position = (_fondo_movido[nodo] as Vector2) + (desplazamiento if bool(estado.activo) else Vector2.ZERO))


## Vaivén del fondo de la batalla (sub_80E26BC): el scroll empieza en `amplitud` y cada
## `periodo` + 1 frames alterna x entre +a y -a, e y entre -a y 0, `veces` cambios; al acabar
## vuelve a 0. El fondo se ve desplazado al revés que el scroll.
func vaiven_fondo(amplitud: Vector2, veces: int, periodo: int) -> void:
	var nodos: Array[Node2D] = _nodos_fondo()
	if nodos.is_empty():
		return
	var e: Dictionary = {"scroll": amplitud, "cuenta": periodo, "veces": veces, "fin": false}
	_cada_frame(veces * (periodo + 1), func(_i: int) -> void:
		if bool(e.fin):
			return
		if int(e.cuenta) == 0:
			var s: Vector2 = e.scroll
			s.x = -amplitud.x if s.x == amplitud.x else amplitud.x
			s.y = 0.0 if s.y == -amplitud.y else -amplitud.y
			e.cuenta = periodo
			e.veces = int(e.veces) - 1
			if int(e.veces) == 0:
				s = Vector2.ZERO
				e.fin = true
			e.scroll = s
		else:
			e.cuenta = int(e.cuenta) - 1
		for nodo: Node2D in nodos:
			if is_instance_valid(nodo):
				nodo.position = (_fondo_movido[nodo] as Vector2) - (e.scroll as Vector2))


## Brillo metálico con el battler mezclado `cantidad` hacia `color` en vez de en gris
## (sub_80E0A4C con su segundo argumento distinto de 0: Cola Veneno). Mismo contrato que
## brillo_metalico(): sin `restaurar` se queda tintado hasta restaurar_paleta().
func brillo_tintado(rol: StringName, color: Color, cantidad: float, frames: int = 63, velocidad: float = 4.0, restaurar: bool = true) -> void:
	var material: ShaderMaterial = _material_brillo(rol)
	if material == null:
		return
	material.set_shader_parameter(&"gris", 0.0)
	material.set_shader_parameter(&"color_tinte", color)
	material.set_shader_parameter(&"tinte", cantidad)
	material.set_shader_parameter(&"brillo", 1.0)
	_cada_frame(frames, func(i: int) -> void:
		material.set_shader_parameter(&"desplazamiento", velocidad * i), func() -> void:
		material.set_shader_parameter(&"brillo", 0.0)
		if restaurar:
			restaurar_paleta(rol))


## Desplazamiento fijo del battler durante `frames` y vuelta a 0 (dos AnimTask_ShakeMon2 sobre
## el mismo sprite se anulan: Explosión y Autodestrucción).
func fijar_desplazamiento(rol: StringName, desplazamiento: Vector2, frames: int) -> void:
	_cada_frame(frames, func(i: int) -> void:
		_fijar_capa(rol, &"fijo", Vector2.ZERO if i >= frames else desplazamiento))


## Fotogramas, volteos y ciclo de tinte comunes a disparo() y recorrido(). "volteos":
## [[h, v], ...] en bucle cada "cada_volteo" frames (animación de la hoja afilada);
## "tinte_ciclo": [colores, frames_por_color, desfase]: el sprite se mezcla hacia cada color de
## 0 a 16 dieciseisavos, uno por frame, y pasa al siguiente; `desfase` = frame del sprite en
## que la tarea da su primer paso (sub_80CC5F8 de Hoja Mágica).
func _animar_sprite(copia: Sprite2D, opciones: Dictionary, i: int) -> void:
	var cuadros: Array = opciones.get("cuadros", [])
	if not cuadros.is_empty():
		var duraciones: Array = opciones.get("duraciones", [])
		var acumulado: int = 0
		for k: int in cuadros.size():
			acumulado += int(duraciones[k]) if k < duraciones.size() else 1
			if i < acumulado or k == cuadros.size() - 1:
				copia.frame = int(cuadros[k])
				break
	var volteos: Array = opciones.get("volteos", [])
	if not volteos.is_empty():
		var v: Array = volteos[(i / maxi(1, int(opciones.get("cada_volteo", 1)))) % volteos.size()]
		copia.flip_h = bool(v[0]) != (direccion < 0.0 and voltear_imagen_con_lado)
		copia.flip_v = bool(v[1])
	var ciclo: Array = opciones.get("tinte_ciclo", [])
	if ciclo.size() >= 2:
		var colores: Array = ciclo[0]
		var cada: int = int(ciclo[1])
		var j: int = maxi(0, i - (int(ciclo[2]) if ciclo.size() > 2 else 0))
		if not (copia.material is ShaderMaterial and (copia.material as ShaderMaterial).shader == SHADER_TINTE):
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = SHADER_TINTE
			copia.material = material
		var m: ShaderMaterial = copia.material as ShaderMaterial
		m.set_shader_parameter(&"color_tinte", colores[(j / cada) % colores.size()])
		m.set_shader_parameter(&"cantidad", float(j % cada) / 16.0)


## Fase (0..255) de una onda [amplitud, paso, fase] en el paso `j`; el paso puede ser fraccionario
## (la fase de Burbuja avanza 128/256 por frame).
static func _fase_onda(onda: Array, j: int) -> int:
	return posmod(floori(float(onda[2]) + float(onda[1]) * j), 256)


func _detras_del_defensor(copia: CanvasItem, detras: bool) -> void:
	if not is_instance_valid(sprite_defensor):
		return
	copia.z_as_relative = not detras
	copia.z_index = z_absoluto(sprite_defensor) - 1 if detras else 0


func _fuera_del_campo(p: Vector2) -> bool:
	return p.x > tamano_campo.x + 16.0 or p.x < -16.0 or p.y > tamano_campo.y or p.y < -16.0


func _nodos_fondo() -> Array[Node2D]:
	var nodos: Array[Node2D] = []
	var padre: Node = get_parent()
	if padre == null:
		return nodos
	for nombre: StringName in NODOS_FONDO_BATALLA:
		var nodo: Node2D = padre.get_node_or_null(NodePath(String(nombre))) as Node2D
		if nodo != null:
			nodos.append(nodo)
			if not _fondo_movido.has(nodo):
				_fondo_movido[nodo] = nodo.position
	return nodos


func _restaurar_sprites() -> void:
	for nodo: Variant in _fondo_movido.keys():
		if is_instance_valid(nodo):
			(nodo as Node2D).position = _fondo_movido[nodo]
	_fondo_movido.clear()
	super._restaurar_sprites()
