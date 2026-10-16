class_name NetProtocol
extends RefCounted
## Shared networking constants and pure helpers (tickets, rate limits,
## payload validation). The lobby service mirrors the ticket format in
## services/lobby/src/tickets.ts.

const DEFAULT_PORT := 24600
const LAN_PORT := 24610
const MAX_PLAYERS := 6
const AUTH_TIMEOUT := 5.0
const RECONNECT_WINDOW := 60.0
const LOAD_TIMEOUT := 60.0
const BROADCAST_HZ := 15.0
const TIME_SYNC_SECONDS := 2.0
## Fastest legitimate player speed (sprint) plus margin, meters/second.
const MAX_PLAYER_SPEED := 6.5
const MAX_AUTH_BYTES := 2048
const TICKET_VERSION := 1

## Reasons sent to clients (translation keys).
const REJECT_VERSION := "NET_REJECT_VERSION"
const REJECT_TICKET := "NET_REJECT_TICKET"
const REJECT_EXPIRED := "NET_REJECT_EXPIRED"
const REJECT_FULL := "NET_REJECT_FULL"
const REJECT_STARTED := "NET_REJECT_STARTED"
const REJECT_KICKED := "NET_REJECT_KICKED"
const REJECT_NAME := "NET_REJECT_NAME"
const REJECT_MALFORMED := "NET_REJECT_MALFORMED"


static func b64url(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")


static func b64url_decode(text: String) -> PackedByteArray:
	var s := text.replace("-", "+").replace("_", "/")
	while s.length() % 4 != 0:
		s += "="
	return Marshalls.base64_to_raw(s)


static func hmac_sha256(secret: String, message: PackedByteArray) -> PackedByteArray:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	ctx.update(message)
	return ctx.finish()


## Signs a ticket payload. Used by tests and the LAN tooling; production
## tickets are minted by the lobby service with the same algorithm.
static func make_ticket(payload: Dictionary, secret: String) -> String:
	var body := JSON.stringify(payload).to_utf8_buffer()
	return b64url(body) + "." + b64url(hmac_sha256(secret, body))


## Verifies signature, version, expiry and room. Returns
## {"ok": bool, "reason": String, "payload": Dictionary}.
static func verify_ticket(ticket: String, secret: String, room_id: String, now_unix: int) -> Dictionary:
	if secret.is_empty() or ticket.length() > 1500:
		return {"ok": false, "reason": REJECT_TICKET}
	var parts := ticket.split(".")
	if parts.size() != 2:
		return {"ok": false, "reason": REJECT_TICKET}
	var body := b64url_decode(parts[0])
	var sig := b64url_decode(parts[1])
	if body.is_empty() or not constant_time_equals(sig, hmac_sha256(secret, body)):
		return {"ok": false, "reason": REJECT_TICKET}
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not payload is Dictionary:
		return {"ok": false, "reason": REJECT_TICKET}
	var p: Dictionary = payload
	if int(p.get("v", 0)) != TICKET_VERSION:
		return {"ok": false, "reason": REJECT_TICKET}
	if str(p.get("room", "")) != room_id or room_id.is_empty():
		return {"ok": false, "reason": REJECT_TICKET}
	if int(p.get("exp", 0)) < now_unix:
		return {"ok": false, "reason": REJECT_EXPIRED}
	if str(p.get("uid", "")).length() < 8:
		return {"ok": false, "reason": REJECT_TICKET}
	return {"ok": true, "reason": "", "payload": p}


static func constant_time_equals(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var diff := 0
	for i in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0


static func finite_vec(v: Variant) -> bool:
	if not v is Vector3:
		return false
	var p: Vector3 = v
	return is_finite(p.x) and is_finite(p.y) and is_finite(p.z) and p.length() < 10000.0


static func finite_num(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


## Token bucket per (peer, kind). Returns false when the call must be dropped.
class RateLimiter:
	extends RefCounted
	## kind -> [capacity, refill per second]
	var limits := {
		"motion": [40.0, 30.0],
		"action": [10.0, 8.0],
		"lobby": [10.0, 4.0],
		"ping": [3.0, 1.0],
	}
	var _buckets: Dictionary = {}
	var dropped: Dictionary = {}

	func allow(peer: int, kind: String, now: float) -> bool:
		var lim: Array = limits.get(kind, [5.0, 2.0])
		var key := "%d:%s" % [peer, kind]
		var b: Array = _buckets.get(key, [float(lim[0]), now])
		var tokens := minf(float(lim[0]), float(b[0]) + (now - float(b[1])) * float(lim[1]))
		if tokens < 1.0:
			_buckets[key] = [tokens, now]
			dropped[peer] = int(dropped.get(peer, 0)) + 1
			return false
		_buckets[key] = [tokens - 1.0, now]
		return true

	func forget(peer: int) -> void:
		for key in _buckets.keys():
			if str(key).begins_with("%d:" % peer):
				_buckets.erase(key)
		dropped.erase(peer)
