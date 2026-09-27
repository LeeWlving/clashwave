# Mihomo's JNI bridge resolves these classes and methods by name.
-keep class io.github.oviron.libmihomo.Clash { *; }
-keep interface io.github.oviron.libmihomo.TunInterface { *; }
-keep interface io.github.oviron.libmihomo.InvokeInterface { *; }
-keepclasseswithmembernames class io.github.oviron.libmihomo.** {
    native <methods>;
}
