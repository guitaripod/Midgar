import sys

PBX = "/Users/marcus/Dev/ios/DreamEater/DreamEater.xcodeproj/project.pbxproj"

PKG = "ADEAD0DEADBEEF0000000011"
PROD = "ADEAD0DEADBEEF0000000012"
BUILD = "ADEAD0DEADBEEF0000000013"

text = open(PBX).read()
if "guitaripod/Midgar" in text:
    print("Midgar already present; nothing to do")
    sys.exit(0)

lines = text.split("\n")


def indent(line):
    return line[: len(line) - len(line.lstrip("\t"))]


def insert_after_token(token, new_lines, expect=1):
    hits = [i for i, l in enumerate(lines) if token in l]
    if len(hits) != expect:
        sys.exit(f"anchor {token!r} found {len(hits)} times, expected {expect}")
    i = hits[0]
    for j, nl in enumerate(new_lines):
        lines.insert(i + 1 + j, nl)


def insert_before_token(token, new_lines, expect=1):
    hits = [i for i, l in enumerate(lines) if token in l]
    if len(hits) != expect:
        sys.exit(f"anchor {token!r} found {len(hits)} times, expected {expect}")
    i = hits[0]
    for j, nl in enumerate(new_lines):
        lines.insert(i + j, nl)


# 1. Frameworks build phase files list
anchor = "ACED175C0000000000000013 /* AICreditsCore in Frameworks */,"
ind = indent(next(l for l in lines if anchor in l))
insert_after_token(anchor, [f"{ind}{BUILD} /* Midgar in Frameworks */,"])

# 2. app target packageProductDependencies list
anchor = "ACED175C0000000000000012 /* AICreditsCore */,"
ind = indent(next(l for l in lines if anchor in l))
insert_after_token(anchor, [f"{ind}{PROD} /* Midgar */,"])

# 3. project packageReferences list
anchor = 'ACED175C0000000000000011 /* XCRemoteSwiftPackageReference "AICredits" */,'
ind = indent(next(l for l in lines if anchor in l))
insert_after_token(anchor, [f'{ind}{PKG} /* XCRemoteSwiftPackageReference "Midgar" */,'])

# 4. PBXBuildFile object
anchor = "ACED175C0000000000000013 /* AICreditsCore in Frameworks */ = {isa = PBXBuildFile;"
ind = indent(next(l for l in lines if anchor in l))
insert_after_token(
    anchor,
    [f"{ind}{BUILD} /* Midgar in Frameworks */ = {{isa = PBXBuildFile; productRef = {PROD} /* Midgar */; }};"],
)

# 5. XCSwiftPackageProductDependency object
anchor_obj = "ACED175C0000000000000012 /* AICreditsCore */ = {"
ind = indent(next(l for l in lines if anchor_obj in l))
t = "\t"
insert_before_token(
    "/* End XCSwiftPackageProductDependency section */",
    [
        f"{ind}{PROD} /* Midgar */ = {{",
        f"{ind}{t}isa = XCSwiftPackageProductDependency;",
        f'{ind}{t}package = {PKG} /* XCRemoteSwiftPackageReference "Midgar" */;',
        f"{ind}{t}productName = Midgar;",
        f"{ind}}};",
    ],
)

# 6. XCRemoteSwiftPackageReference object
anchor_obj = 'ACED175C0000000000000011 /* XCRemoteSwiftPackageReference "AICredits" */ = {'
ind = indent(next(l for l in lines if anchor_obj in l))
insert_before_token(
    "/* End XCRemoteSwiftPackageReference section */",
    [
        f'{ind}{PKG} /* XCRemoteSwiftPackageReference "Midgar" */ = {{',
        f"{ind}{t}isa = XCRemoteSwiftPackageReference;",
        f'{ind}{t}repositoryURL = "https://github.com/guitaripod/Midgar";',
        f"{ind}{t}requirement = {{",
        f"{ind}{t}{t}kind = upToNextMajorVersion;",
        f"{ind}{t}{t}minimumVersion = 1.0.0;",
        f"{ind}{t}}};",
        f"{ind}}};",
    ],
)

open(PBX, "w").write("\n".join(lines))
print("patched DreamEater pbxproj with Midgar")
