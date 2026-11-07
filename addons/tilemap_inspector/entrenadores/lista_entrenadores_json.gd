@tool
extends RefCounted

## Lectura y escritura estable de `BaseDatos/lista_entrenadores.json`.
##
## `JSON.stringify` convierte todos los números a float (`541.0`) y reordena el
## formato; este serializador reproduce `json.dumps(ensure_ascii=False,
## indent="\t")` de Python (el formato de los importadores del decomp): orden de
## inserción de las claves, enteros sin decimales y escapes JSON mínimos. Así
## cargar y guardar sin cambios deja el archivo idéntico.


## Parsea el texto y convierte a int los floats sin parte decimal.
static func cargar(texto: String) -> Array:
	var datos: Variant = JSON.parse_string(texto)
	if not datos is Array:
		return []
	return _normalizar(datos)


static func serializar(lista: Array) -> String:
	return _valor(lista, 0) + "\n"


static func _normalizar(valor: Variant) -> Variant:
	match typeof(valor):
		TYPE_FLOAT:
			return int(valor) if is_equal_approx(valor, roundf(valor)) and absf(valor) < 1e15 else valor
		TYPE_ARRAY:
			var arr: Array = []
			for v in valor:
				arr.append(_normalizar(v))
			return arr
		TYPE_DICTIONARY:
			var dic := {}
			for k in valor:
				dic[k] = _normalizar(valor[k])
			return dic
	return valor


static func _valor(valor: Variant, nivel: int) -> String:
	match typeof(valor):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if valor else "false"
		TYPE_INT:
			return str(valor)
		TYPE_FLOAT:
			return str(valor)
		TYPE_STRING, TYPE_STRING_NAME:
			return _cadena(str(valor))
		TYPE_ARRAY:
			if valor.is_empty():
				return "[]"
			var partes: PackedStringArray = []
			for v in valor:
				partes.append(_sangria(nivel + 1) + _valor(v, nivel + 1))
			return "[\n" + ",\n".join(partes) + "\n" + _sangria(nivel) + "]"
		TYPE_DICTIONARY:
			if valor.is_empty():
				return "{}"
			var partes: PackedStringArray = []
			for k in valor:
				partes.append(_sangria(nivel + 1) + _cadena(str(k)) + ": " + _valor(valor[k], nivel + 1))
			return "{\n" + ",\n".join(partes) + "\n" + _sangria(nivel) + "}"
	return _cadena(str(valor))


static func _sangria(nivel: int) -> String:
	return "\t".repeat(nivel)


static func _cadena(texto: String) -> String:
	var r := "\""
	for i in texto.length():
		var c := texto.unicode_at(i)
		match c:
			0x22: r += "\\\""
			0x5C: r += "\\\\"
			0x0A: r += "\\n"
			0x0D: r += "\\r"
			0x09: r += "\\t"
			0x08: r += "\\b"
			0x0C: r += "\\f"
			_:
				if c < 0x20:
					r += "\\u%04x" % c
				else:
					r += char(c)
	return r + "\""
