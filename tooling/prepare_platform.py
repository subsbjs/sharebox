import os, pathlib, shutil, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
os.chdir(root)
platform = 'windows' if os.name == 'nt' else 'android'
with tempfile.TemporaryDirectory(prefix='sharebox-template-') as tmp:
    template = pathlib.Path(tmp)/'sharebox'
    subprocess.run(['flutter', 'create', '--no-pub', '--platforms='+platform, '--org', 'com.sharebox', '--project-name', 'sharebox', str(template)], check=True, shell=(os.name=='nt'))
    if not (root/platform).exists():
        shutil.copytree(template/platform, root/platform)
if platform == 'android':
    p=root/'android/app/src/main/AndroidManifest.xml'
    s=p.read_text()
    if 'android.permission.INTERNET' not in s:
        i=s.index('>')+1
        s=s[:i]+'\n    <uses-permission android:name="android.permission.INTERNET" />'+s[i:]
    p.write_text(s.replace('android:label="sharebox"','android:label="ShareBox"'))
    activity = root/'android/app/src/main/kotlin/com/sharebox/sharebox/MainActivity.kt'
    activity.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root/'platform/android/MainActivity.kt', activity)
else:
    # Flutter's native runner exits its message loop when the main window closes.
    # Fail the build if a changed template no longer provides this guarantee.
    main = (root/'windows/runner/main.cpp').read_text()
    window = (root/'windows/runner/win32_window.cpp').read_text()
    assert 'SetQuitOnClose(true)' in main, 'Windows runner must quit on close'
    assert 'PostQuitMessage' in window, 'Windows runner must terminate its event loop'
