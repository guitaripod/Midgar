import sys, re

pbx = sys.argv[1]
lines = open(pbx).read().split("\n")
changed = False
for i, l in enumerate(lines):
    if 'repositoryURL = "https://github.com/guitaripod/Midgar"' in l:
        lines[i] = l.replace("guitaripod/Midgar", "guitaripod/MidgarKit")
        changed = True
        for j in range(i, min(i + 8, len(lines))):
            if "minimumVersion" in lines[j]:
                lines[j] = re.sub(r"minimumVersion = [^;]+;", "minimumVersion = 2.0.0;", lines[j])
                break

out = "\n".join(lines)
out = out.replace("productName = Midgar;", "productName = MidgarKit;")
out = out.replace('XCRemoteSwiftPackageReference "Midgar"', 'XCRemoteSwiftPackageReference "MidgarKit"')
out = out.replace("/* Midgar */", "/* MidgarKit */")
out = out.replace("Midgar in Frameworks", "MidgarKit in Frameworks")
open(pbx, "w").write(out)
print(("updated " if changed else "NO Midgar ref in ") + pbx)
