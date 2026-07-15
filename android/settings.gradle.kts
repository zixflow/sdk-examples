pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenLocal() // Local Zixflow SDK build (BUG-A12 fix, version "local")
        google()
        mavenCentral()
    }
}

rootProject.name = "ZixflowSdkExample"
include(":app")
