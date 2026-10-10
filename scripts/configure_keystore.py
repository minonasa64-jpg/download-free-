import os

p = 'android/app/build.gradle'
if not os.path.exists(p):
    print(f"File not found: {p}")
    exit(0)

with open(p, 'r') as f:
    s = f.read()

signing_code = '''
    signingConfigs {
        release {
            storeFile file('boykta_release.keystore')
            storePassword 'boykta2026pro'
            keyAlias 'boyktapro'
            keyPassword 'boykta2026pro'
            v1SigningEnabled true
            v2SigningEnabled true
        }
    }
'''

if 'signingConfigs {' not in s:
    s = s.replace('android {', 'android {\n' + signing_code, 1)

if 'signingConfig signingConfigs.debug' in s:
    s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release')
elif 'buildTypes {' in s:
    s = s.replace('buildTypes {', 'buildTypes {\n        release {\n            signingConfig signingConfigs.release\n        }')

with open(p, 'w') as f:
    f.write(s)

print("build.gradle successfully configured with release signing!")
