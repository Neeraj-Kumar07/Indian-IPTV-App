"""
Builds data/TestTypes.m3u: a few FRESH entries of every link type found in the
SOURCES playlists, so you can check that the app plays each type.

Needs only SOURCES from your sync.py (everything else is inside this file).

Run from the project root (next to sync.py):
    python make_test_playlist.py                 -> 3 fresh entries per type
    python make_test_playlist.py --per-type 5    -> 5 per type
    python make_test_playlist.py --verify        -> also test candidates with the
                                                    checks of the NEW sync.py
                                                    (needs ffmpeg), verified first

Channel names get a "[type]" prefix so you can see what each one tests.
Entries whose token (exp=) is already expired are never picked.
Widevine entries can't be verified by ffmpeg, so they are always "unverified".
"""
import re
import sys
import time
import urllib.request

try:
    from sync import SOURCES
except Exception as e:                      # pragma: no cover
    sys.exit("could not read SOURCES from sync.py: %s" % e)

OUT = "data/TestTypes.m3u"
UA = "Mozilla/5.0"
EXPIRY_MARGIN = 600
HEX_PAIR = r"[0-9a-fA-F]{32}:[0-9a-fA-F]{32}"

# order = order in the output file
TYPES = [
    "plain-hls",
    "clearkey-hex",
    "clearkey-multi-hex",
    "clearkey-json-keys",
    "clearkey-json-map",
    "clearkey-braces",
    "clearkey-license-url",
    "clearkey-url-extensionless",
    "widevine-license-url",
    "url-tail-headers",
]


# ------------------------------------------------------------
# M3U helpers
# ------------------------------------------------------------

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")


def display_name(extinf):
    q = extinf.rfind('"')
    i = extinf.find(",", q if q != -1 else 0)
    return extinf[i + 1:].strip() if i != -1 else ""


def norm_name(extinf):
    n = display_name(extinf).lower()
    n = re.sub(r"\|.*$", "", n)
    n = re.sub(r"\(.*?\)", "", n)
    return re.sub(r"[^a-z0-9]+", "", n)


def parse(text):
    head, blocks = [], []
    for line in text.splitlines():
        if line.startswith("#EXTINF"):
            blocks.append([line, []])
        elif blocks:
            if line.strip():
                blocks[-1][1].append(line)
        else:
            head.append(line)
    return head, blocks


def url_of(body):
    return next((l for l in reversed(body) if not l.startswith("#")), None)


def key_raw_of(body):
    for l in body:
        if l.lower().startswith("#kodiprop:inputstream.adaptive.license_key="):
            return l.split("=", 1)[1].strip()
    return None


def license_type_of(body):
    for l in body:
        if l.lower().startswith("#kodiprop:inputstream.adaptive.license_type="):
            return l.split("=", 1)[1].strip().lower()
    return ""


def expired(body):
    m = re.search(r"exp=(\d{9,11})", "\n".join(body))
    return bool(m) and int(m.group(1)) < time.time() + EXPIRY_MARGIN


# ------------------------------------------------------------
# Type detection
# ------------------------------------------------------------

def classify(body):
    """-> one of TYPES, or None when the entry is not a useful test case."""
    url = url_of(body)
    if not url:
        return None
    low = url.lower()
    raw = (key_raw_of(body) or "").strip()
    ltype = license_type_of(body)
    has_ext = ".mpd" in low or ".m3u8" in low

    if "widevine" in ltype:
        return "widevine-license-url" if raw.lower().startswith("http") else None

    if raw:
        if raw.lower().startswith("http"):
            return "clearkey-license-url" if has_ext else "clearkey-url-extensionless"
        if raw.startswith("{"):
            if '"keys"' in raw:
                return "clearkey-json-keys"
            return "clearkey-json-map" if '"' in raw else "clearkey-braces"
        if re.fullmatch(HEX_PAIR + "(," + HEX_PAIR + ")+", raw):
            return "clearkey-multi-hex"
        if not re.fullmatch(HEX_PAIR, raw):
            return None            # placeholder such as 0000 or null:null

    if "|" in low:
        return "url-tail-headers"
    if raw:
        return "clearkey-hex"
    if ".m3u8" in low:
        return "plain-hls"
    return None


def relabel(extinf, tag):
    q = extinf.rfind('"')
    i = extinf.find(",", q if q != -1 else 0)
    if i == -1:
        return extinf
    return "%s,[%s] %s" % (extinf[:i], tag, extinf[i + 1:].strip())


def get_checker():
    """The NEW sync.py has prewarm() and health(); the old one doesn't."""
    try:
        import sync
        if hasattr(sync, "prewarm") and hasattr(sync, "health"):
            return sync
    except Exception:
        pass
    return None


# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

def build(texts, per_type=3, checker=None, max_check=25):
    pools = {t: [] for t in TYPES}
    seen = set()
    for text in texts:
        _, blocks = parse(text)
        for extinf, body in blocks:
            kind = classify(body)
            if kind is None or expired(body):
                continue
            key = (kind, norm_name(extinf))
            if key in seen:
                continue
            seen.add(key)
            pools[kind].append((extinf, body))

    chosen, report = [], []
    for kind in TYPES:
        pool = pools[kind]
        picked = pool[:per_type]
        if checker and pool:
            cand = pool[:max_check]
            checker.prewarm([b for _, b in cand])
            good = [c for c in cand if checker.health(c[1]) is True]
            maybe = [c for c in cand if checker.health(c[1]) is None]
            picked = (good + maybe)[:per_type]
            report.append("%-28s found %4d | verified %2d | unverified %2d | written %d"
                          % (kind, len(pool), len(good), len(maybe), len(picked)))
        else:
            report.append("%-28s found %4d | written %d" % (kind, len(pool), len(picked)))
        for extinf, body in picked:
            chosen.append((relabel(extinf, kind), body))
    return chosen, report


def main():
    per_type = 3
    if "--per-type" in sys.argv:
        per_type = int(sys.argv[sys.argv.index("--per-type") + 1])

    checker = None
    if "--verify" in sys.argv:
        checker = get_checker()
        if checker is None:
            print("NOTE: --verify needs the NEW sync.py (with health/prewarm); "
                  "continuing without verification")

    texts = []
    for u in dict.fromkeys(SOURCES):
        try:
            texts.append(fetch(u))
            print("loaded", u.rsplit("/", 1)[-1])
        except Exception as e:
            print("could not load", u, e)
    if not texts:
        sys.exit("no source playlist could be loaded")

    chosen, report = build(texts, per_type, checker)
    print()
    print("\n".join(report))

    lines = ["#EXTM3U"]
    for extinf, body in chosen:
        lines.append(extinf)
        lines.extend(body)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\nwrote %d channels to %s" % (len(chosen), OUT))


if __name__ == "__main__":
    main()