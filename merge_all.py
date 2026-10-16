"""
Merges all source playlists into data/TestTypes.m3u.

Every channel block (#EXTINF + its DRM/header lines + URL) is copied EXACTLY as it
is in the source, so sync.py sees the same data it would see from the original links.

Duplicate rule:
  - same channel name AND same link details (URL, headers, keys, token) -> duplicate,
    only one copy is kept (even if logo / group-title / tvg-name differ).
  - same channel name but ANY difference in the link details -> kept as a separate entry.
"""
import os
import re
import sys
import time
import urllib.request

SOURCES = [
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S12.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S13.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S10.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/digital.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S1.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S11.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S2.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S3.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S4.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S5.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S6.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S7.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S8.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S9.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S3.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S2.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S1.m3u",
    "https://raw.githubusercontent.com/amazeyourself/m3u/refs/heads/main/jtv.m3u",
]
# NOTE: your own data/Entertainments.m3u is intentionally NOT in this list.

OUTPUT = "data/TestTypes.m3u"
UA = "Mozilla/5.0"
MIN_KEEP_RATIO = 0.5   # if the new file has fewer than 50% of the old entries, don't overwrite


def fetch(url, tries=3):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")
        except Exception as e:
            last = e
            time.sleep(2 * (i + 1))
    raise last


def blocks_of(text):
    """Yield each channel as a tuple of lines, unchanged."""
    cur = None
    for line in text.splitlines():
        if line.startswith("#EXTINF"):
            if cur:
                yield tuple(cur)
            cur = [line]
        elif cur is not None and line.strip():
            cur.append(line)
    if cur:
        yield tuple(cur)


def display_name(extinf):
    q = extinf.rfind('"')
    i = extinf.find(",", q if q != -1 else 0)
    return extinf[i + 1:].strip() if i != -1 else ""


def norm_name(extinf):
    t = display_name(extinf).lower()
    t = re.sub(r"\|.*$", "", t)        # drop "| GmaxHub" style suffix
    t = re.sub(r"\(.*?\)", "", t)      # drop "(1080p)" style suffix
    return re.sub(r"[^a-z0-9]+", "", t)  # "hd" stays, so HD and non-HD are different


def dup_key(block):
    """Same channel name + same link details (all lines after #EXTINF) = duplicate."""
    return norm_name(block[0]), tuple(l.strip() for l in block[1:])


def has_tvg_id(block):
    m = re.search(r'tvg-id="([^"]*)"', block[0])
    return bool(m and m.group(1).strip())


def count_entries(path):
    try:
        with open(path, encoding="utf-8") as f:
            return sum(1 for l in f if l.startswith("#EXTINF"))
    except OSError:
        return 0


def main():
    seen, merged = {}, []       # dup_key -> index in merged
    loaded = 0
    for url in SOURCES:
        try:
            text = fetch(url)
        except Exception as e:
            print("[SOURCE ERROR]", url, e)
            continue
        n = 0
        for b in blocks_of(text):
            k = dup_key(b)
            if k not in seen:
                seen[k] = len(merged)
                merged.append(b)
                n += 1
            elif has_tvg_id(b) and not has_tvg_id(merged[seen[k]]):
                merged[seen[k]] = b     # same channel+link: keep the copy that has a tvg-id
        loaded += 1
        print("[SOURCE OK] %4d new entries | %s" % (n, url.rsplit("/", 1)[-1]))

    if not loaded or not merged:
        sys.exit("no source could be loaded, keeping the old file")

    old = count_entries(OUTPUT)
    if old and len(merged) < old * MIN_KEEP_RATIO:
        sys.exit("new file has %d entries vs %d before (too few), keeping the old file"
                 % (len(merged), old))

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write("#EXTM3U\n")
        for b in merged:
            f.write("\n".join(b) + "\n")
    print("wrote %d entries from %d/%d sources -> %s" % (len(merged), loaded, len(SOURCES), OUTPUT))


if __name__ == "__main__":
    main()