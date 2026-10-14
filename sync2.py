"""
sync2.py  -  runs AFTER sync.py.

Every channel that exists in BOTH my playlist and the source playlist gets its
link details (URL, headers, cookie, license key, ...) replaced with the source's,
on every run. There is NO health check and NO channel list.

How a channel is matched (same rules on my file and on the source file):
  1. tvg-name first.  tvg-name="Star Plus Digital | Gmax"  ->  "starplusdigital"
  2. if my entry has no tvg-name, or the source has no entry with that tvg-name,
     fall back to the channel name after the last comma, exactly like sync.py.
In both cases the text is lower-cased, the "| Gmax" part and any "(...)" part are
dropped, and everything except letters and digits (spaces too) is removed.
"""
import re
import urllib.request

from sync import attr, display_name, norm_name, parse, url_of, app_can_play, MINE, UA

# ------------------------------------------------------------
# SETTINGS
# ------------------------------------------------------------
FORCE_SOURCE = "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/digital.m3u"        # <- put your ONE source playlist raw URL here

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
    """Try the matches in this order and stop at the first hit:
       1. my tvg-name        = source tvg-name
       2. my channel name    = source channel name        (what sync.py does)
       3. my channel name    = source tvg-name            (my file has no tvg-name, and the
                                                           source's visible name is broken,
                                                           e.g. "w_450 | Gmax")
       4. my tvg-name        = source channel name
    Returns (how, candidates)."""
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


def force_update(mine_text, source_text):
    by_tvg, by_name = build_source_index(source_text)
    head, mine = parse(mine_text)

    used = {}            # id(candidate list) -> how many of my copies already got a link from it
    updated, unchanged, no_match, no_spare, dirty = 0, 0, 0, 0, False

    for block in mine:
        extinf, body = block
        name = display_name(extinf)
        group, cands = find_candidates(extinf, by_tvg, by_name)
        if not cands:
            no_match += 1
            continue

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

    out = None
    if dirty:
        out = "\n".join(head + [x for e, b in mine for x in [e] + b]) + "\n"
    return out, dict(updated=updated, unchanged=unchanged, no_match=no_match, no_spare=no_spare)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")


def main():
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

    out, st = force_update(mine_text, source_text)
    if out is not None:
        with open(MINE, "w", encoding="utf-8") as f:
            f.write(out)
    print("sync2: updated %(updated)d, already identical %(unchanged)d, "
          "not in source %(no_match)d, no spare link %(no_spare)d" % st)


if __name__ == "__main__":
    main()