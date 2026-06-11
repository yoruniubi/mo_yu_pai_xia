#!/usr/bin/env python3
"""
卡牌音效生成器 - 使用纯数学合成生成 WAV 音效
生成多种卡牌相关音效：打出、抽牌、攻击、回复、护盾、连招等
"""

import wave
import math
import struct
import os
import random

SAMPLE_RATE = 44100
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Sounds", "cards", "lofi")

def ensure_dir():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

def sine(t, freq):
    return math.sin(2.0 * math.pi * freq * t)

def saw(t, freq):
    return 2.0 * ((t * freq) % 1.0) - 1.0

def square(t, freq):
    return 1.0 if (t * freq) % 1.0 < 0.5 else -1.0

def triangle(t, freq):
    v = (t * freq) % 1.0
    return 4.0 * abs(v - 0.5) - 1.0

def noise():
    return random.uniform(-1.0, 1.0)

def envelope(t, duration, attack=0.01, decay=0.1, sustain=0.7, release=0.2):
    """ADSR 包络"""
    if t < attack:
        return t / attack
    elif t < attack + decay:
        return 1.0 - (1.0 - sustain) * (t - attack) / decay
    elif t < duration - release:
        return sustain
    else:
        return sustain * (1.0 - (t - (duration - release)) / release)

def lowpass_filter(samples, cutoff=0.3):
    """简单的一阶低通滤波"""
    filtered = []
    prev = 0.0
    alpha = cutoff
    for s in samples:
        prev = prev + alpha * (s - prev)
        filtered.append(prev)
    return filtered

def write_wav(filename, samples):
    """写入 16-bit mono WAV 文件"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        # 归一化并转换为 16-bit
        max_val = max(abs(s) for s in samples) if samples else 1.0
        if max_val < 0.01:
            max_val = 1.0
        data = []
        for s in samples:
            val = int(max(-32768, min(32767, s / max_val * 28000)))
            data.append(struct.pack('<h', val))
        wf.writeframes(b''.join(data))
    return filepath

def generate_card_play():
    """卡牌打出音效 - 清脆的翻牌声"""
    duration = 0.25
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.002, decay=0.05, sustain=0.3, release=0.15)
        # 高频叮当声 + 中频纸牌声
        s = sine(t, 1200) * 0.3 + sine(t, 2400) * 0.2 + sine(t, 800) * 0.5
        # 加入一点噪声模拟纸牌摩擦
        s += noise() * 0.08 * (1.0 - t / duration)
        samples.append(s * env * 0.8)
    return write_wav("card_play.wav", samples)

def generate_card_draw():
    """抽牌音效 - 快速滑过的声音"""
    duration = 0.2
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.005, decay=0.03, sustain=0.5, release=0.1)
        # 频率从高到低滑动
        freq = 2000 - t * 6000
        s = sine(t, max(200, freq)) * 0.4
        s += noise() * 0.15 * env
        samples.append(s * env * 0.7)
    return write_wav("card_draw.wav", samples)

def generate_card_attack():
    """攻击音效 - 有力的打击声"""
    duration = 0.3
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.003, decay=0.08, sustain=0.2, release=0.2)
        # 低频冲击 + 高频锐利
        s = sine(t, 80) * 0.6 + sine(t, 200) * 0.3 + sine(t, 600) * 0.2
        # 噪声冲击
        s += noise() * 0.2 * (1.0 - t / duration)
        samples.append(s * env * 0.85)
    return write_wav("card_attack.wav", samples)

def generate_card_heal():
    """回复音效 - 温暖上升的治愈声"""
    duration = 0.4
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.02, decay=0.1, sustain=0.6, release=0.25)
        # 上升的琶音
        freq = 400 + t * 600
        s = sine(t, freq) * 0.4 + sine(t, freq * 1.5) * 0.2 + sine(t, freq * 2) * 0.1
        # 柔和的和声
        s += sine(t, 300) * 0.15
        samples.append(s * env * 0.7)
    return write_wav("card_heal.wav", samples)

def generate_card_shield():
    """护盾音效 - 金属质感的防护声"""
    duration = 0.35
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.01, decay=0.08, sustain=0.5, release=0.2)
        # 金属共鸣
        s = sine(t, 500) * 0.3 + sine(t, 1500) * 0.15 + sine(t, 2500) * 0.1
        # 混响效果
        s += sine(t, 500) * 0.2 * (1.0 - t / duration)
        samples.append(s * env * 0.75)
    return write_wav("card_shield.wav", samples)

def generate_card_combo():
    """连招音效 - 连续上升的华丽音效"""
    duration = 0.5
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.01, decay=0.05, sustain=0.7, release=0.2)
        # 三连音上升
        phase = t * 3.0
        freq = 500 + phase * 400
        s = sine(t, freq) * 0.35
        s += sine(t, freq * 1.5) * 0.2
        s += sine(t, freq * 2.0) * 0.1
        # 闪烁感
        s += sine(t, 8000) * 0.05 * (1.0 - t / duration)
        samples.append(s * env * 0.8)
    return write_wav("card_combo.wav", samples)

def generate_card_special():
    """特殊卡牌音效 - 魔法般的神秘音效"""
    duration = 0.45
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.02, decay=0.1, sustain=0.5, release=0.25)
        # 闪烁的星星音效
        freq = 1000 + math.sin(t * 8) * 400
        s = sine(t, freq) * 0.3
        s += sine(t, freq * 1.3) * 0.15
        s += sine(t, freq * 2.5) * 0.08
        # 魔法粉尘
        s += noise() * 0.05 * (1.0 - t / duration)
        samples.append(s * env * 0.65)
    return write_wav("card_special.wav", samples)

def generate_card_debuff():
    """减益音效 - 低沉的负面音效"""
    duration = 0.3
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.01, decay=0.06, sustain=0.3, release=0.2)
        # 下降的不和谐音
        freq = 400 - t * 300
        s = sine(t, max(100, freq)) * 0.4
        s += sine(t, max(100, freq) * 0.5) * 0.3
        s += noise() * 0.1
        samples.append(s * env * 0.7)
    return write_wav("card_debuff.wav", samples)

def generate_card_discard():
    """弃牌音效 - 快速丢弃声"""
    duration = 0.15
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.002, decay=0.03, sustain=0.2, release=0.1)
        s = noise() * 0.5 * (1.0 - t / duration)
        s += sine(t, 300) * 0.2
        samples.append(s * env * 0.6)
    return write_wav("card_discard.wav", samples)

def generate_card_shuffle():
    """洗牌音效 - 连续的纸牌摩擦声"""
    duration = 0.4
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.01, decay=0.05, sustain=0.6, release=0.2)
        # 快速连续的纸牌声
        s = noise() * 0.3
        # 加入节奏感
        s += sine(t, 200 + (i % 2000) * 0.5) * 0.1
        samples.append(s * env * 0.55)
    return write_wav("card_shuffle.wav", samples)

def generate_ui_click():
    """UI 点击音效"""
    duration = 0.08
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.001, decay=0.02, sustain=0.1, release=0.05)
        s = sine(t, 1800) * 0.5 + sine(t, 2400) * 0.3
        samples.append(s * env * 0.6)
    return write_wav("ui_click.wav", samples)

def generate_ui_hover():
    """UI 悬停音效"""
    duration = 0.06
    samples = []
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.001, decay=0.01, sustain=0.3, release=0.04)
        s = sine(t, 1200) * 0.4
        samples.append(s * env * 0.4)
    return write_wav("ui_hover.wav", samples)

def main():
    ensure_dir()
    print("🎵 正在生成卡牌音效...")
    print(f"   输出目录: {OUTPUT_DIR}")
    print()
    
    generators = [
        ("卡牌打出", generate_card_play),
        ("抽牌", generate_card_draw),
        ("攻击", generate_card_attack),
        ("回复/治疗", generate_card_heal),
        ("护盾", generate_card_shield),
        ("连招", generate_card_combo),
        ("特殊卡牌", generate_card_special),
        ("减益", generate_card_debuff),
        ("弃牌", generate_card_discard),
        ("洗牌", generate_card_shuffle),
        ("UI 点击", generate_ui_click),
        ("UI 悬停", generate_ui_hover),
    ]
    
    for name, gen_func in generators:
        path = gen_func()
        print(f"   ✅ {name}: {os.path.basename(path)}")
    
    print()
    print("🎉 所有音效生成完成！")
    print(f"   文件位置: {OUTPUT_DIR}")
    print()
    print("💡 提示：可以用任意音频播放器试听这些 WAV 文件")
    print("   或在 Godot 中导入使用")

if __name__ == "__main__":
    main()