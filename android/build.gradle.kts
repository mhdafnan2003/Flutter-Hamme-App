allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
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

subprojects {
    val configureJvm = {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Standardize on JVM 11/17 for all modules now that social_share is gone
            val target = if (project.name == "flutter_secure_storage") "17" else "11"
            
            try {
                android.compileSdkVersion("android-36")
                android.compileOptions {
                    sourceCompatibility = if (target == "17") JavaVersion.VERSION_17 else JavaVersion.VERSION_11
                    targetCompatibility = if (target == "17") JavaVersion.VERSION_17 else JavaVersion.VERSION_11
                }
            } catch (e: Exception) {}

            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(target))
                }
            }
        }
    }

    if (project.state.executed) {
        configureJvm()
    } else {
        project.afterEvaluate { 
            configureJvm()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
