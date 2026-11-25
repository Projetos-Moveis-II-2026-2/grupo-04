import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Credenciais de assinatura de release. O arquivo android/key.properties e o
// keystore (.jks) ficam fora do versionamento (veja o README).
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "br.unitins.olimpus"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "br.unitins.olimpus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storePassword = keyProperties.getProperty("storePassword")
                keyProperties.getProperty("storeFile")?.let { storeFile = file(it) }
            }
        }
    }

    buildTypes {
        release {
            // Nunca assina com a chave de debug. Sem key.properties, a validacao
            // abaixo interrompe apenas as tarefas de release que forem executadas.
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Falha com mensagem clara se uma tarefa de release for executada sem a
// configuracao de assinatura. Debug, analyze e testes nao sao afetados.
gradle.taskGraph.whenReady {
    val releaseTaskPattern =
        Regex("^(assemble|bundle|package|install|sign|validateSigning).*Release.*")
    val releaseRequested = allTasks.any {
        it.project == project && releaseTaskPattern.matches(it.name)
    }
    if (!releaseRequested) return@whenReady

    if (!keyPropertiesFile.exists()) {
        throw GradleException(
            "Assinatura de release nao configurada: o arquivo " +
                "${keyPropertiesFile.path} nao existe. Crie android/key.properties " +
                "com storePassword, keyPassword, keyAlias e storeFile " +
                "(passo a passo na secao 'Build de producao (.aab)' do README). " +
                "O build de release nao e assinado com a chave de debug.",
        )
    }
    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missingKeys = requiredKeys.filter { keyProperties.getProperty(it).isNullOrBlank() }
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "key.properties incompleto: faltam as chaves ${missingKeys.joinToString()}.",
        )
    }
    val keystore = file(keyProperties.getProperty("storeFile"))
    if (!keystore.exists()) {
        throw GradleException(
            "O keystore indicado em storeFile nao foi encontrado. Use um caminho " +
                "absoluto (ou relativo a android/app) para o arquivo .jks.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
