import Foundation

enum OptionsPreset: String, CaseIterable, Identifiable {
    case `default`
    case all
    case ios
    case android
    case web
    case unreal
    case unity
    case reactNative
    case flutter
    case nodeBackend
    case python
    case docsOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: return "Default"
        case .all: return "All (Text-focused)"
        case .ios: return "iOS (Swift/ObjC)"
        case .android: return "Android (Kotlin/Java)"
        case .web: return "Web (JS/TS)"
        case .unreal: return "Unreal (C++ GameDev)"
        case .unity: return "Unity (C# GameDev)"
        case .reactNative: return "React Native (Cross-platform)"
        case .flutter: return "Flutter"
        case .nodeBackend: return "Node/Backend"
        case .python: return "Python"
        case .docsOnly: return "Docs-only"
        }
    }

    func options(base: DumpOptions) -> DumpOptions {
        switch self {
        case .default:
            return DumpOptions.default

        case .all:
            return DumpOptions(
                includeGlobs: "*.swift,*.h,*.m,*.mm,*.metal,*.plist,*.xib,*.storyboard,*.strings,*.stringsdict,*.xcconfig,*.entitlements,*.pbxproj,Package.swift,*.kt,*.kts,*.java,*.gradle,*.gradle.kts,*.xml,*.pro,*.properties,*.cpp,*.cc,*.c,*.hpp,*.hh,*.hxx,*.uplugin,*.uproject,*.Build.cs,*.Target.cs,*.ini,*.cs,*.shader,*.cginc,*.compute,*.hlsl,*.js,*.jsx,*.mjs,*.cjs,*.ts,*.tsx,*.json,*.yml,*.yaml,*.html,*.css,*.scss,*.sass,*.svelte,*.vue,*.toml,*.cfg,*.env,*.md,*.txt,*.sh,*.bat,*.ps1,*.py,*.rb,*.go,*.rs,*.sql,Dockerfile,docker-compose*.yml",
                excludeGlobs: "*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css,*.apk,*.aab,*.aar,*.jar,*.so,*.app,*.xcarchive,*.ipa,*.dSYM,*.bcsymbolmap,*.uasset,*.umap,*.pak",
                excludeDirs: base.excludeDirs,
                skipLargeFiles: true,
                maxSizeMB: 10
            )

        case .ios:
            return DumpOptions(
                includeGlobs: "*.swift,*.m,*.mm,*.h,*.metal,*.plist,*.xib,*.storyboard,*.strings,*.stringsdict,*.xcconfig,*.entitlements,*.pbxproj,Package.swift,*.json,*.yml,*.yaml,*.md,*.txt",
                excludeGlobs: "*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css,*.app,*.xcarchive,*.ipa,*.dSYM,*.bcsymbolmap",
                excludeDirs: base.excludeDirs,
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .android:
            return DumpOptions(
                includeGlobs: "*.kt,*.java,*.kts,*.gradle,*.gradle.kts,*.xml,*.pro,*.properties,*.aidl,*.json,*.yml,*.yaml,*.md,*.txt,*.sh",
                excludeGlobs: "*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css,*.apk,*.aab,*.aar,*.jar,*.so",
                excludeDirs: base.excludeDirs,
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .web:
            return DumpOptions(
                includeGlobs: "*.js,*.jsx,*.mjs,*.cjs,*.ts,*.tsx,*.html,*.css,*.scss,*.sass,*.svelte,*.vue,*.astro,*.json,*.yml,*.yaml,*.md,*.txt,*.sh",
                excludeGlobs: "*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs,
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .unreal:
            return DumpOptions(
                includeGlobs: "*.cpp,*.hpp,*.h,*.cc,*.c,*.Build.cs,*.Target.cs,*.uplugin,*.uproject,Config/*.ini,*.usf,*.ush,*.json,*.yml,*.yaml,*.py,*.sh,*.bat,*.md,*.txt",
                excludeGlobs: "*.uasset,*.umap,*.pak,*.pdb,*.exe,*.dll,*.lib,*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs + ",Binaries,Intermediate,Saved,DerivedDataCache",
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .unity:
            return DumpOptions(
                includeGlobs: "*.cs,*.shader,*.cginc,*.hlsl,*.asmdef,*.rsp,*.uxml,*.uss,Packages/*.json,ProjectSettings/*.asset,*.md,*.txt",
                excludeGlobs: "*.unity,*.prefab,*.fbx,*.psd,*.tga,*.png,*.jpg,*.jpeg,*.exr,*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs + ",Library,Temp,Obj,Build,Logs",
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .reactNative:
            return DumpOptions(
                includeGlobs: "*.js,*.jsx,*.ts,*.tsx,*.json,*.yml,*.yaml,*.md,*.sh,*.gradle,*.kt,*.java,*.xml,*.m,*.mm,*.swift,*.plist,*.xcconfig,*.pbxproj,*.entitlements",
                excludeGlobs: "*.min.js,*.map,*.bundle.js,*.bundle.css,*.apk,*.aab,*.aar,*.jar,*.so,*.app,*.xcarchive,*.ipa,*.dSYM,*.bcsymbolmap,*.lock",
                excludeDirs: base.excludeDirs + ",ios/Pods,android/.gradle,android/build,ios/build",
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .flutter:
            return DumpOptions(
                includeGlobs: "*.dart,*.yaml,*.yml,*.arb,*.md,*.txt,*.sh,*.gradle,*.kt,*.java,*.xml,*.swift,*.m,*.mm,*.plist,*.xcconfig",
                excludeGlobs: "*.apk,*.aab,*.aar,*.jar,*.so,*.app,*.xcarchive,*.ipa,*.dSYM,*.bcsymbolmap,*.lock,*.min.js,*.map,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs + ",build,.dart_tool,ios/Pods,android/.gradle,ios/build,android/build",
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .nodeBackend:
            return DumpOptions(
                includeGlobs: "*.js,*.cjs,*.mjs,*.ts,*.json,*.yml,*.yaml,*.md,*.env.example,Dockerfile,docker-compose*.yml",
                excludeGlobs: "*.min.js,*.map,*.lock,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs + ",dist,build,coverage,.nuxt",
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .python:
            return DumpOptions(
                includeGlobs: "*.py,*.pyi,pyproject.toml,poetry.lock,requirements*.txt,setup.cfg,*.toml,*.ini,*.cfg,*.json,*.yml,*.yaml,*.md,*.txt,*.sh",
                excludeGlobs: "*.pyc,*.pyo,*.pyd,*.ipynb,*.lock,*.min.js,*.map,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs + ",__pycache__,.mypy_cache,.pytest_cache,build,dist",
                skipLargeFiles: true,
                maxSizeMB: 5
            )

        case .docsOnly:
            return DumpOptions(
                includeGlobs: "*.md,*.rst,*.adoc,docs/**/*,*.txt",
                excludeGlobs: "*.lock,*.min.js,*.map,*.bundle.js,*.bundle.css",
                excludeDirs: base.excludeDirs,
                skipLargeFiles: true,
                maxSizeMB: 5
            )
        }
    }
}
