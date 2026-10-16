class_name NameValidator
extends RefCounted
## Display-name rules shared by the client UI and (mirrored) by the lobby
## service. Display names are cosmetic: they never grant access to anything.

enum Result { OK, TOO_SHORT, TOO_LONG, INVALID_CHARACTERS }

const MIN_LENGTH := 2
const MAX_LENGTH := 20


## Trims whitespace and collapses runs of inner whitespace to one space.
static func normalize(raw: String) -> String:
	var stripped := raw.strip_edges()
	var out := ""
	var last_space := false
	for i in stripped.length():
		var c := stripped[i]
		var is_space := c == " " or c == "\t" or c == "\u00a0" or c == "\u3000"
		if is_space:
			if not last_space:
				out += " "
			last_space = true
		else:
			out += c
			last_space = false
	return out


static func validate(raw: String) -> Result:
	var clean := normalize(raw)
	if clean.length() < MIN_LENGTH:
		return Result.TOO_SHORT
	if clean.length() > MAX_LENGTH:
		return Result.TOO_LONG
	for i in clean.length():
		var code := clean.unicode_at(i)
		if not _is_allowed_codepoint(code):
			return Result.INVALID_CHARACTERS
	return Result.OK


static func error_key(result: Result) -> String:
	match result:
		Result.TOO_SHORT:
			return "NAME_ERR_SHORT"
		Result.TOO_LONG:
			return "NAME_ERR_LONG"
		Result.INVALID_CHARACTERS:
			return "NAME_ERR_CHARS"
	return ""


## Rejects control, formatting, private-use and markup-significant characters.
## Letters/marks/digits from any script are allowed so non-English names work.
static func _is_allowed_codepoint(code: int) -> bool:
	if code < 0x20 or (code >= 0x7f and code <= 0x9f):
		return false  # C0/C1 controls
	if code >= 0x200b and code <= 0x200f:
		return false  # zero-width and directional marks
	if code >= 0x202a and code <= 0x202e:
		return false  # bidi embedding/override (spoofing)
	if code >= 0x2066 and code <= 0x2069:
		return false  # bidi isolates
	if code == 0xfeff or code == 0x00ad:
		return false  # BOM, soft hyphen
	if code >= 0xe000 and code <= 0xf8ff:
		return false  # private use
	if code >= 0xd800 and code <= 0xdfff:
		return false  # lone surrogates
	if code >= 0xfff0:
		return false  # specials and supplementary private use
	# Characters with markup meaning in BBCode/HTML-ish renderers.
	if code in [0x5b, 0x5d, 0x3c, 0x3e, 0x5c, 0x60, 0x7b, 0x7d]:
		return false
	return true


## Escape for any context that might interpret markup. UI should still prefer
## plain Label nodes (no BBCode) for untrusted text.
static func escape_bbcode(text: String) -> String:
	# Single pass: a two-step replace would also escape the "]" of "[lb]".
	var out := ""
	for i in text.length():
		var c := text[i]
		if c == "[":
			out += "[lb]"
		elif c == "]":
			out += "[rb]"
		else:
			out += c
	return out
