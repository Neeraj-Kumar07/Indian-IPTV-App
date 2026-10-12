#
#
# # ////////////////////////////////////////////////
#
# """
# Keeps data/Entertainments.m3u working.
#
# For every channel in Entertainments.m3u:
#   1. find the same channel in the "everything" playlist(s) (by tvg-id, else by name)
#   2. if my copy still works -> keep it
#   3. if my copy is dead/expired -> copy the fresh, working entry from the source
# """
# import json
# import re
# import sys
# import time
# import urllib.error
# import urllib.request
#
# SOURCES = [
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S12.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S13.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S10.m3u",
#     "https://raw.githubusercontent.com/Neeraj-Kumar07/Indian-IPTV-App/refs/heads/master/data/Entertainments.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/digital.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S1.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S11.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S2.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S3.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S4.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S5.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S6.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S7.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S8.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S9.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S3.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S2.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S1.m3u",
# #     "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/refs/heads/main/LiveTV/India/LiveTV.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S1.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S3.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/sportlink-update/refs/heads/main/zee4.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/b16d9b7c3363328098e1a0c1336a3af0709aa006/mixiptv2.m3u",
# #     "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/cbc826b7c9d8e9e226ac353c3c241b6ad50a37fa/LiveTV/India/LiveTV.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/b16d9b7c3363328098e1a0c1336a3af0709aa006/mixiptv.m3u",
#
#
#
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/6694404c0ce9b362575724390c3875620d26f9d6/ALL.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/main/sony.m3u",
# #     "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/cbc826b7c9d8e9e226ac353c3c241b6ad50a37fa/LiveTV/India/LiveTV.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/6694404c0ce9b362575724390c3875620d26f9d6/sony6.m3u",
# ]
#
# MINE = "data/Entertainments.m3u"
#
# EXPIRY_MARGIN = 600        # treat a token as dead 10 min before its exp= time
# ADD_MISSING_TVG_ID = True  # copy tvg-id from the source into my entries that lack one
# UA = "Mozilla/5.0"
#
#
# # ------------------------------------------------------------
# # M3U helpers
# # ------------------------------------------------------------
#
# def attr(extinf, name):
#     m = re.search(r'%s="([^"]*)"' % re.escape(name), extinf)
#     if m and m.group(1).strip():
#         return m.group(1).strip()
#     return None
#
#
# def display_name(extinf):
#     q = extinf.rfind('"')
#     i = extinf.find(",", q if q != -1 else 0)
#     return extinf[i + 1:].strip() if i != -1 else ""
#
#
# def norm_name(extinf):
#     n = display_name(extinf).lower()
#     n = re.sub(r"\|.*$", "", n)        # drop "| GmaxHub" style suffix
#     n = re.sub(r"\(.*?\)", "", n)      # drop "(1080p)" style suffix
#     return re.sub(r"[^a-z0-9]+", "", n)
#
#
# def add_tvg_id(extinf, tid):
#     if attr(extinf, "tvg-id"):
#         return extinf
#     return re.sub(r"^(#EXTINF:-?\d+)", lambda m: '%s tvg-id="%s"' % (m.group(1), tid),
#                   extinf, count=1)
#
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
#
# def url_of(body):
#     return next((l for l in reversed(body) if not l.startswith("#")), None)
#
#
# # ------------------------------------------------------------
# # Health check
# # ------------------------------------------------------------
#
# def headers_of(body):
#     h = {"User-Agent": UA}
#     for l in body:
#         low = l.lower()
#         val = l.split("=", 1)[1].strip() if "=" in l else ""
#         if low.startswith("#extvlcopt:http-user-agent="):
#             h["User-Agent"] = val
#         elif low.startswith("#extvlcopt:http-referrer=") or low.startswith("#extvlcopt:http-referer="):
#             h["Referer"] = val
#         elif low.startswith("#extvlcopt:http-origin="):
#             h["Origin"] = val
#         elif low.startswith("#extvlcopt:http-cookie="):
#             h["Cookie"] = val
#         elif low.startswith("#exthttp:"):
#             try:
#                 data = json.loads(l.split(":", 1)[1])
#                 if isinstance(data, dict):
#                     h.update({str(k): str(v) for k, v in data.items()})
#             except Exception:
#                 pass
#     return h
#
#
# def expiry(body):
#     m = re.search(r"exp=(\d{9,11})", "\n".join(body))
#     return int(m.group(1)) if m else None
#
#
# def expired(body):
#     e = expiry(body)
#     return e is not None and e < time.time() + EXPIRY_MARGIN
#
#
# def probe(body):
#     """True = plays, False = dead, None = can't tell (blocked for this server)."""
#     url = url_of(body)
#     if not url:
#         return False
#     url = url.split("|")[0].strip()
#     try:
#         req = urllib.request.Request(url, headers=headers_of(body))
#         r = urllib.request.urlopen(req, timeout=10)
#         data = r.read(8192).decode("utf-8", "ignore")
#         if r.status != 200:
#             return False
#         u = url.lower()
#         if ".m3u8" in u:
#             return "#EXTM3U" in data
#         if ".mpd" in u:
#             return "<mpd" in data.lower()
#         return True
#     except urllib.error.HTTPError as e:
#         # GitHub's servers are outside India: Jio often answers 401/403/451 to them
#         # even when the stream works fine on your TV.
#         return None if e.code in (401, 403, 451) else False
#     except Exception:
#         return False
#
#
# _health_cache = {}
#
#
# def health(body):
#     k = tuple(body)
#     if k not in _health_cache:
#         _health_cache[k] = False if expired(body) else probe(body)
#     return _health_cache[k]
#
#
# def app_can_play(body):
#     """The app only supports ClearKey DRM (or no DRM). Skip Widevine/PlayReady."""
#     for l in body:
#         if l.lower().startswith("#kodiprop:inputstream.adaptive.license_type="):
#             if "clearkey" not in l.lower():
#                 return False
#     return True
#
#
# # ------------------------------------------------------------
# # Core logic
# # ------------------------------------------------------------
#
# def build_index(source_texts):
#     by_id, by_name = {}, {}
#     for text in source_texts:
#         _, blocks = parse(text)
#         for extinf, body in blocks:
#             if not url_of(body):
#                 continue
#             entries = []
#             tid = attr(extinf, "tvg-id")
#             if tid:
#                 entries.append(by_id.setdefault(tid.lower(), []))
#             key = norm_name(extinf)
#             if key:
#                 entries.append(by_name.setdefault(key, []))
#             for lst in entries:
#                 if all(b != body for _, b in lst):
#                     lst.append((extinf, body))
#     return by_id, by_name
#
#
# def find_candidates(extinf, by_id, by_name):
#     # Name first: ids from different playlists can collide (e.g. "202" can be
#     # a different channel in another source). Id is only the fallback.
#     key = norm_name(extinf)
#     if key and key in by_name:
#         return by_name[key], "name"
#     tid = attr(extinf, "tvg-id")
#     if tid and tid.lower() in by_id:
#         return by_id[tid.lower()], "id"
#     return [], None
#
#
# def update(mine_text, source_texts):
#     by_id, by_name = build_index(source_texts)
#     head, mine = parse(mine_text)
#     replaced, dirty = 0, False
#
#     # Links already used by my entries of the same channel. A replacement must not
#     # copy a link that another copy of that channel already uses (keeps your backups distinct).
#     taken = {}
#     for e, b in mine:
#         taken.setdefault(norm_name(e), set()).add(tuple(b))
#
#     for block in mine:
#         extinf, body = block
#         name = display_name(extinf)
#         nkey = norm_name(extinf)
#         cands, how = find_candidates(extinf, by_id, by_name)
#         if not cands:
#             print("no match in source:", name)
#             continue
#
#         if ADD_MISSING_TVG_ID and not attr(extinf, "tvg-id"):
#             sid = attr(cands[0][0], "tvg-id")
#             if sid:
#                 block[0] = add_tvg_id(extinf, sid)
#                 dirty = True
#
#         if any(b == body for _, b in cands):
#             continue                      # identical to the source -> up to date
#
#         state = health(body)
#         if state is True:
#             continue                      # still works -> keep
#
#         # Every candidate differs from mine (a new cookie/token counts as different)
#         fresh = [b for _, b in cands
#                  if b != body and tuple(b) not in taken[nkey]
#                  and not expired(b) and app_can_play(b)]
#         new = next((b for b in fresh if health(b) is True), None)
#         if new is None and state is False:
#             # mine is definitely dead; take the fresh entry even if this server can't verify it
#             new = next((b for b in fresh if health(b) is None), None)
#
#         if new:
#             block[1] = list(new)
#             taken[nkey].add(tuple(new))
#             replaced += 1
#             dirty = True
#             print("replaced (%s match): %s" % (how, name))
#         else:
#             print("dead, no working replacement:", name)
#
#     out = None
#     if dirty:
#         out = "\n".join(head + [x for e, b in mine for x in [e] + b]) + "\n"
#     return out, replaced
#
#
# def fetch(url):
#     req = urllib.request.Request(url, headers={"User-Agent": UA})
#     return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")
#
#
# def main():
#     texts = []
#     for u in SOURCES:
#         try:
#             texts.append(fetch(u))
#             print("loaded source:", u)
#         except Exception as e:
#             print("could not load", u, e)
#     if not texts:
#         sys.exit("no source playlist could be loaded")
#
#     with open(MINE, encoding="utf-8") as f:
#         mine_text = f.read()
#
#     out, replaced = update(mine_text, texts)
#     if out is not None:
#         with open(MINE, "w", encoding="utf-8") as f:
#             f.write(out)
#     print("total replaced:", replaced)
#
#
# if __name__ == "__main__":
#     main()


# THE ABOVE IS THE ORIGINAL
# ///////////////////////////////////////////////////////////
#
# """
# Keeps data/Entertainments.m3u working.
#
# For every channel in Entertainments.m3u:
#   1. find the same channel in the "everything" playlist(s) (by name, else by tvg-id)
#   2. if my copy still works -> keep it
#   3. if my copy is dead/expired -> copy the fresh, working entry from the source
#
# CHANGE FROM THE OLD VERSION: "still works" is now decided by the same checker as
# the "v2 real decode + key check" tester: token expiry, manifest fetch with the
# entry's own headers, license-key vs stream-KID match, and a real ffmpeg decode.
# Run this on a machine in India (your laptop), not GitHub Actions, or Jio/Star
# streams will return 403 and cannot be verified.
# """
# import base64
# import json
# import os
# import re
# import shutil
# import subprocess
# import sys
# import time
# import urllib.request
# from concurrent.futures import ThreadPoolExecutor
#
# import requests
#
# SOURCES = [
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S12.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S13.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S10.m3u",
#     "https://raw.githubusercontent.com/Neeraj-Kumar07/Indian-IPTV-App/refs/heads/master/data/Entertainments.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/digital.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S1.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S11.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S2.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S3.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S4.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S5.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S6.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S7.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S8.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S9.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S3.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S2.m3u",
#     "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/Sport_S1.m3u",
# #     "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/refs/heads/main/LiveTV/India/LiveTV.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/sportlink-update/refs/heads/main/zee4.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/b16d9b7c3363328098e1a0c1336a3af0709aa006/mixiptv2.m3u",
# #     "https://raw.githubusercontent.com/bugsfreeweb/LiveTVCollector/cbc826b7c9d8e9e226ac353c3c241b6ad50a37fa/LiveTV/India/LiveTV.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/b16d9b7c3363328098e1a0c1336a3af0709aa006/mixiptv.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/6694404c0ce9b362575724390c3875620d26f9d6/ALL.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/main/sony.m3u",
# #     "https://raw.githubusercontent.com/sportlive18/jio-tv-auto-update-playlist/6694404c0ce9b362575724390c3875620d26f9d6/sony6.m3u",
# ]
#
# MINE = "data/Entertainments.m3u"
#
# EXPIRY_MARGIN = 600         # treat a token as dead 10 min before its exp= time
# ADD_MISSING_TVG_ID = True   # copy tvg-id from the source into my entries that lack one
# UA = "Mozilla/5.0"
#
# # ---- checker settings (from the "v2" tester) ----
# _WIN_FFMPEG = r"C:\Users\neera\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.1-full_build\bin\ffmpeg.exe"
# FFMPEG_PATH = os.environ.get("FFMPEG_PATH") or (
#     _WIN_FFMPEG if os.path.isfile(_WIN_FFMPEG) else (shutil.which("ffmpeg") or "ffmpeg"))
# DECODE_SECONDS = 4          # how much video to really decode
# FFMPEG_TIMEOUT = 15         # seconds to wait on network inside ffmpeg
# MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "4"))   # parallel health checks
# SHAKY_IS_OK = True          # decoded but printed startup warnings -> count as working
# UNVERIFIED_FALLBACK = os.environ.get("UNVERIFIED_FALLBACK", "0") == "1"  # if mine is dead and no candidate can be verified (HTTP 401/403/451
#                             # from this machine), copy the fresh one anyway? Old behaviour = True
# NULL_OUT = "NUL" if os.name == "nt" else "/dev/null"
#
#
# # ------------------------------------------------------------
# # M3U helpers (unchanged)
# # ------------------------------------------------------------
#
# def attr(extinf, name):
#     m = re.search(r'%s="([^"]*)"' % re.escape(name), extinf)
#     if m and m.group(1).strip():
#         return m.group(1).strip()
#     return None
#
#
# def display_name(extinf):
#     q = extinf.rfind('"')
#     i = extinf.find(",", q if q != -1 else 0)
#     return extinf[i + 1:].strip() if i != -1 else ""
#
#
# def norm_name(extinf):
#     n = display_name(extinf).lower()
#     n = re.sub(r"\|.*$", "", n)        # drop "| GmaxHub" style suffix
#     n = re.sub(r"\(.*?\)", "", n)      # drop "(1080p)" style suffix
#     return re.sub(r"[^a-z0-9]+", "", n)
#
#
# def add_tvg_id(extinf, tid):
#     if attr(extinf, "tvg-id"):
#         return extinf
#     return re.sub(r"^(#EXTINF:-?\d+)", lambda m: '%s tvg-id="%s"' % (m.group(1), tid),
#                   extinf, count=1)
#
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
#
# def url_of(body):
#     return next((l for l in reversed(body) if not l.startswith("#")), None)
#
#
# # ------------------------------------------------------------
# # Health check  (NEW: same logic as the v2 tester)
# # ------------------------------------------------------------
#
# def headers_of(body):
#     h = {"User-Agent": UA}
#     for l in body:
#         low = l.lower()
#         val = l.split("=", 1)[1].strip() if "=" in l else ""
#         if low.startswith("#extvlcopt:http-user-agent="):
#             h["User-Agent"] = val
#         elif low.startswith(("#extvlcopt:http-referrer=", "#extvlcopt:http-referer=")):
#             h["Referer"] = val
#         elif low.startswith("#extvlcopt:http-origin="):
#             h["Origin"] = val
#         elif low.startswith("#extvlcopt:http-cookie="):
#             h["Cookie"] = val
#         elif low.startswith("#extvlcopt:http-extra-headers="):
#             k, _, v = val.partition(":")
#             if k.strip() and v.strip():
#                 h[k.strip()] = v.strip()
#         elif low.startswith("#exthttp:"):
#             try:
#                 data = json.loads(l.split(":", 1)[1])
#                 if isinstance(data, dict):
#                     for k, v in data.items():
#                         k = {"cookie": "Cookie", "origin": "Origin", "referer": "Referer",
#                              "user-agent": "User-Agent"}.get(str(k).lower(), str(k))
#                         h[k] = str(v)
#             except Exception:
#                 pass
#     return h
#
#
# def key_raw_of(body):
#     for l in body:
#         if l.lower().startswith("#kodiprop:inputstream.adaptive.license_key="):
#             return l.split("=", 1)[1].strip()
#     return None
#
#
# def expiry(body):
#     # only look at the URL and header lines, not unrelated text
#     text = "\n".join(l for l in body if not l.lower().startswith("#kodiprop"))
#     m = re.search(r"exp=(\d{9,11})", text)
#     return int(m.group(1)) if m else None
#
#
# def expired(body):
#     e = expiry(body)
#     return e is not None and e < time.time() + EXPIRY_MARGIN
#
#
# def b64_to_hex(s):
#     s = s.replace("-", "+").replace("_", "/")
#     s += "=" * (-len(s) % 4)
#     return base64.b64decode(s).hex()
#
#
# def parse_keys(raw, headers):
#     """Returns {kid_hex: key_hex}. Handles kid:key[,kid:key], JWK json, and key URLs."""
#     keys = {}
#     if not raw:
#         return keys
#     raw = raw.strip()
#     if raw.lower().startswith("http"):
#         try:
#             raw = requests.get(raw, headers=headers, timeout=8).text.strip()
#         except Exception:
#             return keys
#     if raw.startswith("{"):
#         try:
#             for k in json.loads(raw).get("keys", []):
#                 keys[b64_to_hex(k["kid"])] = b64_to_hex(k["k"])
#         except Exception:
#             pass
#         return keys
#     for pair in raw.split(","):
#         if ":" in pair:
#             kid, key = pair.strip().split(":", 1)
#             if re.fullmatch(r"[0-9a-fA-F]{32}", kid) and re.fullmatch(r"[0-9a-fA-F]{32}", key):
#                 keys[kid.lower()] = key.lower()
#     return keys
#
#
# def decode_test(url, headers, key):
#     """Really decode a few seconds of video. Returns (state, note); state = ok | shaky | fail."""
#     hdrs = dict(headers)
#     ua = hdrs.pop("User-Agent", UA)
#     hdr_str = "".join("%s: %s\r\n" % (k, v) for k, v in hdrs.items())
#
#     cmd = [FFMPEG_PATH, "-nostdin", "-v", "error", "-user_agent", ua]
#     if hdr_str:
#         cmd += ["-headers", hdr_str]
#     if key:
#         cmd += ["-cenc_decryption_key", key]
#     cmd += ["-rw_timeout", str(FFMPEG_TIMEOUT * 1_000_000),
#             "-i", url, "-map", "0:v:0", "-t", str(DECODE_SECONDS), "-f", "null", NULL_OUT]
#     try:
#         r = subprocess.run(cmd, capture_output=True, text=True,
#                            timeout=FFMPEG_TIMEOUT + DECODE_SECONDS + 25)
#     except FileNotFoundError:
#         return "fail", "ffmpeg not found"
#     except Exception as e:
#         return "fail", "ffmpeg error: %s" % str(e)[:60]
#     err = (r.stderr or "").strip().splitlines()
#     last = err[-1][:80] if err else ""
#     if r.returncode != 0:
#         return "fail", last or "ffmpeg exit %d" % r.returncode
#     return ("shaky", last) if err else ("ok", "")
#
#
# def probe(body):
#     """Returns (verdict, reason). verdict: True = plays, False = dead,
#     None = can't tell (HTTP 401/403/451 from this machine)."""
#     url = url_of(body)
#     if not url:
#         return False, "no url"
#     url = url.split("|")[0].strip()
#     if url.endswith("?"):
#         url = url[:-1]
#     h = headers_of(body)
#
#     try:
#         r = requests.get(url, headers=h, timeout=10, stream=True)
#         status = r.status_code
#         text = next(r.iter_content(chunk_size=262144), b"").decode("utf-8", "ignore")
#         r.close()
#     except Exception as e:
#         return False, "request failed: %s" % str(e)[:60]
#     if status in (401, 403, 451):
#         return None, "HTTP %d (blocked for this server)" % status
#     if status != 200:
#         return False, "HTTP %d" % status
#
#     is_mpd = "<mpd" in text.lower()
#     if not is_mpd and "#EXTM3U" not in text:
#         return False, "HTTP 200 but not a manifest"
#
#     candidates = []
#     if is_mpd:
#         kids = {k.replace("-", "").lower()
#                 for k in re.findall(r'default_KID="([0-9a-fA-F-]+)"', text, re.I)}
#         if kids:
#             keys = parse_keys(key_raw_of(body), h)
#             if not keys:
#                 return False, "encrypted, no usable key"
#             candidates = [keys[k] for k in kids if k in keys]
#             if not candidates:
#                 return False, "key does not match stream KID"
#
#     saw_shaky, last_note = False, ""
#     for key in (candidates or [None]):
#         state, note = decode_test(url, h, key)
#         if state == "ok":
#             return True, "plays"
#         if state == "shaky":
#             saw_shaky, last_note = True, note
#         else:
#             last_note = note
#     if saw_shaky and SHAKY_IS_OK:
#         return True, "plays (warnings)"
#     return False, "decode failed: %s" % last_note
#
#
# _health_cache = {}
# _reason_cache = {}
#
#
# def _check(body):
#     if expired(body):
#         e = expiry(body)
#         return False, "token expired"
#     return probe(body)
#
#
# def health(body):
#     k = tuple(body)
#     if k not in _health_cache:
#         _health_cache[k], _reason_cache[k] = _check(body)
#     return _health_cache[k]
#
#
# def reason(body):
#     health(body)
#     return _reason_cache.get(tuple(body), "")
#
#
# def prefetch_health(bodies):
#     """Check many entries in parallel so the run doesn't take hours."""
#     todo = [b for b in {tuple(b) for b in bodies} if b not in _health_cache]
#     with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
#         for b, (v, why) in zip(todo, ex.map(lambda b: _check(list(b)), todo)):
#             _health_cache[b], _reason_cache[b] = v, why
#     counts = {}
#     for b in {tuple(b) for b in bodies}:
#         key = "plays" if _health_cache.get(b) is True else (
#             "unverifiable" if _health_cache.get(b) is None else "dead")
#         counts[key] = counts.get(key, 0) + 1
#     print("my entries:", counts)
#
#
# def app_can_play(body):
#     """The app only supports ClearKey DRM (or no DRM). Skip Widevine/PlayReady."""
#     for l in body:
#         if l.lower().startswith("#kodiprop:inputstream.adaptive.license_type="):
#             if "clearkey" not in l.lower():
#                 return False
#     return True
#
#
# # ------------------------------------------------------------
# # Core logic (same as before)
# # ------------------------------------------------------------
#
# def build_index(source_texts):
#     by_id, by_name = {}, {}
#     for text in source_texts:
#         _, blocks = parse(text)
#         for extinf, body in blocks:
#             if not url_of(body):
#                 continue
#             entries = []
#             tid = attr(extinf, "tvg-id")
#             if tid:
#                 entries.append(by_id.setdefault(tid.lower(), []))
#             key = norm_name(extinf)
#             if key:
#                 entries.append(by_name.setdefault(key, []))
#             for lst in entries:
#                 if all(b != body for _, b in lst):
#                     lst.append((extinf, body))
#     return by_id, by_name
#
#
# def find_candidates(extinf, by_id, by_name):
#     # Name first: ids from different playlists can collide. Id is only the fallback.
#     key = norm_name(extinf)
#     if key and key in by_name:
#         return by_name[key], "name"
#     tid = attr(extinf, "tvg-id")
#     if tid and tid.lower() in by_id:
#         return by_id[tid.lower()], "id"
#     return [], None
#
#
# def update(mine_text, source_texts):
#     by_id, by_name = build_index(source_texts)
#     head, mine = parse(mine_text)
#     replaced, dirty = 0, False
#
#     print("checking %d of my entries (real decode, this takes a while)..." % len(mine))
#     prefetch_health([b for _, b in mine if url_of(b)])
#
#     # Links already used by my entries of the same channel. A replacement must not
#     # copy a link that another copy of that channel already uses (keeps backups distinct).
#     taken = {}
#     for e, b in mine:
#         taken.setdefault(norm_name(e), set()).add(tuple(b))
#
#     for block in mine:
#         extinf, body = block
#         name = display_name(extinf)
#         nkey = norm_name(extinf)
#         cands, how = find_candidates(extinf, by_id, by_name)
#         if not cands:
#             print("no match in source:", name)
#             continue
#
#         if ADD_MISSING_TVG_ID and not attr(extinf, "tvg-id"):
#             sid = attr(cands[0][0], "tvg-id")
#             if sid:
#                 block[0] = add_tvg_id(extinf, sid)
#                 dirty = True
#
#         state = health(body)
#         if state is True:
#             continue                      # still plays -> keep
#
#         # Every candidate differs from mine (a new cookie/token counts as different)
#         fresh = [b for _, b in cands
#                  if b != body and tuple(b) not in taken[nkey]
#                  and not expired(b) and app_can_play(b)]
#         new = next((b for b in fresh if health(b) is True), None)
#         if new is None and state is False and UNVERIFIED_FALLBACK:
#             new = next((b for b in fresh if health(b) is None), None)
#
#         if new:
#             block[1] = list(new)
#             taken[nkey].add(tuple(new))
#             replaced += 1
#             dirty = True
#             print("replaced (%s match): %s" % (how, name))
#         elif state is None:
#             print("unverifiable, kept old link: %s  (%s)" % (name, reason(body)))
#         else:
#             print("dead, no working replacement: %s  (%s)" % (name, reason(body)))
#
#     out = None
#     if dirty:
#         out = "\n".join(head + [x for e, b in mine for x in [e] + b]) + "\n"
#     return out, replaced
#
#
# def fetch(url):
#     req = urllib.request.Request(url, headers={"User-Agent": UA})
#     return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")
#
#
# def check_ffmpeg():
#     try:
#         subprocess.run([FFMPEG_PATH, "-version"], capture_output=True, timeout=15, check=True)
#     except Exception:
#         sys.exit("ffmpeg not found (%s). Install it first, e.g. 'sudo apt-get install -y ffmpeg' "
#                  "on the runner, or set FFMPEG_PATH." % FFMPEG_PATH)
#
#
# def main():
#     check_ffmpeg()
#     texts = []
#     for u in SOURCES:
#         try:
#             texts.append(fetch(u))
#             print("loaded source:", u)
#         except Exception as e:
#             print("could not load", u, e)
#     if not texts:
#         sys.exit("no source playlist could be loaded")
#
#     with open(MINE, encoding="utf-8") as f:
#         mine_text = f.read()
#
#     out, replaced = update(mine_text, texts)
#     if out is not None:
#         with open(MINE, "w", encoding="utf-8") as f:
#             f.write(out)
#     print("total replaced:", replaced)
#
#
# if __name__ == "__main__":
#     main()

# THIS ABOVE IS 2ND CODE
# ////////////////////////////////////////////////////////////////////////////
# NOW FROM HERE THE NEW 3RD CODE IS STARTING


import base64
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import requests

SOURCES = [
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S12.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S13.m3u",
    "https://raw.githubusercontent.com/purupc00-dev/Gmax-JioTV/refs/heads/main/Playlists/JioTV_S10.m3u",
    "https://raw.githubusercontent.com/Neeraj-Kumar07/Indian-IPTV-App/refs/heads/master/data/Entertainments.m3u",
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
]

MINE = "data/Entertainments.m3u"

EXPIRY_MARGIN = 600         # treat a token as dead 10 min before its exp= time
ADD_MISSING_TVG_ID = True   # copy tvg-id from the source into my entries that lack one
UA = "Mozilla/5.0"

FFMPEG_PATH = os.environ.get("FFMPEG_PATH") or shutil.which("ffmpeg") or "ffmpeg"
DECODE_SECONDS = 4          # how much video to really decode
FFMPEG_TIMEOUT = 15         # seconds to wait on network inside ffmpeg
MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "8"))   # parallel health checks
SHAKY_IS_OK = True          # decoded but printed startup warnings -> count as working
NULL_OUT = "NUL" if os.name == "nt" else "/dev/null"


# ------------------------------------------------------------
# M3U helpers (unchanged)
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
# Health check: a link is either working (True) or dead (False)
# ------------------------------------------------------------

def headers_of(body):
    h = {"User-Agent": UA}
    for l in body:
        low = l.lower()
        val = l.split("=", 1)[1].strip() if "=" in l else ""
        if low.startswith("#extvlcopt:http-user-agent="):
            h["User-Agent"] = val
        elif low.startswith(("#extvlcopt:http-referrer=", "#extvlcopt:http-referer=")):
            h["Referer"] = val
        elif low.startswith("#extvlcopt:http-origin="):
            h["Origin"] = val
        elif low.startswith("#extvlcopt:http-cookie="):
            h["Cookie"] = val
        elif low.startswith("#extvlcopt:http-extra-headers="):
            k, _, v = val.partition(":")
            if k.strip() and v.strip():
                h[k.strip()] = v.strip()
        elif low.startswith("#exthttp:"):
            try:
                data = json.loads(l.split(":", 1)[1])
                if isinstance(data, dict):
                    for k, v in data.items():
                        k = {"cookie": "Cookie", "origin": "Origin", "referer": "Referer",
                             "user-agent": "User-Agent"}.get(str(k).lower(), str(k))
                        h[k] = str(v)
            except Exception:
                pass
    return h


def key_raw_of(body):
    for l in body:
        if l.lower().startswith("#kodiprop:inputstream.adaptive.license_key="):
            return l.split("=", 1)[1].strip()
    return None


def expiry(body):
    text = "\n".join(l for l in body if not l.lower().startswith("#kodiprop"))
    m = re.search(r"exp=(\d{9,11})", text)
    return int(m.group(1)) if m else None


def expired(body):
    e = expiry(body)
    return e is not None and e < time.time() + EXPIRY_MARGIN


def b64_to_hex(s):
    s = s.replace("-", "+").replace("_", "/")
    s += "=" * (-len(s) % 4)
    return base64.b64decode(s).hex()


def parse_keys(raw, headers):
    """Returns {kid_hex: key_hex}. Handles kid:key[,kid:key], JWK json, and key URLs."""
    keys = {}
    if not raw:
        return keys
    raw = raw.strip()
    if raw.lower().startswith("http"):
        try:
            raw = requests.get(raw, headers=headers, timeout=8).text.strip()
        except Exception:
            return keys
    if raw.startswith("{"):
        try:
            for k in json.loads(raw).get("keys", []):
                keys[b64_to_hex(k["kid"])] = b64_to_hex(k["k"])
        except Exception:
            pass
        return keys
    for pair in raw.split(","):
        if ":" in pair:
            kid, key = pair.strip().split(":", 1)
            if re.fullmatch(r"[0-9a-fA-F]{32}", kid) and re.fullmatch(r"[0-9a-fA-F]{32}", key):
                keys[kid.lower()] = key.lower()
    return keys


def decode_test(url, headers, key):
    """Really decode a few seconds of video. Returns (state, note); state = ok | shaky | fail."""
    hdrs = dict(headers)
    ua = hdrs.pop("User-Agent", UA)
    hdr_str = "".join("%s: %s\r\n" % (k, v) for k, v in hdrs.items())

    cmd = [FFMPEG_PATH, "-nostdin", "-v", "error", "-user_agent", ua]
    if hdr_str:
        cmd += ["-headers", hdr_str]
    if key:
        cmd += ["-cenc_decryption_key", key]
    cmd += ["-rw_timeout", str(FFMPEG_TIMEOUT * 1_000_000),
            "-i", url, "-map", "0:v:0", "-t", str(DECODE_SECONDS), "-f", "null", NULL_OUT]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=FFMPEG_TIMEOUT + DECODE_SECONDS + 25)
    except FileNotFoundError:
        return "fail", "ffmpeg not found"
    except Exception as e:
        return "fail", "ffmpeg error: %s" % str(e)[:60]
    err = (r.stderr or "").strip().splitlines()
    last = err[-1][:80] if err else ""
    if r.returncode != 0:
        return "fail", last or "ffmpeg exit %d" % r.returncode
    return ("shaky", last) if err else ("ok", "")


def probe(body):
    """Returns (working, reason). working is True or False, nothing in between."""
    url = url_of(body)
    if not url:
        return False, "no url"
    url = url.split("|")[0].strip()
    if url.endswith("?"):
        url = url[:-1]
    h = headers_of(body)

    # one retry, so a single slow response doesn't mark a good link dead
    status, text, err = None, "", ""
    for _ in range(2):
        try:
            r = requests.get(url, headers=h, timeout=10, stream=True)
            status = r.status_code
            text = next(r.iter_content(chunk_size=262144), b"").decode("utf-8", "ignore")
            r.close()
            break
        except Exception as e:
            err = str(e)[:60]
    if status is None:
        return False, "request failed: %s" % err
    if status in (401, 403, 451):
        return None, "HTTP %d (blocked for this server)" % status
    if status != 200:
        return False, "HTTP %d" % status

    is_mpd = "<mpd" in text.lower()
    if not is_mpd and "#EXTM3U" not in text:
        return False, "HTTP 200 but not a manifest"

    candidates = []
    if is_mpd:
        kids = {k.replace("-", "").lower()
                for k in re.findall(r'default_KID="([0-9a-fA-F-]+)"', text, re.I)}
        if kids:
            keys = parse_keys(key_raw_of(body), h)
            if not keys:
                return False, "encrypted, no usable key"
            candidates = [keys[k] for k in kids if k in keys]
            if not candidates:
                return False, "key does not match stream KID"

    saw_shaky, last_note = False, ""
    for key in (candidates or [None]):
        state, note = decode_test(url, h, key)
        if state == "ok":
            return True, "plays"
        if state == "shaky":
            saw_shaky, last_note = True, note
        else:
            last_note = note
    if saw_shaky and SHAKY_IS_OK:
        return True, "plays (warnings)"
    return False, "decode failed: %s" % last_note


_health_cache = {}
_reason_cache = {}


def _check(body):
    if expired(body):
        return False, "token expired"
    return probe(body)


def health(body):
    k = tuple(body)
    if k not in _health_cache:
        _health_cache[k], _reason_cache[k] = _check(body)
    return _health_cache[k]


def reason(body):
    health(body)
    return _reason_cache.get(tuple(body), "")


def prefetch_health(bodies, label):
    """Check many entries in parallel."""
    todo = [b for b in {tuple(b) for b in bodies} if b not in _health_cache]
    if todo:
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
            for b, (v, why) in zip(todo, ex.map(lambda b: _check(list(b)), todo)):
                _health_cache[b], _reason_cache[b] = v, why
    uniq = {tuple(b) for b in bodies}
    ok = sum(1 for b in uniq if _health_cache.get(b) is True)
    unv = sum(1 for b in uniq if _health_cache.get(b) is None)
    print("%s: %d working, %d dead, %d unverifiable (of %d)"
          % (label, ok, len(uniq) - ok - unv, unv, len(uniq)))


def app_can_play(body):
    """The app only supports ClearKey DRM (or no DRM). Skip Widevine/PlayReady."""
    for l in body:
        if l.lower().startswith("#kodiprop:inputstream.adaptive.license_type="):
            if "clearkey" not in l.lower():
                return False
    return True


# ------------------------------------------------------------
# Matching logic (same as before: name first, tvg-id as fallback)
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
    key = norm_name(extinf)
    if key and key in by_name:
        return by_name[key], "name"
    tid = attr(extinf, "tvg-id")
    if tid and tid.lower() in by_id:
        return by_id[tid.lower()], "id"
    return [], None


def usable(body):
    return not expired(body) and app_can_play(body)


def update(mine_text, source_texts):
    by_id, by_name = build_index(source_texts)
    head, mine = parse(mine_text)
    replaced, dirty = 0, False

    # Step 1: test my own entries
    print("step 1: testing %d entries in my playlist..." % len(mine))
    prefetch_health([b for _, b in mine if url_of(b)], "my entries")

    # Step 2: test source links, but only for channels that are dead in my playlist
    need = []
    for extinf, body in mine:
        if url_of(body) and health(body) is not True:
            cands, _ = find_candidates(extinf, by_id, by_name)
            need += [b for _, b in cands if b != body and usable(b)]
    print("step 2: testing %d source links for the dead channels..." % len({tuple(b) for b in need}))
    prefetch_health(need, "source links")

    # Links already used by my entries of the same channel, so backups stay distinct.
    taken = {}
    for e, b in mine:
        taken.setdefault(norm_name(e), set()).add(tuple(b))

    # Step 3: keep working entries, replace dead ones
    for block in mine:
        extinf, body = block
        name = display_name(extinf)
        nkey = norm_name(extinf)
        cands, how = find_candidates(extinf, by_id, by_name)

        if ADD_MISSING_TVG_ID and cands and not attr(extinf, "tvg-id"):
            sid = attr(cands[0][0], "tvg-id")
            if sid:
                block[0] = add_tvg_id(extinf, sid)
                dirty = True

        state = health(body)
        if state is True:
            continue                      # working -> keep exactly as it is

        if not cands:
            print("%s, no match in source: %s  (%s)"
                  % ("dead" if state is False else "unverifiable", name, reason(body)))
            continue

        fresh = [b for _, b in cands
                 if b != body and tuple(b) not in taken[nkey] and usable(b)]

        # 1) a candidate that is verified working
        new = next((b for b in fresh if health(b) is True), None)
        kind = "verified"

        # 2) none verified: if MY link is confirmed dead, take an unverifiable
        #    candidate (451/403/401) with the latest token expiry
        if new is None and state is False:
            unv = [b for b in fresh if health(b) is None]
            if unv:
                new = max(unv, key=lambda b: expiry(b) or 0)
                kind = "UNVERIFIED (blocked here, may work elsewhere)"

        if new:
            block[1] = list(new)
            taken[nkey].add(tuple(new))
            replaced += 1
            dirty = True
            print("replaced [%s] (%s match): %s  (was: %s)" % (kind, how, name, reason(body)))
        elif state is None:
            print("unverifiable, kept old link: %s  (%s)" % (name, reason(body)))
        else:
            print("dead, no replacement found: %s  (%s)" % (name, reason(body)))

    out = None
    if dirty:
        out = "\n".join(head + [x for e, b in mine for x in [e] + b]) + "\n"
    return out, replaced


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")


def check_ffmpeg():
    try:
        subprocess.run([FFMPEG_PATH, "-version"], capture_output=True, timeout=15, check=True)
    except Exception:
        sys.exit("ffmpeg not found (%s). Install it first, e.g. 'sudo apt-get install -y ffmpeg' "
                 "on the runner, or set FFMPEG_PATH." % FFMPEG_PATH)


def main():
    check_ffmpeg()
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
