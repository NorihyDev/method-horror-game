extends TestCase
## Ticket signing/verification and rate limiting.

const SECRET := "test-secret-not-for-production-0123456789"


func _payload(exp_offset: int = 300) -> Dictionary:
	return {"v": 1, "room": "room-abc", "uid": "user-12345678", "name": "Ann", "color": 2,
		"exp": int(Time.get_unix_time_from_system()) + exp_offset}


func test_valid_ticket_verifies() -> void:
	var t := NetProtocol.make_ticket(_payload(), SECRET)
	var r := NetProtocol.verify_ticket(t, SECRET, "room-abc", int(Time.get_unix_time_from_system()))
	assert_true(r["ok"], str(r))
	assert_eq(r["payload"]["uid"], "user-12345678")


func test_tampered_ticket_rejected() -> void:
	var t := NetProtocol.make_ticket(_payload(), SECRET)
	var parts := t.split(".")
	var p := _payload()
	p["uid"] = "user-attacker99"
	var forged := NetProtocol.b64url(JSON.stringify(p).to_utf8_buffer()) + "." + parts[1]
	var now := int(Time.get_unix_time_from_system())
	assert_false(NetProtocol.verify_ticket(forged, SECRET, "room-abc", now)["ok"], "payload swap")
	assert_false(NetProtocol.verify_ticket(t, "other-secret", "room-abc", now)["ok"], "wrong secret")
	assert_false(NetProtocol.verify_ticket(t + "x", SECRET, "room-abc", now)["ok"], "corrupted signature")
	assert_false(NetProtocol.verify_ticket("garbage", SECRET, "room-abc", now)["ok"], "garbage")
	assert_false(NetProtocol.verify_ticket("", SECRET, "room-abc", now)["ok"], "empty")


func test_ticket_bound_to_room_and_time() -> void:
	var now := int(Time.get_unix_time_from_system())
	var t := NetProtocol.make_ticket(_payload(), SECRET)
	assert_false(NetProtocol.verify_ticket(t, SECRET, "room-other", now)["ok"], "other room")
	var expired := NetProtocol.make_ticket(_payload(-5), SECRET)
	var r := NetProtocol.verify_ticket(expired, SECRET, "room-abc", now)
	assert_false(r["ok"])
	assert_eq(r["reason"], NetProtocol.REJECT_EXPIRED)
	assert_false(NetProtocol.verify_ticket(t, "", "room-abc", now)["ok"], "server without secret refuses all")


func test_rate_limiter_drops_bursts_and_refills() -> void:
	var rl := NetProtocol.RateLimiter.new()
	var allowed := 0
	for i in 30:
		if rl.allow(7, "action", 100.0):
			allowed += 1
	assert_eq(allowed, 10, "burst capped at capacity")
	assert_false(rl.allow(7, "action", 100.05))
	assert_true(rl.allow(7, "action", 101.0), "refills over time")
	assert_true(rl.allow(8, "action", 100.0), "other peers unaffected")


func test_validators() -> void:
	assert_true(NetProtocol.finite_vec(Vector3(1, 2, 3)))
	assert_false(NetProtocol.finite_vec(Vector3(NAN, 0, 0)))
	assert_false(NetProtocol.finite_vec(Vector3(1e9, 0, 0)))
	assert_false(NetProtocol.finite_vec("1,2,3"))
	assert_false(NetProtocol.finite_num(INF))
	assert_true(NetProtocol.finite_num(3))


func test_ticket_minted_by_lobby_service_verifies() -> void:
	# Minted by services/lobby/src/security.ts signTicket(); exp 4102444800 (2100-01-01).
	var from_node := "eyJ2IjoxLCJyb29tIjoicm9vbV9ub2RlIiwidWlkIjoidXNyX2Zyb21ub2RlMSIsIm5hbWUiOiJCb2IiLCJjb2xvciI6MywiZXhwIjo0MTAyNDQ0ODAwfQ.X0ocpKkCUYXu2xpGVfVgzh2lfzqIvdVxeybVYZTHTQ0"
	var r := NetProtocol.verify_ticket(from_node, SECRET, "room_node", int(Time.get_unix_time_from_system()))
	assert_true(r["ok"], "cross-language ticket: " + str(r))
	assert_eq(str(r.get("payload", {}).get("uid", "")), "usr_fromnode1")
