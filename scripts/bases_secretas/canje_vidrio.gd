extends Control
class_name CanjeVidrio

signal terminada
const PAUSA: StringName = &"canje_vidrio"
@export var dialogo: DialogoBaseSecreta
@export var menu: MenuCanjeVidrio
@export var telon: ColorRect
var activa: bool = false
var comprometido: bool = false
var _sesion: int = 0
var _contexto: Dictionary = {}
var _taller: TallerVidrio
var _fanfarria: bool = false


func iniciar(artesano: Node2D, taller: TallerVidrio) -> void:
	var admin: Node2D = artesano.nodo_administrador
	var actor: Node2D = admin.jugador
	_taller = taller
	_sesion += 1
	activa = true
	comprometido = false
	_contexto = {"artesano": artesano, "admin": admin, "jugador": actor, "mapa": admin.mapa_actual,
		"partida": SistemaGuardado.datos_vivos, "inventario": SistemaGuardado.get_bases_secretas(),
		"posicion": actor.global_position, "frente": actor.facing_direction, "capa": Singleton.capa_activa,
		"posicion_artesano": artesano.global_position,
		"cuadro": admin.cuadro_dialogo, "raiz_cuadro": admin.cuadro_dialogo.nodo_raiz,
		"jugador_cuadro": admin.cuadro_dialogo.nodo_jugador}
	dialogo.cuadro = admin.cuadro_dialogo
	dialogo.cuadro.nodo_raiz = null
	dialogo.cuadro.nodo_jugador = null
	Singleton.mantener_pausa(PAUSA, true)
	_ejecutar(_sesion)


func _vigente(sesion: int) -> bool:
	var admin: Variant = _contexto.get("admin")
	var actor: Variant = _contexto.get("jugador")
	var artesano: Variant = _contexto.get("artesano")
	return activa and sesion == _sesion and is_inside_tree() and not is_queued_for_deletion() \
		and is_instance_valid(admin) and is_instance_valid(actor) and is_instance_valid(artesano) \
		and artesano.is_visible_in_tree() and artesano.taller == _taller and not artesano.is_queued_for_deletion() \
		and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
		and artesano.global_position == _contexto.get("posicion_artesano") \
		and SistemaGuardado.datos_vivos == _contexto.get("partida") \
		and SistemaGuardado.get_bases_secretas() == _contexto.get("inventario") \
		and admin.mapa_actual == _contexto.get("mapa") and admin.jugador == actor and int(admin.coneccion) == 0 \
		and actor.global_position == _contexto.get("posicion") and actor.facing_direction == _contexto.get("frente") \
		and Singleton.capa_activa == int(_contexto.get("capa", -1)) \
		and (artesano.capa_datos < 0 or Singleton.capa_activa == artesano.capa_datos) \
		and is_instance_valid(_contexto.get("cuadro")) and not _contexto.get("cuadro").is_queued_for_deletion() \
		and admin.cuadro_dialogo == _contexto.get("cuadro") \
		and (comprometido or _taller.tiene_saco())


func _ejecutar(sesion: int) -> void:
	await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_COMPROBAR"))
	if not _vigente(sesion): return
	if _taller.ceniza() < 250:
		await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_POCA_CENIZA", "", 250 - _taller.ceniza()))
		if _vigente(sesion): cancelar()
		return
	await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_SUFICIENTE"))
	if not _vigente(sesion): return
	while _vigente(sesion):
		var indice: int = await menu.elegir()
		if not _vigente(sesion): return
		if indice < 0:
			await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_SALIR"))
			break
		var receta: Dictionary = TallerVidrio.RECETAS[indice]
		var nombre: String = DatosCanjeVidrio.nombre_receta(indice)
		if not _taller.disponible(indice):
			await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_ELEGIR"))
			continue # Las flautas ausentes siguen sin habilitarse ni cobrar.
		if _taller.ceniza() < int(receta.costo):
			await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_FALTAN", nombre, int(receta.costo) - _taller.ceniza()))
			continue
		var acepta: bool = await dialogo.preguntar(DatosCanjeVidrio.texto("VIDRIO_CONFIRMAR", nombre))
		if not _vigente(sesion): return
		if not acepta:
			await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_ELEGIR"))
			continue
		await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_ESPERAR", nombre))
		if not _vigente(sesion): return
		await _fundir(sesion, true)
		if not _vigente(sesion): return
		Singleton.play_sound.emit("SE_SELECT")
		var fin: int = Time.get_ticks_msec() + 500 # delay 30 / 60 Hz original.
		while _vigente(sesion) and Time.get_ticks_msec() < fin: await get_tree().process_frame
		if not _vigente(sesion): return
		await _fundir(sesion, false)
		if not _vigente(sesion): return
		var resultado: StringName = _taller.canjear(indice)
		match resultado:
			&"entregado":
				comprometido = true
				await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_TERMINADO", nombre))
				if not _vigente(sesion): return
				await _anunciar(sesion, receta, nombre)
				break
			&"ceniza_insuficiente":
				await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_FALTAN", nombre, int(receta.costo) - _taller.ceniza()))
			&"sin_espacio", &"version_incompatible":
				if receta.get("decoracion", false):
					await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_NO_CABE", nombre))
					if not _vigente(sesion): return
				await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_SIN_PC" if receta.get("decoracion", false) else "VIDRIO_SIN_MOCHILA"))
				break
			_:
				break
	if _vigente(sesion): cancelar()


func _anunciar(sesion: int, receta: Dictionary, nombre: String) -> void:
	var decoracion: bool = bool(receta.get("decoracion", false))
	dialogo.show()
	dialogo.cuadro.mostrar(DatosCanjeVidrio.texto("VIDRIO_OBTENIDO" if decoracion else "VIDRIO_OBJETO_OBTENIDO", nombre), false, false, dialogo.texto_terminado.emit)
	_reproducir_fanfarria(sesion)
	while _vigente(sesion) and (_fanfarria or dialogo.cuadro.estado_dialogo == dialogo.cuadro.EstadoDialogo.APARECIENDO):
		await get_tree().process_frame
	if not _vigente(sesion): return
	await dialogo.mensaje(DatosCanjeVidrio.texto("VIDRIO_ENVIADO_PC" if decoracion else "VIDRIO_OBJETO_GUARDADO", nombre))


func _reproducir_fanfarria(sesion: int) -> void:
	_fanfarria = true
	await Fanfarria.reproducir_cancelable(self, "OBTENIDO_OBJETO", _vigente.bind(sesion))
	if sesion == _sesion: _fanfarria = false


func _fundir(sesion: int, oscuro: bool) -> void:
	telon.show()
	var inicio: int = Time.get_ticks_msec()
	while _vigente(sesion) and Time.get_ticks_msec() - inicio < 250:
		var peso: float = clampf(float(Time.get_ticks_msec() - inicio) / 250.0, 0.0, 1.0)
		telon.color.a = peso if oscuro else 1.0 - peso
		await get_tree().process_frame
	if _vigente(sesion):
		telon.color.a = 1.0 if oscuro else 0.0
		telon.visible = oscuro


func _process(_delta: float) -> void:
	if activa and not _vigente(_sesion): cancelar()


func cancelar() -> void:
	if not activa: return
	_sesion += 1
	activa = false
	_fanfarria = false
	menu.cancelar()
	dialogo.cancelar()
	telon.hide()
	var cuadro: Variant = _contexto.get("cuadro")
	if is_instance_valid(cuadro):
		cuadro.nodo_raiz = _contexto.get("raiz_cuadro") if is_instance_valid(_contexto.get("raiz_cuadro")) else null
		cuadro.nodo_jugador = _contexto.get("jugador_cuadro") if is_instance_valid(_contexto.get("jugador_cuadro")) else null
	_contexto.clear()
	Singleton.mantener_pausa(PAUSA, false)
	terminada.emit()


func _exit_tree() -> void: cancelar()
