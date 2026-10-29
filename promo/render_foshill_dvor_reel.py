#!/usr/bin/env python3
"""FOSHILL case reel: DVOR bot. 1080x1920, about 22s.

Visual system matches the MERCH reel: near-black, faint grid, lime glow,
three ellipses cropped by the frame. The phone is a device, not a flat card.
Metric is −65% (this club), the action is the word БОТ on foshill.com.

Bed, burned into the file:
  Digital Clouds
  Alejandro Magaña (A. M.)
  https://assets.mixkit.co/music/175/175.mp3
  Mixkit Stock Music Free License
  https://mixkit.co/license/#musicFree
  Allowed in social video. Not for TV, radio, games, or discs.
  Attribution is not required.

Needs: Python 3, Pillow, numpy, ffmpeg.
Fonts download into promo/.fonts on first run.
"""

import math
import os
import subprocess
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
FPS = 30
DURATION = 22.6
PAD = 84

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.join(HERE, ".fonts")
FRAME_DIR = os.path.join(HERE, ".frames")
AUDIO_DIR = os.path.join(HERE, ".audio")
OUT_MP4 = os.path.join(HERE, "foshill-dvor-reel.mp4")
MUSIC = os.path.join(AUDIO_DIR, "digital-clouds.mp3")
MUSIC_URL = "https://assets.mixkit.co/music/175/175.mp3"

FONTS = {
    "Playfair.ttf": "https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf",
    "PlayfairItalic.ttf": "https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf",
    "Manrope.ttf": "https://github.com/google/fonts/raw/main/ofl/manrope/Manrope%5Bwght%5D.ttf",
    "JetBrains.ttf": "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf",
    "Unbounded.ttf": "https://github.com/google/fonts/raw/main/ofl/unbounded/Unbounded%5Bwght%5D.ttf",
}

BG = (12, 12, 13, 255)
FG = (244, 242, 236, 255)
MUTED = (164, 162, 154, 255)
LIME = (198, 255, 61, 255)
INK = (12, 12, 13, 255)
SCREEN_DARK = (14, 14, 16, 255)
SCREEN_LIGHT = (246, 244, 236, 255)

SCENES = [
    ("hook", 0.00, 3.60),
    ("pain", 3.20, 7.05),
    ("quiz", 6.65, 10.85),
    ("check", 10.45, 14.35),
    ("loyal", 13.95, 17.55),
    ("metric", 17.15, 20.15),
    ("end", 19.75, DURATION + 0.05),
]
FADE = 0.36

_fonts = {}
GRID = None
GLOW = None
METRIC_GLOW = None
VIGNETTE = None
GRAIN = None
MARKS = {}


def ensure_fonts():
    os.makedirs(FONT_DIR, exist_ok=True)
    for name, url in FONTS.items():
        path = os.path.join(FONT_DIR, name)
        if os.path.exists(path) and os.path.getsize(path) > 1000:
            continue
        print("font", name)
        urllib.request.urlretrieve(url, path)


def ensure_music():
    os.makedirs(AUDIO_DIR, exist_ok=True)
    if os.path.exists(MUSIC) and os.path.getsize(MUSIC) > 10000:
        return
    print("music", MUSIC_URL)
    urllib.request.urlretrieve(MUSIC_URL, MUSIC)


def font(name, size, weight):
    key = (name, size, weight)
    if key not in _fonts:
        face = ImageFont.truetype(os.path.join(FONT_DIR, name), size)
        try:
            face.set_variation_by_axes([weight])
        except Exception:
            pass
        _fonts[key] = face
    return _fonts[key]


def display(size, weight=760):
    return font("Unbounded.ttf", size, weight)


def serif_i(size, weight=650):
    return font("PlayfairItalic.ttf", size, weight)


def sans(size, weight=560):
    return font("Manrope.ttf", size, weight)


def mono(size, weight=500):
    return font("JetBrains.ttf", size, weight)


def clamp(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def ease(t):
    t = clamp(t)
    x1, y1, x2, y2 = 0.16, 1.0, 0.3, 1.0
    u = t
    for _ in range(8):
        cx = 3 * x1
        bx = 3 * (x2 - x1) - cx
        ax = 1 - cx - bx
        dx = ((ax * u + bx) * u + cx) * u - t
        dxdt = (3 * ax * u + 2 * bx) * u + cx
        if abs(dxdt) < 1e-6:
            break
        u = clamp(u - dx / dxdt)
    cy = 3 * y1
    by = 3 * (y2 - y1) - cy
    ay = 1 - cy - by
    return ((ay * u + by) * u + cy) * u


def reveal(t, delay, dur=0.55):
    e = ease((t - delay) / dur) if dur else 1.0
    return e, (1.0 - e) * 36.0


def text_width(face, text, tracking=0.0):
    if not text:
        return 0.0
    w = 0.0
    for i, ch in enumerate(text):
        w += face.getlength(ch)
        if i < len(text) - 1:
            w += tracking
    return w


def draw_text(draw, x, y, text, face, fill, tracking=0.0, align="left"):
    w = text_width(face, text, tracking)
    if align == "center":
        x -= w / 2
    elif align == "right":
        x -= w
    pen = x
    for ch in text:
        draw.text((pen, y), ch, font=face, fill=fill)
        pen += face.getlength(ch) + tracking
    return w


def wrap(text, face, max_w):
    lines, cur = [], ""
    for word in text.split():
        trial = word if not cur else f"{cur} {word}"
        if face.getlength(trial) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines or [""]


def with_alpha(color, alpha):
    return (color[0], color[1], color[2], int(clamp(alpha) * 255))


def paint(base, alpha, fn):
    if alpha < 0.02:
        return
    if alpha > 0.985:
        fn(ImageDraw.Draw(base))
        return
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(layer))
    channel = layer.getchannel("A")
    layer.putalpha(channel.point(lambda p, k=alpha: int(p * k)))
    base.alpha_composite(layer)


def kicker(draw, label, y, alpha=1.0):
    if alpha <= 0.02:
        return
    draw.ellipse([PAD, y + 8, PAD + 12, y + 20], fill=with_alpha(LIME, alpha))
    draw_text(draw, PAD + 24, y, label, mono(22, 560), with_alpha(FG, alpha), tracking=3.2)


def block(draw, lines, x, y, face, fill, gap=8):
    step = int(face.size * 1.12) + gap
    for line in lines:
        draw.text((x, y), line, font=face, fill=fill)
        y += step
    return y


def make_glow():
    yy, xx = np.ogrid[0 : H + 80, 0 : W + 80]
    r = np.sqrt((xx - (W * 0.72 + 40)) ** 2 + (yy - (H * 0.34 + 40)) ** 2)
    fall = np.clip(1.0 - r / (H * 0.48), 0, 1) ** 2
    alpha = (fall * 0.16 * 255).astype(np.uint8)
    arr = np.zeros((H + 80, W + 80, 4), dtype=np.uint8)
    arr[..., 0] = LIME[0]
    arr[..., 1] = LIME[1]
    arr[..., 2] = LIME[2]
    arr[..., 3] = alpha
    return Image.fromarray(arr)


def make_grid():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    step = 96
    for x in range(0, W, step):
        draw.line([(x, 0), (x, H)], fill=(255, 255, 255, 16))
    for y in range(0, H, step):
        draw.line([(0, y), (W, y)], fill=(255, 255, 255, 16))
    return im


def make_mark(cx, cy, scale):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    specs = [
        (0, 168, 248, (92, 92, 94, 140)),
        (78, 128, 196, (58, 58, 60, 200)),
        (138, 82, 142, (*LIME[:3], 220)),
    ]
    for dx, rx, ry, fill in specs:
        dx, rx, ry = dx * scale, rx * scale, ry * scale
        draw.ellipse([cx + dx - rx, cy - ry, cx + dx + rx, cy + ry], fill=fill)
    return overlay.filter(ImageFilter.GaussianBlur(1.3))


def make_vignette():
    yy, xx = np.ogrid[0:H, 0:W]
    nx = (xx - W / 2) / (W * 0.78)
    ny = (yy - H / 2) / (H * 0.82)
    return np.clip(1.0 - 0.42 * (nx**2 + ny**2), 0.62, 1.0).astype(np.float32)


def make_grain():
    rng = np.random.default_rng(7)
    return rng.integers(0, 255, size=(H, W), dtype=np.uint8)


def make_metric_glow():
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([20, 620, 820, 1040], fill=(*LIME[:3], 36))
    return glow.filter(ImageFilter.GaussianBlur(48))


def init_plates():
    global GRID, GLOW, METRIC_GLOW, VIGNETTE, GRAIN
    GRID = make_grid()
    GLOW = make_glow()
    METRIC_GLOW = make_metric_glow()
    VIGNETTE = make_vignette()
    GRAIN = make_grain()
    MARKS["right"] = make_mark(1040, 1480, 0.98)
    MARKS["low"] = make_mark(1080, 1680, 0.82)
    MARKS["end"] = make_mark(1020, 340, 0.62)


def paste_glow(base, t, phase=0.0):
    dx = int(math.sin(t * 0.55 + phase) * 16)
    dy = int(math.cos(t * 0.42 + phase) * 12)
    crop = GLOW.crop((40 - dx, 40 - dy, 40 - dx + W, 40 - dy + H))
    base.alpha_composite(crop)


def stage(t, phase=0.0, mark=None):
    im = Image.new("RGBA", (W, H), BG)
    im.alpha_composite(GRID)
    paste_glow(im, t, phase)
    if mark:
        im.alpha_composite(MARKS[mark])
    return im


def finish(im, t):
    arr = np.array(im).astype(np.float32)
    shift = int(t * 37) % H
    grain = np.roll(GRAIN, shift, axis=0)
    grain = np.roll(grain, int(t * 19) % W, axis=1)
    g = (grain.astype(np.float32) - 128.0) * 0.018
    rgb = arr[..., :3] + g[..., None]
    rgb *= VIGNETTE[..., None]
    arr[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def phone(base, box, light, painter):
    x0, y0, x1, y1 = box
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle([x0 + 10, y0 + 24, x1 + 14, y1 + 28], radius=72, fill=(0, 0, 0, 90))
    draw.rounded_rectangle([x0 - 3, y0 + 118, x0 + 4, y0 + 176], radius=2, fill=(88, 88, 90, 255))
    draw.rounded_rectangle([x0 - 3, y0 + 196, x0 + 4, y0 + 286], radius=2, fill=(88, 88, 90, 255))
    draw.rounded_rectangle([x1 - 4, y0 + 168, x1 + 4, y0 + 246], radius=2, fill=(88, 88, 90, 255))
    draw.rounded_rectangle(box, radius=68, fill=(72, 72, 74, 255))
    draw.rounded_rectangle([x0 + 3, y0 + 3, x1 - 3, y1 - 3], radius=65, fill=(16, 16, 18, 255))
    screen = (246, 244, 236, 255) if light else SCREEN_DARK
    inset = 12
    glass = [x0 + inset, y0 + inset, x1 - inset, y1 - inset]
    draw.rounded_rectangle(glass, radius=54, fill=screen)
    cx = (x0 + x1) / 2
    draw.rounded_rectangle([cx - 58, y0 + 24, cx + 58, y0 + 52], radius=14, fill=(6, 6, 7, 255))
    ink = (28, 28, 26, 255) if light else FG
    mute = (120, 116, 108, 255) if light else (176, 174, 166, 255)
    draw.text((glass[0] + 22, y0 + 28), "23:40", font=sans(16, 700), fill=ink)
    bx, by = glass[2] - 78, y0 + 32
    for i in range(4):
        h = 3 + i * 2
        sx = bx + i * 5
        draw.rounded_rectangle([sx, by + 11 - h, sx + 3, by + 11], radius=1, fill=ink)
    bat = [glass[2] - 52, y0 + 32, glass[2] - 28, y0 + 44]
    draw.rounded_rectangle(bat, radius=3, outline=ink, width=1)
    draw.rectangle([bat[2], by + 3, bat[2] + 2, by + 8], fill=ink)
    draw.rounded_rectangle([cx - 48, glass[3] - 16, cx + 48, glass[3] - 10], radius=3, fill=mute)
    content = [glass[0] + 36, glass[1] + 52, glass[2] - 36, glass[3] - 28]
    painter(draw, content, light)


def scene_hook(t):
    im = stage(t, mark="right")
    def head(d):
        y = 690
        kicker(d, "КЕЙС", y)
        y += 70
        face = display(78, 760)
        d.text((PAD, y), "Заявки в DVOR", font=face, fill=FG)
        y += 100
        d.text((PAD, y), "шли через", font=face, fill=FG)
        y += 108
        d.text((PAD, y), "менеджера", font=serif_i(108, 650), fill=LIME)
        y += 140
        d.text((PAD, y), "@dvor.sport", font=sans(36, 680), fill=LIME)

    paint(im, 1, head)
    return im


def scene_pain(t):
    im = stage(t, 0.8, mark="low")
    a, dy = reveal(t, 0.05, 0.5)

    def body(d, dy=dy):
        y = 620 + dy
        kicker(d, "23:40", y)
        y += 78
        lead = display(64, 740)
        d.text((PAD, y), "Он утопал в них.", font=lead, fill=FG)
        y += 130
        line = display(52, 700)
        d.text((PAD, y), "Всем ответить.", font=line, fill=FG)
        y += 78
        d.text((PAD, y), "Всем подсказать.", font=line, fill=FG)
        y += 78
        d.text((PAD, y), "Всё ", font=line, fill=FG)
        w = line.getlength("Всё ")
        d.text((PAD + w, y - 6), "зафиксировать.", font=serif_i(64, 650), fill=LIME)
        y += 120
        note = sans(32, 500)
        for row in wrap("Места, перенос, чек и что взять на поход.", note, 880):
            d.text((PAD, y), row, font=note, fill=MUTED)
            y += 46

    paint(im, a, body)
    return im


# iPhone 16 body is 71.6 × 147.6 mm. The old box was ~1.7, so the phone looked squashed.
PHONE_W = 600
PHONE_H = round(PHONE_W * 147.6 / 71.6)
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = H - 36 - PHONE_H
PHONE_BOX = (PHONE_X, PHONE_Y, PHONE_X + PHONE_W, PHONE_Y + PHONE_H)


def scene_quiz(t):
    im = stage(t, 1.1)
    a, dy = reveal(t, 0.02, 0.45)

    def copy(d, dy=dy):
        y = 248 + dy
        kicker(d, "БОТ", y)
        y += 64
        d.text((PAD, y), "Три вопроса", font=display(64, 760), fill=FG)
        y += 96
        face = sans(32, 520)
        y = block(d, wrap("Цель, опыт, формат. Потом бот сам предлагает ближайшее время.", face, 900), PAD, y, face, MUTED, 4)

    paint(im, a, copy)
    if a > 0.4:
        chosen = ease((t - 1.15) / 0.35)
        slot = ease((t - 1.85) / 0.4)

        def screen(d, content, light, chosen=chosen, slot=slot):
            x0, y0, x1, y1 = content
            width = x1 - x0
            d.ellipse([x0, y0, x0 + 36, y0 + 36], fill=(48, 48, 50, 255))
            d.ellipse([x0 + 10, y0 + 10, x0 + 26, y0 + 26], fill=LIME)
            d.text((x0 + 48, y0 + 2), "DVOR", font=sans(22, 700), fill=FG)
            d.text((x0 + 48, y0 + 28), "бот", font=sans(16, 500), fill=MUTED)
            d.line([(x0, y0 + 56), (x1, y0 + 56)], fill=(42, 42, 44, 255), width=1)
            y = y0 + 76
            face = sans(22, 600)
            msg = "Какая цель?"
            tw = min(face.getlength(msg) + 40, width * 0.86)
            th = 58
            d.rounded_rectangle([x0, y, x0 + tw, y + th], radius=20, fill=FG)
            d.text((x0 + 20, y + 14), msg, font=face, fill=INK)
            y += th + 16
            key = sans(20, 650)
            for lab in ("Сила", "Бокс", "Выносливость"):
                hot = lab == "Бокс"
                k = chosen if hot else 0.0
                bg = (
                    int(38 + (LIME[0] - 38) * k),
                    int(38 + (LIME[1] - 38) * k),
                    int(40 + (LIME[2] - 40) * k),
                    255,
                )
                fg = (INK if k > 0.55 else FG)
                d.rounded_rectangle([x0, y, x1, y + 52], radius=16, fill=bg)
                d.text((x0 + (width - key.getlength(lab)) / 2, y + 12), lab, font=key, fill=fg)
                y += 62
            if slot > 0.05:
                y += 8
                slot_face = sans(22, 650)
                label = "Среда, 19:30"
                tw = slot_face.getlength(label) + 44
                d.rounded_rectangle([x0, y, x0 + tw, y + 58], radius=20, fill=(*FG[:3], int(255 * slot)))
                d.text((x0 + 22, y + 14), label, font=slot_face, fill=(*INK[:3], int(255 * slot)))

        phone(im, [PHONE_BOX[0], PHONE_BOX[1] + int((1 - a) * 24), PHONE_BOX[2], PHONE_BOX[3] + int((1 - a) * 24)], False, screen)
    return im


def scene_check(t):
    im = stage(t, 1.6)
    a, dy = reveal(t, 0.02, 0.45)
    press = ease((t - 1.2) / 0.35)

    def copy(d, dy=dy):
        y = 248 + dy
        kicker(d, "ОПЛАТА", y)
        y += 64
        d.text((PAD, y), "Чек кнопкой", font=display(64, 760), fill=FG)
        y += 100
        face = sans(32, 520)
        text = "Человек кидает фото чека, менеджер жмёт «подтвердить». Если слот не оплатили, бот напомнит сам."
        block(d, wrap(text, face, 900), PAD, y, face, MUTED, 4)

    paint(im, a, copy)

    def screen(d, content, light, press=press):
        x0, y0, x1, y1 = content
        ink = (24, 24, 22, 255)
        mute = (110, 108, 102, 255)
        d.text((x0, y0), "Чек", font=display(36, 720), fill=ink)
        d.text((x0, y0 + 52), "Бокс, среда, 19:30", font=sans(22, 560), fill=mute)
        card = [x0, y0 + 108, x1, y1 - 108]
        d.rounded_rectangle(card, radius=22, fill=(232, 230, 222, 255))
        d.text((x0 + 24, card[1] + 22), "ФОТО ЧЕКА", font=mono(16, 560), fill=mute)
        d.rounded_rectangle([x0 + 24, card[1] + 70, x1 - 24, card[3] - 28], radius=16, fill=(214, 212, 204, 255))
        button = [x0, y1 - 78, x1, y1 - 12]
        bg = (
            int(24 + (LIME[0] - 24) * press),
            int(24 + (LIME[1] - 24) * press),
            int(26 + (LIME[2] - 26) * press),
            255,
        )
        fg = INK if press > 0.55 else FG
        d.rounded_rectangle(button, radius=22, fill=bg)
        label = "подтвердить"
        face = sans(26, 700)
        d.text((button[0] + (button[2] - button[0] - face.getlength(label)) / 2, button[1] + 18), label, font=face, fill=fg)

    if a > 0.35:
        shift = int((1 - a) * 20)
        phone(im, [PHONE_BOX[0], PHONE_BOX[1] + shift, PHONE_BOX[2], PHONE_BOX[3] + shift], True, screen)
    return im


def scene_loyal(t):
    im = stage(t, 0.4, mark="low")
    a, dy = reveal(t, 0.04, 0.5)

    def body(d, dy=dy):
        y = 500 + dy
        kicker(d, "ЛОЯЛЬНОСТЬ", y)
        y += 78
        d.text((PAD, y), "Кроме записи", font=display(58, 740), fill=FG)
        y += 84
        d.text((PAD, y), "доработали", font=display(58, 740), fill=FG)
        y += 86
        d.text((PAD, y), "лояльность", font=serif_i(78, 650), fill=LIME)
        y += 130
        face = sans(34, 520)
        text = "Это программа лояльности. Баллы после тренировки, похода и кэмпа копятся у человека в боте."
        y = block(d, wrap(text, face, 900), PAD, y, face, FG, 6)
        y += 18
        close = "Мы остаёмся на поддержке бота и постоянно его улучшаем."
        block(d, wrap(close, face, 900), PAD, y, face, MUTED, 6)

    paint(im, a, body)
    return im


def scene_metric(t):
    im = stage(t, 2.0, mark="low")
    a, dy = reveal(t, 0.04, 0.55)
    if a > 0.15:
        im.alpha_composite(METRIC_GLOW)

    def body(d, dy=dy):
        y = 560 + dy
        kicker(d, "ЗАЯВКИ", y)
        y += 70
        d.text((PAD, y), "−65%", font=display(188, 820), fill=LIME)
        y += 230
        d.text((PAD, y), "времени на заявки", font=display(42, 700), fill=FG)
        y += 80
        face = sans(34, 520)
        block(d, wrap("Столько сняли с вечеров DVOR.", face, 860), PAD, y, face, MUTED, 4)

    paint(im, a, body)
    return im


def scene_end(t):
    im = stage(t, 0.6, mark="end")
    a, dy = reveal(t, 0.02, 0.4)

    def body(d, dy=dy):
        y = 700 + dy
        face = sans(34, 520)
        label = "Напишите в заявке"
        d.text(((W - face.getlength(label)) / 2, y), label, font=face, fill=MUTED)
        word = display(168, 820)
        ww = word.getlength("БОТ")
        d.text(((W - ww) / 2, y + 70), "БОТ", font=word, fill=LIME)
        site = sans(36, 650)
        d.text(((W - site.getlength("foshill.com")) / 2, y + 280), "foshill.com", font=site, fill=FG)
        nick = mono(22, 500)
        d.text(((W - nick.getlength("@foshill")) / 2, y + 350), "@foshill", font=nick, fill=MUTED)

    paint(im, a, body)
    return im


RENDERERS = {
    "hook": scene_hook,
    "pain": scene_pain,
    "quiz": scene_quiz,
    "check": scene_check,
    "loyal": scene_loyal,
    "metric": scene_metric,
    "end": scene_end,
}


def scene_opacity(t, start, end):
    if t < start or t >= end:
        return 0.0
    if t < start + FADE:
        return (t - start) / FADE
    if t > end - FADE:
        return (end - t) / FADE
    return 1.0


def compose(t, grade=True):
    base = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for name, start, end in SCENES:
        op = scene_opacity(t, start, end)
        if op <= 0:
            continue
        layer = RENDERERS[name](t - start)
        if op < 0.999:
            r, g, b, al = layer.split()
            al = al.point(lambda p, k=op: int(p * k))
            layer = Image.merge("RGBA", (r, g, b, al))
        base.alpha_composite(layer)
    if grade:
        base = finish(base, t)
    return base.convert("RGB")


def encode():
    fade_out = max(0.2, DURATION - 0.85)
    subprocess.check_call(
        [
            "ffmpeg", "-y",
            "-framerate", str(FPS), "-start_number", "0",
            "-i", os.path.join(FRAME_DIR, "%04d.jpg"),
            "-i", MUSIC,
            "-t", f"{DURATION:.3f}",
            "-filter:a", f"afade=t=in:st=0:d=0.4,afade=t=out:st={fade_out:.3f}:d=0.8,loudnorm=I=-16:TP=-1.5:LRA=11",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
            "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart",
            OUT_MP4,
        ]
    )


def main():
    stills = "--stills" in sys.argv
    ensure_fonts()
    ensure_music()
    init_plates()
    os.makedirs(FRAME_DIR, exist_ok=True)
    if stills:
        shots = {
            "hook": 1.1,
            "pain": 5.1,
            "quiz": 9.4,
            "check": 13.0,
            "loyal": 16.2,
            "metric": 18.7,
            "end": 21.6,
        }
        for name, t in shots.items():
            path = os.path.join(HERE, f"reel-{name}.jpg")
            compose(t).save(path, quality=90)
            print("still", path)
        return

    frames = int(DURATION * FPS)
    for i in range(frames):
        compose(i / FPS).save(os.path.join(FRAME_DIR, f"{i:04d}.jpg"), quality=90)
        if i % 30 == 0:
            print(f"frame {i}/{frames}")
    encode()
    print("wrote", OUT_MP4)


if __name__ == "__main__":
    main()
