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
