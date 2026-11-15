class_name YardFloatStack
extends RefCounted

## Where a centre-screen float sits. `order` is salvage, then the observer line.
## A float only yields to rows earlier in that order. The salvage tween rises, so the gap grows.
static func y(host_size_y: float, self_node: Control, order: Array) -> float:
	var at := host_size_y * 0.42
	for other in order:
		var node := other as Control
		if node == self_node:
			break
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		if node.size.y <= 1.0:
			continue
		at = maxf(at, node.position.y + node.size.y + 6.0)
	return at
