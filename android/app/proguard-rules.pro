# Firebase / Firestore models are used reflectively by the SDK.
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
-dontwarn com.google.firebase.**
