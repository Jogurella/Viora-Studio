#!/usr/bin/env python3
"""Inspect a real signed iPhone IPA; emit a feed only after matching its published bytes."""
import argparse, datetime, hashlib, json, os, pathlib, plistlib, stat, subprocess, tempfile, urllib.request, urllib.parse, zipfile

def digest(stream):
    h=hashlib.sha256(); size=0
    while block:=stream.read(1024*1024):
        size+=len(block)
        if size>1024*1024*1024: raise ValueError('Artifact exceeds 1 GiB limit')
        h.update(block)
    return h.hexdigest(),size

def inspect_ipa(path):
    with path.open('rb') as stream: sha,size=digest(stream)
    with tempfile.TemporaryDirectory() as temporary:
        root=pathlib.Path(temporary)
        with zipfile.ZipFile(path) as archive:
            if sum(x.file_size for x in archive.infolist())>1024*1024*1024: raise ValueError('Unpacked IPA exceeds 1 GiB')
            for item in archive.infolist():
                parts=pathlib.PurePosixPath(item.filename)
                if parts.is_absolute() or '..' in parts.parts or stat.S_ISLNK(item.external_attr>>16): raise ValueError('Unsafe archive entry')
            archive.extractall(root)
            for item in archive.infolist():
                target=root/item.filename
                if target.is_file(): target.chmod((item.external_attr>>16)&0o777 or 0o644)
        apps=list((root/'Payload').glob('*.app'))
        if len(apps)!=1: raise ValueError('Expected one app in Payload')
        app=apps[0]
        if list(app.rglob('*.appex')): raise ValueError('App extensions need explicit permission aggregation')
        info=plistlib.loads((app/'Info.plist').read_bytes())
        if info.get('DTPlatformName')!='iphoneos': raise ValueError('Not an iPhone device build')
        subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True,capture_output=True)
        raw=subprocess.run(['codesign','-d','--entitlements',':-',str(app)],check=True,capture_output=True).stdout
        entitlements=plistlib.loads(raw[raw.index(b'<?xml'):])
        profile=subprocess.run(['security','cms','-D','-i',str(app/'embedded.mobileprovision')],check=True,capture_output=True).stdout
        expiry=plistlib.loads(profile)['ExpirationDate']
        if expiry.replace(tzinfo=datetime.timezone.utc)<=datetime.datetime.now(datetime.timezone.utc): raise ValueError('Provisioning profile expired')
        return dict(sha256=sha,size=size,bundleIdentifier=info['CFBundleIdentifier'],version=info['CFBundleShortVersionString'],buildVersion=info['CFBundleVersion'],minOSVersion=info['MinimumOSVersion'],profileExpires=expiry.isoformat()+'Z',appPermissions=dict(entitlements=sorted(entitlements),privacy={k:v for k,v in info.items() if k.startswith('NS') and 'UsageDescription' in k}))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ipa',type=pathlib.Path,required=True); parser.add_argument('--inspect',action='store_true')
    parser.add_argument('--download-url'); parser.add_argument('--icon-url'); parser.add_argument('--output',type=pathlib.Path)
    args=parser.parse_args(); details=inspect_ipa(args.ipa)
    if args.inspect: print(json.dumps(details,indent=2)); return
    if not all([args.download_url,args.icon_url,args.output]): parser.error('Feed requires --download-url, --icon-url and --output')
    expected='https://github.com/Jogurella/Viora-Studio/releases/download/'
    if not args.download_url.startswith(expected) or not args.download_url.endswith('.ipa'): raise ValueError('Use a real Viora Studio GitHub release IPA URL')
    if urllib.parse.urlparse(args.icon_url).scheme!='https': raise ValueError('Icon URL must use HTTPS')
    with urllib.request.urlopen(args.download_url,timeout=30) as response: remote_sha,remote_size=digest(response)
    if (remote_sha,remote_size)!=(details['sha256'],details['size']): raise ValueError('Published artifact does not match this IPA')
    with urllib.request.urlopen(args.icon_url,timeout=30) as response:
        if not response.headers.get('Content-Type','').startswith('image/'): raise ValueError('Icon URL is not an image')
    version={k:details[k] for k in ['version','buildVersion','size','minOSVersion']}
    version.update(date=datetime.datetime.now(datetime.timezone.utc).isoformat(),downloadURL=args.download_url,localizedDescription='Native Apple preview; see platform test status in the repository.')
    app=dict(name='Viora Studio',bundleIdentifier=details['bundleIdentifier'],developerName='Jogurella',localizedDescription='Native Bilder und Videos über deinen privaten SwarmUI-Server.',iconURL=args.icon_url,tintColor='8B7BFF',versions=[version],appPermissions=details['appPermissions'])
    with args.output.open('x') as output: json.dump(dict(name='Viora Studio',apps=[app],news=[]),output,indent=2,ensure_ascii=False)
    print('Created feed:',args.output)
if __name__=='__main__': main()
