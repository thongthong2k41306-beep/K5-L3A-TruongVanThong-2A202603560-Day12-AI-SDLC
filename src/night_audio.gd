extends Node
## Original synthesized cues, with no external audio assets.
const RATE := 12000
const CUES := {
	"mote_picked": [660.0, 880.0], "lantern_lit": [330.0, 440.0, 660.0, 880.0],
	"pulse": [180.0, 260.0, 440.0], "player_hit": [125.0, 94.0],
	"jump": [260.0, 390.0], "dash": [320.0, 475.0], "won": [392.0, 523.0, 659.0, 784.0],
	"lost": [392.0, 293.0, 196.0], "shade_spawned": [110.0, 123.0],
	"countdown": [660.0], "wind_warning": [156.0, 196.0, 155.0], "charm_picked": [523.0, 784.0]
}
var effects: Dictionary = {}
var music: AudioStreamPlayer

func _ready() -> void:
	for cue in CUES:
		effects[cue] = _track(CUES[cue], 0.105, false)
	music = AudioStreamPlayer.new()
	music.stream = _track([130.81, 164.81, 196.0, 261.63, 146.83, 174.61, 220.0, 196.0], 1.6, true)
	music.volume_db = -18
	add_child(music)
	music.play()

func _track(notes: Array, length: float, loop: bool) -> AudioStreamWAV:
	var span := int(length * RATE)
	var data := PackedByteArray()
	data.resize(notes.size() * span * 2)
	for i in notes.size():
		for j in span:
			var time := float(j) / RATE
			var envelope := minf(1, time / 0.014) * pow(1.0 - time / length, 1.5)
			var phase := TAU * time * float(notes[i])
			var sample := (sin(phase) + sin(phase * 2.0) * 0.21) * envelope * 7000.0
			data.encode_s16((i * span + j) * 2, int(sample))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = notes.size() * span
	return stream

func cue(name: String) -> void:
	if not effects.has(name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = effects[name]
	player.volume_db = -9
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
