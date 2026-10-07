extends RefCounted

## One visible modal. Narrative (events, Dawn) sits above ambient menus
## (build list, room card, laws). The covered menu stays on the stack.

const AMBIENT := 1
const NARRATIVE := 2

var _stack: Array = []


func push(priority: int, token: String) -> void:
	var kept: Array = []
	for entry in _stack:
		if int(entry.priority) == priority:
			continue
		kept.append(entry)
	kept.append({"priority": priority, "token": token})
	kept.sort_custom(func(a, b): return int(a.priority) < int(b.priority))
	_stack = kept


func pop() -> void:
	if _stack.is_empty():
		return
	_stack.pop_back()


func top_token() -> String:
	if _stack.is_empty():
		return ""
	return str(_stack.back().token)


func top_priority() -> int:
	if _stack.is_empty():
		return 0
	return int(_stack.back().priority)


func visible_count() -> int:
	return 0 if _stack.is_empty() else 1


func depth() -> int:
	return _stack.size()


func is_empty() -> bool:
	return _stack.is_empty()
