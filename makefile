.PHONY: simulator iphone both

SIMULATOR := "iPhone 17 Pro"
IPHONE := "iPhone"

simulator:
	flutter run -d $(SIMULATOR)

iphone:
	flutter run -d $(IPHONE)

both:
	@echo "🚀 Launching simulator..."
	flutter run -d $(SIMULATOR) &

	@sleep 3

	@echo "🚀 Launching physical iPhone..."
	flutter run -d $(IPHONE) &

	@wait