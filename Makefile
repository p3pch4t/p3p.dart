version:
	sed -i "s/version: .*/version: 1.0.0+$(shell git rev-list --count HEAD)/" "pubspec.yaml"