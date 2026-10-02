# import re, urllib.request
#
# FRIEND = "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/main/ALL.m3u"  # check branch name
# MINE = "data/Entertainments.m3u"
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
#     h = {"User-Agent": "Mozilla/5.0"}
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
# _, fblocks = parse(urllib.request.urlopen(FRIEND, timeout=60).read().decode("utf-8", "ignore"))
# friend = {}
# for extinf, body in fblocks:
#     k = tvg(extinf)
#     if k:
#         friend.setdefault(k, []).append(body)
#
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


# ////////////////////////////////////////////////////////////////////////////////


import re, json, os, urllib.request, urllib.parse

OWNER, REPO = "sportlive18", "jio-tv-auto-update-playlist"
MINE = "data/Entertainments.m3u"
UA = {"User-Agent": "Mozilla/5.0"}

def api(path):
    req = urllib.request.Request("https://api.github.com/repos/%s/%s/%s" % (OWNER, REPO, path),
                                 headers={"User-Agent": "sync", "Accept": "application/vnd.github+json"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    return json.load(urllib.request.urlopen(req, timeout=30))

def list_m3u_urls():
    branch = api("")["default_branch"]
    tree = api("git/trees/%s?recursive=1" % branch)["tree"]
    return ["https://raw.githubusercontent.com/%s/%s/%s/%s" % (OWNER, REPO, branch, urllib.parse.quote(t["path"]))
            for t in tree if t["type"] == "blob" and t["path"].lower().endswith(".m3u")]

def tvg(extinf):
    m = re.search(r'tvg-id="([^"]+)"', extinf)
    return m.group(1).lower() if m else None

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

def alive(body):
    url = url_of(body)
    if not url:
        return False
    h = dict(UA)
    for l in body:
        low = l.lower()
        if low.startswith("#extvlcopt:http-user-agent="):
            h["User-Agent"] = l.split("=", 1)[1]
        elif low.startswith("#extvlcopt:http-referrer="):
            h["Referer"] = l.split("=", 1)[1]
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=10)
        data = r.read(2048).decode("utf-8", "ignore")
        if r.status != 200:
            return False
        u = url.lower()
        if ".m3u8" in u:
            return "#EXTM3U" in data
        if ".mpd" in u:
            return "<MPD" in data
        return True
    except Exception:
        return False

# ---- load all of the friend's m3u files ----
friend = {}
files = list_m3u_urls()
print("friend m3u files found:", len(files))
for u in files:
    try:
        text = urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60).read().decode("utf-8", "ignore")
    except Exception as e:
        print("skip", u, e)
        continue
    _, fblocks = parse(text)
    for extinf, body in fblocks:
        k = tvg(extinf)
        if not k:
            continue
        lst = friend.setdefault(k, [])
        if url_of(body) not in [url_of(b) for b in lst]:   # skip duplicate urls
            lst.append(body)

# ---- update my file ----
head, mine = parse(open(MINE, encoding="utf-8").read())
changed = 0
for block in mine:
    k = tvg(block[0])
    if not k or k not in friend:
        continue                      # no tvg-id -> never touched
    if alive(block[1]):
        continue                      # working -> keep
    new = next((b for b in friend[k] if url_of(b) != url_of(block[1]) and alive(b)), None)
    name = block[0].split(",")[-1]
    if new:
        block[1] = new
        changed += 1
        print("replaced:", name)
    else:
        print("dead, no working replacement:", name)

if changed:
    out = head + [x for extinf, body in mine for x in [extinf] + body]
    open(MINE, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("total replaced:", changed)