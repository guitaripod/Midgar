import time, json, os, sys, urllib.request, urllib.error
import jwt

KEY_ID = "DSS2FFU68G"
ISSUER = "a5ebdab5-0ceb-463c-8151-195b902f117b"
P8 = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_DSS2FFU68G.p8")

APPS = {
    "1484270248": "knowtheflag", "1523538855": "inventory", "6661019277": "DreamEater",
    "6746733380": "aotd", "6751730339": "Pixie", "6705124497": "solarbeam",
    "6736438070": "sforesight", "6727000827": "psywave", "6736581403": "doublekick",
    "6779927672": "payday", "6777952645": "psybeam",
}

IPHONE_PRIORITY = ["APP_IPHONE_67", "APP_IPHONE_69", "APP_IPHONE_65", "APP_IPHONE_61", "APP_IPHONE_58", "APP_IPHONE_55", "APP_IPHONE_47"]
MAX_SHOTS = 6


def token():
    payload = {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, open(P8).read(), algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


TOK = token()


def get(path):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, headers={"Authorization": "Bearer " + TOK})
    try:
        return json.load(urllib.request.urlopen(req, timeout=40))
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "_body": e.read().decode()[:200]}


def screenshot_url(asset):
    t = asset.get("templateUrl")
    if not t:
        return None
    return t.replace("{w}", str(asset.get("width", 1290))).replace("{h}", str(asset.get("height", 2796))).replace("{f}", "png")


def shots_for_localization(loc_id):
    sets = get(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=50")
    if "data" not in sets:
        return []
    iphone_sets = [s for s in sets["data"] if str(s["attributes"].get("screenshotDisplayType", "")).startswith("APP_IPHONE")]
    if not iphone_sets:
        return []

    def rank(s):
        dt = s["attributes"].get("screenshotDisplayType", "")
        return IPHONE_PRIORITY.index(dt) if dt in IPHONE_PRIORITY else 99
    iphone_sets.sort(key=rank)
    for s in iphone_sets:
        shots = get(f"/v1/appScreenshotSets/{s['id']}/appScreenshots?limit=10")
        urls = []
        for sc in shots.get("data", []):
            asset = sc["attributes"].get("imageAsset")
            if asset:
                u = screenshot_url(asset)
                if u:
                    urls.append(u)
        if urls:
            return urls[:MAX_SHOTS]
    return []


def shots_for_app(app_id):
    versions = get(f"/v1/apps/{app_id}/appStoreVersions?limit=5")
    for v in versions.get("data", []):
        locs = get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations?limit=50")
        loc_data = locs.get("data", [])
        ordered = sorted(loc_data, key=lambda l: 0 if l["attributes"].get("locale") == "en-US" else 1)
        for loc in ordered:
            urls = shots_for_localization(loc["id"])
            if urls:
                return urls, v["attributes"].get("versionString"), loc["attributes"].get("locale")
    return [], None, None


result = {}
for app_id, name in APPS.items():
    urls, ver, locale = shots_for_app(app_id)
    result[app_id] = urls
    print(f"{name:14} {app_id}  {len(urls)} shots  (v{ver}, {locale})", file=sys.stderr)

json.dump(result, open("/tmp/midgar_screenshots.json", "w"), indent=1)
print("wrote /tmp/midgar_screenshots.json", file=sys.stderr)
