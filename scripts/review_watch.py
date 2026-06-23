import time, json, os, urllib.request, urllib.error
import jwt

KEY_ID = "DSS2FFU68G"
ISSUER = "a5ebdab5-0ceb-463c-8151-195b902f117b"
P8 = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_DSS2FFU68G.p8")
STATE_FILE = os.path.expanduser("~/.config/midgar/review_state.json")

# apps submitted with the MidgarKit "More Apps" integration
APPS = [
    ("6746733380", "App of the Dead", ["IOS"]),
    ("6779927672", "Pay Day", ["IOS"]),
    ("6777952645", "Psybeam", ["IOS"]),
    ("1523538855", "Inventory", ["IOS"]),
    ("1484270248", "Master of Flags", ["IOS"]),
    ("6661019277", "Dream Eater", ["IOS"]),
    ("6727000827", "Psywave", ["IOS"]),
    ("6736581403", "Double Kick", ["IOS"]),
    ("6705124497", "Solar Beam", ["IOS", "MAC_OS", "VISION_OS"]),
]

IN_FLIGHT = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "PROCESSING_FOR_APP_STORE"}
REJECTED = {"REJECTED", "METADATA_REJECTED", "DEVELOPER_REJECTED", "INVALID_BINARY"}
APPROVED = {"READY_FOR_SALE", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE"}

TOK = jwt.encode({"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                 open(P8).read(), algorithm="ES256", headers={"kid": KEY_ID})


def get(path):
    """Returns parsed JSON, or None on a transient failure after retries. Fails fast."""
    for attempt in range(2):
        req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path,
                                     headers={"Authorization": "Bearer " + TOK})
        try:
            return json.load(urllib.request.urlopen(req, timeout=15))
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 1:
                time.sleep(2); continue
            return {"_error": e.code}
        except Exception:
            if attempt < 1:
                time.sleep(2); continue
            return None
    return None


def current_states():
    states, complete = {}, True
    for app_id, name, platforms in APPS:
        for plat in platforms:
            v = get(f"/v1/apps/{app_id}/appStoreVersions?filter[platform]={plat}&limit=1")
            if not isinstance(v, dict) or "data" not in v:
                complete = False
                continue
            data = v["data"]
            if data:
                a = data[0]["attributes"]
                states[f"{name} [{plat}]"] = {"version": a.get("versionString"), "state": a.get("appStoreState")}
    return states, complete


def load_prev():
    try:
        return json.load(open(STATE_FILE))
    except Exception:
        return {}


def main():
    prev = load_prev()
    cur, complete = current_states()

    if not complete:
        # Don't overwrite the good snapshot or diff against a partial read.
        print(f"⚠ Incomplete read ({len(cur)}/11) — App Store Connect API errored on some apps. "
              f"Keeping the previous snapshot; will reconcile next run.")
        return

    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    json.dump(cur, open(STATE_FILE, "w"), indent=2)

    changes, rejections = [], []
    for key, info in cur.items():
        old = prev.get(key, {}).get("state")
        if old != info["state"]:
            changes.append(f"  CHANGED  {key}  {info['version']}  {old or '(new)'} -> {info['state']}")
        if info["state"] in REJECTED:
            rejections.append(f"{key} ({info['version']})")

    print(f"=== MidgarKit submissions — {len(cur)} tracked ===")
    for key, info in sorted(cur.items()):
        flag = "  <-- ACTION" if info["state"] in REJECTED else ("  ✓" if info["state"] in APPROVED else "")
        print(f"  {key:26} {info['version']:7} {info['state']}{flag}")
    print()
    print("CHANGES SINCE LAST CHECK:\n" + "\n".join(changes) if changes else "No changes since last check.")
    if rejections:
        print("\n⚠ REJECTED — needs resubmission:", ", ".join(rejections))


if __name__ == "__main__":
    main()
