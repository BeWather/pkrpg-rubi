extends EfectoCapasNativo
class_name EfectoEspecialNativo
## Componentes de §24 (documentacion/piloto_animaciones_nativas.md): la familia especial. Va en un archivo
## hermano para que efecto_capas_nativo.gd no crezca sin control; hereda todos los componentes anteriores y
## añade:
##
## - opción "claves" de sprite_estado(): recorrido por fotogramas clave [[frame, Vector2], ...] (posición
##   relativa a `desde`, interpolada en línea recta y truncada entre claves): las trayectorias de los callbacks
##   que no son una recta, un arco o una órbita (las notas de Canto Mortal, las bolsas de Truco, las manos de
##   Refuerzo). El generador deja solo las claves necesarias para seguir el original a ±1 px. "claves_rival":
##   las que se usan cuando ataca el rival (el original no es simétrico: la bola de Meteorobola).
## - opción "gris_desde" de sprite_estado(): desde ese frame el sprite se ve en gris (sub_8079108 sobre su
##   paleta: las notas de Canto Mortal).
## - opción "detras_de" de sprite_estado(): [[frame, rol], ...]: desde ese frame el sprite va detrás del battler
##   `rol` ("atacante", "defensor", "jugador" o "rival"; "" = delante de los dos): subprioridad que cambia en el
##   callback (el dedo de Señuelo, las bolsas de Truco).
## - mover_battler(): desplazamiento de un battler por fotogramas clave (x2 / y2 que escribe una tarea).
## - ocultar_battler() / parpadeo_battler(): `invisible` del battler (Teletransporte, Relevo, Velocidad Extrema).
## - mezclar_paleta_terreno(): mezcla de paleta hacia el color del terreno de la batalla (`datos.terreno`).
## - ventana_fondo(): ventana que crece y oscurece el fondo (Maldición de un fantasma).
## - fondo_por_claves() / fijar_fondo(): scroll del fondo propio por claves (Sísmico) y changebg sin fundido.
## - silueta_defensor(): silueta blanca de la especie del defensor vista desde el lado del atacante (Imitación).
## - transformar() / sustituto(): el atacante pasa a la imagen del defensor (mosaico) o al muñeco del sustituto.
##   La imagen nueva se queda: al acabar la escena la confirma `apariencia` (lo pone el adaptador en batalla, con
##   el mismo BattleOwnedAppearanceLease que la VM); sin él (comparador) el atacante vuelve a su imagen.
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador» reflejadas en x
## según `direccion`.

const SHADER_MOSAICO: Shader = preload("res://escenas/batalla/animaciones_nativas/mosaico.gdshader")
const TEXTURA_SUSTITUTO_ESPALDA: Texture2D = preload("res://graficos/batalla/animaciones/substitute_back.png")
const TEXTURA_SUSTITUTO_FRENTE: Texture2D = preload("res://graficos/batalla/animaciones/substitute_front.png")

## Proveedor de los cambios de apariencia que se quedan (Transformación, Sustituto): objeto con
## preparar_transformacion(), preparar_sustituto(), confirmar() y descartar(). Lo pone el adaptador en batalla.
var apariencia: Object = null
var _confirmar_apariencia: bool = false
var _cancelada: bool = false
## Copias de battlers creadas por transformar() / sustituto() / silueta_defensor().
var _copias_especiales: Array[Sprite2D] = []


## Opciones "claves" y "claves_rival" (ver arriba) sumadas a las de las clases padre.
func _trayectoria(opciones: Dictionary, vida: int) -> Array[Vector2]:
	var resultado: Array[Vector2] = super._trayectoria(opciones, vida)
	var claves: Array = opciones.get("claves", [])
	if direccion < 0.0 and opciones.has("claves_rival"):
		claves = opciones.claves_rival
	if claves.is_empty():
		return resultado
	for i: int in resultado.size():
		resultado[i] += _en_claves(claves, i).floor()
	return resultado


## Valor interpolado en el frame `i` de unas claves [[frame, Vector2], ...] (constante fuera de ellas).
static func _en_claves(claves: Array, i: int) -> Vector2:
	if i <= int(claves[0][0]):
		return claves[0][1]
	for k: int in range(1, claves.size()):
		if i <= int(claves[k][0]):
			var f0: int = int(claves[k - 1][0])
			var f1: int = int(claves[k][0])
			var a: Vector2 = claves[k - 1][1]
			var b: Vector2 = claves[k][1]
			return a.lerp(b, float(i - f0) / maxf(1.0, f1 - f0))
	return claves.back()[1]


func _extra_sprite(copia: Sprite2D, opciones: Dictionary, i: int) -> void:
	super._extra_sprite(copia, opciones, i)
	var detras: Array = opciones.get("detras_de", [])
	for clave: Array in detras:
		if int(clave[0]) == i:
			var rol: StringName = StringName(clave[1])
			if rol == &"jugador":
				rol = &"atacante" if direccion > 0.0 else &"defensor"
			elif rol == &"rival":
				rol = &"defensor" if direccion > 0.0 else &"atacante"
			_detras_de(copia, rol if rol != &"" else &"atacante", rol != &"")
	if opciones.has("gris_desde") and i == int(opciones.gris_desde):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER_BRILLO
		material.set_shader_parameter(&"gris", 1.0)
		material.set_shader_parameter(&"brillo", 0.0)
		copia.material = material


## Desplazamiento del battler `rol` por fotogramas clave [[frame, Vector2], ...] (px, caso jugador; se refleja
## en x con `direccion`), interpolado y truncado entre claves; al acabar vuelve a 0 (la tarea pone x2 = y2 = 0).
## `claves_rival`: las que se usan cuando ataca el rival (Teletransporte sube la mitad).
func mover_battler(rol: StringName, claves: Array, claves_rival: Array = []) -> void:
	if direccion < 0.0 and not claves_rival.is_empty():
		claves = claves_rival
	if claves.is_empty():
		return
	var frames: int = int(claves.back()[0])
	_cada_frame(frames, func(i: int) -> void:
		var v: Vector2 = Vector2.ZERO if i >= frames else _reflejar(_en_claves(claves, i).floor())
		_fijar_capa(rol, &"especial", v))


## Oculta el battler `rol` (invisible del original) o lo vuelve a mostrar. Opacidad 0 en su material
## temporal: la escena lo devuelve al acabar, como el resto de cambios del battler.
func ocultar_battler(rol: StringName, oculto: bool = true) -> void:
	visibilidad_battler(rol, not oculto)


## Visibilidad del battler `rol` por claves [[frame, visible], ...] (el invisible que alterna una tarea).
func parpadeo_battler(rol: StringName, cambios: Array) -> void:
	if cambios.is_empty():
		return
	var ultimo: int = int(cambios.back()[0])
	_cada_frame(ultimo, func(i: int) -> void:
		for c: Array in cambios:
			if int(c[0]) == i:
				visibilidad_battler(rol, bool(c[1])))


## Mezcla de paleta del `rol` hacia el color del terreno de la batalla (`datos.terreno`, índice de
## BATTLE_ENVIRONMENT_*; sin dato, la hierba) de `colores` (la tabla del original), como mezclar_paleta().
func mezclar_paleta_terreno(rol: StringName, colores: Array, desde: int, hasta: int, retardo: int = 1) -> void:
	var indice: int = clampi(int(datos.get("terreno", 0)), 0, colores.size() - 1)
	mezclar_paleta(rol, colores[indice], desde, hasta, retardo)


## Ventana que oscurece el fondo de la batalla (WIN0 con REG_BLDY 16 sobre BG3, sub_80DECB0): un rectángulo negro
## por debajo de los battlers crece desde `desde` (`desde_rival` cuando ataca el rival; posiciones de la pantalla)
## hasta cubrir el campo en `frames` frames; al acabar, el fondo queda negro (su paleta, BeginNormalPaletteFade a 16).
func ventana_fondo(desde: Vector2, desde_rival: Vector2, frames: int) -> void:
	var inicio: Vector2 = desde_rival if direccion < 0.0 else desde
	var padre: Node = fondo if fondo != null else self
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.BLACK
	padre.add_child(rect)
	_efectos.append(rect)
	var ancho_abajo: float = 72.0
	_cada_frame(frames, func(i: int) -> void:
		if not is_instance_valid(rect):
			return
		if i >= frames:
			rect.queue_free()
			fijar_tinte(&"fondo", Color.BLACK, 1.0)
			return
		var k: float = i / 16.0
		var izquierda: float = inicio.x - inicio.x * k
		var derecha: float = inicio.x + (tamano_campo.x - inicio.x) * k
		var arriba: float = inicio.y - inicio.y * k
		var abajo: float = inicio.y + ancho_abajo * k
		rect.position = Vector2(izquierda, arriba).floor()
		rect.size = Vector2(derecha - izquierda, abajo - arriba).floor())


## Scroll del fondo propio por claves [[frame, Vector2], ...] relativas a donde estaba (gBattle_BG3_X/Y que escribe
## una tarea frame a frame: el Sísmico sube rápido frenando, baja y salta en y).
func fondo_por_claves(claves: Array) -> void:
	if fondo == null or claves.is_empty():
		return
	var inicial: Vector2 = fondo.desplazamiento
	var frames: int = int(claves.back()[0])
	var id: int = _id_tarea_fondo()
	_cada_frame(frames, func(i: int) -> void:
		if id == _tarea_fondo:
			fondo.desplazamiento = inicial + _en_claves(claves, i).floor())


## changebg: el fondo propio pasa a la textura de `plantilla` al momento (LoadMoveBg, sin fundido).
func fijar_fondo(plantilla: NodePath) -> void:
	if fondo == null:
		return
	_tarea_fondo += 1
	fondo.fotograma = 0
	fondo.fijar_imagen(_plantilla_de_fondo(plantilla))
	fondo.mostrar_imagen = true


## Textura de la especie del battler `rol` vista desde el lado del atacante (espalda si el atacante es el
## jugador): la especie la pone el adaptador en `datos` ("especie_defensor") o sale de la textura del battler.
func _textura_vista_atacante(rol: StringName) -> Texture2D:
	var sprite: Sprite2D = sprite_de(rol)
	var especie: String = str(datos.get("especie_" + str(rol), ""))
	if especie.is_empty() and is_instance_valid(sprite) and sprite.texture != null:
		especie = sprite.texture.resource_path.get_file().get_basename()
	# sub_8031FC4: en concurso siempre gMonBackPicTable, aunque el concursante anime como el lado rival.
	var lado: StringName = PosicionesBattlersJSON.LADO_JUGADOR if direccion > 0.0 or concurso else PosicionesBattlersJSON.LADO_ENEMIGO
	var brillante: bool = is_instance_valid(sprite) and sprite.texture != null and "-shiny/" in sprite.texture.resource_path
	var ruta: String = LienzoBattlers.ruta_sprite(especie, lado, brillante)
	return load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null


## Copia de un battler como Sprite2D propio en su sitio (misma textura, fotograma, volteo y transformada).
func _copia_de(sprite: Sprite2D, z: int) -> Sprite2D:
	var copia: Sprite2D = Sprite2D.new()
	for propiedad: StringName in [&"texture", &"centered", &"offset", &"flip_h", &"flip_v", &"hframes", &"vframes", &"frame", &"region_enabled", &"region_rect"]:
		copia.set(propiedad, sprite.get(propiedad))
	add_child(copia)
	copia.global_transform = sprite.global_transform
	copia.z_as_relative = false
	copia.z_index = z
	_copias_especiales.append(copia)
	_efectos.append(copia)
	return copia


## Silueta de Imitación (AnimTask_RolePlaySilhouette): la especie del defensor vista desde el lado del atacante, toda
## blanca, con los pies en la base del atacante + `desplazamiento` (caso jugador), durante `vida` frames. Opciones:
## "mezcla_claves" ([[frame, eva, evb], ...], REG_BLDALPHA) y "matriz" ([[frame, x, y], ...] de la matriz afín, más =
## más pequeña, interpolada; alrededor del centro).
func silueta_defensor(desplazamiento: Vector2, vida: int, opciones: Dictionary = {}) -> void:
	var textura: Texture2D = _textura_vista_atacante(&"defensor")
	if textura == null or not is_instance_valid(sprite_atacante):
		return
	var copia: Sprite2D = _copia_de(sprite_atacante, z_absoluto(sprite_atacante))
	copia.texture = textura
	copia.hframes = 1
	copia.vframes = 1
	copia.frame = 0
	copia.region_enabled = false
	# Pies a la altura de los del atacante (sub_8079F44 coloca la especie con su y_offset sobre la base).
	var base_local: float = sprite_atacante.get_rect().end.y
	copia.position = to_local(sprite_atacante.to_global(Vector2(0.0, base_local))) - Vector2(0.0, copia.get_rect().end.y * copia.scale.y) + _reflejar(desplazamiento)
	var blanco: ShaderMaterial = ShaderMaterial.new()
	blanco.shader = SHADER_TINTE
	blanco.set_shader_parameter(&"color_tinte", Color.WHITE)
	blanco.set_shader_parameter(&"cantidad", 1.0)
	copia.material = blanco
	var mezcla: Array = opciones.get("mezcla_claves", [])
	var matriz: Array = opciones.get("matriz", [])
	var escala0: Vector2 = copia.scale
	var centro: Vector2 = copia.position + (copia.get_rect().get_center() * escala0)
	_cada_frame(vida, func(i: int) -> void:
		if not is_instance_valid(copia):
			return
		if i >= vida:
			copia.visible = false
			return
		var opacidad: float = 1.0
		for clave: Array in mezcla:
			if int(clave[0]) <= i:
				opacidad = float(clave[1])
		blanco.set_shader_parameter(&"alfa", opacidad)
		if not matriz.is_empty():
			var m: Vector2 = _matriz_en(matriz, i)
			var k: Vector2 = Vector2(256.0 / maxf(1.0, m.x), 256.0 / maxf(1.0, m.y))
			copia.scale = escala0 * k
			copia.position = centro - copia.get_rect().get_center() * copia.scale)


static func _matriz_en(claves: Array, i: int) -> Vector2:
	var resultado: Vector2 = Vector2(float(claves[0][1]), float(claves[0][2]))
	for k: int in range(1, claves.size()):
		if i <= int(claves[k][0]):
			var t: float = float(i - int(claves[k - 1][0])) / maxf(1.0, int(claves[k][0]) - int(claves[k - 1][0]))
			return Vector2(lerpf(float(claves[k - 1][1]), float(claves[k][1]), t), lerpf(float(claves[k - 1][2]), float(claves[k][2]), t))
		resultado = Vector2(float(claves[k][1]), float(claves[k][2]))
	return resultado


## Transformación (sub_812D7E8): una copia del atacante en su sitio (el original se oculta) se pixela (mosaico de
## REG_MOSAIC, un escalón cada `cada` frames hasta `pasos`), cambia a la imagen del defensor (la que da `apariencia`;
## sin él, la textura del defensor vista desde el lado del atacante, 6/16 hacia el blanco) y se despixela. La imagen
## nueva se queda hasta el final de la escena, que la confirma (ver _finalizar()).
func transformar(cada: int, pasos: int) -> void:
	if not is_instance_valid(sprite_atacante):
		return
	# §33: guarda del llamador exigida y no ligada: como la VM, ni mosaico ni cambio de imagen.
	if apariencia != null and bool(apariencia.call(&"transformacion_anulada", sprite_atacante)):
		return
	var copia: Sprite2D = _copia_de(sprite_atacante, z_absoluto(sprite_atacante))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER_MOSAICO
	copia.material = material
	_ventana_mosaico(copia, material)
	visibilidad_battler(&"atacante", false)
	var total: int = cada * pasos * 2 + 2
	var pies: float = sprite_atacante.get_rect().end.y
	_cada_frame(total, func(i: int) -> void:
		if not is_instance_valid(copia):
			return
		if i < cada * pasos:
			material.set_shader_parameter(&"mosaico", float(mini((i + 1) / cada, pasos)))
		elif i == cada * pasos:
			_cambiar_a_defensor(copia, material, pies)
		else:
			var j: int = i - cada * pasos - 1
			material.set_shader_parameter(&"mosaico", float(maxi(0, pasos - (j + 1) / cada))))


func _ventana_mosaico(copia: Sprite2D, material: ShaderMaterial) -> void:
	var tamano: Vector2 = copia.texture.get_size() if copia.texture != null else Vector2.ONE
	var region: Rect2 = copia.region_rect if copia.region_enabled else Rect2(Vector2.ZERO, tamano)
	var fotograma: Vector2 = region.size / Vector2(copia.hframes, copia.vframes)
	material.set_shader_parameter(&"origen_uv", (region.position + Vector2(copia.frame_coords) * fotograma) / tamano)
	material.set_shader_parameter(&"tamano_uv", fotograma / tamano)


func _cambiar_a_defensor(copia: Sprite2D, material: ShaderMaterial, pies: float) -> void:
	var nueva: Dictionary = apariencia.call(&"preparar_transformacion") if apariencia != null else {}
	var textura: Texture2D = nueva.get("texture", null)
	if textura == null:
		textura = _textura_vista_atacante(&"defensor")
		material.set_shader_parameter(&"blanco", 6.0 / 16.0)
	if textura == null:
		return
	var fondo_antes: Vector2 = copia.to_global(Vector2(0.0, pies))
	copia.texture = textura
	copia.hframes = 1
	copia.vframes = 1
	copia.frame = 0
	copia.region_enabled = false
	if nueva.has("flip_h"):
		copia.flip_h = bool(nueva.flip_h)
	# Los pies se quedan donde estaban (como BattleOwnedAppearanceLease.finalize()).
	copia.global_position += fondo_antes - copia.to_global(Vector2(0.0, copia.get_rect().end.y))
	_ventana_mosaico(copia, material)
	_confirmar_apariencia = apariencia != null and not nueva.is_empty()


## Sustituto (sub_81312E4 + sub_8131408): el atacante se estrecha y se aplasta (matriz +0x60 / -0xD por frame, 9
## frames) y desaparece; el muñeco (espalda o frente según el lado) cae desde (+200, -200) con gravedad (112/256 px por
## frame²; deja de ir en diagonal cuando su y llega a -32), bota una vez y se queda. Suena SE_M_BUBBLE2 en cada bote
## (nodo «SonidoBote» si la escena lo tiene). Como en Transformación, el muñeco se queda: lo confirma _finalizar().
func sustituto() -> void:
	if not is_instance_valid(sprite_atacante):
		return
	# §33: guarda del llamador exigida y no ligada: como la VM, ni aplastamiento ni muñeco.
	if apariencia != null and bool(apariencia.call(&"sustituto_anulado", sprite_atacante)):
		return
	var nueva: Dictionary = apariencia.call(&"preparar_sustituto") if apariencia != null else {}
	var textura: Texture2D = nueva.get("texture", TEXTURA_SUSTITUTO_ESPALDA if direccion > 0.0 or concurso else TEXTURA_SUSTITUTO_FRENTE)
	var original: Vector2 = (_escalas.get(&"atacante", [sprite_atacante, sprite_atacante.scale]) as Array)[1]
	if not _escalas.has(&"atacante"):
		_escalas[&"atacante"] = [sprite_atacante, sprite_atacante.scale]
	var centro: Vector2 = sprite_atacante.get_rect().get_center() * original
	var pies_globales: Vector2 = sprite_atacante.to_global(Vector2(0.0, sprite_atacante.get_rect().end.y))
	# Las lambdas capturan por valor: el muñeco va en el diccionario (se crea una sola vez).
	var estado: Dictionary = {"fase": 0, "v": 0, "y": -200.0, "x": 200.0, "muneco": null}
	var sonido_bote: AudioStreamPlayer2D = get_node_or_null(^"SonidoBote") as AudioStreamPlayer2D
	var total: int = 9 + 2 + 120
	_cada_frame(total, func(i: int) -> void:
		if i == 0:
			return
		if i <= 9:
			var k: Vector2 = Vector2(256.0 / (256.0 + 0x60 * i), 256.0 / (256.0 - 0xD * i))
			sprite_atacante.scale = original * k
			_fijar_capa(&"atacante", &"escala", (centro - centro * k).floor())
			if i == 9:
				sprite_atacante.scale = original
				_fijar_capa(&"atacante", &"escala", Vector2.ZERO)
				visibilidad_battler(&"atacante", false)
			return
		if estado.muneco == null:
			estado.muneco = _copia_de(sprite_atacante, z_absoluto(sprite_atacante))
			var muneco_nuevo: Sprite2D = estado.muneco
			muneco_nuevo.texture = textura
			muneco_nuevo.hframes = 1
			muneco_nuevo.vframes = 1
			muneco_nuevo.frame = 0
			muneco_nuevo.region_enabled = false
			muneco_nuevo.flip_h = bool(nueva.get("flip_h", sprite_atacante.flip_h))
			_confirmar_apariencia = apariencia != null and not nueva.is_empty()
		var muneco: Sprite2D = estado.muneco
		if not is_instance_valid(muneco):
			return
		match int(estado.fase):
			0:
				estado.v = int(estado.v) + 112
				estado.y = float(estado.y) + (int(estado.v) >> 8)
				if to_local(pies_globales).y - sprite_atacante.get_rect().size.y * original.y + float(estado.y) >= -32.0:
					estado.x = 0.0
				if float(estado.y) >= 0.0:
					estado.y = 0.0
					estado.v = int(estado.v) - 0x800
					estado.fase = 1
					if sonido_bote != null:
						sonido_bote.play()
			1:
				estado.v = maxi(0, int(estado.v) - 112)
				estado.y = float(estado.y) - (int(estado.v) >> 8)
				if int(estado.v) == 0:
					estado.fase = 2
			2:
				estado.v = int(estado.v) + 112
				estado.y = minf(0.0, float(estado.y) + (int(estado.v) >> 8))
				if float(estado.y) >= 0.0:
					estado.fase = 3
					if sonido_bote != null:
						sonido_bote.play()
		var pies_muneco: Vector2 = Vector2(0.0, muneco.get_rect().end.y) * muneco.scale
		muneco.position = to_local(pies_globales) - pies_muneco + Vector2(float(estado.x) * direccion, float(estado.y)))


## Sacudida amortiguada (sub_80E1864) con la amplitud que da la potencia del movimiento (gAnimMovePower / 10 + 3, cuando
## el script no la fija: Magnitud). Dura más con más potencia: la escena no termina hasta que acaba.
func terremoto_por_potencia(objetivo: StringName, cambios: int) -> void:
	var amplitud: int = int(datos.get("potencia", 60)) / 10 + 3
	terremoto(objetivo, amplitud, cambios)
	_alargar(2 * cambios + 8 * (amplitud - 1) + 3)


## Vaivén del defensor (sub_80A9058) con la amplitud de la potencia (gAnimMovePower / 12, de 1 a 16; Escupir, Bola Hielo).
func vaiven_por_potencia(rol: StringName, periodo: int, veces: int, vertical: bool) -> void:
	var d: int = clampi(int(datos.get("potencia", 60)) / 12, 1, 16)
	vaiven(rol, d / 2 + (d & 1), d / 2, periodo, veces, vertical)


## Efectos cuya duración depende de un dato de batalla: terminar() espera a que acaben (el `end` del script espera a
## las tareas visuales).
var _pendientes: int = 0
var _terminar_pendiente: bool = false
var _liberar_pendiente: StringName = &""


func _alargar(frames: int) -> void:
	_pendientes += 1
	_cada_frame(frames, func(_i: int) -> void: pass, _fin_alargado)


func _fin_alargado() -> void:
	_pendientes -= 1
	if _pendientes > 0:
		return
	if _terminar_pendiente:
		_terminar_pendiente = false
		super.terminar()
	if _liberar_pendiente != &"":
		var nombre: StringName = _liberar_pendiente
		_liberar_pendiente = &""
		super._al_acabar_animacion(nombre)


func terminar() -> void:
	if _pendientes > 0:
		_terminar_pendiente = true
		return
	super.terminar()


func _al_acabar_animacion(nombre: StringName) -> void:
	if _pendientes > 0:
		_liberar_pendiente = nombre
		return
	super._al_acabar_animacion(nombre)


func cancelar() -> void:
	_cancelada = true
	super.cancelar()


## Al acabar (no al cancelar), la imagen nueva de transformar() / sustituto() se queda: `apariencia` la confirma
## después de que la escena devuelva los battlers a su estado (y entonces se quitan las copias). §33: la confirma justo
## al devolverlos, antes de emitir `terminado`, para que el llamador que espera el fin (BattleTransformPresentation.
## reconcile(), BattleSubstitutePresentation.ensure_doll()) ya vea la imagen nueva y no haga su respaldo.
var _apariencia_resuelta: bool = false


func _restaurar_sprites() -> void:
	super._restaurar_sprites()
	_resolver_apariencia()


func _resolver_apariencia() -> void:
	if _apariencia_resuelta:
		return
	_apariencia_resuelta = true
	if apariencia != null:
		apariencia.call(&"confirmar" if _confirmar_apariencia and not _cancelada else &"descartar")


func _finalizar() -> void:
	if _terminado:
		return
	super._finalizar()
	_resolver_apariencia()
	for copia: Sprite2D in _copias_especiales:
		if is_instance_valid(copia):
			copia.queue_free()
	_copias_especiales.clear()
