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
        google()
        mavenCentral()
    }
}

rootProject.name = "generative-ui-sample"

// Composite build: include the library from packages/
includeBuild("../../packages/android") {
    dependencySubstitution {
        substitute(module("com.generativeui:dsl")).using(project(":"))
    }
}

include(":sample-app")
