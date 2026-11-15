class_name Synth
extends RefCounted
## Procedural sound synthesis. Everything is computed once at start-up into AudioStreamWAV buffers
## (no recordings, no external files). A buffer plays reliably in a single-threaded web export,
## where a live AudioStreamGenerator can stutter.

# === CONSTANTS ===
const RATE: int = 22050


# === PUBLIC METHODS ===
## Brass-like cartoon "speech": a sawtooth pair through a resonant low-pass filter whose cutoff
## opens and closes on every syllable (the "wah"). Keys of `p`: f0, syllables, syl (seconds),
## gap (seconds), cut_lo, cut_hi, attack (0-1), decay_pow, bend, spread (semitones of intonation).
static func brass(p: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var f0: float = p["f0"]
	var syllables: int = p["syllables"]
	var cut_lo: float = p["cut_lo"]
	var cut_hi: float = p["cut_hi"]
	var attack: float = p["attack"]
	var decay_pow: float = p["decay_pow"]
	var bend: float = p["bend"]
	var spread: float = p.get("spread", 2.0)
	var phase: float = 0.0
	var phase2: float = 0.0
	var low: float = 0.0
	var band: float = 0.0
	var t: float = 0.0
	for s: int in range(syllables):
		var syl: float = float(p["syl"]) * rng.randf_range(0.85, 1.2)
		var n: int = int(syl * RATE)
		var f_syl: float = f0 * pow(2.0, rng.randf_range(-spread, spread) / 12.0)
		for i: int in range(n):
			var u: float = float(i) / float(n)
			var env: float = minf(u / attack, 1.0) * pow(1.0 - u, decay_pow)
			var open: float = sin(PI * minf(u * 1.15, 1.0))
			var cutoff: float = cut_lo + (cut_hi - cut_lo) * open
			var freq: float = f_syl * (1.0 - bend * u) * (1.0 + 0.012 * sin(TAU * 5.5 * t))
			phase = fposmod(phase + freq / RATE, 1.0)
			phase2 = fposmod(phase2 + freq * 1.006 / RATE, 1.0)
			var saw: float = (phase * 2.0 - 1.0) * 0.6 + (phase2 * 2.0 - 1.0) * 0.4
			var f: float = 2.0 * sin(PI * cutoff / RATE)
			low += f * band
			var high: float = saw - low - 0.35 * band
			band += f * high
			out.append((low + 0.35 * band) * env)
			t += 1.0 / RATE
		var gap: int = int(float(p["gap"]) * rng.randf_range(0.7, 1.3) * RATE)
		for i: int in range(gap):
			out.append(0.0)
			t += 1.0 / RATE
	return out


## A short pitched blip that glides from f_start to f_end. `square` adds a hollow, game-like edge.
static func tone(f_start: float, f_end: float, dur: float, square: float, decay_pow: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = int(dur * RATE)
	var phase: float = 0.0
	for i: int in range(n):
		var u: float = float(i) / float(n)
		var freq: float = lerpf(f_start, f_end, u)
		phase = fposmod(phase + freq / RATE, 1.0)
		var s: float = sin(TAU * phase)
		var sq: float = 1.0 if phase < 0.5 else -1.0
		var env: float = minf(u / 0.03, 1.0) * pow(1.0 - u, decay_pow)
		out.append(lerpf(s, sq * 0.6, square) * env)
	return out


## Packs samples into a 16-bit mono stream, normalised so its loudest sample is `peak`.
static func to_stream(samples: PackedFloat32Array, peak: float = 0.6) -> AudioStreamWAV:
	var top: float = 0.0001
	for v: float in samples:
		top = maxf(top, absf(v))
	var k: float = peak / top
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i] * k, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
