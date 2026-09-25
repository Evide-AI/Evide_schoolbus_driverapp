# Firebase Cloud Messaging
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# flutter_local_notifications schedules through these
-keep class com.dexterous.** { *; }

# Keep annotations Play's review tooling reads
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod