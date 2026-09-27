import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    pluginManager.withPlugin("com.android.library") {
        // Several Flutter plugins assume every AGP 9 project uses AGP's built-in
        // Kotlin support. Flutter currently disables that mode for compatibility,
        // so make sure Kotlin sources in those plugins are still compiled.
        if (project.file("src/main/kotlin").isDirectory) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
    afterEvaluate {
        extensions.findByType(ApplicationExtension::class.java)?.ndkVersion =
            "29.0.14033849"
        extensions.findByType(LibraryExtension::class.java)?.ndkVersion =
            "29.0.14033849"
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
