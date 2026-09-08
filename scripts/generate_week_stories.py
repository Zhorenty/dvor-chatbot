#!/usr/bin/env python3
"""Compose DVOR week stories 1080×1920 from the live Google Sheets schedule."""

from __future__ import annotations

import argparse
import csv
import io
import random
import re
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(__file__).resolve().parent / "assets" / "week_stories"
SHEETS_ID = "1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q"
TRAININGS_CSV = f"https://docs.google.com/spreadsheets/d/{SHEETS_ID}/export?format=csv&gid=0"
HIKES_CSV = f"https://docs.google.com/spreadsheets/d/{SHEETS_ID}/export?format=csv&gid=294119056"
MOSCOW = ZoneInfo("Europe/Moscow")
WEEKDAYS = ("пн", "вт", "ср", "чт", "пт", "сб", "вс")

W, H = 1080, 1920
MARGIN = 92
WHITE = (255, 255, 255, 255)
ACCENT = (173, 184, 56, 255)
MUTED = (255, 255, 255, 72)
LINE_Y = 1768

FONT_BLACK = ASSETS / "Montserrat-Black.ttf"
FONT_EXTRABOLD = ASSETS / "Montserrat-ExtraBold.ttf"
FONT_MEDIUM = ASSETS / "Montserrat-Medium.ttf"
LOGO_MARK = ASSETS / "logo-dvor.png"
BG_COVER = ASSETS / "court.jpg"
BG_SCHED = ASSETS / "boxing.jpg"

EMOJI_RE = re.compile(
    "["
    "\U0001f300-\U0001faff"
    "\U00002700-\U000027bf"
    "\U0001f1e0-\U0001f1ff"
    "\U00002600-\U000026ff"
    "\U0000fe00-\U0000fe0f"
    "\U0000200d"
    "]+",
    flags=re.UNICODE,
)


@dataclass
class Slot:
    starts_at: datetime
    title: str
    location: str
    coach: str | None
    notes: str | None
    is_super: bool
    super_tag: str | None = None


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def tracked_width(text: str, fnt: ImageFont.FreeTypeFont, tracking: int) -> int:
    if not text:
        return 0
    total = 0
    for i, ch in enumerate(text):
        total += fnt.getlength(ch)
        if i < len(text) - 1:
            total += tracking
    return int(round(total))


def draw_tracked(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    fnt: ImageFont.FreeTypeFont,
    fill,
    tracking: int = -2,
    anchor: str = "lt",
) -> tuple[int, int]:
    x, y = xy
    width = tracked_width(text, fnt, tracking)
    bbox = fnt.getbbox("Hg")
    height = bbox[3] - bbox[1]
    if anchor == "mt":
        x -= width / 2
    elif anchor == "mm":
        x -= width / 2
        y -= height / 2
    elif anchor == "rt":
        x -= width
    cx = x
    for i, ch in enumerate(text):
        draw.text((cx, y), ch, font=fnt, fill=fill)
        cx += fnt.getlength(ch) + (tracking if i < len(text) - 1 else 0)
    return width, int(fnt.getbbox(text)[3] - fnt.getbbox(text)[1])


def wrap_text(text: str, fnt: ImageFont.FreeTypeFont, max_width: int, tracking: int = 0) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = word if not cur else f"{cur} {word}"
        if tracked_width(trial, fnt, tracking) <= max_width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def fetch_csv(url: str) -> list[dict[str, str]]:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=20) as response:
        body = response.read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(body)))


def parse_sheet_datetime(date_raw: str, time_raw: str) -> datetime | None:
    date_raw = date_raw.strip()
    time_raw = (time_raw or "").strip()
    if not date_raw:
        return None
    for fmt in ("%d.%m.%Y %H:%M", "%d.%m.%Y"):
        try:
            value = datetime.strptime(f"{date_raw} {time_raw}".strip(), fmt)
            return value.replace(tzinfo=MOSCOW)
        except ValueError:
            continue
    return None


def strip_emoji(text: str) -> str:
    return EMOJI_RE.sub("", text).replace("🟡", "").strip()


def clean_spaces(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def poster_title(title: str, coach: str | None) -> str:
    raw = clean_spaces(strip_emoji(title))
    if coach:
        raw = re.sub(r"\s+[cс]\s+.+$", "", raw, flags=re.IGNORECASE)
    return raw.upper()


def poster_location(location: str) -> str:
    raw = clean_spaces(strip_emoji(location))
    lowered = raw.casefold()
    if "кубан" in lowered:
        return "СТАДИОН «КУБАНЬ»"
    if "варг" in lowered:
        return "БОЙЦОВСКИЙ КЛУБ «ВАРГ»"
    if "surf" in lowered:
        return "SURF COFFEE X RIVERSIDE"
    raw = re.sub(r"\s*\([^)]*\)\s*", " ", raw)
    return clean_spaces(raw).upper()


def compress_notes(notes: str | None, *, super_event: bool) -> list[str]:
    if not notes:
        return []
    text = strip_emoji(notes)
    text = text.replace("не просто так, а ", "")
    text = re.sub(r"Ставь кроссовки и беги с нами!\s*", "", text)
    text = re.sub(r"ЧТО ВХОДИТ[\s\S]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"ВАЖНО:[\s\S]*", "", text)
    text = re.sub(r"ЧТО БРАТЬ[\s\S]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"Тренер:[\s\S]*", "", text)
    text = re.sub(r"Уровень сложности:\s*", "Сложность: ", text, flags=re.IGNORECASE)
    chunks = [clean_spaces(part) for part in re.split(r"[\n.!?]+", text) if clean_spaces(part)]
    skip_prefixes = (
        "приглашаем",
        "ставь",
        "не бойся",
        "виды, ради",
        "старт:",
        "финиш:",
        "календар",
    )
    kept: list[str] = []
    for chunk in chunks:
        lowered = chunk.casefold()
        if any(lowered.startswith(prefix) for prefix in skip_prefixes):
            continue
        if re.fullmatch(r"\d{1,2}\s+сентября|\d{1,2}\.\d{2}(\.\d{4})?", lowered):
            continue
        sentence = chunk if chunk.endswith(".") else f"{chunk}."
        kept.append(sentence)
        if super_event and len(kept) >= 3:
            break
        if not super_event:
            break
    if super_event:
        return kept[:3]
    if not kept:
        return []
    line = kept[0]
    if len(line) > 92:
        line = line[:89].rsplit(" ", 1)[0]
        line = line if line.endswith(".") else f"{line}."
    return [line]


def first_plan_time(plan: str | None) -> str | None:
    if not plan:
        return None
    match = re.search(r"\b(\d{1,2}:\d{2})\b", plan)
    if not match:
        return None
    hours, minutes = match.group(1).split(":")
    return f"{int(hours):02d}:{minutes}"


def super_tag_from_text(title: str, description: str) -> str:
    blob = f"{title} {description}".casefold()
    if "outdvor" in blob:
        return "КОЛЛАБОРАЦИЯ DVOR × OUTDVOR"
    if "восхожд" in blob:
        return "ВОСХОЖДЕНИЕ"
    return "ВЫЕЗД"


def week_bounds(now: datetime) -> tuple[datetime, datetime]:
    local = now.astimezone(MOSCOW)
    monday = (local - timedelta(days=local.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    sunday_end = monday + timedelta(days=7)
    return monday, sunday_end


def load_week_slots(now: datetime) -> list[Slot]:
    monday, sunday_end = week_bounds(now)
    slots: list[Slot] = []

    for row in fetch_csv(TRAININGS_CSV):
        title = (row.get("название") or "").strip()
        location = (row.get("место") or "").strip()
        if not title or not location:
            continue
        starts = parse_sheet_datetime(row.get("дата") or "", row.get("время") or "")
        if starts is None or not (monday <= starts < sunday_end) or starts <= now:
            continue
        coach = clean_spaces(row.get("тренер") or "") or None
        notes = (row.get("заметки") or "").strip() or None
        slots.append(
            Slot(
                starts_at=starts,
                title=title,
                location=location,
                coach=coach,
                notes=notes,
                is_super=False,
            )
        )

    for row in fetch_csv(HIKES_CSV):
        title = (row.get("название") or "").strip()
        location = (row.get("место") or "").strip()
        if not title:
            continue
        starts = parse_sheet_datetime(row.get("дата_с") or "", first_plan_time(row.get("план")) or "00:00")
        if starts is None or not (monday <= starts < sunday_end) or starts <= now:
            continue
        description = (row.get("описание") or "").strip() or None
        slots.append(
            Slot(
                starts_at=starts,
                title=title,
                location=location or "АДЫГЕЯ",
                coach=None,
                notes=description,
                is_super=True,
                super_tag=super_tag_from_text(title, description or ""),
            )
        )

    slots.sort(key=lambda item: item.starts_at)
    return slots


def date_pill(slot: Slot) -> str:
    return f"{slot.starts_at:%d.%m} ({WEEKDAYS[slot.starts_at.weekday()]})"


def time_label(slot: Slot) -> str:
    return f"{slot.starts_at:%H:%M}"


def titled(slot: Slot) -> str:
    name = poster_title(slot.title, slot.coach)
    if slot.is_super:
        return f"«{name}»"
    if slot.coach:
        return f"{name} ({slot.coach.upper()})"
    return name


def load_bg(path: Path, dark: float = 0.32, blur: float = 16, brightness: float = 1.0) -> Image.Image:
    im = Image.open(path).convert("RGB")
    im = ImageOps.fit(im, (W, H), Image.Resampling.LANCZOS, centering=(0.5, 0.45))
    if brightness != 1.0:
        im = ImageEnhance.Brightness(im).enhance(brightness)
    im = im.filter(ImageFilter.GaussianBlur(blur))
    overlay_grade = Image.new("RGB", (W, H), (28, 32, 12))
    im = Image.blend(im, overlay_grade, 0.12)
    im = ImageEnhance.Color(im).enhance(0.94)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    overlay = Image.new("RGBA", (W, H), (10, 12, 8, int(255 * dark)))
    return Image.alpha_composite(im.convert("RGBA"), overlay)


def add_grain(im: Image.Image, amount: int = 28) -> Image.Image:
    rng = random.Random(20260908)
    noise = Image.new("L", (W, H))
    noise.putdata([rng.randint(0, 255) for _ in range(W * H)])
    noise = noise.filter(ImageFilter.GaussianBlur(0.4))
    grain = Image.merge("RGB", (noise, noise, noise)).convert("RGBA")
    grain.putalpha(amount)
    return Image.alpha_composite(im.convert("RGBA"), grain)


def blit_pill_ring(im: Image.Image, box: tuple[int, int, int, int], color, stroke: int) -> None:
    x0, y0, x1, y1 = box
    h = y1 - y0
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=h / 2, fill=color)
    cut = Image.new("L", im.size, 0)
    cd = ImageDraw.Draw(cut)
    inner = (x0 + stroke, y0 + stroke, x1 - stroke, y1 - stroke)
    ih = inner[3] - inner[1]
    cd.rounded_rectangle(inner, radius=max(1, ih / 2), fill=255)
    layer.putalpha(ImageChops.subtract(layer.split()[-1], cut))
    im.alpha_composite(layer)


def draw_pill_outline(
    im: Image.Image,
    text: str,
    center: tuple[int, int],
    fnt: ImageFont.FreeTypeFont,
    color,
    tracking: int = -1,
    pad_x: int = 28,
    pad_y: int = 12,
    stroke: int = 3,
) -> tuple[int, int, int, int]:
    tw = tracked_width(text, fnt, tracking)
    bbox = fnt.getbbox(text)
    th = bbox[3] - bbox[1]
    w = tw + pad_x * 2
    h = th + pad_y * 2
    x0 = int(center[0] - w / 2)
    y0 = int(center[1] - h / 2)
    x1, y1 = x0 + w, y0 + h
    blit_pill_ring(im, (x0, y0, x1, y1), color, stroke)
    d = ImageDraw.Draw(im)
    cx = x0 + pad_x
    text_y = y0 + pad_y - bbox[1] - 1
    for i, ch in enumerate(text):
        d.text((cx, text_y), ch, font=fnt, fill=WHITE)
        cx += fnt.getlength(ch) + (tracking if i < len(text) - 1 else 0)
    return (x0, y0, x1, y1)


def draw_left_pill(
    im: Image.Image,
    text: str,
    left: int,
    cy: int,
    fnt: ImageFont.FreeTypeFont,
    color,
    tracking: int = -1,
    pad_x: int = 14,
    pad_y: int = 8,
    stroke: int = 3,
) -> tuple[int, int, int, int]:
    tw = tracked_width(text, fnt, tracking)
    bbox = fnt.getbbox(text)
    th = bbox[3] - bbox[1]
    w = tw + pad_x * 2
    h = th + pad_y * 2
    x0, y0 = left, int(cy - h / 2)
    x1, y1 = x0 + w, y0 + h
    blit_pill_ring(im, (x0, y0, x1, y1), color, stroke)
    d = ImageDraw.Draw(im)
    cx = x0 + pad_x
    text_y = y0 + pad_y - bbox[1] - 1
    for i, ch in enumerate(text):
        d.text((cx, text_y), ch, font=fnt, fill=WHITE)
        cx += fnt.getlength(ch) + (tracking if i < len(text) - 1 else 0)
    return (x0, y0, x1, y1)


def draw_story_line(
    draw: ImageDraw.ImageDraw,
    color,
    x0: int,
    x1: int,
    start_dot: bool,
    end_dot: bool,
) -> None:
    y = LINE_Y
    r = 8
    draw.line((x0, y, x1, y), fill=color, width=3)
    if start_dot:
        draw.ellipse((x0 - r, y - r, x0 + r, y + r), fill=color)
    if end_dot:
        draw.ellipse((x1 - r, y - r, x1 + r, y + r), fill=color)


def paste_dvor_logo(im: Image.Image, cx: float, cy: float, width: int) -> None:
    logo = Image.open(LOGO_MARK).convert("RGBA")
    ratio = width / logo.width
    logo = logo.resize((width, max(1, int(logo.height * ratio))), Image.Resampling.LANCZOS)
    x = int(cx - logo.width / 2)
    y = int(cy - logo.height / 2)
    im.alpha_composite(logo, (x, y))


def cover(range_label: str) -> Image.Image:
    im = load_bg(BG_COVER, dark=0.30, blur=16, brightness=1.05)
    d = ImageDraw.Draw(im)
    pill_f = font(FONT_EXTRABOLD, 34)
    draw_pill_outline(im, range_label, (W // 2, 210), pill_f, ACCENT, tracking=-1, pad_x=34, pad_y=14, stroke=3)
    title_f = font(FONT_BLACK, 186)
    draw_tracked(d, (W / 2, 560), "НЕДЕЛЯ", title_f, WHITE, tracking=-10, anchor="mt")
    draw_tracked(d, (W / 2, 770), "ДВОРА", title_f, WHITE, tracking=-10, anchor="mt")
    draw_story_line(d, ACCENT, x0=MARGIN, x1=W, start_dot=True, end_dot=False)
    return add_grain(im, 34)


def schedule_header(d: ImageDraw.ImageDraw) -> None:
    f = font(FONT_BLACK, 54)
    draw_tracked(d, (W / 2, 88), "РАСПИСАНИЕ", f, WHITE, tracking=-3, anchor="mt")
    draw_tracked(d, (W / 2, 152), "НА НЕДЕЛЮ", f, WHITE, tracking=-3, anchor="mt")


def regular_slot(im: Image.Image, d: ImageDraw.ImageDraw, y: int, slot: Slot) -> int:
    date_f = font(FONT_EXTRABOLD, 22)
    time_f = font(FONT_BLACK, 28)
    title_f = font(FONT_BLACK, 26)
    loc_f = font(FONT_EXTRABOLD, 20)
    notes_f = font(FONT_MEDIUM, 20)
    pill = draw_left_pill(im, date_pill(slot), MARGIN, y + 22, date_f, ACCENT)
    d.text((pill[2] + 16, y + 6), time_label(slot), font=time_f, fill=WHITE)
    block_x = 430
    block_w = W - MARGIN - block_x
    ty = y
    for line in wrap_text(titled(slot), title_f, block_w, tracking=-1)[:2]:
        draw_tracked(d, (block_x, ty), line, title_f, WHITE, tracking=-1, anchor="lt")
        ty += 32
    draw_tracked(d, (block_x, ty + 2), poster_location(slot.location), loc_f, ACCENT, tracking=-1, anchor="lt")
    ty += 30
    for line in compress_notes(slot.notes, super_event=False)[:1]:
        for wrapped in wrap_text(line, notes_f, block_w)[:1]:
            d.text((block_x, ty), wrapped, font=notes_f, fill=WHITE)
            ty += 26
    return max(ty + 8, y + 118)


def super_card(im: Image.Image, y: int, slot: Slot) -> None:
    d = ImageDraw.Draw(im)
    x0, x1 = MARGIN - 8, W - MARGIN + 8
    y0, y1 = y, y + 390
    card = Image.new("RGBA", im.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((x0, y0, x1, y1), radius=24, fill=(8, 6, 4, 168), outline=ACCENT, width=3)
    im.alpha_composite(card)
    d = ImageDraw.Draw(im)
    split = 360
    d.line((split, y0 + 32, split, y1 - 32), fill=(255, 255, 255, 160), width=2)
    date_f = font(FONT_BLACK, 52)
    day_f = font(FONT_EXTRABOLD, 26)
    time_f = font(FONT_EXTRABOLD, 26)
    title_f = font(FONT_BLACK, 28)
    tag_f = font(FONT_EXTRABOLD, 18)
    body_f = font(FONT_MEDIUM, 20)
    left_cx = int((x0 + split) / 2)
    draw_tracked(d, (left_cx, y0 + 48), f"{slot.starts_at:%d.%m}", date_f, ACCENT, tracking=-3, anchor="mt")
    draw_tracked(
        d,
        (left_cx, y0 + 112),
        f"({WEEKDAYS[slot.starts_at.weekday()]})",
        day_f,
        WHITE,
        tracking=0,
        anchor="mt",
    )
    draw_pill_outline(im, time_label(slot), (left_cx, y0 + 200), time_f, WHITE, pad_x=22, pad_y=10, stroke=3)
    rx = split + 24
    rw = x1 - rx - 24
    ty = y0 + 36
    for line in wrap_text(titled(slot), title_f, rw, tracking=-1)[:2]:
        draw_tracked(d, (rx, ty), line, title_f, WHITE, tracking=-1, anchor="lt")
        ty += 34
    for line in wrap_text(slot.super_tag or "ВЫЕЗД", tag_f, rw):
        draw_tracked(d, (rx, ty + 4), line, tag_f, ACCENT, tracking=0, anchor="lt")
        ty += 26
    ty += 8
    body = compress_notes(slot.notes, super_event=True)
    if not body:
        body = ["Выезд."]
    for line in body[:4]:
        for wrapped in wrap_text(line, body_f, rw):
            d.text((rx, ty), wrapped, font=body_f, fill=WHITE)
            ty += 24
            if ty > y1 - 28:
                return


def schedule(slots: list[Slot]) -> Image.Image:
    im = load_bg(BG_SCHED, dark=0.28, blur=12, brightness=1.45)
    d = ImageDraw.Draw(im)
    schedule_header(d)
    regulars = [item for item in slots if not item.is_super]
    supers = [item for item in slots if item.is_super]
    y = 236
    for i, slot in enumerate(regulars):
        y = regular_slot(im, d, y, slot)
        if i < len(regulars) - 1:
            d.line((MARGIN, y + 6, W - MARGIN, y + 6), fill=MUTED, width=1)
            y += 22
        else:
            y += 18
    for slot in supers:
        super_card(im, y, slot)
        y += 410
    d = ImageDraw.Draw(im)
    draw_story_line(d, ACCENT, x0=0, x1=W // 2, start_dot=False, end_dot=True)
    paste_dvor_logo(im, W / 2, 1844, width=268)
    return add_grain(im, 30)


def cover_range(slots: list[Slot]) -> str:
    first = min(item.starts_at for item in slots)
    last = max(item.starts_at for item in slots)
    return f"{first:%d.%m} – {last:%d.%m}"


def write_credits(out_dir: Path, slots: list[Slot]) -> None:
    lines = [
        f"Неделя: {cover_range(slots)}",
        "",
        "Слоты:",
    ]
    for slot in slots:
        kind = "супер" if slot.is_super else "обычный"
        lines.append(
            f"- {date_pill(slot)} {time_label(slot)} [{kind}] "
            f"{titled(slot)} / {poster_location(slot.location)}"
        )
    lines += [
        "",
        "Фоны — Unsplash License:",
        "01-cover.png — Moises Alex (@arnok), грунт/корт",
        "https://unsplash.com/photos/WqI-PbYugn4",
        "02-schedule.png — Bogdan Yukhymchuk (@yuhy), боксёрские перчатки",
        "https://unsplash.com/photos/XmvuWRDimrg",
        "",
        "Логотип DVOR — scripts/assets/week_stories/logo-dvor.png",
        "Акцент: #ADB838",
    ]
    (out_dir / "CREDITS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate DVOR week stories from Google Sheets.")
    parser.add_argument("--now", help="Override now, e.g. 2026-09-08T13:48")
    args = parser.parse_args()
    now = (
        datetime.fromisoformat(args.now).replace(tzinfo=MOSCOW)
        if args.now
        else datetime.now(MOSCOW)
    )
    for required in (FONT_BLACK, FONT_EXTRABOLD, FONT_MEDIUM, LOGO_MARK, BG_COVER, BG_SCHED):
        if not required.exists():
            raise SystemExit(f"Missing asset: {required}")

    slots = load_week_slots(now)
    if not slots:
        raise SystemExit("No remaining slots for the current week.")

    out_dir = ROOT / "output" / f"stories-{now:%Y-%m-%d}"
    out_dir.mkdir(parents=True, exist_ok=True)
    frames = [("01-cover.png", cover(cover_range(slots))), ("02-schedule.png", schedule(slots))]
    for name, im in frames:
        path = out_dir / name
        im.convert("RGB").save(path, "PNG", optimize=True)
        print("wrote", path)
    write_credits(out_dir, slots)
    print("wrote", out_dir / "CREDITS.txt")


if __name__ == "__main__":
    main()
