.DEFAULT_GOAL := run
.PHONY: build run stop install

build:
	scripts/build.sh

stop:
	-pkill -x LaunchpadPlus

# Остановить старую копию, пересобрать и запустить новую
run: stop build
	open build/Launchpad+.app

# Установить в /Applications и запустить оттуда (автозапуск лучше включать из установленной копии)
install: stop build
	rm -rf "/Applications/Launchpad+.app"
	cp -R "build/Launchpad+.app" /Applications/
	open "/Applications/Launchpad+.app"
