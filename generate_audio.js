/**
 * generate_audio.js
 * Generates procedural WAV audio assets for Rumor Mill (medieval intrigue game).
 * Run: node generate_audio.js
 *
 * Produces 16-bit mono PCM WAV files at 22050 Hz.
 * All sounds are synthesized — no external dependencies.
 */

const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 22050;
const BASE_DIR = path.join(__dirname, 'rumor_mill', 'assets', 'audio');

// ── WAV writer ─────────────────────────────────────────────────────────────────

function writeWav(filename, samples) {
  const numSamples = samples.length;
  const dataSize = numSamples * 2; // 16-bit
  const buf = Buffer.alloc(44 + dataSize);

  // RIFF header
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataSize, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);        // chunk size
  buf.writeUInt16LE(1, 20);         // PCM
  buf.writeUInt16LE(1, 22);         // mono
  buf.writeUInt32LE(SAMPLE_RATE, 24);
  buf.writeUInt32LE(SAMPLE_RATE * 2, 28); // byte rate
  buf.writeUInt16LE(2, 32);         // block align
  buf.writeUInt16LE(16, 34);        // bits per sample
  buf.write('data', 36);
  buf.writeUInt32LE(dataSize, 40);

  for (let i = 0; i < numSamples; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(s * 32767), 44 + i * 2);
  }

  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(filename, buf);
  console.log(`  wrote ${filename} (${numSamples} samples, ${(numSamples / SAMPLE_RATE).toFixed(2)}s)`);
}

// ── Utility oscillators ────────────────────────────────────────────────────────

function sine(freq, t) {
  return Math.sin(2 * Math.PI * freq * t);
}

function noise() {
  return (Math.random() * 2 - 1);
}

// Simple one-pole low-pass filter state
function lowpass(prev, cur, alpha) {
  return prev + alpha * (cur - prev);
}

// ADSR envelope: returns gain 0..1 at position t within total duration dur
function adsr(t, dur, attack, decay, sustain, release) {
  if (t < attack) return t / attack;
  if (t < attack + decay) return 1 - (1 - sustain) * (t - attack) / decay;
  if (t < dur - release) return sustain;
  return sustain * Math.max(0, 1 - (t - (dur - release)) / release);
}

// ── SFX generators ─────────────────────────────────────────────────────────────

function gen_ui_click() {
  const dur = 0.08;
  const n = Math.floor(dur * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 60);
    return env * (sine(1200, t) * 0.6 + noise() * 0.15);
  });
}

function gen_whisper() {
  const dur = 0.6;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = adsr(t, dur, 0.05, 0.1, 0.5, 0.25);
    const raw = noise();
    prev = lowpass(prev, raw, 0.08);
    return prev * env * 0.7;
  });
}

function gen_journal_open() {
  const dur = 0.45;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 5) * (1 - Math.exp(-t * 30));
    const raw = noise();
    prev = lowpass(prev, raw, 0.15);
    // Add soft creak
    const creak = sine(320 + t * 180, t) * 0.12 * Math.exp(-t * 8);
    return (prev * 0.5 + creak) * env;
  });
}

function gen_journal_close() {
  const dur = 0.35;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    // Reverse envelope: sudden then fade
    const env = Math.pow(Math.max(0, 1 - t / dur), 1.5);
    const raw = noise();
    prev = lowpass(prev, raw, 0.12);
    const creak = sine(280 - t * 100, t) * 0.1 * Math.exp(-t * 12);
    return (prev * 0.5 + creak) * env;
  });
}

function gen_rumor_panel_open() {
  const dur = 0.5;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = adsr(t, dur, 0.08, 0.15, 0.3, 0.2);
    const raw = noise();
    prev = lowpass(prev, raw, 0.1);
    const swoosh = sine(600 + t * 400, t) * 0.08 * Math.exp(-t * 6);
    return (prev * 0.4 + swoosh) * env;
  });
}

function gen_rumor_panel_close() {
  const dur = 0.4;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = Math.pow(Math.max(0, 1 - t / dur), 2);
    const raw = noise();
    prev = lowpass(prev, raw, 0.1);
    const swoosh = sine(800 - t * 300, t) * 0.08 * Math.exp(-t * 8);
    return (prev * 0.4 + swoosh) * env;
  });
}

function gen_rumor_spread() {
  const dur = 0.7;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = adsr(t, dur, 0.03, 0.1, 0.4, 0.35);
    const raw = noise();
    prev = lowpass(prev, raw, 0.06);
    // Add very soft harmonic hum suggesting voices
    const hum = sine(220, t) * 0.05 * Math.exp(-t * 3) +
                sine(330, t) * 0.03 * Math.exp(-t * 2);
    return (prev * 0.55 + hum) * env;
  });
}

function gen_recon_observe() {
  const dur = 0.4;
  const n = Math.floor(dur * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    // Subtle lens/focus "tick" + soft tail
    const tick = sine(1800, t) * Math.exp(-t * 50) * 0.8;
    const tail = sine(600, t) * Math.exp(-t * 8) * 0.15;
    return tick + tail;
  });
}

function gen_recon_eavesdrop() {
  const dur = 0.55;
  const n = Math.floor(dur * SAMPLE_RATE);
  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    // Soft thud + hush noise (ear against wall)
    const thud = sine(80, t) * Math.exp(-t * 20) * 0.6;
    const raw = noise();
    prev = lowpass(prev, raw, 0.05);
    const hush = prev * adsr(t, dur, 0.05, 0.1, 0.3, 0.3) * 0.35;
    return thud + hush;
  });
}

function gen_new_day() {
  const dur = 1.8;
  const n = Math.floor(dur * SAMPLE_RATE);
  // Bell tone: D5 (587Hz) + overtones
  const bell_freq = 587;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 2.5);
    return env * (
      sine(bell_freq, t) * 0.6 +
      sine(bell_freq * 2.756, t) * 0.2 +   // bell-like inharmonic overtone
      sine(bell_freq * 5.404, t) * 0.08 +
      sine(bell_freq * 0.5, t) * 0.12       // sub for warmth
    );
  });
}

function gen_win() {
  const dur = 2.5;
  const n = Math.floor(dur * SAMPLE_RATE);
  // Rising major fanfare: C4-E4-G4-C5 arpeggio then held chord
  const notes = [261.63, 329.63, 392.0, 523.25];
  const stepDur = 0.25;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const step = Math.min(3, Math.floor(t / stepDur));
    const tInStep = t - step * stepDur;

    let s = 0;
    if (t < notes.length * stepDur) {
      // Arpeggio phase
      const f = notes[step];
      const env = adsr(tInStep, stepDur * 1.5, 0.01, 0.05, 0.7, 0.2);
      s = sine(f, t) * 0.5 * env +
          sine(f * 2, t) * 0.15 * env +
          sine(f * 0.5, t) * 0.1 * env;
    } else {
      // Chord hold
      const holdT = t - notes.length * stepDur;
      const chordEnv = Math.exp(-holdT * 1.2);
      for (const f of notes) {
        s += sine(f, t) * 0.2 * chordEnv +
             sine(f * 2, t) * 0.05 * chordEnv;
      }
    }
    return s;
  });
}

function gen_fail() {
  const dur = 2.0;
  const n = Math.floor(dur * SAMPLE_RATE);
  // Descending minor: A4-F4-D4-A3
  const notes = [440, 349.23, 293.66, 220];
  const stepDur = 0.3;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    const step = Math.min(3, Math.floor(t / stepDur));
    const f = notes[step];
    const tInStep = t - step * stepDur;
    const env = adsr(tInStep, stepDur * 2, 0.01, 0.1, 0.6, 0.3) * Math.exp(-t * 0.6);
    return (
      sine(f, t) * 0.55 * env +
      sine(f * 1.5, t) * 0.1 * env +      // fifth for richness
      sine(f * 0.5, t) * 0.15 * env        // warmth
    );
  });
}

// ── Music generators (~30s looping ambient tracks) ─────────────────────────────

function gen_main_theme() {
  const dur = 30.0;
  const n = Math.floor(dur * SAMPLE_RATE);
  // Medieval drone on D3 (146.83 Hz) + arpeggiated D minor pentatonic
  // D3, A3, D4, F4, A4 — slow modal arpeggiation with reverb-like tails
  const drone_freq = 146.83;
  const arp_notes = [146.83, 220, 293.66, 349.23, 440];
  const arp_rate = 0.8; // seconds per note

  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;

    // Drone layer (always present)
    const drone = (
      sine(drone_freq, t) * 0.25 +
      sine(drone_freq * 2, t) * 0.1 +
      sine(drone_freq * 3, t) * 0.04 +
      sine(drone_freq * 0.5, t) * 0.08
    ) * (0.6 + 0.1 * sine(0.13, t)); // slow tremolo

    // Arp layer
    const arp_idx = Math.floor(t / arp_rate) % arp_notes.length;
    const arp_f = arp_notes[arp_idx];
    const arp_t = t % arp_rate;
    const arp_env = Math.exp(-arp_t * 2.5) * (1 - Math.exp(-arp_t * 20));
    const arp = sine(arp_f, t) * arp_env * 0.3 +
                sine(arp_f * 2, t) * arp_env * 0.08;

    // Very soft noise floor (breath)
    let breath = (Math.random() * 2 - 1) * 0.015;

    // Fade in/out at loop boundaries
    const fade_in  = Math.min(1, t / 3.0);
    const fade_out = Math.min(1, (dur - t) / 3.0);
    const fade = fade_in * fade_out;

    return (drone + arp + breath) * fade;
  });
}

function gen_ambient_day() {
  const dur = 30.0;
  const n = Math.floor(dur * SAMPLE_RATE);
  // Bright, lighter feel: G4 drone + birds-like upper harmonics + gentle pulse
  const base_freq = 392.0; // G4

  let prev = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;

    // Warm pad
    const pad = (
      sine(base_freq, t) * 0.15 +
      sine(base_freq * 1.5, t) * 0.08 +  // fifth
      sine(base_freq * 2, t) * 0.05 +
      sine(base_freq * 0.5, t) * 0.1
    ) * (0.8 + 0.12 * sine(0.2, t));

    // Birdsong-like high tones (quasi-random)
    const bird_cycle = 4.7;
    const bird_t = t % bird_cycle;
    let bird = 0;
    if (bird_t < 0.3) {
      bird = sine(2093 + 200 * Math.sin(bird_t * 40), t) *
             Math.exp(-bird_t * 12) * 0.12;
    } else if (bird_t > 2.1 && bird_t < 2.45) {
      const bt = bird_t - 2.1;
      bird = sine(1760 + 150 * Math.sin(bt * 30), t) *
             Math.exp(-bt * 10) * 0.09;
    }

    // Soft wind
    const raw = Math.random() * 2 - 1;
    prev = lowpass(prev, raw, 0.04);
    const wind = prev * 0.04 * (0.7 + 0.3 * sine(0.07, t));

    const fade_in  = Math.min(1, t / 3.0);
    const fade_out = Math.min(1, (dur - t) / 3.0);
    return (pad + bird + wind) * fade_in * fade_out;
  });
}

function gen_ambient_night() {
  const dur = 30.0;
  const n = Math.floor(dur * SAMPLE_RATE);
  // Dark, low drone on A2 (110Hz) + wolf-howl-like mid harmonic + cricket shimmer
  const base_freq = 110.0; // A2

  let prevNoise = 0;
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;

    // Deep drone
    const drone = (
      sine(base_freq, t) * 0.3 +
      sine(base_freq * 2, t) * 0.08 +
      sine(base_freq * 3.02, t) * 0.04 + // slight detuning for unease
      sine(base_freq * 0.5, t) * 0.12
    ) * (0.7 + 0.15 * sine(0.09, t));

    // Owl / night ambience (slow sweep)
    const owl_cycle = 7.3;
    const owl_t = t % owl_cycle;
    let owl = 0;
    if (owl_t < 0.8) {
      owl = sine(440 - 80 * (owl_t / 0.8), t) *
            adsr(owl_t, 0.8, 0.1, 0.2, 0.5, 0.3) * 0.1;
    }

    // Cricket shimmer (high freq noise modulated)
    const raw = Math.random() * 2 - 1;
    prevNoise = lowpass(prevNoise, raw, 0.25);
    const cricket = prevNoise * 0.03 * (0.5 + 0.5 * sine(16, t));

    const fade_in  = Math.min(1, t / 3.0);
    const fade_out = Math.min(1, (dur - t) / 3.0);
    return (drone + owl + cricket) * fade_in * fade_out;
  });
}

// ── Main ───────────────────────────────────────────────────────────────────────

console.log('Generating Rumor Mill audio assets...\n');

const sfxDir = path.join(BASE_DIR, 'sfx');
const musicDir = path.join(BASE_DIR, 'music');

const sfx = [
  ['ui_click',          gen_ui_click],
  ['whisper',           gen_whisper],
  ['journal_open',      gen_journal_open],
  ['journal_close',     gen_journal_close],
  ['rumor_panel_open',  gen_rumor_panel_open],
  ['rumor_panel_close', gen_rumor_panel_close],
  ['rumor_spread',      gen_rumor_spread],
  ['recon_observe',     gen_recon_observe],
  ['recon_eavesdrop',   gen_recon_eavesdrop],
  ['new_day',           gen_new_day],
  ['win',               gen_win],
  ['fail',              gen_fail],
];

const music = [
  ['main_theme',    gen_main_theme],
  ['ambient_day',   gen_ambient_day],
  ['ambient_night', gen_ambient_night],
];

console.log('SFX:');
for (const [name, gen] of sfx) {
  const samples = gen();
  writeWav(path.join(sfxDir, name + '.wav'), samples);
}

console.log('\nMusic:');
for (const [name, gen] of music) {
  const samples = gen();
  writeWav(path.join(musicDir, name + '.wav'), samples);
}

console.log('\nDone. All audio assets generated.');
