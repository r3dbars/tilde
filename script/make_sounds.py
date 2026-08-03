#!/usr/bin/env python3
"""Generate the accept-sound pack: three pitch-variant thocks for Tab-word
accepts and a two-note ding for the tilde whole-phrase accept. All audio is
synthesized (original, no licensing). Output: ~/Library/Application
Support/Tilde/sounds/ — the keyboard prefers these over system sounds;
drop in your own .wav files with the same names to customize."""
import math, struct, wave, os, random
SR = 44100
outdir = os.path.expanduser("~/Library/Application Support/Tilde/sounds")
os.makedirs(outdir, exist_ok=True)

def write(name, samples):
    w = wave.open(os.path.join(outdir, name), "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s*32767)))) for s in samples))
    w.close()

def thock(base_hz):
    n = int(SR*0.09); out = []
    for i in range(n):
        t = i/SR
        env = math.exp(-t*55)
        body = 0.8*math.sin(2*math.pi*base_hz*t) + 0.25*math.sin(2*math.pi*base_hz*2.3*t)
        click = (random.random()*2-1) * math.exp(-t*600) * 0.35
        out.append((body*env + click) * 0.5)
    return out

def ding():
    n = int(SR*0.32); out = []
    for i in range(n):
        t = i/SR
        n1 = math.sin(2*math.pi*659.3*t) * math.exp(-t*9)
        n2 = math.sin(2*math.pi*987.8*t) * math.exp(-max(0,t-0.07)*9) * (0 if t<0.07 else 1)
        shimmer = 0.15*math.sin(2*math.pi*1975.5*t)*math.exp(-t*12)
        out.append((0.55*n1 + 0.5*n2 + shimmer) * 0.42)
    return out

if __name__ == "__main__":
    random.seed(7)
    for i, hz in enumerate([95, 105, 118], 1):
        write(f"tab_{i}.wav", thock(hz))
    write("tilde.wav", ding())
    print("sound pack written to", outdir)
