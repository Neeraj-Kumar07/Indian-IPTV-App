"""
sync2.py  -  runs AFTER sync.py.

Updates ONLY the channels you list in FORCE_CHANNELS. For each listed channel that
exists in my playlist AND in the source playlist, the link details (URL, headers,
cookie, license key, ...) are replaced with the source's, on every run.
There is NO health check. Channels that are not in the list are never touched,
and if the list is empty nothing happens.

How a listed channel is found in my file, and then in the source:
  1. my tvg-name        = source tvg-name
  2. my channel name    = source channel name        (what sync.py does)
  3. my channel name    = source tvg-name            (source's visible name is broken,
                                                      e.g. "w_450 | Gmax")
  4. my tvg-name        = source channel name
The text is lower-cased, the "| Gmax" part and any "(...)" part are dropped, and
everything except letters and digits (spaces too) is removed.
"""
import re
import urllib.request

from sync import attr, display_name, norm_name, parse, url_of, app_can_play, MINE, UA

# ------------------------------------------------------------
# SETTINGS
# ------------------------------------------------------------
FORCE_SOURCE = ["https://raw.githubusercontent.com/sportlive18/sportlink-update/refs/heads/main/tstar.m3u",
"https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/digital.m3u", ]       # <- put your ONE source playlist raw URL here

# Channels to update. Write each name the way it appears in your playlist
# ("| Gmax", spaces and capitals don't matter). Example:
#   FORCE_CHANNELS = ["Star Sports 1 HD", "Aaj Tak"]
FORCE_CHANNELS = [
    # Sports
    "STAR SPORTS 2 Hindi HD", "STAR SPORTS 2 Hindi", "TATA IPL LIVE TV", "STAR SPORTS 1 SELECT HD",
    "STAR SPORTS 2 HD", "STAR SPORTS 1 HD", "STAR SPORTS 1 Hindi HD", "STAR SPORTS 2 SELECT HD",
    "Star Sports Khel Digital", "Star Sports 1 Digital", "Star Sports 2 Digital", "Star Sports 2 Hindi Digital",
    "Star Sports 1 Hindi Digital", "Star Sports 3 Digital", "Star Sports Select 1 Digital", "Star Sports Select 2 Digital",
    "ESPN 1 AFRICA LIVE", "Star Sports Select HD2", "Star Sports Hindi 1", "Star Sports 2",
    "Star Sports Select HD1", "Star Sports 1",

    # Entertainment
    "Savdhaan India: Crime 24/7", "Colors HD", "Colors Rishtey", "Colors Infinity HD",
    "StarPlus", "Star Utsav", "Star Bharat", "Star Bharat HD",
    "Star Plus HD", "Star Plus Digital", "Colors Digital", "Star Utsav Digital",
    "Colors Rishtey Digital", "Star Bharat Digital", "Star Kiran Digital", "Bigboss 24/7 live-HINDI",

    # Movies
    "Colors Cineplex Superhits", "Colors Cineplex Bollywood", "Colors Cineplex HD", "Star Gold",
    "Star Gold HD", "Star Gold Digital", "Colors Cineplex Digital",
]

ONLY_CLEARKEY = True     # skip source links the app cannot play (Widevine/PlayReady)
REPLACE_EXTINF = False   # False: keep my #EXTINF line (name, logo, group) and replace only
                         #        the link lines below it.
                         # True : also copy the source's #EXTINF line.


# ------------------------------------------------------------
def norm_text(s):
    """Same normalisation as norm_name() in sync.py, but for a plain string."""
    s = s.lower()
    s = re.sub(r"\|.*$", "", s)        # drop "| Gmax"
    s = re.sub(r"\(.*?\)", "", s)      # drop "(1080p)"
    return re.sub(r"[^a-z0-9]+", "", s)


def tvg_key(extinf):
    t = attr(extinf, "tvg-name")
    return norm_text(t) if t else ""


def build_source_index(text):
    by_tvg, by_name = {}, {}
    _, blocks = parse(text)
    for extinf, body in blocks:
        if not url_of(body):
            continue
        if ONLY_CLEARKEY and not app_can_play(body):
            continue
        for index, key in ((by_tvg, tvg_key(extinf)), (by_name, norm_name(extinf))):
            if not key:
                continue
            lst = index.setdefault(key, [])
            if all(b != body for _, b in lst):
                lst.append((extinf, body))
    return by_tvg, by_name


def find_candidates(extinf, by_tvg, by_name):
    """Try the matches in order and stop at the first hit. Returns (how, candidates)."""
    mine_tvg, mine_name = tvg_key(extinf), norm_name(extinf)
    tries = (
        ("tvg-name", mine_tvg, by_tvg),
        ("name", mine_name, by_name),
        ("name vs source tvg-name", mine_name, by_tvg),
        ("tvg-name vs source name", mine_tvg, by_name),
    )
    for how, key, index in tries:
        if key and key in index:
            return how, index[key]
    return None, []


def force_update(mine_text, source_text, channels):
    wanted = {}
    for n in channels:
        k = norm_text(n)
        if k:
            wanted[k] = n
    if not wanted:
        return None, dict(updated=0, unchanged=0, no_match=0, no_spare=0)

    by_tvg, by_name = build_source_index(source_text)
    head, mine = parse(mine_text)

    used = {}            # id(candidate list) -> how many of my copies already got a link from it
    in_mine, in_source = set(), set()
    updated, unchanged, no_match, no_spare, dirty = 0, 0, 0, 0, False

    for block in mine:
        extinf, body = block
        hit = {tvg_key(extinf), norm_name(extinf)} & set(wanted)
        if not hit:
            continue                      # not in my list -> never touched
        in_mine |= hit

        name = display_name(extinf)
        group, cands = find_candidates(extinf, by_tvg, by_name)
        if not cands:
            no_match += 1
            print("not found in source, left as is: %s" % name)
            continue
        in_source |= hit

        i = used.get(id(cands), 0)
        used[id(cands)] = i + 1
        if i >= len(cands):
            # more copies of this channel in my file than links in the source;
            # leave the extra copies alone so backups stay distinct
            no_spare += 1
            print("no spare source link for copy #%d, left as is: %s" % (i + 1, name))
            continue

        new_extinf, new_body = cands[i]
        if new_body == body and (not REPLACE_EXTINF or new_extinf == extinf):
            unchanged += 1
            continue
        block[1] = list(new_body)
        if REPLACE_EXTINF:
            block[0] = new_extinf
        updated += 1
        dirty = True
        print("updated [%s] (copy #%d): %s" % (group, i + 1, name))

    for k, n in wanted.items():
        if k not in in_mine:
            print("listed but not in my playlist: %s" % n)

    out = None
    if dirty:
        out = "\n".join(head + [x for e, b in mine for x in [e] + b]) + "\n"
    return out, dict(updated=updated, unchanged=unchanged, no_match=no_match, no_spare=no_spare)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")


def main():
    if not FORCE_CHANNELS:
        print("sync2: FORCE_CHANNELS is empty, nothing to do.")
        return
    if not FORCE_SOURCE:
        print("sync2: FORCE_SOURCE is empty, nothing to do.")
        return
    try:
        source_text = fetch(FORCE_SOURCE)
    except Exception as e:
        # exit 0 on purpose: sync.py's changes must still be committed
        print("sync2: could not load source (%s). Playlist left unchanged." % e)
        return

    with open(MINE, encoding="utf-8") as f:
        mine_text = f.read()

    out, st = force_update(mine_text, source_text, FORCE_CHANNELS)
    if out is not None:
        with open(MINE, "w", encoding="utf-8") as f:
            f.write(out)
    print("sync2: updated %(updated)d, already identical %(unchanged)d, "
          "not in source %(no_match)d, no spare link %(no_spare)d" % st)


if __name__ == "__main__":
    main()






