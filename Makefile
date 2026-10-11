.DEFAULT_GOAL := run
.PHONY: build run stop install dmg

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

# Собрать DMG для релиза: build/Launchpad-Plus-<версия>.dmg (версия — из файла VERSION)
dmg:
	scripts/make_dmg.sh
