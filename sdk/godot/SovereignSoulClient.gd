extends Node
class_name SovereignSoulClient

## Sovereign Soul Engine — Godot 4 Client
## Drop-in node for persistent NPC psychology in Godot.

@export var base_url: String = "http://localhost:8561"
@export var api_key: String = ""

signal response_received(speech: String, thought: String, action: Dictionary)
signal error_occurred(message: String)

func chat(character_slug: String, message: String, scene_id: String = "") -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_chat_completed.bind(http))
	
	var headers := ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)
		
	var body := {
		"character_slug": character_slug,
		"message": message
	}
	if scene_id != "":
		body["scene_id"] = scene_id
		
	var url := base_url + "/sse/api/npc_chat"
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		emit_signal("error_occurred", "Failed to initiate HTTP request to SSE")
		http.queue_free()

func _on_chat_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if response_code != 200:
		emit_signal("error_occurred", "SSE returned error code: %d" % response_code)
		return
		
	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		emit_signal("error_occurred", "Failed to parse SSE JSON response")
		return
		
	var data: Dictionary = json.data
	var speech: String = data.get("public_speech", "")
	var thought: String = data.get("private_thought", "")
	var action: Dictionary = data.get("proposed_action", {})
	
	emit_signal("response_received", speech, thought, action)
