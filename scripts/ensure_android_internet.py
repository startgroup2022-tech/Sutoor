"""Add Android release INTERNET permission so authenticated REST APIs work in APK/AAB."""
from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text(encoding='utf-8')
marker = '<application'
permission = '<uses-permission android:name="android.permission.INTERNET" />'
if permission not in s:
    assert marker in s, 'Unexpected AndroidManifest structure'
    s = s.replace(marker, permission + '\n    ' + marker, 1)
    p.write_text(s, encoding='utf-8')
print('Android internet permission ready')
