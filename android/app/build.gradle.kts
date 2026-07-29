
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.qlnext.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        val keystorePath = System.getenv("KEYSTORE_PATH")
        if (keystorePath != null && file(keystorePath).isFile) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                    ?: error("KEYSTORE_PASSWORD env var not set")
                keyAlias = System.getenv("KEY_ALIAS")
                    ?: error("KEY_ALIAS env var not set")
                keyPassword = System.getenv("KEY_PASSWORD")
                    ?: error("KEY_PASSWORD env var not set")
            }
        }
    }

    defaultConfig {
        applicationId = "com.qlnext.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    buildTypes {
        release {
            // Signing with the release config from env vars (KEYSTORE_PATH etc.),
            // falling back to debug if not configured.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// AGP 9 currently leaves the proto-format resource archive out of the APK in
// this emulated build environment. Re-attach the binary resource archive and
// sign the final file so the Flutter output is a valid installable APK.
val repairReleaseApk by tasks.registering {
    dependsOn("convertShrunkResourcesToBinaryRelease")

    doLast {
        val buildRoot = layout.buildDirectory.get().asFile
        val sdkCandidates = listOfNotNull(
            System.getenv("ANDROID_HOME"),
            System.getenv("ANDROID_SDK_ROOT"),
            file(System.getProperty("user.home")).resolve("Android/Sdk").absolutePath,
            "/opt/android-sdk",
        ).map { file(it) }
        val sdkRoot = sdkCandidates.firstOrNull { it.isDirectory }
            ?: error("Android SDK not found")
        val buildTools = sdkRoot.resolve("build-tools")
            .listFiles()
            ?.filter { it.isDirectory && it.resolve("aapt2").isFile }
            ?.maxByOrNull { it.name }
            ?: error("Android build-tools not found in ${sdkRoot.absolutePath}")
        val aapt2 = buildTools.resolve("aapt2")
        val zipalign = buildTools.resolve("zipalign")
        val apksigner = buildTools.resolve("apksigner")
        val androidJar = sdkRoot.resolve("platforms")
            .listFiles()
            ?.filter { it.isDirectory && it.resolve("android.jar").isFile }
            ?.maxByOrNull { it.name }
            ?.resolve("android.jar")
            ?: error("Android platform not found in ${sdkRoot.absolutePath}")
        val targetSdk = androidJar.parentFile?.name?.removePrefix("android-")
            ?: error("Android platform directory is missing")
        val box64 = file("/usr/local/bin/box64").takeIf { it.isFile && it.canExecute() }
        if (box64 == null) {
            // GitHub's native x86_64 runner does not need the legacy APK
            // repair path that exists for the local box64 environment.
            logger.lifecycle("Native Android runner detected; keeping Gradle APK outputs unchanged")
            return@doLast
        }

        fun toolCommand(tool: java.io.File, vararg arguments: String): Array<String> {
            val command = mutableListOf<String>()
            box64?.let { command += it.absolutePath }
            command += tool.absolutePath
            command.addAll(arguments)
            return command.toTypedArray()
        }

        val releaseDirectory = file("$buildRoot/outputs/apk/release")
        val apks = releaseDirectory.listFiles()
            ?.filter {
                it.isFile && it.extension == "apk" &&
                    it.name.endsWith("-release.apk")
            }
            ?: emptyList()
        if (apks.isEmpty()) {
            logger.lifecycle("No release APKs found; keeping the Gradle outputs unchanged")
            return@doLast
        }
        // AGP 9 changes this intermediate path between environments and may
        // omit the archive entirely when resource shrinking has no output.
        val resourceApk = buildRoot.walkTopDown().firstOrNull {
            it.isFile && it.extension == "ap_"
        }
        if (resourceApk == null) {
            logger.lifecycle("No binary resource archive found; keeping the Gradle APK unchanged")
            return@doLast
        }
        val resourceArchive = resourceApk
        fun runCommand(workingDirectory: java.io.File, vararg command: String) {
            val exitCode = ProcessBuilder(command.toList())
                .directory(workingDirectory)
                .inheritIO()
                .start()
                .waitFor()
            check(exitCode == 0)
        }

        // AGP 9's intermediate APK can omit the binary manifest in this
        // emulated build environment. Compile the packaged manifest with the
        // same resource table before attaching it to the final APK.
        val manifestXml = buildRoot.walkTopDown().firstOrNull {
            it.isFile && it.name == "AndroidManifest.xml" &&
                it.path.contains("packaged_manifests")
        } ?: error("Packaged AndroidManifest.xml not found")
        val keystorePath = System.getenv("KEYSTORE_PATH")
        val keystorePassword = System.getenv("KEYSTORE_PASSWORD") ?: "android"
        val keyAlias = System.getenv("KEY_ALIAS") ?: "androiddebugkey"
        val keyPassword = System.getenv("KEY_PASSWORD") ?: "android"

        val signingKeystore = when {
            keystorePath != null && file(keystorePath).isFile -> file(keystorePath)
            else -> file(System.getProperty("user.home")).resolve(".android/debug.keystore")
        }
        if (!signingKeystore.isFile) {
            logger.lifecycle("No keystore available; skipping APK repair")
            return@doLast
        }
        apks.forEach { apk ->
            val staging = file(
                "$buildRoot/outputs/apk/release/repair/${apk.nameWithoutExtension}",
            )
            staging.deleteRecursively()
            staging.mkdirs()

            val resources = file("$staging/resources")
            copy {
                from(zipTree(resourceArchive))
                into(resources)
            }

            val merged = file("$staging/app-unmerged.apk")
            apk.copyTo(merged, overwrite = true)

            val manifestApk = file("$staging/manifest-compiled.apk")
            runCommand(
                staging,
                *toolCommand(
                    aapt2,
                    "link",
                    "-o",
                    manifestApk.absolutePath,
                    "--manifest",
                    manifestXml.absolutePath,
                    "-I",
                    androidJar.absolutePath,
                    "-I",
                    resourceArchive.absolutePath,
                    "--min-sdk-version",
                    "24",
                    "--target-sdk-version",
                    targetSdk,
                ),
            )
            copy {
                from(zipTree(manifestApk).matching { include("AndroidManifest.xml") })
                into(resources)
            }
            // resources.arsc must remain stored (not deflated) for Android 11+.
            runCommand(
                staging,
                "jar",
                "uf0",
                merged.absolutePath,
                "-C",
                resources.absolutePath,
                ".",
            )

            val aligned = file("$staging/app-aligned.apk")
            runCommand(
                staging,
                *toolCommand(
                    zipalign,
                    "-f",
                    "4",
                    merged.absolutePath,
                    aligned.absolutePath,
                ),
            )

            runCommand(
                staging,
                *toolCommand(
                    apksigner,
                    "sign",
                    "--ks",
                    signingKeystore.absolutePath,
                    "--ks-key-alias",
                    keyAlias,
                    "--ks-pass",
                    "pass:$keystorePassword",
                    "--key-pass",
                    "pass:$keyPassword",
                    "--min-sdk-version",
                    "24",
                    "--out",
                    "$staging/app-signed.apk",
                    aligned.absolutePath,
                ),
            )
            file("$staging/app-signed.apk").copyTo(apk, overwrite = true)
        }
    }
}

tasks.matching { it.name == "packageRelease" }.configureEach {
    finalizedBy(repairReleaseApk)
}

flutter {
    source = "../.."
}
