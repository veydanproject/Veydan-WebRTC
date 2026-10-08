#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Veydan Project
# SPDX-License-Identifier: LicenseRef-PolyForm-Perimeter-1.0.1
#
# Stamps every class file of a jar as a class file of the given major
# version at most (default 61, Java 17), in place:
#
#   jar-class-version.py [--major N] <file.jar>
#
# The Android tree compiles its Java for Java 21 (major 65) and uses nothing
# of it; the stamp alone is enough for the dexer of an older Android Gradle
# plugin to refuse the jar. Only the two bytes of the version change.
import argparse
import os
import zipfile

MAGIC = b"\xca\xfe\xba\xbe"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--major", type=int, default=61)
    parser.add_argument("jar")
    args = parser.parse_args()
    tmp = args.jar + ".tmp"
    changed = 0
    with zipfile.ZipFile(args.jar) as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as dst:
        for item in src.infolist():
            data = src.read(item)
            if item.filename.endswith(".class") and data[:4] == MAGIC and int.from_bytes(data[6:8], "big") > args.major:
                data = data[:6] + args.major.to_bytes(2, "big") + data[8:]
                changed += 1
            dst.writestr(item, data)
    os.replace(tmp, args.jar)
    print(f">> {args.jar}: {changed} class files stamped as major {args.major}")


if __name__ == "__main__":
    main()
