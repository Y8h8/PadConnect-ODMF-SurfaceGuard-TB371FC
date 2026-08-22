# Source-only notice

This directory intentionally does **not** include `odmf.jar`.

The build script requires a user-owned stock `odmf.jar` whose SHA-256 is:

`628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d`

The script applies the same verified 2-byte DEX field-index patch used by the original SurfaceGuard project, recalculates the DEX signature/checksum, verifies the resulting patched JAR SHA-256, and then packages the combined Magisk module.
