## Procesador de comandos de escape para diálogos
## Maneja la tokenización y ejecución de comandos embebidos en texto

extends RefCounted
class_name DialogCommandProcessor

signal comando_ejecutado(comando: String, parametros: Array)

enum Velocidad { LENTA, MEDIA, RAPIDA, TURBO }

## Procesa comandos de sustitución y ejecución en diálogos.<br>
## Ejemplo: "Hola {PN}" -> "Hola <nombre_del_jugador>"
func procesar_comandos_sustitucion(texto: String) -> String:
	var texto_procesado = texto

	# Reemplazar {PN} con el nombre del jugador
	if texto_procesado.contains("{PN}"):
		var nombre_jugador = _obtener_nombre_jugador()
		texto_procesado = texto_procesado.replace("{PN}", nombre_jugador)
		print("🔄 [COMANDO] {PN} reemplazado por: ", nombre_jugador)

	# Ligaduras de la fuente ({PO}, {Ké}, {PK}, {MN}): antes de tokenizar comandos
	texto_procesado = FormateadorLigaduras.formatear(texto_procesado)

	return texto_procesado

## Divide una sección de texto en tokens de texto plano (String) y comandos embebidos (Dictionary).<br>
## Mantiene el orden en el que aparecen en la sección.<br>
## Ejemplo: "Hola {menu_confirmacion} mundo" -> ["Hola ", {comando: "opera_menu_confirmacion", parametros: []}, " mundo"]
func split_section_tokens(section: String) -> Array:
	var tokens: Array = []

	# Primero procesar los comandos de sustitución de texto
	var texto_procesado = procesar_comandos_sustitucion(section)

	# Buscar comandos del tipo {comando:params}
	var regex = RegEx.new()
	regex.compile("(?:\\\\)?\\{([^}]+)\\}")
	var res = regex.search_all(texto_procesado)

	if res.size() == 0:
		tokens.append(texto_procesado)
		return tokens

	var last_index = 0
	for match in res:
		var inner = match.get_string(1)
		var start = match.get_start(0)

		# Texto antes del comando
		if start > last_index:
			tokens.append(texto_procesado.substr(last_index, start - last_index))

		# Parsear comando y parámetros
		var partes = inner.split(":")
		var cmd = partes[0]
		var params = []
		if partes.size() > 1:
			params = partes[1].split(",")
		tokens.append({"comando": cmd, "parametros": params})
		last_index = match.get_end(0)

	# Texto restante después del último comando
	if last_index < texto_procesado.length():
		tokens.append(texto_procesado.substr(last_index, texto_procesado.length() - last_index))

	return tokens

## Ejecuta un comando y retorna resultado con tipo y datos
## Retorna: {tipo: "modal|espera|configuracion|control", datos: cualquier_cosa}
func ejecutar_comando(comando: String, parametros: Array = []) -> Dictionary:
	print("⚡ [COMANDO] Ejecutando: ", comando, " params: ", parametros)

	emit_signal("comando_ejecutado", comando, parametros)

	match comando:
		"opera_menu_confirmacion":
			return {"tipo": "modal", "datos": "menu_si_no"}

		"pausa", "esperar":
			var tiempo = 0.5
			if parametros.size() > 0:
				tiempo = float(parametros[0])
			return {"tipo": "espera", "datos": tiempo}

		"cerrar":
			return {"tipo": "control", "datos": "cerrar"}

		"velocidad":
			if parametros.size() > 0:
				var nueva_velocidad = _parsear_velocidad(parametros[0])
				return {"tipo": "configuracion", "datos": {"velocidad": nueva_velocidad}}
			return {"tipo": "desconocido", "datos": null}
		_:
			print("⚠️ [COMANDO] Comando desconocido: ", comando)
			return {"tipo": "desconocido", "datos": null}

## Convierte un parámetro de texto a un valor del enum Velocidad.
func _parsear_velocidad(param: String) -> Velocidad:
	match param.to_lower():
		"lenta":
			return Velocidad.LENTA
		"media":
			return Velocidad.MEDIA
		"rapida", "rápida":
			return Velocidad.RAPIDA
		"turbo":
			return Velocidad.TURBO
		_:
			return Velocidad.MEDIA

## Obtiene el nombre del jugador desde el sistema de guardado, con fallback global y nombre por defecto.
func _obtener_nombre_jugador() -> String:
	var sg = Engine.get_main_loop().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.jugador:
		var nombre = sg.datos_vivos.jugador.nombre
		if nombre != null and nombre != "":
			return nombre

	# Fallback global
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.jugador:
		var nombre = SistemaGuardado.datos_vivos.jugador.nombre
		if nombre != null and nombre != "":
			return nombre

	# Nombre por defecto
	return "PLANO"
