allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("http://192.168.10.96:8081/repository/maven-releases/")
            isAllowInsecureProtocol = true
        }
//        maven {
//            name = "GitHubPackages"
//            url = uri("https://maven.pkg.github.com/Bearound/bearound-android-sdk")
//            credentials {
//                username = System.getenv("GPR_USER")
//                password = System.getenv("GPR_KEY")
//            }
//        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
