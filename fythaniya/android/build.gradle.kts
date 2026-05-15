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
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Force all Android subprojects to use the locally installed NDK version.
subprojects {
    val targetNdkVersion = "27.0.12077973"

    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            ndkVersion = targetNdkVersion
        }
    }
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            ndkVersion = targetNdkVersion
        }
    }

    // afterEvaluate overrides ndkVersion set inside a subproject's own build.gradle.
    // Guard with state.executed so we skip :app, which is pre-evaluated by
    // evaluationDependsOn(":app") above and would throw if afterEvaluate is called on it.
    if (!project.state.executed) {
        afterEvaluate {
            if (project.plugins.hasPlugin("com.android.application") ||
                project.plugins.hasPlugin("com.android.library")) {
                extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                    ndkVersion = targetNdkVersion
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
