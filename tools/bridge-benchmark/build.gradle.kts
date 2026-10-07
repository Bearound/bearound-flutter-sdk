import java.security.MessageDigest
import org.gradle.api.artifacts.component.ModuleComponentIdentifier

plugins {
    id("com.android.library") version "8.11.1"
    id("org.jetbrains.kotlin.android") version "2.1.0"
}

val repo = projectDir.resolve("../..").canonicalFile
val publishedCommit = "4f61d32d47b96cd16de0464c3f04f4aaea5d8a50"
val sourcePath = "android/src/main/kotlin/com/example/bearound_flutter_sdk/BearoundFlutterSdkPlugin.kt"
val nativeCoordinate = "com.github.Bearound:bearound-android-sdk:v3.14.0"
val generatedDir = layout.buildDirectory.dir("generated/published")
val hashesFile = layout.buildDirectory.file("source-hashes.properties")
val flutterHome = System.getenv("BRIDGE_FLUTTER_HOME") ?: "/opt/homebrew/share/flutter"
val flutterJar = file("$flutterHome/bin/cache/artifacts/engine/android-arm64/flutter.jar")
require(flutterJar.isFile) { "Flutter embedding jar missing: $flutterJar" }

fun git(vararg args: String): ByteArray {
    val process = ProcessBuilder(listOf("git", "-C", repo.path) + args).start()
    val bytes = process.inputStream.readBytes()
    val error = process.errorStream.readBytes().toString(Charsets.UTF_8)
    check(process.waitFor() == 0) { "Git source generation failed: $error" }
    return bytes
}

fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
    .digest(bytes).joinToString("") { "%02x".format(it) }

val generatePublishedSource by tasks.registering {
    inputs.file(repo.resolve(sourcePath))
    inputs.property("publishedCommit", publishedCommit)
    outputs.dir(generatedDir)
    outputs.file(hashesFile)
    outputs.upToDateWhen { false }
    doLast {
        check(git("rev-parse", "v3.14.0^{commit}").toString(Charsets.UTF_8).trim() == publishedCommit)
        val original = git("show", "$publishedCommit:$sourcePath")
        check(sha256(original) == "7d4fbbc13e6dc0ae1eced82576d50e9da18a798618d2320ef1f3ee0e0d94d270")
        val source = original.toString(Charsets.UTF_8)
        val normalized = source.split('\n').joinToString("\n") { line ->
            if (line.contains("\u2014")) {
                check(line.trimStart().startsWith("//")) { "Punctuation change outside a line comment" }
                line.replace("\u2014", ",")
            } else line
        }
        val generated = normalized.replace(
            "class BearoundFlutterSdkPlugin :", "class PublishedBearoundFlutterSdkPlugin :"
        )
        check(generated != normalized) { "Published class rename did not match" }
        val withoutComments = Regex("(?m)^\\s*//[^\\n]*")
        check(generated.replace("class PublishedBearoundFlutterSdkPlugin :", "class BearoundFlutterSdkPlugin :")
            .replace(withoutComments, "") == source.replace(withoutComments, ""))
        val target = generatedDir.get().asFile.resolve(
            "com/example/bearound_flutter_sdk/PublishedBearoundFlutterSdkPlugin.kt"
        )
        target.parentFile.mkdirs()
        target.writeText(generated)
        hashesFile.get().asFile.writeText(
            "publishedCommit=$publishedCommit\n" +
                "publishedOriginal=${sha256(original)}\n" +
                "publishedGenerated=${sha256(target.readBytes())}\n" +
                "candidate=${sha256(repo.resolve(sourcePath).readBytes())}\n" +
                "nativeCoordinate=$nativeCoordinate\n"
        )
        logger.lifecycle("Source hashes: ${hashesFile.get().asFile}")
    }
}

android {
    namespace = "com.example.bearound_flutter_sdk.bridge_benchmark"
    compileSdk = 36
    defaultConfig { minSdk = 23 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }
    sourceSets {
        getByName("main") {
            java.srcDir(repo.resolve("android/src/main/kotlin"))
            java.srcDir(generatedDir)
        }
    }
    testOptions.unitTests.isIncludeAndroidResources = true
}

dependencies {
    implementation(nativeCoordinate)
    implementation("androidx.core:core-ktx:1.16.0")
    implementation(files(flutterJar))
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.13")
}

val verifyNativeDependency by tasks.registering {
    doLast {
        val natives = configurations.getByName("debugCompileClasspath").incoming.resolutionResult
            .allComponents.mapNotNull { it.id as? ModuleComponentIdentifier }
            .filter { it.group == "com.github.Bearound" && it.module == "bearound-android-sdk" }
        check(natives.single().version == "v3.14.0") { "Native dependency must stay published v3.14.0" }
        logger.lifecycle("Native dependency verified: $nativeCoordinate")
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    dependsOn(generatePublishedSource, verifyNativeDependency)
}

tasks.withType<Test>().configureEach {
    useJUnit()
    outputs.upToDateWhen { false }
    maxHeapSize = "2g"
    systemProperty("bridge.repo", repo.path)
    systemProperty("bridge.hashes", hashesFile.get().asFile.path)
    providers.gradleProperty("bridgeOutput").orNull?.let { systemProperty("bridge.output", it) }
    systemProperty("robolectric.offline", "true")
    systemProperty("robolectric.dependency.dir", System.getenv("BRIDGE_ROBOLECTRIC_DIR") ?:
        "${System.getProperty("user.home")}/.m2/repository/org/robolectric/android-all-instrumented/14-robolectric-10818077-i6")
    testLogging { events("passed", "failed", "skipped") }
}
