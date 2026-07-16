allprojects {
    repositories {
        google()
        mavenCentral()
        // 阿里云 EMAS 云发布（Taobao OneSDK）依赖仓库
        maven { url = uri("https://maven.aliyun.com/nexus/content/repositories/releases/") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
