P3PGO_TAG=v1.0.0RC3

version:
	sed -i "s/version: .*/version: 1.0.0+$(shell git rev-list --count HEAD)/" "pubspec.yaml"

.PHONY: lib/src/generated_bindings.dart
lib/src/generated_bindings.dart:
	-rm -rf vendor
	mkdir vendor
	wget https://git.mrcyjanek.net/p3pch4t/p3pgo/releases/download/${P3PGO_TAG}/api_linux_amd64.h.xz -O vendor/api_host.h.xz
	unxz vendor/api_host.h.xz
	dart run ffigen
	rm -rf vendor