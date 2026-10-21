"""
Removes DEAD channels from data/TestTypes.m3u (run BEFORE merge_all.py).

Uses the same checker as sync.py (token expiry, manifest fetch, key/KID match,
real ffmpeg decode), so "dead" means exactly the same thing in both scripts.

  working       -> kept
  dead          -> removed (expired token, HTTP 404/410/5xx, bad manifest,
                   decode failed, key mismatch, request failed ...)
  unverifiable  -> kept (HTTP 401/403/451 = blocked for this machine, NOT proven dead)
                   set REMOVE_UNVERIFIABLE=1 to remove these too

Safety: if nothing at all could be verified, or too many entries would be removed
(network outage on the runner?), the file is left untouched.
"""
import os
import sys
from concurrent.futures import ThreadPoolExecutor

import sync  # your existing checker script (sync.py in the same folder)

TARGET = os.environ.get("TARGET", "data/TestTypes.m3u")
REMOVE_UNVERIFIABLE = os.environ.get("REMOVE_UNVERIFIABLE", "0") == "1"
MAX_REMOVE_FRACTION = float(os.environ.get("MAX_REMOVE_FRACTION", "0.95"))
MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "8"))


def main():
    sync.check_ffmpeg()
    with open(TARGET, encoding="utf-8", errors="ignore") as f:
        text = f.read()

    head, blocks = sync.parse(text)
    total = len(blocks)
    print("loaded %d entries from %s" % (total, TARGET))
    if not total:
        return

    # check every unique entry once, in parallel
    uniq = list({tuple(b) for _, b in blocks if sync.url_of(b)})
    results = {}
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        for b, res in zip(uniq, ex.map(lambda b: sync._check(list(b)), uniq)):
            results[b] = res

    keep, removed = [], []
    n_ok = n_unv = 0
    for extinf, body in blocks:
        state, why = results.get(tuple(body), (False, "no url"))
        if state is True:
            n_ok += 1
            keep.append((extinf, body))
        elif state is None:
            n_unv += 1
            if REMOVE_UNVERIFIABLE:
                removed.append((extinf, why))
            else:
                keep.append((extinf, body))
        else:
            removed.append((extinf, why))

    print("working: %d | unverifiable: %d | dead: %d"
          % (n_ok, n_unv, len(removed) - (n_unv if REMOVE_UNVERIFIABLE else 0)))

    # safety guards
    if n_ok + n_unv == 0:
        print("NOTHING could be verified (network/ffmpeg problem?) - file left untouched.")
        return
    if len(removed) / total > MAX_REMOVE_FRACTION:
        print("would remove %d of %d entries (> %.0f%%) - file left untouched."
              % (len(removed), total, MAX_REMOVE_FRACTION * 100))
        return

    for extinf, why in removed:
        print("removed: %s  (%s)" % (sync.display_name(extinf), why))

    if removed:
        out = "\n".join(head + [x for e, b in keep for x in [e] + b]) + "\n"
        with open(TARGET, "w", encoding="utf-8") as f:
            f.write(out)
    print("total removed:", len(removed), "| remaining:", len(keep))


if __name__ == "__main__":
    main()