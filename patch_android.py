from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
android = root / "android"
if not android.exists():
    raise SystemExit("Android project folder is missing. Generate it with flutter create first.")

kts = android / "app" / "build.gradle.kts"
groovy = android / "app" / "build.gradle"

if kts.exists():
    path = kts
    source = path.read_text(encoding="utf-8")

    def replace_required(pattern: str, replacement: str, content: str, label: str) -> str:
        updated, count = re.subn(pattern, replacement, content, count=1)
        if count != 1:
            raise SystemExit(f"Could not set {label} in {path}")
        return updated

    source = replace_required(
        r"(?m)^(\s*compileSdk\s*=\s*).+$",
        r"\g<1>37",
        source,
        "compileSdk=37",
    )
    source = replace_required(
        r"(?m)^(\s*minSdk\s*=\s*).+$",
        r"\g<1>26",
        source,
        "minSdk=26",
    )
    source = re.sub(
        r"(?m)^(\s*sourceCompatibility\s*=\s*)JavaVersion\.[A-Z0-9_]+.*$",
        r"\g<1>JavaVersion.VERSION_17",
        source,
    )
    source = re.sub(
        r"(?m)^(\s*targetCompatibility\s*=\s*)JavaVersion\.[A-Z0-9_]+.*$",
        r"\g<1>JavaVersion.VERSION_17",
        source,
    )
    path.write_text(source, encoding="utf-8")

elif groovy.exists():
    path = groovy
    source = path.read_text(encoding="utf-8")

    def replace_required(pattern: str, replacement: str, content: str, label: str) -> str:
        updated, count = re.subn(pattern, replacement, content, count=1)
        if count != 1:
            raise SystemExit(f"Could not set {label} in {path}")
        return updated

    if re.search(r"(?m)^\s*compileSdkVersion\s+", source):
        source = replace_required(
            r"(?m)^(\s*compileSdkVersion\s+).+$",
            r"\g<1>37",
            source,
            "compileSdkVersion=37",
        )
    else:
        source = replace_required(
            r"(?m)^(\s*compileSdk\s+).+$",
            r"\g<1>37",
            source,
            "compileSdk=37",
        )

    if re.search(r"(?m)^\s*minSdkVersion\s+", source):
        source = replace_required(
            r"(?m)^(\s*minSdkVersion\s+).+$",
            r"\g<1>26",
            source,
            "minSdkVersion=26",
        )
    else:
        source = replace_required(
            r"(?m)^(\s*minSdk\s+).+$",
            r"\g<1>26",
            source,
            "minSdk=26",
        )

    source = re.sub(
        r"(?m)^(\s*sourceCompatibility\s+)JavaVersion\.VERSION_[A-Z0-9_]+.*$",
        r"\g<1>JavaVersion.VERSION_17",
        source,
    )
    source = re.sub(
        r"(?m)^(\s*targetCompatibility\s+)JavaVersion\.VERSION_[A-Z0-9_]+.*$",
        r"\g<1>JavaVersion.VERSION_17",
        source,
    )
    path.write_text(source, encoding="utf-8")
else:
    raise SystemExit("Could not find android/app/build.gradle(.kts).")

manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
if manifest.exists():
    content = manifest.read_text(encoding="utf-8")
    content = re.sub(
        r'android:label="[^"]*"',
        'android:label="TUN VPNSOPR"',
        content,
        count=1,
    )
    if "android.permission.CAMERA" not in content:
        match = re.search(r"<manifest\b[^>]*>", content)
        if not match:
            raise SystemExit("AndroidManifest.xml has no manifest tag.")
        content = (
            content[:match.end()]
            + '\n    <uses-permission android:name="android.permission.CAMERA" />'
            + content[match.end():]
        )
    manifest.write_text(content, encoding="utf-8")

print("Android settings patched: compileSdk=37, minSdk=26, Java 17, camera permission, app label.")
