## Formateador de ligaduras de `fuentes/pokemon-rs.ttf`
## Convierte macros legibles ({PO}, {Ké}, {PK}, {MN}, {...}) en glifos de la fuente.
## Es una transformación de presentación: aplicar justo antes de asignar el texto
## a un Label/RichTextLabel y no guardar nunca el resultado en partida ni en la BD.
## Ver documentacion/20260920-fuente-pokemon-rs-ligaduras.md

extends RefCounted
class_name FormateadorLigaduras

const LIGADURAS_POKEMON := {
	"{PO}": "",
	"{Ké}": "",
	"{PK}": "",
	"{MN}": "",
	"{...}": "\uE08D.",
}


static func formatear(texto: String) -> String:
	if not texto.contains("{"):
		return texto
	for macro in LIGADURAS_POKEMON:
		texto = texto.replace(macro, LIGADURAS_POKEMON[macro])
	return texto
