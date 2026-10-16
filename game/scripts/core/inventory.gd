class_name Inventory
extends RefCounted
## Small slot inventory. Each slot holds one item id with a stack count.
## Pure data: the authority mutates it, presentation only reads it.

const DEFAULT_CAPACITY := 6

var capacity := DEFAULT_CAPACITY
## item id -> max stack size (missing ids stack to 1)
var stack_limits: Dictionary = {}
var slots: Array[Dictionary] = []


func _init(p_capacity: int = DEFAULT_CAPACITY, p_stack_limits: Dictionary = {}) -> void:
	capacity = p_capacity
	stack_limits = p_stack_limits


func count(item_id: String) -> int:
	var total := 0
	for s in slots:
		if s["id"] == item_id:
			total += int(s["count"])
	return total


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func can_add(item_id: String, amount: int = 1) -> bool:
	return _space_for(item_id) >= amount


func add(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0 or not can_add(item_id, amount):
		return false
	var remaining := amount
	var limit := _limit(item_id)
	for s in slots:
		if remaining == 0:
			break
		if s["id"] == item_id and int(s["count"]) < limit:
			var take := mini(remaining, limit - int(s["count"]))
			s["count"] = int(s["count"]) + take
			remaining -= take
	while remaining > 0:
		var take := mini(remaining, limit)
		slots.append({"id": item_id, "count": take})
		remaining -= take
	return true


func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not has(item_id, amount):
		return false
	var remaining := amount
	for i in range(slots.size() - 1, -1, -1):
		if remaining == 0:
			break
		var s := slots[i]
		if s["id"] != item_id:
			continue
		var take := mini(remaining, int(s["count"]))
		s["count"] = int(s["count"]) - take
		remaining -= take
		if int(s["count"]) <= 0:
			slots.remove_at(i)
	return true


func item_at(index: int) -> String:
	if index < 0 or index >= slots.size():
		return ""
	return slots[index]["id"]


func is_empty() -> bool:
	return slots.is_empty()


func to_array() -> Array:
	var out := []
	for s in slots:
		out.append({"id": s["id"], "count": int(s["count"])})
	return out


## Rebuilds from serialized data, discarding malformed entries.
func load_array(data: Array) -> void:
	slots.clear()
	for entry in data:
		if entry is Dictionary and entry.get("id") is String and not str(entry["id"]).is_empty():
			var item: String = entry["id"]
			var wanted := clampi(int(entry.get("count", 1)), 1, 99)
			var fits := mini(wanted, _space_for(item))
			if fits > 0:
				add(item, fits)


func _limit(item_id: String) -> int:
	return maxi(1, int(stack_limits.get(item_id, 1)))


func _space_for(item_id: String) -> int:
	var limit := _limit(item_id)
	var space := 0
	for s in slots:
		if s["id"] == item_id:
			space += limit - int(s["count"])
	space += (capacity - slots.size()) * limit
	return space
