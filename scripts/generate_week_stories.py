#!/usr/bin/env python3
"""Compose DVOR week stories (1080×1920) and feed posts (1080×1350) from Google Sheets."""

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
HEADER_GAP = 52
LINE_GAP = 52
LOGO_Y = 1844
LOGO_W = 268
COVER_PILL_Y = 210
COVER_TITLE_SIZE = 186
COVER_TITLE_Y = (560, 770)
HEADER_SIZE = 54
HEADER_Y = (88, 152)


@dataclass(frozen=True)
class OutputFormat:
    name: str
    folder: str
    w: int
    h: int
    margin: int
    line_y: int
    content_top: int
    content_bottom: int
    super_gap: int
    super_pad: int
    header_gap: int
    line_gap: int
    logo_y: int
    logo_w: int
    cover_pill_y: int
    cover_title_size: int
    cover_title_y: tuple[int, int]
    header_size: int
    header_y: tuple[int, int]


STORY = OutputFormat(
    name="story",
    folder="stories",
    w=1080,
    h=1920,
    margin=92,
    line_y=1768,
    content_top=208,
    content_bottom=1748,
    super_gap=44,
    super_pad=44,
    header_gap=52,
    line_gap=52,
    logo_y=1844,
    logo_w=268,
    cover_pill_y=210,
    cover_title_size=186,
    cover_title_y=(560, 770),
    header_size=54,
    header_y=(88, 152),
)
POST = OutputFormat(
    name="post",
    folder="posts",
    w=1080,
    h=1350,
    margin=72,
    line_y=1238,
    content_top=156,
    content_bottom=1218,
    super_gap=28,
    super_pad=32,
    header_gap=36,
    line_gap=36,
    logo_y=1294,
    logo_w=220,
    cover_pill_y=148,
    cover_title_size=128,
    cover_title_y=(390, 536),
    header_size=42,
    header_y=(52, 104),
)


def apply_format(fmt: OutputFormat) -> None:
    global W, H, MARGIN, LINE_Y, CONTENT_TOP, CONTENT_BOTTOM
    global SUPER_GAP, SUPER_PAD, HEADER_GAP, LINE_GAP, LOGO_Y, LOGO_W
    global COVER_PILL_Y, COVER_TITLE_SIZE, COVER_TITLE_Y, HEADER_SIZE, HEADER_Y
    W = fmt.w
    H = fmt.h
    MARGIN = fmt.margin
    LINE_Y = fmt.line_y
    CONTENT_TOP = fmt.content_top
    CONTENT_BOTTOM = fmt.content_bottom
    SUPER_GAP = fmt.super_gap
    SUPER_PAD = fmt.super_pad
    HEADER_GAP = fmt.header_gap
    LINE_GAP = fmt.line_gap
    LOGO_Y = fmt.logo_y
    LOGO_W = fmt.logo_w
    COVER_PILL_Y = fmt.cover_pill_y
    COVER_TITLE_SIZE = fmt.cover_title_size
    COVER_TITLE_Y = fmt.cover_title_y
    HEADER_SIZE = fmt.header_size
    HEADER_Y = fmt.header_y


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


def paint_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    fnt: ImageFont.FreeTypeFont,
    fill,
    tracking: int = 0,
) -> None:
    x, y = xy
    for i, ch in enumerate(text):
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += fnt.getlength(ch) + (tracking if i < len(text) - 1 else 0)


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
    paint_text(draw, (x, y), text, fnt, fill, tracking=tracking)
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
            if words[-1].casefold() in {
                "в",
                "и",
                "на",
                "с",
                "по",
                "от",
                "для",
                "а",
                "но",
                "не",
                "что",
                "как",
                "или",
                "только",
            }:
                continue
            lines = lines_of([" ".join(words)])
            if len(lines) <= max_lines:
                return lines
        break
    return wrap_text(text, fnt, max_width)[:max_lines]


CLAUSE_SPLIT = re.compile(r"(\s*[—–:;]\s*)")
FILLER_STARTS = (
    "приглашаем",
    "ставь",
    "не бойся",
    "виды, ради",
    "старт:",
    "финиш:",
    "календар",
    "что вас",
    "что тебя",
    "что входит",
    "что брать",
    "важно",
)
HYPE_TAILS = ("всем тем", "не только", "в жизни")
FILLER_CONTAINS = ("приглашает", "ставь кроссовки")
LOGISTICS_HEADS = (
    "трансфер",
    "ужин",
    "прожива",
    "гид",
    "работа гида",
    "кровать",
)


def note_sentences(notes: str | None) -> list[str]:
    if not notes:
        return []
    text = strip_emoji(notes)
    text = re.sub(r"\s*не просто так, а\s*", ", ", text, flags=re.IGNORECASE)
    text = re.sub(r"Ставь кроссовки и беги с нами!\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"ЧТО ВХОДИТ[\s\S]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"ВАЖНО:[\s\S]*", "", text)
    text = re.sub(r"ЧТО БРАТЬ[\s\S]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"Тренер:[\s\S]*", "", text)
    sentences: list[str] = []
    for part in re.split(r"[\n.!?]+", text):
        chunk = drop_scene_leadin(strip_hype_clause(clean_spaces(part)))
        if chunk:
            sentences.append(chunk)
    return sentences


def drop_scene_leadin(text: str) -> str:
    parts = re.split(r"\s+[—–]\s+", text, maxsplit=1)
    if len(parts) != 2:
        return text
    left, right = parts
    blob = left.casefold()
    if any(token in blob for token in ("dvor", "команд", "традицион")) and len(right) >= 24:
        return right[0].upper() + right[1:] if right[0].islower() else right
    return text


def strip_hype_clause(text: str) -> str:
    parts = re.split(r"\s+[—–]\s+", text, maxsplit=1)
    if len(parts) == 2 and any(token in parts[1].casefold() for token in HYPE_TAILS):
        return parts[0]
    return text


def is_filler_sentence(chunk: str, *, title: str | None = None, coach: str | None = None) -> bool:
    lowered = chunk.casefold()
    if any(lowered.startswith(prefix) for prefix in FILLER_STARTS):
        return True
    if any(token in lowered for token in FILLER_CONTAINS):
        return True
    if "руб" in lowered or "₽" in chunk:
        return True
    if re.fullmatch(r"\d{1,2}\s+[а-яё]+|\d{1,2}\.\d{2}(\.\d{4})?", lowered):
        return True
    if re.fullmatch(r"\(?\d+[\s\d]*метр[аов]*\.?\s*\)?", lowered):
        return True
    if coach and coach.casefold() in lowered:
        return True
    if title:
        titled_raw = clean_spaces(strip_emoji(title)).casefold()
        if titled_raw and (lowered == titled_raw or titled_raw in lowered):
            return True
    return False


PLACE_SKIP_FIRST = {
    "с",
    "на",
    "в",
    "к",
    "от",
    "для",
    "это",
    "вас",
    "нам",
    "мы",
    "подойдёт",
    "подойдет",
    "идём",
    "идем",
    "едем",
}


def list_place_name(chunk: str) -> str | None:
    if " — " not in chunk and " – " not in chunk:
        return None
    name = clean_spaces(re.split(r"\s+[—–]\s+", chunk, maxsplit=1)[0])
    lowered = name.casefold()
    if any(token in lowered for token in LOGISTICS_HEADS):
        return None
    words = name.split()
    if not (1 <= len(words) <= 5) or len(name) > 42:
        return None
    first = words[0].casefold()
    if first in PLACE_SKIP_FIRST or first.startswith("подойд"):
        return None
    return name


def shorten_by_comma(text: str, max_chars: int) -> str:
    parts = [part.strip() for part in text.split(",") if part.strip()]
    if not parts:
        return text[:max_chars].rsplit(" ", 1)[0].rstrip(" ,")
    acc = parts[0]
    for part in parts[1:]:
        trial = f"{acc}, {part}"
        if len(trial) > max_chars:
            break
        acc = trial
    if len(acc) > max_chars:
        return acc[:max_chars].rsplit(" ", 1)[0].rstrip(" ,")
    return acc


def shorten_to(text: str, max_chars: int) -> str:
    text = clean_spaces(text).rstrip(" .;:—–-,")
    if len(text) <= max_chars:
        return text
    acc = ""
    for part in CLAUSE_SPLIT.split(text):
        if re.fullmatch(r"\s*[—–:;]\s*", part or ""):
            trial = acc + part
            if len(trial) > max_chars:
                break
            acc = trial
            continue
        trial = acc + part
        if acc and len(trial) > max_chars:
            break
        if not acc and len(part) > max_chars:
            return shorten_by_comma(part, max_chars)
        acc = trial
    acc = acc.rstrip(" .;:—–-,")
    return acc or shorten_by_comma(text, max_chars)


def join_summary(parts: list[str], max_chars: int) -> str:
    picked: list[str] = []
    for part in parts:
        part = clean_spaces(part).rstrip(" .")
        if not part:
            continue
        if not picked and len(part) > max_chars:
            part = shorten_to(part, max_chars)
        trial = ". ".join(picked + [part])
        if picked and len(trial) > max_chars:
            break
        picked.append(part)
    text = ". ".join(picked)
    if not text:
        return ""
    return text if text.endswith(".") else f"{text}."


def accumulate_training(notes: str | None, coach: str | None = None) -> str:
    parts = [item for item in note_sentences(notes) if not is_filler_sentence(item, coach=coach)]
    return join_summary(parts, 175)


SCENIC_TOKENS = ("панорам", "вершин", "озер", "хребет", "восхожд", "скал", "фишт", "оштен")


def accumulate_super(notes: str | None, title: str) -> str:
    if not notes:
        return ""
    hooks: list[str] = []
    places: list[str] = []
    for chunk in note_sentences(notes):
        if is_filler_sentence(chunk, title=title):
            continue
        place = list_place_name(chunk)
        if place:
            if place not in places:
                places.append(place)
            continue
        hooks.append(chunk)
    parts: list[str] = []
    scenic = [item for item in hooks if any(token in item.casefold() for token in SCENIC_TOKENS)]
    lead = scenic[0] if scenic else (hooks[0] if hooks else "")
    if lead:
        parts.append(lead)
    rest = [item for item in hooks if item != lead]
    shorts = [item for item in rest if len(item) <= 48]
    if shorts:
        parts.append(shorts[0])
    if places:
        parts.append(", ".join(places[:3]))
    return join_summary(parts, 180)


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
    if any(token in blob for token in ("восхожд", "вершин", "тхач")):
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


def parse_training_slot(row: dict[str, str]) -> Slot | None:
    title = (row.get("название") or "").strip()
    location = (row.get("место") or "").strip()
    if not title or not location:
        return None
    starts = parse_sheet_datetime(row.get("дата") or "", row.get("время") or "")
    if starts is None:
        return None
    coach = clean_spaces(row.get("тренер") or "") or None
    notes = (row.get("заметки") or "").strip() or None
    return Slot(
        starts_at=starts,
        title=title,
        location=location,
        coach=coach,
        notes=notes,
        is_super=False,
    )


def parse_hike_slot(row: dict[str, str]) -> Slot | None:
    title = (row.get("название") or "").strip()
    location = (row.get("место") or "").strip()
    if not title:
        return None
    starts = parse_sheet_datetime(row.get("дата_с") or "", first_plan_time(row.get("план")) or "00:00")
    if starts is None:
        return None
    description = (row.get("описание") or "").strip() or None
    return Slot(
        starts_at=starts,
        title=title,
        location=location or "АДЫГЕЯ",
        coach=None,
        notes=description,
        is_super=True,
        super_tag=super_tag_from_text(title, description or ""),
    )


def load_week_slots(now: datetime, *, remaining_only: bool = True) -> list[Slot]:
    monday, sunday_end = week_bounds(now)
    slots: list[Slot] = []

    for row in fetch_csv(TRAININGS_CSV):
        slot = parse_training_slot(row)
        if slot is None or not (monday <= slot.starts_at < sunday_end):
            continue
        if remaining_only and slot.starts_at <= now:
            continue
        slots.append(slot)

    hikes = [slot for row in fetch_csv(HIKES_CSV) if (slot := parse_hike_slot(row)) is not None]
    in_week = [
        slot
        for slot in hikes
        if monday <= slot.starts_at < sunday_end and (not remaining_only or slot.starts_at > now)
    ]
    if in_week:
        slots.extend(in_week)
    else:
        upcoming = [slot for slot in hikes if slot.starts_at >= sunday_end]
        upcoming.sort(key=lambda item: item.starts_at)
        if upcoming:
            slots.append(upcoming[0])

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
    paint_text(d, (x0 + pad_x, y0 + pad_y - bbox[1] - 1), text, fnt, WHITE, tracking=tracking)
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
    paint_text(d, (x0 + pad_x, y0 + pad_y - bbox[1] - 1), text, fnt, WHITE, tracking=tracking)
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
    pill_f = font(FONT_EXTRABOLD, 34 if H > 1400 else 28)
    draw_pill_outline(im, range_label, (W // 2, COVER_PILL_Y), pill_f, ACCENT, tracking=-1, pad_x=34, pad_y=14, stroke=3)
    title_f = font(FONT_BLACK, COVER_TITLE_SIZE)
    draw_tracked(d, (W / 2, COVER_TITLE_Y[0]), "НЕДЕЛЯ", title_f, WHITE, tracking=-10, anchor="mt")
    draw_tracked(d, (W / 2, COVER_TITLE_Y[1]), "ДВОРА", title_f, WHITE, tracking=-10, anchor="mt")
    draw_story_line(d, ACCENT, x0=MARGIN, x1=W, start_dot=True, end_dot=False)
    paste_dvor_logo(im, W / 2, LOGO_Y, width=LOGO_W)
    return add_grain(im, 34)


def schedule_header(d: ImageDraw.ImageDraw) -> None:
    f = font(FONT_BLACK, HEADER_SIZE)
    draw_tracked(d, (W / 2, HEADER_Y[0]), "РАСПИСАНИЕ", f, WHITE, tracking=-3, anchor="mt")
    draw_tracked(d, (W / 2, HEADER_Y[1]), "НА НЕДЕЛЮ", f, WHITE, tracking=-3, anchor="mt")


def schedule_column_bounds() -> tuple[int, int]:
    header_f = font(FONT_BLACK, HEADER_SIZE)
    bbox = header_f.getbbox("НА НЕДЕЛЮ")
    header_bottom = HEADER_Y[1] + (bbox[3] - bbox[1])
    return header_bottom + HEADER_GAP, LINE_Y - LINE_GAP


def regular_slot(
    im: Image.Image,
    d: ImageDraw.ImageDraw,
    y0: int,
    y1: int,
    slot: Slot,
    draw_rule: bool,
    compact: bool = False,
) -> None:
    date_f = font(FONT_EXTRABOLD, 20 if compact else 24)
    time_f = font(FONT_BLACK, 24 if compact else 30)
    title_f = font(FONT_BLACK, 22 if compact else 28)
    loc_f = font(FONT_EXTRABOLD, 18 if compact else 22)
    notes_f = font(FONT_MEDIUM, 18 if compact else 22)
    title_lh = 26 if compact else 34
    loc_lh = 28 if compact else 36
    note_lh = 22 if compact else 28
    block_x = 390 if compact else 430
    block_w = W - MARGIN - block_x
    title_lines = wrap_text(titled(slot), title_f, block_w, tracking=-1)[:2]
    avail = max(0, y1 - y0 - (18 if compact else 36))
    min_block = title_lh * len(title_lines) + loc_lh
    max_notes = max(1, min(3 if compact else 4, (avail - min_block) // note_lh))
    note_lines = fit_wrapped(accumulate_training(slot.notes, slot.coach), notes_f, block_w, max_notes)
    stacked = title_lh * len(title_lines) + loc_lh + note_lh * max(len(note_lines), 1)
    extra = max(0, (y1 - y0) - stacked - (24 if compact else 36))
    gaps = 2 + len(title_lines) + max(len(note_lines) - 1, 0)
    bump = extra / max(gaps, 1)
    y = y0 + (8 if compact else 14) + bump * 0.35
    pill = draw_left_pill(im, date_pill(slot), MARGIN, y + (16 if compact else 22), date_f, ACCENT, pad_x=12, pad_y=6)
    paint_text(d, (pill[2] + 12, y + (4 if compact else 6)), time_label(slot), time_f, WHITE)
    ty = y
    for line in title_lines:
        draw_tracked(d, (block_x, ty), line, title_f, WHITE, tracking=-1, anchor="lt")
        ty += title_lh + bump
    draw_tracked(d, (block_x, ty + 2), poster_location(slot.location), loc_f, ACCENT, tracking=-1, anchor="lt")
    ty += loc_lh + bump
    for i, line in enumerate(note_lines):
        paint_text(d, (block_x, ty), line, notes_f, WHITE)
        ty += note_lh + (bump if i < len(note_lines) - 1 else 0)
    if draw_rule:
        d.line((MARGIN, y1 - 2, W - MARGIN, y1 - 2), fill=MUTED, width=1)


def super_block_h(slot: Slot) -> int:
    title_f = font(FONT_BLACK, 30)
    tag_f = font(FONT_EXTRABOLD, 20)
    body_f = font(FONT_MEDIUM, 24)
    rw = W - MARGIN + 8 - 360 - 24 - 24
    title_lines = wrap_text(titled(slot), title_f, rw, tracking=-1)[:2]
    tag_lines = wrap_text(slot.super_tag or "ВЫЕЗД", tag_f, rw)
    note_lines = fit_wrapped(accumulate_super(slot.notes, slot.title), body_f, rw, 4)
    right = SUPER_PAD + 36 * len(title_lines) + 28 * len(tag_lines) + 18 + 32 * len(note_lines) + SUPER_PAD
    left = SUPER_PAD + 220 + SUPER_PAD
    min_h = 360 if H > 1400 else 250
    return max(right, left, min_h)


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
    note_lines = fit_wrapped(accumulate_super(slot.notes, slot.title), body_f, rw, 4)
    ty = y0 + SUPER_PAD
    for line in title_lines:
        draw_tracked(d, (rx, ty), line, title_f, WHITE, tracking=-1, anchor="lt")
        ty += 36
    for line in tag_lines:
        draw_tracked(d, (rx, ty + 4), line, tag_f, ACCENT, tracking=0, anchor="lt")
        ty += 28
    ty += 18
    for line in note_lines:
        paint_text(d, (rx, ty), line, body_f, WHITE)
        ty += 32


def schedule(slots: list[Slot], background: Background) -> Image.Image:
    im = load_bg(background.path, dark=0.28, blur=12, brightness=1.25)
    d = ImageDraw.Draw(im)
    schedule_header(d)
    regulars = [item for item in slots if not item.is_super]
    supers = [item for item in slots if item.is_super]
    super_h = sum(super_block_h(item) for item in supers)
    content_top, content_bottom = schedule_column_bounds()
    if supers:
        super_h += SUPER_GAP * (len(supers) - 1)
        train_bottom = content_bottom - super_h - SUPER_GAP
    else:
        train_bottom = content_bottom
    n_regular = max(len(regulars), 1)
    band = (train_bottom - content_top) / n_regular if regulars else 0
    compact = H <= 1400 and len(regulars) >= 4
    y = float(content_top)
    for i, slot in enumerate(regulars):
        y1 = train_bottom if i == len(regulars) - 1 else int(round(content_top + band * (i + 1)))
        regular_slot(
            im,
            d,
            int(y),
            int(y1),
            slot,
            draw_rule=i < len(regulars) - 1,
            compact=compact,
        )
        y = y1
    if supers:
        y = train_bottom + SUPER_GAP
        for i, slot in enumerate(supers):
            y1 = content_bottom if i == len(supers) - 1 else int(y + super_block_h(slot))
            super_card(im, int(y), int(y1), slot)
            y = y1 + SUPER_GAP
    d = ImageDraw.Draw(im)
    draw_story_line(d, ACCENT, x0=0, x1=W // 2, start_dot=False, end_dot=True)
    paste_dvor_logo(im, W / 2, LOGO_Y, width=LOGO_W)
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
        summary = accumulate_super(slot.notes, slot.title) if slot.is_super else accumulate_training(slot.notes, slot.coach)
        lines.append(
            f"- {date_pill(slot)} {time_label(slot)} [{kind}] "
            f"{titled(slot)} / {poster_location(slot.location)}"
        )
        if summary:
            lines.append(f"  {summary}")
    lines += [
        "",
        "Фоны — Unsplash License, новые на каждую генерацию:",
        "Форматы: stories 1080×1920, posts 1080×1350 (4:5).",
        f"01-cover.png — {cover_bg.credit}, {cover_bg.what}",
        cover_bg.url,
        f"02-schedule.png — {schedule_bg.credit}, {schedule_bg.what}",
        schedule_bg.url,
        "",
        "Логотип DVOR — scripts/assets/week_stories/logo-dvor.png",
        "Акцент: #ADB838",
    ]
    (out_dir / "CREDITS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_week_start(raw: str) -> datetime:
    value = datetime.fromisoformat(raw)
    if value.tzinfo is None:
        value = value.replace(tzinfo=MOSCOW)
    return value.astimezone(MOSCOW).replace(hour=0, minute=0, second=0, microsecond=0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate DVOR week stories and posts from Google Sheets.")
    parser.add_argument("--now", help="Override now, e.g. 2026-09-08T13:48")
    parser.add_argument("--week-start", help="Monday of the target week, e.g. 2026-09-21")
    args = parser.parse_args()
    remaining_only = True
    if args.week_start:
        now = parse_week_start(args.week_start)
        remaining_only = False
    elif args.now:
        now = datetime.fromisoformat(args.now)
        if now.tzinfo is None:
            now = now.replace(tzinfo=MOSCOW)
    else:
        now = datetime.now(MOSCOW)
    for required in (FONT_BLACK, FONT_EXTRABOLD, FONT_MEDIUM, LOGO_MARK):
        if not required.exists():
            raise SystemExit(f"Missing asset: {required}")

    slots = load_week_slots(now, remaining_only=remaining_only)
    if not slots:
        raise SystemExit("No remaining slots for the selected week.")

    cover_bg, schedule_bg = pick_backgrounds()
    week_label = week_range_label(now)
    for fmt in (STORY, POST):
        apply_format(fmt)
        out_dir = ROOT / "output" / f"{fmt.folder}-{now:%Y-%m-%d}"
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
