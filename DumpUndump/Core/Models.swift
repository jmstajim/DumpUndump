import Foundation

struct DumpOptions: Codable, Equatable {
    var includeGlobs: String
    var excludeGlobs: String
    var excludeDirs: String
    var skipLargeFiles: Bool
    var maxSizeMB: Int

    static let `default` = DumpOptions(
        includeGlobs: "*.swift,*.h,*.m,*.mm,*.metal,*.plist,*.xib,*.storyboard,*.strings,*.stringsdict,*.xcconfig,*.entitlements,*.pbxproj,Package.swift,*.kt,*.kts,*.java,*.gradle,*.gradle.kts,*.xml,*.pro,*.properties,*.cpp,*.cc,*.c,*.hpp,*.hh,*.hxx,*.uplugin,*.uproject,*.Build.cs,*.Target.cs,*.ini,*.cs,*.shader,*.cginc,*.compute,*.hlsl,*.js,*.jsx,*.mjs,*.cjs,*.ts,*.tsx,*.json,*.yml,*.yaml,*.html,*.css,*.scss,*.sass,*.svelte,*.vue,*.astro,*.toml,*.cfg,*.env,*.md,*.txt,*.sh,*.bat,*.ps1,*.py,*.rb,*.go,*.rs,*.sql,Dockerfile,docker-compose*.yml",
        excludeGlobs: "*.min.js,*.lock,*.map,*.bundle.js,*.bundle.css,*.apk,*.aab,*.aar,*.jar,*.so,*.app,*.xcarchive,*.ipa,*.dSYM,*.bcsymbolmap,*.uasset,*.umap,*.pak",
        excludeDirs: ".git,DerivedData,build,.build,Build,Pods,Carthage,NodeModules,node_modules,.swiftpm,.xcworkspace,xcuserdata,.idea,.gradle,.gitlab,dist,out,.venv,venv,.vscode,.vs,.dccache,.cache,.next,.nuxt,Binaries,Intermediate,Saved,DerivedDataCache,Library,Temp,Obj,Logs,__pycache__,.mypy_cache,.pytest_cache,.dart_tool,ios/Pods,ios/build,android/.gradle,android/build,coverage",
        skipLargeFiles: true,
        maxSizeMB: 10
    )
}

struct DumpResult {
    let text: String
    let filesCount: Int
}

struct UndumpReport {
    var created: [String] = []
    var updated: [String] = []
    var skipped: [String] = []

    var summary: String {
        var parts: [String] = []
        if !created.isEmpty { parts.append("Created: \(created.count)") }
        if !updated.isEmpty { parts.append("Updated: \(updated.count)") }
        if !skipped.isEmpty { parts.append("Skipped: \(skipped.count)") }
        return parts.isEmpty ? "" : parts.joined(separator: " • ")
    }
}


