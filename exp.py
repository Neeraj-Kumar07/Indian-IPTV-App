import re
import urllib.request

from sync import SOURCES


def count(text):
    return {
        "keyURL": len(re.findall(r"license_key=https?://", text, re.I)),
        "json": len(re.findall(r"license_key=\{", text)),
        "multi": len(re.findall(r"license_key=[0-9a-fA-F]{32}:[0-9a-fA-F]{32},", text)),
        "non-clearkey": len(re.findall(r"license_type=(?!clearkey)", text, re.I)),
    }


for u in dict.fromkeys(SOURCES):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        t = urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "ignore")
        print(u.rsplit("/", 1)[-1], count(t))
    except Exception as e:
        print(u.rsplit("/", 1)[-1], "FAILED:", e)

with open("data/Entertainments.m3u", encoding="utf-8") as f:
    print("MY Entertainments.m3u", count(f.read()))