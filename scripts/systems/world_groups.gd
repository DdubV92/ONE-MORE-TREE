class_name WorldGroups
extends RefCounted
## Group lookup limited to one world instance (tests and tools can have more
## than one world alive while an old one is being freed).

static func of(n: Node, group: String) -> Array[Node]:
	var out: Array[Node] = []
	var root: Node = n
	while root and not root is IslandWorld:
		root = root.get_parent()
	for g in n.get_tree().get_nodes_in_group(group):
		if root == null or root.is_ancestor_of(g):
			out.append(g)
	return out
