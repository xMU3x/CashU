plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

val runNumber = (System.getenv("GITHUB_RUN_NUMBER") ?: "0").toInt()
// المفتاح العام فقط (publishable/anon) — يُمرَّر من Secret باسم SUPABASE_ANON_KEY ولا يُكتب في الكود.
val supabaseKey = (System.getenv("SUPABASE_ANON_KEY") ?: "").trim()

android {
    namespace = "com.werd.cashu"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.werd.cashu"
        minSdk = 23
        targetSdk = 35
        versionCode = 1000 + runNumber
        versionName = "1.0.$runNumber"
        buildConfigField("String", "SUPABASE_URL", "\"https://suxjvfyraqpcxplpvqzz.supabase.co\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"$supabaseKey\"")
        buildConfigField("String", "GITHUB_REPO", "\"${System.getenv("GITHUB_REPOSITORY") ?: ""}\"")
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    buildTypes { release { isMinifyEnabled = false } }
    lint { abortOnError = false; checkReleaseBuilds = false }
    testOptions { unitTests.isReturnDefaultValues = true }
}

ksp { arg("room.schemaLocation", "$projectDir/schemas") }

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons)
    implementation(libs.activity.compose)
    implementation(libs.navigation.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.viewmodel)
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    implementation(libs.coroutines.android)
    implementation(libs.serialization.json)
    implementation(libs.datastore)
    testImplementation(libs.junit)
}
