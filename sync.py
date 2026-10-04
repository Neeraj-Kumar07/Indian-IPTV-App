#
#
#
# # ////////////////////////////////////////////////////////////////////////////////
#
# import re, json, os, urllib.request, urllib.parse
#
# OWNER, REPO = "sportlive18", "jio-tv-auto-update-playlist"
# MINE = "data/Entertainments.m3u"
# UA = {"User-Agent": "Mozilla/5.0"}
#
# def api(path):
#     url = "https://api.github.com/repos/%s/%s" % (OWNER, REPO)
#     if path:
#         url += "/" + path
#     req = urllib.request.Request(url, headers={"User-Agent": "sync", "Accept": "application/vnd.github+json"})
#     tok = os.environ.get("GITHUB_TOKEN")
#     if tok:
#         req.add_header("Authorization", "Bearer " + tok)
#     return json.load(urllib.request.urlopen(req, timeout=30))
#
# def list_m3u_urls():
#     branch = api("")["default_branch"]
#     tree = api("git/trees/%s?recursive=1" % branch)["tree"]
#     return ["https://raw.githubusercontent.com/%s/%s/%s/%s" % (OWNER, REPO, branch, urllib.parse.quote(t["path"]))
#             for t in tree if t["type"] == "blob" and t["path"].lower().endswith(".m3u")]
#
# def tvg(extinf):
#     m = re.search(r'tvg-id="([^"]+)"', extinf)
#     return m.group(1).lower() if m else None
#
# def parse(text):
#     head, blocks = [], []
#     for line in text.splitlines():
#         if line.startswith("#EXTINF"):
#             blocks.append([line, []])
#         elif blocks:
#             if line.strip():
#                 blocks[-1][1].append(line)
#         else:
#             head.append(line)
#     return head, blocks
#
# def url_of(body):
#     return next((l for l in reversed(body) if not l.startswith("#")), None)
#
# def alive(body):
#     url = url_of(body)
#     if not url:
#         return False
#     h = dict(UA)
#     for l in body:
#         low = l.lower()
#         if low.startswith("#extvlcopt:http-user-agent="):
#             h["User-Agent"] = l.split("=", 1)[1]
#         elif low.startswith("#extvlcopt:http-referrer="):
#             h["Referer"] = l.split("=", 1)[1]
#     try:
#         r = urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=10)
#         data = r.read(2048).decode("utf-8", "ignore")
#         if r.status != 200:
#             return False
#         u = url.lower()
#         if ".m3u8" in u:
#             return "#EXTM3U" in data
#         if ".mpd" in u:
#             return "<MPD" in data
#         return True
#     except Exception:
#         return False
#
# # ---- load all of the friend's m3u files ----
# friend = {}
# files = list_m3u_urls()
# print("friend m3u files found:", len(files))
# for u in files:
#     try:
#         text = urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60).read().decode("utf-8", "ignore")
#     except Exception as e:
#         print("skip", u, e)
#         continue
#     _, fblocks = parse(text)
#     for extinf, body in fblocks:
#         k = tvg(extinf)
#         if not k:
#             continue
#         lst = friend.setdefault(k, [])
#         if url_of(body) not in [url_of(b) for b in lst]:
#             lst.append(body)
#
# # ---- update my file ----
# head, mine = parse(open(MINE, encoding="utf-8").read())
# changed = 0
# for block in mine:
#     k = tvg(block[0])
#     if not k or k not in friend:
#         continue                      # no tvg-id -> never touched
#     if alive(block[1]):
#         continue                      # working -> keep
#     new = next((b for b in friend[k] if url_of(b) != url_of(block[1]) and alive(b)), None)
#     name = block[0].split(",")[-1]
#     if new:
#         block[1] = new
#         changed += 1
#         print("replaced:", name)
#     else:
#         print("dead, no working replacement:", name)
#
# if changed:
#     out = head + [x for extinf, body in mine for x in [extinf] + body]
#     open(MINE, "w", encoding="utf-8").write("\n".join(out) + "\n")
# print("total replaced:", changed)


# ////////////////////////////////////////////////

"""
Keeps data/Entertainments.m3u working.

For every channel in Entertainments.m3u:
  1. find the same channel in the "everything" playlist(s) (by tvg-id, else by name)
  2. if my copy still works -> keep it
  3. if my copy is dead/expired -> copy the fresh, working entry from the source
"""
import json
import re
import sys
import time
import urllib.error
import urllib.request

SOURCES = [
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S12.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S13.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S10.m3u",
    "https://github.com/sportlive18/jio-tv-auto-update-playlist/blob/b16d9b7c3363328098e1a0c1336a3af0709aa006/voot.m3u",
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
    "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/b16d9b7c3363328098e1a0c1336a3af0709aa006/mixiptv2.m3u",
    "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/cbc826b7c9d8e9e226ac353c3c241b6ad50a37fa/LiveTV/India/LiveTV.m3u",
    "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/b16d9b7c3363328098e1a0c1336a3af0709aa006/mixiptv.m3u",



    "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/6694404c0ce9b362575724390c3875620d26f9d6/ALL.m3u",
    "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/main/sony.m3u",
    "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/cbc826b7c9d8e9e226ac353c3c241b6ad50a37fa/LiveTV/India/LiveTV.m3u",
    "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/6694404c0ce9b362575724390c3875620d26f9d6/sony6.m3u",
]

MINE = "data/Entertainments.m3u"

EXPIRY_MARGIN = 600        # treat a token as dead 10 min before its exp= time
ADD_MISSING_TVG_ID = True  # copy tvg-id from the source into my entries that lack one
UA = "Mozilla/5.0"


# ------------------------------------------------------------
# M3U helpers
# ------------------------------------------------------------

def attr(extinf, name):
    m = re.search(r'%s="([^"]*)"' % re.escape(name), extinf)
    if m and m.group(1).strip():
        return m.group(1).strip()
    return None


def display_name(extinf):
    q = extinf.rfind('"')
    i = extinf.find(",", q if q != -1 else 0)
    return extinf[i + 1:].strip() if i != -1 else ""


def norm_name(extinf):
    n = display_name(extinf).lower()
    n = re.sub(r"\|.*$", "", n)        # drop "| GmaxHub" style suffix
    n = re.sub(r"\(.*?\)", "", n)      # drop "(1080p)" style suffix
    return re.sub(r"[^a-z0-9]+", "", n)


def add_tvg_id(extinf, tid):
    if attr(extinf, "tvg-id"):
        return extinf
    return re.sub(r"^(#EXTINF:-?\d+)", lambda m: '%s tvg-id="%s"' % (m.group(1), tid),
                  extinf, count=1)


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


# ------------------------------------------------------------
# Health check
# ------------------------------------------------------------

def headers_of(body):
    h = {"User-Agent": UA}
    for l in body:
        low = l.lower()
        val = l.split("=", 1)[1].strip() if "=" in l else ""
        if low.startswith("#extvlcopt:http-user-agent="):
            h["User-Agent"] = val
        elif low.startswith("#extvlcopt:http-referrer=") or low.startswith("#extvlcopt:http-referer="):
            h["Referer"] = val
        elif low.startswith("#extvlcopt:http-origin="):
            h["Origin"] = val
        elif low.startswith("#extvlcopt:http-cookie="):
            h["Cookie"] = val
        elif low.startswith("#exthttp:"):
            try:
                data = json.loads(l.split(":", 1)[1])
                if isinstance(data, dict):
                    h.update({str(k): str(v) for k, v in data.items()})
            except Exception:
                pass
    return h


def expiry(body):
    m = re.search(r"exp=(\d{9,11})", "\n".join(body))
    return int(m.group(1)) if m else None


def expired(body):
    e = expiry(body)
    return e is not None and e < time.time() + EXPIRY_MARGIN


def probe(body):
    """True = plays, False = dead, None = can't tell (blocked for this server)."""
    url = url_of(body)
    if not url:
        return False
    url = url.split("|")[0].strip()
    try:
        req = urllib.request.Request(url, headers=headers_of(body))
        r = urllib.request.urlopen(req, timeout=10)
        data = r.read(8192).decode("utf-8", "ignore")
        if r.status != 200:
            return False
        u = url.lower()
        if ".m3u8" in u:
            return "#EXTM3U" in data
        if ".mpd" in u:
            return "<mpd" in data.lower()
        return True
    except urllib.error.HTTPError as e:
        # GitHub's servers are outside India: Jio often answers 401/403/451 to them
        # even when the stream works fine on your TV.
        return None if e.code in (401, 403, 451) else False
    except Exception:
        return False


_health_cache = {}


def health(body):
    k = tuple(body)
    if k not in _health_cache:
        _health_cache[k] = False if expired(body) else probe(body)
    return _health_cache[k]


def app_can_play(body):
    """The app only supports ClearKey DRM (or no DRM). Skip Widevine/PlayReady."""
    for l in body:
        if l.lower().startswith("#kodiprop:inputstream.adaptive.license_type="):
            if "clearkey" not in l.lower():
                return False
    return True


# ------------------------------------------------------------
# Core logic
# ------------------------------------------------------------

def build_index(source_texts):
    by_id, by_name = {}, {}
    for text in source_texts:
        _, blocks = parse(text)
        for extinf, body in blocks:
            if not url_of(body):
                continue
            entries = []
            tid = attr(extinf, "tvg-id")
            if tid:
                entries.append(by_id.setdefault(tid.lower(), []))
            key = norm_name(extinf)
            if key:
                entries.append(by_name.setdefault(key, []))
            for lst in entries:
                if all(b != body for _, b in lst):
                    lst.append((extinf, body))
    return by_id, by_name


def find_candidates(extinf, by_id, by_name):
    # Name first: ids from different playlists can collide (e.g. "202" can be
    # a different channel in another source). Id is only the fallback.
    key = norm_name(extinf)
    if key and key in by_name:
        return by_name[key], "name"
    tid = attr(extinf, "tvg-id")
    if tid and tid.lower() in by_id:
        return by_id[tid.lower()], "id"
    return [], None


def update(mine_text, source_texts):
    by_id, by_name = build_index(source_texts)
    head, mine = parse(mine_text)
    replaced, dirty = 0, False

    # Links already used by my entries of the same channel. A replacement must not
    # copy a link that another copy of that channel already uses (keeps your backups distinct).
    taken = {}
    for e, b in mine:
        taken.setdefault(norm_name(e), set()).add(tuple(b))

    for block in mine:
        extinf, body = block
        name = display_name(extinf)
        nkey = norm_name(extinf)
        cands, how = find_candidates(extinf, by_id, by_name)
        if not cands:
            print("no match in source:", name)
            continue

        if ADD_MISSING_TVG_ID and not attr(extinf, "tvg-id"):
            sid = attr(cands[0][0], "tvg-id")
            if sid:
                block[0] = add_tvg_id(extinf, sid)
                dirty = True

        if any(b == body for _, b in cands):
            continue                      # identical to the source -> up to date

        state = health(body)
        if state is True:
            continue                      # still works -> keep

        # Every candidate differs from mine (a new cookie/token counts as different)
        fresh = [b for _, b in cands
                 if b != body and tuple(b) not in taken[nkey]
                 and not expired(b) and app_can_play(b)]
        new = next((b for b in fresh if health(b) is True), None)
        if new is None and state is False:
            # mine is definitely dead; take the fresh entry even if this server can't verify it
            new = next((b for b in fresh if health(b) is None), None)

        if new:
            block[1] = list(new)
            taken[nkey].add(tuple(new))
            replaced += 1
            dirty = True
            print("replaced (%s match): %s" % (how, name))
        else:
            print("dead, no working replacement:", name)

    out = None
    if dirty:
        out = "\n".join(head + [x for e, b in mine for x in [e] + b]) + "\n"
    return out, replaced


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")


def main():
    texts = []
    for u in SOURCES:
        try:
            texts.append(fetch(u))
            print("loaded source:", u)
        except Exception as e:
            print("could not load", u, e)
    if not texts:
        sys.exit("no source playlist could be loaded")

    with open(MINE, encoding="utf-8") as f:
        mine_text = f.read()

    out, replaced = update(mine_text, texts)
    if out is not None:
        with open(MINE, "w", encoding="utf-8") as f:
            f.write(out)
    print("total replaced:", replaced)


if __name__ == "__main__":
    main()