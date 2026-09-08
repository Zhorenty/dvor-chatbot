#!/usr/bin/env python3
"""Compose DVOR week stories 1080×1920 from the live Google Sheets schedule."""

from __future__ import annotations

import argparse
import csv
import io
import json
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
CACHE = ASSETS / "cache"
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
CONTENT_TOP = 208
CONTENT_BOTTOM = 1748
SUPER_GAP = 44
SUPER_PAD = 44

FONT_BLACK = ASSETS / "Montserrat-Black.ttf"
FONT_EXTRABOLD = ASSETS / "Montserrat-ExtraBold.ttf"
FONT_MEDIUM = ASSETS / "Montserrat-Medium.ttf"
LOGO_MARK = ASSETS / "logo-dvor.png"
USED_PHOTOS = ASSETS / "last_photos.json"

PHOTO_POOL = (
    {"id": "1549719386-74dfcbf7dbed", "credit": "Bogdan Yukhymchuk", "url": "https://unsplash.com/photos/XmvuWRDimrg", "what": "боксёрские перчатки"},
    {"id": "1554068865-24cecd4e34b8", "credit": "Moises Alex", "url": "https://unsplash.com/photos/WqI-PbYugn4", "what": "грунтовый корт"},
    {"id": "1551632811-561732d1e306", "credit": "Toomas Tartes", "url": "https://unsplash.com/photos/Yizrl9N_eDA", "what": "тропа к горе"},
    {"id": "1552674605-db6ffd4facb5", "credit": "Fitsum Admasu", "url": "https://unsplash.com/photos/oGv9xIl7DkY", "what": "бег, силуэты"},
    {"id": "1534438327276-14e5300c3a48", "credit": "Unsplash", "url": "https://unsplash.com/photos/Hn3S88e9NII", "what": "зал"},
    {"id": "1517836357463-d25dfeac3438", "credit": "Unsplash", "url": "https://unsplash.com/photos/gJtDg6WfMlQ", "what": "силовая"},
    {"id": "1571019614242-c5c5dee9f50b", "credit": "Unsplash", "url": "https://unsplash.com/photos/p7o8eLQ14aI", "what": "тренировка"},
    {"id": "1526506118085-60ce8714f8c5", "credit": "Unsplash", "url": "https://unsplash.com/photos/WNoLnJo7tS8", "what": "зал, движение"},
    {"id": "1464822759023-fed622ff2c3b", "credit": "Unsplash", "url": "https://unsplash.com/photos/8bI5fVVtdp8", "what": "горы"},
    {"id": "1518611012118-696072aa579a", "credit": "Unsplash", "url": "https://unsplash.com/photos/NTyBbu66_SI", "what": "растяжка / зал"},
    {"id": "1517963879433-6ad2b056d712", "credit": "Unsplash", "url": "https://unsplash.com/photos/oX6d8wONM6Q", "what": "ринг"},
    {"id": "1502905340366-9d32df4b7a0e", "credit": "Unsplash", "url": "https://unsplash.com/photos/NTyBbu66_SI", "what": "бег по дороге"},
    {"id": "1483721310020-03333eadbdcc", "credit": "Unsplash", "url": "https://unsplash.com/photos/C1t1jbpHdeI", "what": "вершина, снег"},
    {"id": "1506905925346-21bda4d32df4", "credit": "Unsplash", "url": "https://unsplash.com/photos/y2azHvupCVo", "what": "горный хребет"},
    {"id": "1513593771513-7b58bdc7b6fd", "credit": "Unsplash", "url": "https://unsplash.com/photos/nCJ_XdqQhIg", "what": "бег в городе"},
    {"id": "1536924430088-8bc494f2960a", "credit": "Unsplash", "url": "https://unsplash.com/photos/WNoLnJo7tS8", "what": "бокс"},
    {"id": "1541534747586-6b2c80d8a4c0", "credit": "Unsplash", "url": "https://unsplash.com/photos/oX6d8wONM6Q", "what": "зал, гири"},
    {"id": "1571902943202-507ec2616e34", "credit": "Unsplash", "url": "https://unsplash.com/photos/sHfo3WOgGTU", "what": "турники"},
    {"id": "1434596823516-bd3824007d55", "credit": "Unsplash", "url": "https://unsplash.com/photos/TFyi0QOx08c", "what": "тропа в лесу"},
    {"id": "1474412060476-77db9c3c3a84", "credit": "Unsplash", "url": "https://unsplash.com/photos/1Z2niiBPg5A", "what": "горы в облаках"},
    {"id": "1522163182402-834f871ac7ae", "credit": "Unsplash", "url": "https://unsplash.com/photos/2Ts5HnA67k8", "what": "скалы"},
    {"id": "1517838277536-f5f99be501cd", "credit": "Unsplash", "url": "https://unsplash.com/photos/p7o8eLQ14aI", "what": "штанга"},
    {"id": "1599058917212-d750089bc04e", "credit": "Unsplash", "url": "https://unsplash.com/photos/sHfo3WOgGTU", "what": "боксёрский зал"},
    {"id": "1571008887538-b36bb32f4571", "credit": "Unsplash", "url": "https://unsplash.com/photos/nCJ_XdqQhIg", "what": "бег, асфальт"},
    {"id": "1476480862126-861e0f54db91", "credit": "Unsplash", "url": "https://unsplash.com/photos/nCJ_XdqQhIg", "what": "кроссовки, бег"},
    {"id": "1549060279-7e168fcee0c2", "credit": "Unsplash", "url": "https://unsplash.com/photos/qC0oLKqPPdw", "what": "бег"},
)

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


@dataclass
class Background:
    path: Path
    credit: str
    url: str
    what: str


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


def fit_wrapped(text: str, fnt: ImageFont.FreeTypeFont, max_width: int, max_lines: int) -> list[str]:
    text = clean_spaces(text).rstrip(" .")
    if not text:
        return []
    sentences = [clean_spaces(part) for part in re.split(r"(?<=[.!?])\s+", text) if clean_spaces(part)]
    if not sentences:
        sentences = [text]

    def lines_of(parts: list[str]) -> list[str]:
        candidate = " ".join(parts)
        if candidate and candidate[-1] not in ".!?":
            candidate = f"{candidate}."
        return wrap_text(candidate, fnt, max_width)

    while sentences:
        lines = lines_of(sentences)
        if len(lines) <= max_lines:
            return lines
        if len(sentences) > 1:
            sentences = sentences[:-1]
            continue
        words = sentences[0].rstrip(".!?").split()
        while len(words) > 2:
            words = words[:-1]
            if words[-1].casefold() in {"в", "и", "на", "с", "по", "от", "для", "а"}:
                continue
            lines = lines_of([" ".join(words)])
            if len(lines) <= max_lines:
                return lines
        break
    return wrap_text(text, fnt, max_width)[:max_lines]


def compact_from_chunks(chunks: list[str], max_chars: int) -> str:
    picked: list[str] = []
    for chunk in chunks:
        trial = ". ".join(picked + [chunk])
        if picked and len(trial) > max_chars:
            break
        picked.append(chunk)
        if len(". ".join(picked)) >= max_chars * 0.55:
            break
    text = ". ".join(picked)
    return text if text.endswith(".") else f"{text}."


def accumulate_training(notes: str | None) -> str:
    chunks = note_chunks(notes)
    if not chunks:
        return ""
    blob = " ".join(chunks).casefold()
    if "кроссфит" in blob or ("гимнастик" in blob and "кардио" in blob):
        return (
            "Функциональный кроссфит: тяжёлая атлетика, гимнастика и кардио. "
            "Сила и координация. Нагрузка под любой уровень."
        )
    if "удар" in blob and "защит" in blob:
        return (
            "Комплексная нагрузка: техника ударов, защита, работа ног, ОФП и спарринг-имитация. "
            "Реакция, взрывная сила и выносливость."
        )
    if "темп" in blob and ("дыш" in blob or "бег" in blob):
        return (
            "Субботний бег: держим темп и дыхание, не сбиваемся. "
            "После — фильтр от Surf Coffee на веранде."
        )
    return compact_from_chunks(chunks, 150)


def accumulate_super(notes: str | None, title: str) -> str:
    raw = strip_emoji(notes or "")
    blob = raw.casefold()
    if not raw:
        return clean_spaces(strip_emoji(title))
    height = re.search(r"(\d{3,4}\s*м)", raw, flags=re.IGNORECASE)
    name = re.sub(r"^восхождение на\s+", "", clean_spaces(strip_emoji(title)), flags=re.IGNORECASE)
    head = name
    if height:
        head = f"{name} ({height.group(1)})"
    if "outdvor" in blob:
        head = f"{head} с Outdvor"
    parts = [head]
    place: list[str] = []
    if "хребет" in blob:
        place.append("Кавказский хребет")
    if "фишт" in blob:
        place.append("ледники Фишта")
    if place:
        parts.append("Панорама: " + ", ".join(place))
    if "щел" in blob:
        parts.append("Путь через Инструкторскую щель — ущелье с буками и родниками")
    if "не для первого" in blob or "базовая выносливость" in blob:
        parts.append("Не для первого похода: нужна выносливость")
    if "первого восхождения" in blob or "для первого восхождения" in blob:
        parts.append("Первое восхождение — без альпинизма")
    text = ". ".join(parts)
    return text if text.endswith(".") else f"{text}."


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


def note_chunks(notes: str | None) -> list[str]:
    if not notes:
        return []
    text = strip_emoji(notes)
    text = text.replace("не просто так, а ", "")
    text = re.sub(r"Ставь кроссовки и беги с нами!\s*", "", text)
    text = re.sub(r"ЧТО ВХОДИТ[\s\S]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"ВАЖНО:[\s\S]*", "", text)
    text = re.sub(r"ЧТО БРАТЬ[\s\S]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"Тренер:[\s\S]*", "", text)
    skip_prefixes = (
        "приглашаем",
        "ставь",
        "не бойся",
        "виды, ради",
        "старт:",
        "финиш:",
        "календар",
    )
    chunks: list[str] = []
    for part in re.split(r"[\n.!?]+", text):
        chunk = clean_spaces(part)
        if not chunk:
            continue
        lowered = chunk.casefold()
        if any(lowered.startswith(prefix) for prefix in skip_prefixes):
            continue
        if re.fullmatch(r"\d{1,2}\s+[а-яё]+|\d{1,2}\.\d{2}(\.\d{4})?", lowered):
            continue
        if "руб" in lowered or "₽" in chunk:
            continue
        chunks.append(chunk)
    return chunks


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


def short_day_month(value: datetime) -> str:
    return f"{value.day}.{value:%m}"


def week_range_label(now: datetime) -> str:
    monday, sunday_end = week_bounds(now)
    sunday = sunday_end - timedelta(seconds=1)
    return f"{short_day_month(monday)} – {short_day_month(sunday)}"


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


def load_used_photo_ids() -> list[str]:
    if not USED_PHOTOS.exists():
        return []
    try:
        data = json.loads(USED_PHOTOS.read_text(encoding="utf-8"))
        return list(data) if isinstance(data, list) else []
    except json.JSONDecodeError:
        return []


def save_used_photo_ids(ids: list[str]) -> None:
    USED_PHOTOS.write_text(json.dumps(ids[-8:], ensure_ascii=False, indent=2), encoding="utf-8")


def download_photo(photo: dict[str, str], dest: Path) -> None:
    url = f"https://images.unsplash.com/photo-{photo['id']}?auto=format&fit=crop&w=1400&h=2500&q=80"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as response:
        dest.write_bytes(response.read())


def pick_backgrounds() -> tuple[Background, Background]:
    CACHE.mkdir(parents=True, exist_ok=True)
    used = load_used_photo_ids()
    order = [item for item in PHOTO_POOL if item["id"] not in used]
    random.shuffle(order)
    fallback = list(PHOTO_POOL)
    random.shuffle(fallback)
    candidates = order + [item for item in fallback if item not in order]
    backgrounds: list[Background] = []
    chosen_ids: list[str] = []
    for photo in candidates:
        if photo["id"] in chosen_ids:
            continue
        path = CACHE / f"{len(backgrounds)}-{photo['id']}-{random.randint(1000, 9999)}.jpg"
        try:
            download_photo(photo, path)
        except Exception:
            continue
        backgrounds.append(
            Background(path=path, credit=photo["credit"], url=photo["url"], what=photo["what"])
        )
        chosen_ids.append(photo["id"])
        if len(backgrounds) == 2:
            break
    if len(backgrounds) < 2:
        raise SystemExit("Could not download two fresh background photos.")
    save_used_photo_ids(used + chosen_ids)
    return backgrounds[0], backgrounds[1]


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
    rng = random.Random()
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


def cover(range_label: str, background: Background) -> Image.Image:
    im = load_bg(background.path, dark=0.30, blur=16, brightness=1.05)
    d = ImageDraw.Draw(im)
    pill_f = font(FONT_EXTRABOLD, 34)
    draw_pill_outline(im, range_label, (W // 2, 210), pill_f, ACCENT, tracking=-1, pad_x=34, pad_y=14, stroke=3)
    title_f = font(FONT_BLACK, 186)
    draw_tracked(d, (W / 2, 560), "НЕДЕЛЯ", title_f, WHITE, tracking=-10, anchor="mt")
    draw_tracked(d, (W / 2, 770), "ДВОРА", title_f, WHITE, tracking=-10, anchor="mt")
    draw_story_line(d, ACCENT, x0=MARGIN, x1=W, start_dot=True, end_dot=False)
    paste_dvor_logo(im, W / 2, 1844, width=268)
    return add_grain(im, 34)


def schedule_header(d: ImageDraw.ImageDraw) -> None:
    f = font(FONT_BLACK, 54)
    draw_tracked(d, (W / 2, 88), "РАСПИСАНИЕ", f, WHITE, tracking=-3, anchor="mt")
    draw_tracked(d, (W / 2, 152), "НА НЕДЕЛЮ", f, WHITE, tracking=-3, anchor="mt")


def regular_block_h(slot: Slot) -> int:
    title_f = font(FONT_BLACK, 28)
    notes_f = font(FONT_MEDIUM, 22)
    block_w = W - MARGIN - 430
    title_lines = wrap_text(titled(slot), title_f, block_w, tracking=-1)[:2]
    note_lines = fit_wrapped(accumulate_training(slot.notes), notes_f, block_w, 3)
    return 16 + 34 * len(title_lines) + 36 + 28 * max(len(note_lines), 1) + 22


def regular_slot(im: Image.Image, d: ImageDraw.ImageDraw, y0: int, y1: int, slot: Slot, draw_rule: bool) -> None:
    date_f = font(FONT_EXTRABOLD, 24)
    time_f = font(FONT_BLACK, 30)
    title_f = font(FONT_BLACK, 28)
    loc_f = font(FONT_EXTRABOLD, 22)
    notes_f = font(FONT_MEDIUM, 22)
    block_x = 430
    block_w = W - MARGIN - block_x
    title_lines = wrap_text(titled(slot), title_f, block_w, tracking=-1)[:2]
    note_lines = fit_wrapped(accumulate_training(slot.notes), notes_f, block_w, 3)
    y = y0 + 16
    pill = draw_left_pill(im, date_pill(slot), MARGIN, y + 22, date_f, ACCENT)
    d.text((pill[2] + 16, y + 6), time_label(slot), font=time_f, fill=WHITE)
    ty = y
    for line in title_lines:
        draw_tracked(d, (block_x, ty), line, title_f, WHITE, tracking=-1, anchor="lt")
        ty += 34
    draw_tracked(d, (block_x, ty + 4), poster_location(slot.location), loc_f, ACCENT, tracking=-1, anchor="lt")
    ty += 36
    for line in note_lines:
        d.text((block_x, ty), line, font=notes_f, fill=WHITE)
        ty += 28
    if draw_rule:
        d.line((MARGIN, y1 - 2, W - MARGIN, y1 - 2), fill=MUTED, width=1)


def super_block_h(slot: Slot) -> int:
    title_f = font(FONT_BLACK, 30)
    tag_f = font(FONT_EXTRABOLD, 20)
    body_f = font(FONT_MEDIUM, 24)
    rw = W - MARGIN + 8 - 360 - 24 - 24
    title_lines = wrap_text(titled(slot), title_f, rw, tracking=-1)[:2]
    tag_lines = wrap_text(slot.super_tag or "ВЫЕЗД", tag_f, rw)
    note_lines = wrap_text(accumulate_super(slot.notes, slot.title), body_f, rw)
    right = SUPER_PAD + 36 * len(title_lines) + 28 * len(tag_lines) + 18 + 32 * len(note_lines) + SUPER_PAD
    left = SUPER_PAD + 220 + SUPER_PAD
    return max(right, left, 360)


def super_card(im: Image.Image, y0: int, y1: int, slot: Slot) -> None:
    d = ImageDraw.Draw(im)
    x0, x1 = MARGIN - 8, W - MARGIN + 8
    card = Image.new("RGBA", im.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((x0, y0, x1, y1), radius=24, fill=(8, 6, 4, 168), outline=ACCENT, width=3)
    im.alpha_composite(card)
    d = ImageDraw.Draw(im)
    split = 360
    d.line((split, y0 + SUPER_PAD, split, y1 - SUPER_PAD), fill=(255, 255, 255, 160), width=2)
    date_f = font(FONT_BLACK, 56)
    day_f = font(FONT_EXTRABOLD, 28)
    time_f = font(FONT_EXTRABOLD, 28)
    title_f = font(FONT_BLACK, 30)
    tag_f = font(FONT_EXTRABOLD, 20)
    body_f = font(FONT_MEDIUM, 24)
    left_cx = int((x0 + split) / 2)
    left_y = y0 + SUPER_PAD
    draw_tracked(d, (left_cx, left_y), f"{slot.starts_at:%d.%m}", date_f, ACCENT, tracking=-3, anchor="mt")
    draw_tracked(
        d,
        (left_cx, left_y + 72),
        f"({WEEKDAYS[slot.starts_at.weekday()]})",
        day_f,
        WHITE,
        tracking=0,
        anchor="mt",
    )
    draw_pill_outline(im, time_label(slot), (left_cx, left_y + 168), time_f, WHITE, pad_x=22, pad_y=10, stroke=3)
    rx = split + 24
    rw = x1 - rx - 24
    title_lines = wrap_text(titled(slot), title_f, rw, tracking=-1)[:2]
    tag_lines = wrap_text(slot.super_tag or "ВЫЕЗД", tag_f, rw)
    note_lines = wrap_text(accumulate_super(slot.notes, slot.title), body_f, rw)
    ty = y0 + SUPER_PAD
    for line in title_lines:
        draw_tracked(d, (rx, ty), line, title_f, WHITE, tracking=-1, anchor="lt")
        ty += 36
    for line in tag_lines:
        draw_tracked(d, (rx, ty + 4), line, tag_f, ACCENT, tracking=0, anchor="lt")
        ty += 28
    ty += 18
    for line in note_lines:
        d.text((rx, ty), line, font=body_f, fill=WHITE)
        ty += 32


def schedule(slots: list[Slot], background: Background) -> Image.Image:
    im = load_bg(background.path, dark=0.28, blur=12, brightness=1.25)
    d = ImageDraw.Draw(im)
    schedule_header(d)
    regulars = [item for item in slots if not item.is_super]
    supers = [item for item in slots if item.is_super]
    y = CONTENT_TOP
    for i, slot in enumerate(regulars):
        y1 = y + regular_block_h(slot)
        regular_slot(im, d, y, y1, slot, draw_rule=i < len(regulars) - 1)
        y = y1
    if supers:
        y += SUPER_GAP
        for i, slot in enumerate(supers):
            y1 = min(y + super_block_h(slot), CONTENT_BOTTOM)
            super_card(im, y, y1, slot)
            y = y1 + SUPER_GAP
    d = ImageDraw.Draw(im)
    draw_story_line(d, ACCENT, x0=0, x1=W // 2, start_dot=False, end_dot=True)
    paste_dvor_logo(im, W / 2, 1844, width=268)
    return add_grain(im, 30)


def write_credits(
    out_dir: Path,
    slots: list[Slot],
    week_label: str,
    cover_bg: Background,
    schedule_bg: Background,
) -> None:
    lines = [
        f"Неделя: {week_label}",
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
        "Фоны — Unsplash License, новые на каждую генерацию:",
        f"01-cover.png — {cover_bg.credit}, {cover_bg.what}",
        cover_bg.url,
        f"02-schedule.png — {schedule_bg.credit}, {schedule_bg.what}",
        schedule_bg.url,
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
    for required in (FONT_BLACK, FONT_EXTRABOLD, FONT_MEDIUM, LOGO_MARK):
        if not required.exists():
            raise SystemExit(f"Missing asset: {required}")

    slots = load_week_slots(now)
    if not slots:
        raise SystemExit("No remaining slots for the current week.")

    cover_bg, schedule_bg = pick_backgrounds()
    week_label = week_range_label(now)
    out_dir = ROOT / "output" / f"stories-{now:%Y-%m-%d}"
    out_dir.mkdir(parents=True, exist_ok=True)
    frames = [
        ("01-cover.png", cover(week_label, cover_bg)),
        ("02-schedule.png", schedule(slots, schedule_bg)),
    ]
    for name, im in frames:
        path = out_dir / name
        im.convert("RGB").save(path, "PNG", optimize=True)
        print("wrote", path)
    write_credits(out_dir, slots, week_label, cover_bg, schedule_bg)
    print("wrote", out_dir / "CREDITS.txt")


if __name__ == "__main__":
    main()
