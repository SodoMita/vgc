#!/usr/bin/env python3
"""Build Android APK using Qt6 androiddeployqt."""
import argparse
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir")
    parser.add_argument("build_dir")
    parser.add_argument("config")
    parser.add_argument("qt_root")
    args = parser.parse_args()

    build_dir = Path(args.build_dir)
    qt_root = Path(args.qt_root)
    # Find androiddeployqt
    androiddeployqt = qt_root / "bin" / "androiddeployqt"
    if not androiddeployqt.exists():
        androiddeployqt = qt_root / "bin" / "androiddeployqt.exe"
    if not androiddeployqt.exists():
        # Try to find via qmake
        androiddeployqt = qt_root / "bin" / "androiddeployqt"  # fallback
        # Instead search in PATH
        result = subprocess.run(["which", "androiddeployqt"], capture_output=True)
        if result.returncode == 0:
            androiddeployqt = Path(result.stdout.decode().strip())
    if not androiddeployqt.exists():
        print("androiddeployqt not found", file=sys.stderr)
        sys.exit(1)

    # We deploy the illustration app as APK
    app_target = "vgc_illustration_app"
    inputs = build_dir / args.config / "bin" / app_target
    # Also include necessary libs; androiddeployqt looks in build dir
    cmd = [
        str(androiddeployqt),
        "--input", str(inputs / "AndroidManifest.xml" if (inputs / "AndroidManifest.xml").exists() else inputs),
        "--output", str(build_dir / args.config / "android"),
        "--android-platform", "android-29",
        "--gradle",
    ]
    # If manifest missing, generate basic one
    manifest_path = inputs / "AndroidManifest.xml"
    if not manifest_path.exists():
        manifest_path.write_text(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
            'package="io.vgc.illustration" android:versionCode="1" android:versionName="alpha">'
            '<uses-sdk android:minSdkVersion="21" android:targetSdkVersion="29"/>'
            '<application android:label="VGC Illustration" android:icon="@mipmap/ic_launcher">'
            '<activity android:name="org.qtproject.qt5.android.bindings.QtActivity" '
            'android:configChanges="orientation|screenSize|smallestScreenSize" '
            'android:label="VGC Illustration">'
            '<intent-filter><action android:name="android.intent.action.MAIN"/>'
            '<category android:name="android.intent.category.LAUNCHER"/></intent-filter>'
            '</activity></application></manifest>')
        cmd[2] = "--input"; cmd[3] = str(manifest_path)

    print("Running:", " ".join(cmd))
    subprocess.check_call(cmd)
    print("APK built in", build_dir / args.config / "android")


if __name__ == "__main__":
    main()
