# LocalizationParser.gd
# Universal stream parser for XML-style <entry name="KEY">TEXT</entry> and JSON localization formats.
# Decoupled, stand-alone utility compatible with Godot 4.x.
class_name LocalizationParser
extends RefCounted

static var _entry_regex: RegEx = null


## Compiles the regex once statically for fast repeated parsing.
static func _get_entry_regex() -> RegEx:
	if _entry_regex == null:
		_entry_regex = RegEx.new()
		_entry_regex.compile("<entry\\s+name=\"([^\"]+)\">([\\s\\S]*?)</entry>")
	return _entry_regex


## Parses XML string content with <entry name="...">...</entry> into a Dictionary.
static func parse_xml_entries(text: String) -> Dictionary:
	var result: Dictionary = {}
	var regex = _get_entry_regex()
	var matches = regex.search_all(text)

	for m in matches:
		var key = m.get_string(1).strip_edges()
		var raw_val = m.get_string(2)
		var clean_val = unescape_xml_entities(raw_val)
		result[key] = clean_val

	return result


## Parses an XML entries file from disk into a Dictionary.
static func parse_xml_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LocalizationParser: File not found: %s" % path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("LocalizationParser: Failed to open %s for read." % path)
		return {}

	var content = file.get_as_text()
	file.close()
	return parse_xml_entries(content)


## Unescapes standard XML entities (&apos;, &quot;, &lt;, &gt;, &amp;).
static func unescape_xml_entities(s: String) -> String:
	return s \
		.replace("&apos;", "'") \
		.replace("&quot;", "\"") \
		.replace("&lt;", "<") \
		.replace("&gt;", ">") \
		.replace("&amp;", "&")
