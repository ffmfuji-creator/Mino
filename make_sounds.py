"""生成白噪音 / 棕噪音 / 雨声（可无缝循环）和结束提示音，输出到 assets/sounds/。
构建时由工作流运行，不需要手动上传音频文件。纯 Python，无第三方依赖。
"""
import math
import os
import random
import struct
import wave

RATE = 22050
random.seed(20261017)  # 固定种子：每次构建得到同样的声音


def write_wav(path, samples):
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))


def normalize(xs, peak):
    m = max(abs(x) for x in xs) or 1.0
    return [x * peak / m for x in xs]


def make_loop(raw, length, fade):
    """raw 长度为 length+fade；把开头 fade 段和结尾多出来的 fade 段交叉淡化，头尾即可无缝衔接。"""
    out = raw[:length]
    for i in range(fade):
        w = i / fade
        out[i] = raw[i] * w + raw[length + i] * (1.0 - w)
    return out


def white(n):
    return [random.uniform(-1, 1) for _ in range(n)]


def brown(n):
    x = 0.0
    out = []
    for _ in range(n):
        x = (x + random.uniform(-1, 1) * 0.06) * 0.995
        out.append(x)
    return out


def rain(n):
    out = []
    low = 0.0
    prev = 0.0
    env = 0.0
    for _ in range(n):
        w = random.uniform(-1, 1)
        low += (w - low) * 0.25  # 低通：沙沙的底噪
        if random.random() < 0.0016:
            env = random.uniform(0.35, 1.0)  # 一颗雨滴
        drop = (w - prev) * env  # 高通：雨滴的清脆感
        prev = w
        env *= 0.992
        out.append(low * 0.55 + drop * 0.45)
    return out


def chime():
    dur = 1.5
    n = int(RATE * dur)
    notes = [(880.0, 0.0, 1.0), (1318.5, 0.16, 0.8)]
    out = [0.0] * n
    for freq, start, amp in notes:
        s0 = int(start * RATE)
        for i in range(s0, n):
            t = (i - s0) / RATE
            attack = min(1.0, t / 0.005)
            env = math.exp(-t * 3.2) * attack
            v = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t) * math.exp(-t * 2.0)
            out[i] += amp * env * v
    return normalize(out, 0.8)


def main():
    os.makedirs("assets/sounds", exist_ok=True)
    length = RATE * 12
    fade = int(RATE * 0.6)
    n = length + fade
    write_wav("assets/sounds/white.wav", make_loop(normalize(white(n), 0.5), length, fade))
    write_wav("assets/sounds/brown.wav", make_loop(normalize(brown(n), 0.7), length, fade))
    write_wav("assets/sounds/rain.wav", make_loop(normalize(rain(n), 0.7), length, fade))
    write_wav("assets/sounds/chime.wav", chime())
    print("sounds generated")


if __name__ == "__main__":
    main()
