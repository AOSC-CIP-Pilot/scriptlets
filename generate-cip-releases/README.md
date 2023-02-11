generate-cip-releases
=====================

This script generates CIP-bound AOSC OS releases.

Usage
-----

Install aoscbootstrap:

```
# apt install aoscbootstrap
```

Generate releases:

```
# ./generate-cip-releases.sh [VARIANTS]
```

Note
----

With the exception of BuildKit, `generate-cip-releases.sh` will also generate
Qemu images for testing.
