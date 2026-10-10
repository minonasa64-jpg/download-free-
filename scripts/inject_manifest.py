import xml.etree.ElementTree as ET
import os

path = 'android/app/src/main/AndroidManifest.xml'
if not os.path.exists(path):
    print(f"File not found: {path}")
    exit(0)

ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
tree = ET.parse(path)
root = tree.getroot()

perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.ACCESS_WIFI_STATE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
    'com.google.android.gms.permission.AD_ID',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.USE_BIOMETRIC',
    'android.permission.USE_FINGERPRINT',
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'
]

# Collect existing permissions
existing_perms = set()
for elem in root.findall('uses-permission'):
    name = elem.get('{http://schemas.android.com/apk/res/android}name')
    if name:
        existing_perms.add(name)

for p in perms:
    if p not in existing_perms:
        e = ET.Element('uses-permission')
        e.set('{http://schemas.android.com/apk/res/android}name', p)
        root.insert(0, e)

# Inject modern targetSdkVersion 34 to avoid Google Play Protect warning
uses_sdk = root.find('uses-sdk')
if uses_sdk is None:
    uses_sdk = ET.Element('uses-sdk')
    root.insert(0, uses_sdk)
uses_sdk.set('{http://schemas.android.com/apk/res/android}minSdkVersion', '24')
uses_sdk.set('{http://schemas.android.com/apk/res/android}targetSdkVersion', '34')
    
app = root.find('application')
if app is not None:
    app.set('{http://schemas.android.com/apk/res/android}largeHeap', 'true')
    app.set('{http://schemas.android.com/apk/res/android}requestLegacyExternalStorage', 'true')
    app.set('{http://schemas.android.com/apk/res/android}usesCleartextTraffic', 'true')
    app.set('{http://schemas.android.com/apk/res/android}hardwareAccelerated', 'true')
    app.set('{http://schemas.android.com/apk/res/android}extractNativeLibs', 'true')

    for act in app.findall('activity'):
        if '{http://schemas.android.com/apk/res/android}taskAffinity' in act.attrib:
            del act.attrib['{http://schemas.android.com/apk/res/android}taskAffinity']
        act.set('{http://schemas.android.com/apk/res/android}supportsPictureInPicture', 'true')
        act.set('{http://schemas.android.com/apk/res/android}configChanges', 'orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode')
    
tree.write(path, encoding='utf-8', xml_declaration=True)
print("AndroidManifest.xml successfully configured!")
