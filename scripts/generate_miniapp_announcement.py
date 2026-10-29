#!/usr/bin/env python3
"""Compose the Mini App announcement carousel in the week-stories style.

Stories 1080×1920 and feed posts 1080×1350. App screenshots come from
`--shots` (schedule.png, event.png at 1170×2532, see docs/MINIAPP_ARCHITECTURE.md).
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_week_stories as ws  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
BOT = "@dvor_chatbot"
SURFACE = (23, 24, 18, 235)
STROKE = (255, 255, 255, 30)


@dataclass(frozen=True)
class Photo:
    path: Path
    credit: str


def cached(photo_id: str) -> Path:
    matches = sorted(ws.CACHE.glob(f"0-{photo_id}*.jpg"))
    if not matches:
        raise SystemExit(f"Missing cached photo {photo_id}; run generate_week_stories.py once.")
    return matches[0]


def pool_credit(photo_id: str) -> str:
    for item in ws.PHOTO_POOL:
        if item["id"] == photo_id:
            return f"{item['credit']}, {item['what']} — {item['url']}"
    return photo_id


def photo(photo_id: str | None = None, local: str | None = None) -> Photo:
    if local:
        return Photo(ws.ASSETS / local, f"{local} — архив DVOR")
    assert photo_id
    return Photo(cached(photo_id), pool_credit(photo_id))


# ---------- primitives ----------


def is_story() -> bool:
    return ws.H > 1400


def base(bg: Photo, dark: float = 0.42) -> Image.Image:
    return ws.load_bg(bg.path, dark=dark, blur=18, brightness=1.0)


def finish(im: Image.Image, line: bool = True) -> Image.Image:
    d = ImageDraw.Draw(im)
    if line:
        ws.draw_story_line(d, ws.ACCENT, x0=ws.MARGIN, x1=ws.W, start_dot=True, end_dot=False)
    ws.paste_dvor_logo(im, ws.W / 2, ws.LOGO_Y, width=ws.LOGO_W)
    return ws.add_grain(im, 30)


def header(im: Image.Image, lines: list[str], y: int | None = None) -> int:
    d = ImageDraw.Draw(im)
    f = ws.font(ws.FONT_BLACK, 76 if is_story() else 60)
    y = y if y is not None else ws.HEADER_Y[0] + (40 if is_story() else 10)
    step = int(f.size * 0.98)
    for i, line in enumerate(lines):
        ws.draw_tracked(d, (ws.W / 2, y + i * step), line, f, ws.WHITE, tracking=-3, anchor="mt")
    return y + len(lines) * step


def text_block(
    im: Image.Image,
    text: str,
    x: int,
    y: int,
    width: int,
    size: int,
    color=ws.WHITE,
    face: Path | None = None,
    line_gap: float = 1.28,
    center: bool = False,
) -> int:
    d = ImageDraw.Draw(im)
    f = ws.font(face or ws.FONT_MEDIUM, size)
    for line in ws.wrap_text(text, f, width):
        if center:
            ws.draw_tracked(d, (x + width / 2, y), line, f, color, tracking=0, anchor="mt")
        else:
            ws.paint_text(d, (x, y), line, f, color)
        y += int(size * line_gap)
    return y


def number_badge(im: Image.Image, n: int, x: int, y: int, size: int) -> None:
    d = ImageDraw.Draw(im)
    d.ellipse((x, y, x + size, y + size), fill=ws.ACCENT)
    f = ws.font(ws.FONT_BLACK, int(size * 0.52))
    label = str(n)
    w = f.getlength(label)
    bbox = f.getbbox(label)
    d.text((x + (size - w) / 2, y + (size - (bbox[3] - bbox[1])) / 2 - bbox[1]), label, font=f, fill=(13, 14, 11, 255))


def panel(im: Image.Image, box: tuple[int, int, int, int], radius: int = 36) -> None:
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=SURFACE, outline=STROKE, width=2)
    im.alpha_composite(layer)


def phone(im: Image.Image, shot: Path, cx: int, top: int, width: int, crop: float = 1.0) -> int:
    """Pastes a screenshot in a phone bezel; [crop] keeps the top share of the screen."""
    screen = Image.open(shot).convert("RGBA")
    if crop < 1.0:
        screen = screen.crop((0, 0, screen.width, int(screen.height * crop)))
    inner_w = width - 28
    inner_h = int(screen.height * inner_w / screen.width)
    screen = screen.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
    radius = int(width * 0.12)
    h = inner_h + 28
    x0, y0 = int(cx - width / 2), top

    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x0 + 6, y0 + 24, x0 + width + 6, y0 + h + 24), radius=radius, fill=(0, 0, 0, 150))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))

    body = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((x0, y0, x0 + width, y0 + h), radius=radius, fill=(6, 6, 6, 255), outline=(60, 62, 52, 255), width=3)
    im.alpha_composite(body)

    mask = Image.new("L", screen.size, 0)
    md = ImageDraw.Draw(mask)
    if crop < 1.0:
        # Cropped screens fade out at the bottom instead of ending in a hard edge.
        md.rounded_rectangle((0, 0, inner_w, inner_h + radius), radius=radius - 14, fill=255)
        fade = Image.linear_gradient("L").resize((inner_w, int(inner_h * 0.22)))
        fade = Image.eval(fade, lambda v: 255 - v)
        mask.paste(Image.composite(fade, Image.new("L", fade.size, 0), fade), (0, inner_h - fade.height))
    else:
        md.rounded_rectangle((0, 0, inner_w, inner_h), radius=radius - 14, fill=255)
    im.paste(screen, (x0 + 14, y0 + 14), mask)
    return y0 + h


def chips(im: Image.Image, labels: list[str], cy: int, size: int, max_width: int) -> None:
    f = ws.font(ws.FONT_EXTRABOLD, size)
    pad = int(size * 0.8)
    gap = int(size * 0.5)
    widths = [ws.tracked_width(t, f, -1) + pad * 2 for t in labels]
    rows: list[list[int]] = [[]]
    for i, w in enumerate(widths):
        row_w = sum(widths[j] for j in rows[-1]) + gap * len(rows[-1])
        if rows[-1] and row_w + w > max_width:
            rows.append([])
        rows[-1].append(i)
    row_h = int(size * 2.1)
    y = cy - (len(rows) * row_h) // 2
    for row in rows:
        total = sum(widths[i] for i in row) + gap * (len(row) - 1)
        x = (ws.W - total) // 2
        for i in row:
            ws.draw_left_pill(im, labels[i], x, y + row_h // 2, f, ws.ACCENT, tracking=-1, pad_x=pad, pad_y=int(size * 0.42), stroke=3)
            x += widths[i] + gap
        y += row_h


def telegram_input(im: Image.Image, x0: int, y: int, width: int, scale: float) -> None:
    """Stylised Telegram composer: the DVOR menu button left of the message field."""
    h = int(96 * scale)
    panel(im, (x0, y, x0 + width, y + h), radius=h // 2)
    d = ImageDraw.Draw(im)
    f = ws.font(ws.FONT_BLACK, int(34 * scale))
    label = "DVOR"
    bw = int(f.getlength(label) + 56 * scale)
    bx0, by0 = x0 + int(14 * scale), y + int(14 * scale)
    d.rounded_rectangle((bx0, by0, bx0 + bw, y + h - int(14 * scale)), radius=int(22 * scale), fill=ws.ACCENT)
    bbox = f.getbbox(label)
    d.text((bx0 + 28 * scale, y + (h - (bbox[3] - bbox[1])) / 2 - bbox[1]), label, font=f, fill=(13, 14, 11, 255))
    pf = ws.font(ws.FONT_MEDIUM, int(32 * scale))
    pb = pf.getbbox("Сообщение")
    d.text((bx0 + bw + 28 * scale, y + (h - (pb[3] - pb[1])) / 2 - pb[1]), "Сообщение", font=pf, fill=(255, 255, 255, 110))
    # finger pointer ring around the button
    ring = int(10 * scale)
    d.rounded_rectangle((bx0 - ring, by0 - ring, bx0 + bw + ring, y + h - int(14 * scale) + ring), radius=int(30 * scale), outline=ws.ACCENT, width=3)


def centered(im: Image.Image, top: int, bottom: int, draw) -> None:
    """Draws [draw] on a clear layer and moves the result to sit midway
    between [top] and [bottom]."""
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw(layer)
    box = layer.getbbox()
    if box is None:
        return
    dy = int((top + bottom) / 2 - (box[1] + box[3]) / 2)
    im.alpha_composite(layer.crop(box), (box[0], max(0, box[1] + dy)))


# ---------- slides ----------


def slide_cover(bg: Photo) -> Image.Image:
    im = base(bg, dark=0.32)
    d = ImageDraw.Draw(im)
    pill_f = ws.font(ws.FONT_EXTRABOLD, 34 if is_story() else 28)
    ws.draw_pill_outline(im, "ПРИЛОЖЕНИЕ В TELEGRAM", (ws.W // 2, ws.COVER_PILL_Y), pill_f, ws.ACCENT, tracking=-1, pad_x=34, pad_y=14, stroke=3)
    title_f = ws.font(ws.FONT_BLACK, ws.COVER_TITLE_SIZE)
    ws.draw_tracked(d, (ws.W / 2, ws.COVER_TITLE_Y[0]), "НОВЫЙ", title_f, ws.WHITE, tracking=-10, anchor="mt")
    ws.draw_tracked(d, (ws.W / 2, ws.COVER_TITLE_Y[1]), "ДВОР", title_f, ws.WHITE, tracking=-10, anchor="mt")
    sub_y = ws.COVER_TITLE_Y[1] + int(ws.COVER_TITLE_SIZE * 1.55)
    text_block(
        im,
        "Расписание, запись и оплата — в одном окне прямо в Telegram",
        ws.MARGIN + 40,
        sub_y,
        ws.W - 2 * (ws.MARGIN + 40),
        46 if is_story() else 36,
        face=ws.FONT_EXTRABOLD,
        center=True,
    )
    return finish(im)


def slide_how(bg: Photo) -> Image.Image:
    im = base(bg, dark=0.55)
    story = is_story()
    top = header(im, ["КАК ОТКРЫТЬ"])
    width = ws.W - 2 * ws.MARGIN
    steps = [
        f"Зайди в чат с ботом {BOT}",
        "Нажми кнопку DVOR слева от поля ввода",
        "Выбирай тренировку, поход или кэмп — запись в пару касаний",
    ]

    def draw(layer: Image.Image) -> None:
        y = 0
        telegram_input(layer, ws.MARGIN, y, width, 1.25 if story else 1.0)
        y += (120 if story else 96) + (100 if story else 56)
        badge = 76 if story else 60
        size = 48 if story else 38
        for i, step in enumerate(steps, start=1):
            number_badge(layer, i, ws.MARGIN, y, badge)
            end = text_block(layer, step, ws.MARGIN + badge + 34, y + (badge - size) // 2 - 4, width - badge - 34, size, face=ws.FONT_EXTRABOLD)
            y = max(end, y + badge) + (60 if story else 36)
        text_block(layer, "Ничего устанавливать не нужно", ws.MARGIN, y + 10, width, 40 if story else 32, color=(255, 255, 255, 170))

    centered(im, top, ws.LINE_Y - 40, draw)
    return finish(im)


def slide_inside(bg: Photo, shot: Path) -> Image.Image:
    im = base(bg, dark=0.55)
    story = is_story()
    labels = ["Афиша и места", "Запись", "Оплата и чек", "Вершинки", "Мои записи", "BOXING CARD"]
    if story:
        y = header(im, ["ВСЁ В ОДНОМ", "ОКНЕ"])
        bottom = phone(im, shot, ws.W // 2, y + 60, 560, crop=0.86)
        chips(im, labels, (bottom + ws.LINE_Y) // 2 + 6, 36, ws.W - 2 * ws.MARGIN)
    else:
        top = header(im, ["ВСЁ В ОДНОМ ОКНЕ"], y=ws.HEADER_Y[0] + 6)
        items = [
            ("Афиша", "тренировки, походы и кэмпы со свободными местами"),
            ("Запись", "в пару касаний, себя и друга"),
            ("Оплата", "СБП, чек, вершинки и промокод"),
            ("Мои записи", "перенос, отмена, статус оплаты"),
        ]

        def draw(layer: Image.Image) -> None:
            phone(layer, shot, ws.MARGIN + 205, 0, 410, crop=0.82)
            x = ws.MARGIN + 450
            col_w = ws.W - x - ws.MARGIN
            y = 40
            d = ImageDraw.Draw(layer)
            tf = ws.font(ws.FONT_BLACK, 40)
            for title, body in items:
                ws.draw_tracked(d, (x, y), title.upper(), tf, ws.ACCENT, tracking=-2)
                y = text_block(layer, body, x, y + 54, col_w, 30, color=(255, 255, 255, 210)) + 34

        centered(im, top, ws.LINE_Y - 30, draw)
    return finish(im)


def slide_booking(bg: Photo, shot: Path) -> Image.Image:
    im = base(bg, dark=0.58)
    story = is_story()
    steps = ["Выбери слот", "Нажми «Записаться»", "Оплати и прикрепи чек"]
    if story:
        y = header(im, ["ЗАПИСЬ", "ЗА МИНУТУ"])
        bottom = phone(im, shot, ws.W // 2, y + 60, 520, crop=0.66)
        y = bottom + 70
        badge = 64
        for i, step in enumerate(steps, start=1):
            number_badge(im, i, ws.MARGIN + 40, y, badge)
            text_block(im, step, ws.MARGIN + 40 + badge + 30, y + 10, ws.W, 44, face=ws.FONT_EXTRABOLD)
            y += badge + 30
    else:
        top = header(im, ["ЗАПИСЬ ЗА МИНУТУ"], y=ws.HEADER_Y[0] + 6)

        def draw(layer: Image.Image) -> None:
            phone(layer, shot, ws.W - ws.MARGIN - 205, 0, 410, crop=0.82)
            y = 60
            badge = 64
            col_w = ws.W - 2 * ws.MARGIN - 450
            for i, step in enumerate(steps, start=1):
                number_badge(layer, i, ws.MARGIN, y, badge)
                end = text_block(layer, step, ws.MARGIN, y + badge + 18, col_w, 40, face=ws.FONT_EXTRABOLD)
                y = end + 54
            text_block(layer, "Статус оплаты видно сразу в «Моих записях»", ws.MARGIN, y, col_w, 28, color=(255, 255, 255, 170))

        centered(im, top, ws.LINE_Y - 30, draw)
    return finish(im)


def slide_bot(bg: Photo) -> Image.Image:
    im = base(bg, dark=0.55)
    story = is_story()
    top = header(im, ["А БОТ", "ОСТАЁТСЯ"] if story else ["А БОТ ОСТАЁТСЯ"])
    width = ws.W - 2 * ws.MARGIN
    items = [
        "Напомнит об оплате и тренировке",
        "Пришлёт ответ по чеку",
        "Спросит, как прошла тренировка",
        "Позовёт на новые слоты",
    ]
    size = 42 if story else 34
    pad = 40 if story else 30
    f = ws.font(ws.FONT_EXTRABOLD, size)
    dot = int(size * 0.32)
    # Shrink until the longest line fits inside the panel.
    while max(f.getlength(t) for t in items) + 2 * pad + dot + 26 > width and size > 26:
        size -= 2
        f = ws.font(ws.FONT_EXTRABOLD, size)
    row_h = int(size * 1.3) + pad * 2

    def draw(layer: Image.Image) -> None:
        y = 0
        box = (ws.MARGIN, y, ws.MARGIN + width, y + row_h * len(items))
        panel(layer, box)
        d = ImageDraw.Draw(layer)
        for i, item in enumerate(items):
            ry = y + i * row_h
            if i:
                d.line((ws.MARGIN + pad, ry, ws.MARGIN + width - pad, ry), fill=STROKE, width=2)
            cy = ry + row_h // 2
            d.ellipse((ws.MARGIN + pad, cy - dot // 2, ws.MARGIN + pad + dot, cy + dot // 2), fill=ws.ACCENT)
            bbox = f.getbbox(item)
            ws.paint_text(d, (ws.MARGIN + pad + dot + 26, cy - (bbox[3] - bbox[1]) / 2 - bbox[1]), item, f, ws.WHITE)
        cta_y = box[3] + (110 if story else 70)
        cta_f = ws.font(ws.FONT_EXTRABOLD, 40 if story else 32)
        ws.draw_pill_outline(layer, f"{BOT} → кнопка DVOR", (ws.W // 2, cta_y), cta_f, ws.ACCENT, tracking=-1, pad_x=36, pad_y=18, stroke=3)

    centered(im, top, ws.LINE_Y - 40, draw)
    return finish(im)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shots", type=Path, required=True, help="Folder with schedule.png and event.png")
    parser.add_argument("--out", type=Path, default=ROOT / "output" / "miniapp-announcement")
    args = parser.parse_args()

    photos = {
        "cover": photo("1552674605-db6ffd4facb5"),
        "how": photo(local="court.jpg"),
        "inside": photo("1506905925346-21bda4d32df4"),
        "booking": photo(local="boxing.jpg"),
        "bot": photo("1517836357463-d25dfeac3438"),
    }
    schedule_shot = args.shots / "schedule.png"
    event_shot = args.shots / "event.png"

    for fmt in (ws.STORY, ws.POST):
        ws.apply_format(fmt)
        folder = args.out / fmt.folder
        folder.mkdir(parents=True, exist_ok=True)
        slides = [
            ("01-cover", slide_cover(photos["cover"])),
            ("02-how", slide_how(photos["how"])),
            ("03-inside", slide_inside(photos["inside"], schedule_shot)),
            ("04-booking", slide_booking(photos["booking"], event_shot)),
            ("05-bot", slide_bot(photos["bot"])),
        ]
        for name, im in slides:
            path = folder / f"{name}.png"
            im.convert("RGB").save(path, optimize=True)
            print(path.relative_to(ROOT))

    credits = ["Фоны:"] + [f"{key}: {p.credit}" for key, p in photos.items()]
    credits += ["", "Скриншоты — прод Mini App, тестовый пользователь без записей.", "Акцент: #ADB838"]
    (args.out / "CREDITS.txt").write_text("\n".join(credits) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
