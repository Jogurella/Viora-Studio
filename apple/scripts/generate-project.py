#!/usr/bin/env python3
"""Generate a dependency-free multiplatform Xcode project from the checked-in sources."""
import hashlib, pathlib, plistlib
root=pathlib.Path(__file__).resolve().parents[1]
objects={}
def oid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(label,isa,**fields):
 key=oid(label); objects[key]=dict(isa=isa,**fields); return key
sources=[]; refs=[]
for path in sorted(list((root/'Sources').rglob('*.swift'))+list((root/'App').rglob('*.swift'))):
 if path.name.startswith('._'): continue
 rel=str(path.relative_to(root)); ref=add(rel,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=rel,sourceTree='<group>'); refs.append(ref)
 sources.append(add('build:'+rel,'PBXBuildFile',fileRef=ref))
assets=add('Assets','PBXFileReference',lastKnownFileType='folder.assetcatalog',path='App/Assets.xcassets',sourceTree='<group>'); refs.append(assets)
assetbuild=add('build:assets','PBXBuildFile',fileRef=assets)
fontbuilds=[]
for path in sorted((root/'App/Fonts').iterdir()):
 if path.name.startswith('._'): continue
 ref=add(str(path),'PBXFileReference',lastKnownFileType='file',path=str(path.relative_to(root)),sourceTree='<group>'); refs.append(ref)
 fontbuilds.append(add('build:'+str(path),'PBXBuildFile',fileRef=ref))
privacy=add('Privacy','PBXFileReference',lastKnownFileType='text.xml',path='App/PrivacyInfo.xcprivacy',sourceTree='<group>'); refs.append(privacy)
privacybuild=add('build:privacy','PBXBuildFile',fileRef=privacy)
product=add('product','PBXFileReference',explicitFileType='wrapper.application',path='Viora Studio.app',sourceTree='BUILT_PRODUCTS_DIR')
products=add('products','PBXGroup',children=[product],name='Products',sourceTree='<group>')
group=add('group','PBXGroup',children=refs+[products],sourceTree='<group>')
sourcephase=add('sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=sources,runOnlyForDeploymentPostprocessing=0)
frameworks=add('frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
resources=add('resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[assetbuild,privacybuild]+fontbuilds,runOnlyForDeploymentPostprocessing=0)
base=dict(PRODUCT_NAME='Viora Studio',PRODUCT_BUNDLE_IDENTIFIER='com.jogurella.viorastudio',SWIFT_VERSION='5.0',SDKROOT='auto',SUPPORTED_PLATFORMS='iphoneos iphonesimulator macosx',IPHONEOS_DEPLOYMENT_TARGET='17.0',MACOSX_DEPLOYMENT_TARGET='14.0',TARGETED_DEVICE_FAMILY='1',SUPPORTS_MACCATALYST='NO',GENERATE_INFOPLIST_FILE='YES',INFOPLIST_FILE='App/Info.plist',VIORA_DEFAULT_SERVER_URL='',INFOPLIST_KEY_CFBundleDisplayName='Viora Studio',INFOPLIST_KEY_LSApplicationCategoryType='public.app-category.graphics-design',INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription='Speichert von dir ausgewählte Viora-Ergebnisse in deiner Fotomediathek.',INFOPLIST_KEY_UIApplicationSceneManifest_Generation='YES',INFOPLIST_KEY_UILaunchScreen_Generation='YES',MARKETING_VERSION='0.1.0',CURRENT_PROJECT_VERSION='3',CODE_SIGN_STYLE='Automatic',ENABLE_HARDENED_RUNTIME='YES',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',SWIFT_EMIT_LOC_STRINGS='YES')
base['CODE_SIGN_ENTITLEMENTS[sdk=macosx*]']='App/macOS.entitlements'
configs=[]; projectconfigs=[]
for name in ['Debug','Release']:
 settings=base.copy(); settings['SWIFT_OPTIMIZATION_LEVEL']='-Onone' if name=='Debug' else '-O'; settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG' if name=='Debug' else ''
 configs.append(add('target:'+name,'XCBuildConfiguration',name=name,buildSettings=settings))
 projectconfigs.append(add('project:'+name,'XCBuildConfiguration',name=name,buildSettings=dict(CLANG_ENABLE_MODULES='YES',CLANG_ENABLE_OBJC_ARC='YES',ENABLE_USER_SCRIPT_SANDBOXING='YES')))
configlist=add('targetconfigs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
projectconfiglist=add('projectconfigs','XCConfigurationList',buildConfigurations=projectconfigs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
target=add('target','PBXNativeTarget',name='VioraStudio',productName='Viora Studio',productReference=product,productType='com.apple.product-type.application',buildConfigurationList=configlist,buildPhases=[sourcephase,frameworks,resources],buildRules=[],dependencies=[])
project=add('project','PBXProject',attributes={'LastUpgradeCheck':'2630','BuildIndependentTargetsInParallel':'YES'},buildConfigurationList=projectconfiglist,compatibilityVersion='Xcode 14.0',developmentRegion='de',knownRegions=['de','en','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[target])
projectdir=root/'VioraStudio.xcodeproj'; projectdir.mkdir(exist_ok=True)
(projectdir/'project.pbxproj').write_bytes(plistlib.dumps(dict(archiveVersion='1',classes={},objectVersion='56',objects=objects,rootObject=project)))
schemedir=projectdir/'xcshareddata/xcschemes'; schemedir.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Viora Studio.app" BlueprintName="VioraStudio" ReferencedContainer="container:VioraStudio.xcodeproj"/>'
(schemedir/'VioraStudio.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug"/><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
