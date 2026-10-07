class_name Words
extends RefCounted

## One count phrase for UI copy. 1 is singular. 0 and every larger count are plural.


static func count(n: int, one: String, many: String = "") -> String:
	var word := one if n == 1 else (many if many != "" else "%ss" % one)
	return "%d %s" % [n, word]
