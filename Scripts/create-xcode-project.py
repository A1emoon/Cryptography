"""Generate the dependency-free Xcode project. Run after adding/removing source files."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[1]
project_dir = root / 'NumberTheory.xcodeproj'
project_dir.mkdir(exist_ok=True)

# Keep signing, bundle identifiers and other settings changed in Xcode.
project_file = project_dir / 'project.pbxproj'
previous_configurations = {}
if project_file.exists():
    result = subprocess.run(['plutil', '-convert', 'json', '-o', '-', str(project_file)],
                            check=True, capture_output=True, text=True)
    previous_configurations = json.loads(result.stdout)['objects']

def pbx_value(value):
    if isinstance(value, list):
        return '(' + ', '.join(pbx_value(item) for item in value) + ')'
    if isinstance(value, dict):
        return '{ ' + ' '.join(f'{key} = {pbx_value(item)};' for key, item in value.items()) + ' }'
    if isinstance(value, bool):
        return 'YES' if value else 'NO'
    return json.dumps(str(value), ensure_ascii=False)

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def ref(name):
    return uid(name)

objects = []
def obj(name, contents):
    objects.append(f'{uid(name)} = {{ {contents} }};')

sources = sorted(root.glob('App/**/*.swift')) + sorted(root.glob('Sources/NumberTheoryCore/**/*.swift'))
tests = sorted(root.glob('UITests/**/*.swift'))
reference_files = sorted(root.glob('Tests/NumberTheoryCoreTests/**/*.*'))
reference_files += sorted(root.glob('Scripts/*.*')) + sorted(root.glob('Documentation/*.md'))
reference_files += [root/'Sources/NumberTheoryCore/Reference/course-library.json']
reference_files += [root/'README.md', root/'Package.swift', root/'App/Resources/AppIconSource.svg']
file_types = {'.swift': 'sourcecode.swift', '.py': 'text.script.python', '.cjs': 'sourcecode.javascript',
              '.md': 'net.daringfireball.markdown', '.json': 'text.json', '.svg': 'image.svg'}
references = {}
for file in sorted(set(sources + tests + reference_files)):
    if not file.is_file() or file.name.startswith('.'):
        continue
    relative = file.relative_to(root).as_posix()
    kind = file_types.get(file.suffix, 'text')
    obj(relative, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {pbx_value(relative)}; sourceTree = SOURCE_ROOT;')
    references[relative] = ref(relative)
for file in sources + tests:
    relative = file.relative_to(root).as_posix()
    obj('build:' + relative, f'isa = PBXBuildFile; fileRef = {ref(relative)};')
asset_path = 'App/Resources/Assets.xcassets'
obj('assets', f'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {pbx_value(asset_path)}; sourceTree = SOURCE_ROOT;')
references[asset_path] = ref('assets')
obj('assets-build', f'isa = PBXBuildFile; fileRef = {ref("assets")};')
course_path = 'Конспекты и примеры'
obj('course-folder', f'isa = PBXFileReference; lastKnownFileType = folder; path = {pbx_value(course_path)}; sourceTree = SOURCE_ROOT;')
obj('course-build', f'isa = PBXBuildFile; fileRef = {ref("course-folder")};')
obj('library-build', f'isa = PBXBuildFile; fileRef = {ref("Sources/NumberTheoryCore/Reference/course-library.json")};')
for directory in ['Documentation/Screenshots', 'Documentation/References']:
    if (root/directory).exists():
        obj(directory, f'isa = PBXFileReference; lastKnownFileType = folder; path = {pbx_value(directory)}; sourceTree = SOURCE_ROOT;')
        references[directory] = ref(directory)
obj('app-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = NumberTheory.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = NumberTheoryUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products', f'isa = PBXGroup; name = Products; children = ({ref("app-product")}, {ref("test-product")}); sourceTree = "<group>";')

def group(directory):
    prefix = directory + '/'
    direct_files = [path for path in references if path.startswith(prefix) and '/' not in path[len(prefix):]]
    subdirectories = sorted({path[len(prefix):].split('/')[0] for path in references
                             if path.startswith(prefix) and '/' in path[len(prefix):]})
    children = [group(prefix + folder) for folder in subdirectories]
    children += [references[path] for path in sorted(direct_files)]
    key = 'group:' + directory
    obj(key, f'isa = PBXGroup; path = {pbx_value(Path(directory).name)}; children = ({", ".join(children)}); sourceTree = "<group>";')
    return ref(key)

children = [group(directory) for directory in ['App', 'Sources', 'Tests', 'UITests', 'Documentation', 'Scripts']]
children += [references['README.md'], references['Package.swift'], ref('course-folder'), ref('products')]
obj('root-group', f'isa = PBXGroup; children = ({", ".join(children)}); sourceTree = "<group>";')
for name, files in [('app', sources), ('tests', tests)]:
    builds = [ref('build:' + f.relative_to(root).as_posix()) for f in files]
    obj(name+'-sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
    obj(name+'-frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resources = ', '.join(ref(x) for x in ['assets-build','course-build','library-build']) if name == 'app' else ''
    obj(name+'-resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({resources}); runOnlyForDeploymentPostprocessing = 0;')

obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {ref("project")}; proxyType = 1; remoteGlobalIDString = {ref("app-target")}; remoteInfo = NumberTheory;')
obj('dependency', f'isa = PBXTargetDependency; target = {ref("app-target")}; targetProxy = {ref("proxy")};')
for name, product, targetname in [('app', 'app-product', 'NumberTheory'), ('tests', 'test-product', 'NumberTheoryUITests')]:
    phases = ', '.join(ref(name+'-'+p) for p in ('sources', 'frameworks', 'resources'))
    product_type = 'com.apple.product-type.application' if name == 'app' else 'com.apple.product-type.bundle.ui-testing'
    deps = ref('dependency') if name == 'tests' else ''
    obj(name+'-target', f'isa = PBXNativeTarget; buildConfigurationList = {ref(name+"-configs")}; buildPhases = ({phases}); buildRules = (); dependencies = ({deps}); name = {targetname}; productName = {targetname}; productReference = {ref(product)}; productType = "{product_type}";')

for name in ('project', 'app', 'tests'):
    for config in ('Debug', 'Release'):
        settings = {
            'SWIFT_VERSION': '6.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
            'SDKROOT': 'iphoneos', 'CLANG_ENABLE_MODULES': 'YES',
        }
        if name == 'project':
            settings.update({'SWIFT_OPTIMIZATION_LEVEL': '"-Onone"' if config == 'Debug' else '"-O"',
                             'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else '"dwarf-with-dsym"',
                             'ENABLE_TESTABILITY': 'YES' if config == 'Debug' else 'NO',
                             'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '"DEBUG $(inherited)"' if config == 'Debug' else '"$(inherited)"'})
        else:
            settings.update({'PRODUCT_NAME': '"$(TARGET_NAME)"', 'GENERATE_INFOPLIST_FILE': 'YES',
                             'CODE_SIGN_STYLE': 'Automatic', 'TARGETED_DEVICE_FAMILY': '1',
                             'SUPPORTED_PLATFORMS': '"iphoneos iphonesimulator"',
                             'SUPPORTS_MACCATALYST': 'NO',
                             'PRODUCT_BUNDLE_IDENTIFIER': 'com.alemoon.numbertheory' + ('.uitests' if name == 'tests' else ''),
                             'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '1.0',
                             'LD_RUNPATH_SEARCH_PATHS': '"$(inherited) @executable_path/Frameworks"'})
            if name == 'app':
                settings.update({'INFOPLIST_KEY_CFBundleDisplayName': '"Теория чисел"',
                                 'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES',
                                 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES',
                                 'INFOPLIST_KEY_UISupportedInterfaceOrientations': '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
                                 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
                                 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon'})
            else:
                settings['TEST_TARGET_NAME'] = 'NumberTheory'
        previous = previous_configurations.get(ref(name + '-' + config), {}).get('buildSettings', {})
        settings.update({key: pbx_value(value) for key, value in previous.items()})
        formatted = ' '.join(f'{k} = {v};' for k, v in settings.items())
        obj(name+'-'+config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ {formatted} }};')
    obj(name+'-configs', f'isa = XCConfigurationList; buildConfigurations = ({ref(name+"-Debug")}, {ref(name+"-Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2640; BuildIndependentTargetsInParallel = YES; TargetAttributes = {{ {ref("app-target")} = {{ CreatedOnToolsVersion = 26.4; }}; {ref("tests-target")} = {{ CreatedOnToolsVersion = 26.4; TestTargetID = {ref("app-target")}; }}; }}; }}; buildConfigurationList = {ref("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ru; hasScannedForEncodings = 0; knownRegions = (ru, en, Base); mainGroup = {ref("root-group")}; productRefGroup = {ref("products")}; projectDirPath = ""; projectRoot = ""; targets = ({ref("app-target")}, {ref("tests-target")});')
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {ref("project")}; }}\n')
scheme_dir = project_dir / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
def buildable(target, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(target)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:NumberTheory.xcodeproj"/>'
app = buildable('app-target', 'NumberTheory', 'NumberTheory.app')
tests_ref = buildable('tests-target', 'NumberTheoryUITests', 'NumberTheoryUITests.xctest')
if not (scheme_dir/'NumberTheory.xcscheme').exists():
    (scheme_dir/'NumberTheory.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2640" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{tests_ref}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
from configure_watch_project import configure_watch
configure_watch(root, previous_configurations)
print(project_dir)
