# The Flutter plugin compiles against every optional ML Kit text model. This
# app only creates TextRecognitionScript.latin, so the other model classes are
# intentionally absent at runtime.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
