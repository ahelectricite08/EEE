#!/usr/bin/env python3
"""
Patch xcodeproj constants.rb to accept any Xcode object version not yet known.
Reads the project file to detect the actual version, then inserts it.
Usage: python3 patch_xcodeproj.py /path/to/constants.rb
"""
import sys, re, glob

if len(sys.argv) < 2:
    print("Usage: patch_xcodeproj.py <constants.rb>")
    sys.exit(1)

f = sys.argv[1]
c = open(f).read()

# Anchor line present in all xcodeproj versions
anchor = "77 => 'Xcode 16.0',"

# Versions we always want to add
versions_to_patch = {70: 'Xcode 16.4'}

# Auto-detect object version from project file
for pbxproj in glob.glob('ios/*.xcodeproj/project.pbxproj'):
    m = re.search(r'objectVersion = (\d+)', open(pbxproj).read())
    if m:
        v = int(m.group(1))
        if v not in versions_to_patch:
            versions_to_patch[v] = f'Xcode {v}'
        break

c2 = c
for v, label in versions_to_patch.items():
    entry = f"{v} => '{label}',"
    if entry not in c2 and anchor in c2:
        c2 = c2.replace(anchor, f"{anchor}\n      {entry}")

open(f, 'w').write(c2)
patched = [v for v in versions_to_patch if f'{v} =>' in c2]
print(f"PATCHED OK: versions {patched}" if patched else "NOT PATCHED — anchor not found")
