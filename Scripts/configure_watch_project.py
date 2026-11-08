"""Add the independent SwiftUI watchOS companion and its UI test target."""
from pathlib import Path
import hashlib,json,subprocess

def configure_watch(root, previous):
 project=root/'NumberTheory.xcodeproj'; file=project/'project.pbxproj'
 data=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(file)]))
 objects=data['objects']
 def ref(key):return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
 def obj(key,**value):objects[ref(key)]=value;return ref(key)
 core=list(root.glob('Sources/NumberTheoryCore/**/*.swift'))
 shared=list(root.glob('App/Shared/**/*.swift'))
 features=[]
 for directory in ['Course','Cipolla','BerlekampRabin']:
  features+=list((root/'App/Features'/directory).glob('*.swift'))
 for name in ['BinaryDivision/NotebookDivisionView.swift','BinaryDivision/DivisionMathViews.swift','Doubling/NotebookDoublingView.swift','ModularArithmetic/NotebookModularView.swift','ModularArithmetic/ModularMathViews.swift','Polynomials/NotebookPolynomialView.swift','Polynomials/PolynomialMathViews.swift']:
  features.append(root/'App/Features'/name)
 sources=sorted(set(core+shared+features+list(root.glob('WatchApp/**/*.swift'))))
 tests=sorted(root.glob('WatchUITests/**/*.swift'))
 for path in sources+tests:
  rel=path.relative_to(root).as_posix()
  objects.setdefault(ref(rel),dict(isa='PBXFileReference',lastKnownFileType='sourcecode.swift',path=rel,sourceTree='SOURCE_ROOT'))
  obj('watch-build:'+rel,isa='PBXBuildFile',fileRef=ref(rel))
 def group(directory):
  files=sorted({p.relative_to(root).as_posix() for p in sources+tests if p.relative_to(root).as_posix().startswith(directory+'/')})
  prefix=directory+'/'
  children=[group(prefix+x) for x in sorted({p[len(prefix):].split('/')[0] for p in files if '/' in p[len(prefix):]})]
  children += [ref(p) for p in files if '/' not in p[len(prefix):]]
  return obj('group:'+directory,isa='PBXGroup',name=Path(directory).name,children=children,sourceTree='<group>')
 objects[ref('root-group')]['children'] += [group('WatchApp'),group('WatchUITests')]
 for name,files in [('watch',sources),('watchtests',tests)]:
  obj(name+'-sources',isa='PBXSourcesBuildPhase',buildActionMask=2147483647,files=[ref('watch-build:'+p.relative_to(root).as_posix()) for p in files],runOnlyForDeploymentPostprocessing=0)
  obj(name+'-frameworks',isa='PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
  obj(name+'-resources',isa='PBXResourcesBuildPhase',buildActionMask=2147483647,files=[ref(x) for x in ['watch-assets-build','watch-course-build','watch-library-build']] if name=='watch' else [],runOnlyForDeploymentPostprocessing=0)
 obj('watch-assets',isa='PBXFileReference',lastKnownFileType='folder.assetcatalog',path='WatchApp/Resources/Assets.xcassets',sourceTree='SOURCE_ROOT')
 objects[ref('group:WatchApp')]['children'].append(ref('watch-assets'))
 obj('watch-assets-build',isa='PBXBuildFile',fileRef=ref('watch-assets'))
 obj('watch-course-build',isa='PBXBuildFile',fileRef=ref('course-folder'))
 obj('watch-library-build',isa='PBXBuildFile',fileRef=ref('Sources/NumberTheoryCore/Reference/course-library.json'))
 for name,product in [('watch','NumberTheoryWatch.app'),('watchtests','NumberTheoryWatchUITests.xctest')]:
  obj(name+'-product',isa='PBXFileReference',explicitFileType='wrapper.application' if name=='watch' else 'wrapper.cfbundle',includeInIndex=0,path=product,sourceTree='BUILT_PRODUCTS_DIR')
  objects[ref('products')]['children'].append(ref(name+'-product'))
 obj('watch-proxy',isa='PBXContainerItemProxy',containerPortal=ref('project'),proxyType=1,remoteGlobalIDString=ref('watch-target'),remoteInfo='NumberTheoryWatch')
 obj('watch-dependency',isa='PBXTargetDependency',target=ref('watch-target'),targetProxy=ref('watch-proxy'))
 for name,title in [('watch','NumberTheoryWatch'),('watchtests','NumberTheoryWatchUITests')]:
  obj(name+'-target',isa='PBXNativeTarget',buildConfigurationList=ref(name+'-configs'),buildPhases=[ref(name+'-'+x) for x in ['sources','frameworks','resources']],buildRules=[],dependencies=[] if name=='watch' else [ref('watch-dependency')],name=title,productName=title,productReference=ref(name+'-product'),productType='com.apple.product-type.application' if name=='watch' else 'com.apple.product-type.bundle.ui-testing')
  for config in ['Debug','Release']:
   phone=objects[ref('app-'+config)]['buildSettings'];settings=dict(SWIFT_VERSION='6.0',SDKROOT='watchos',SUPPORTED_PLATFORMS='watchos watchsimulator',WATCHOS_DEPLOYMENT_TARGET='10.0',TARGETED_DEVICE_FAMILY='4',PRODUCT_NAME='$(TARGET_NAME)',GENERATE_INFOPLIST_FILE='YES',CODE_SIGN_STYLE='Automatic',PRODUCT_BUNDLE_IDENTIFIER=phone['PRODUCT_BUNDLE_IDENTIFIER']+'.watchkitapp'+('.uitests' if name=='watchtests' else ''),MARKETING_VERSION=phone.get('MARKETING_VERSION','1.0'),CURRENT_PROJECT_VERSION=phone.get('CURRENT_PROJECT_VERSION','1'),LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks',SKIP_INSTALL='YES')
   if phone.get('DEVELOPMENT_TEAM'):settings['DEVELOPMENT_TEAM']=phone['DEVELOPMENT_TEAM']
   if name=='watch':settings.update(INFOPLIST_KEY_CFBundleDisplayName='Теория чисел',INFOPLIST_KEY_WKApplication='YES',INFOPLIST_KEY_WKCompanionAppBundleIdentifier=phone['PRODUCT_BUNDLE_IDENTIFIER'],INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp='YES',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor')
   else:settings['TEST_TARGET_NAME']='NumberTheoryWatch'
   settings.update(previous.get(ref(name+'-'+config),{}).get('buildSettings',{}))
   obj(name+'-'+config,isa='XCBuildConfiguration',name=config,buildSettings=settings)
  obj(name+'-configs',isa='XCConfigurationList',buildConfigurations=[ref(name+'-'+x) for x in ['Debug','Release']],defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
 obj('embed-watch-build',isa='PBXBuildFile',fileRef=ref('watch-product'),settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
 obj('embed-watch',isa='PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='$(CONTENTS_FOLDER_PATH)/Watch',dstSubfolderSpec=16,files=[ref('embed-watch-build')],name='Embed Watch Content',runOnlyForDeploymentPostprocessing=0)
 objects[ref('app-target')]['buildPhases'].append(ref('embed-watch'));objects[ref('app-target')]['dependencies'].append(ref('watch-dependency'))
 objects[ref('project')]['targets'] += [ref('watch-target'),ref('watchtests-target')]
 attributes=objects[ref('project')]['attributes']['TargetAttributes'];attributes[ref('watch-target')]={'CreatedOnToolsVersion':'26.4'};attributes[ref('watchtests-target')]={'CreatedOnToolsVersion':'26.4','TestTargetID':ref('watch-target')}
 # plutil emits a valid PBX plist; identifiers remain stable across regeneration.
 file.write_text(json.dumps(data,ensure_ascii=False));subprocess.run(['plutil','-convert','xml1',str(file)],check=True)
 def buildable(key,title,product):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(key)}" BuildableName="{product}" BlueprintName="{title}" ReferencedContainer="container:NumberTheory.xcodeproj"/>'
 app=buildable('watch-target','NumberTheoryWatch','NumberTheoryWatch.app');test=buildable('watchtests-target','NumberTheoryWatchUITests','NumberTheoryWatchUITests.xctest')
 scheme=project/'xcshareddata/xcschemes/NumberTheoryWatch.xcscheme'
 if not scheme.exists():scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2640" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
