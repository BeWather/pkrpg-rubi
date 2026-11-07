extends RefCounted
## Ruby raw u16 held-stat stage. A descriptor is data, never a held mutation.
static func choice(descriptor: Dictionary) -> bool:return int(descriptor.get("source_effect",0))==29
static func attack(raw: int,descriptor: Dictionary) -> int:
	return (raw*150/100)&65535 if choice(descriptor) else raw
