BIN_DIR := ./bin
BIN := tm2000
SRC := ./src

run: bin-dir
	odin run ${SRC} -out=${BIN_DIR}/${BIN}

debug: build-debug
	lldb ${BIN_DIR}/${BIN}-debug

build: bin-dir
	odin run ${SRC} -out=${BIN_DIR}/${BIN}

build-debug: bin-dir
	odin run ${SRC} -out=${BIN_DIR}/${BIN}-debug

bin-dir:
	@mkdir -p ${BIN_DIR}

release-dir:
	rm -rf ./release
	mkdir -p release

clean:
	rm -rf ${BIN_DIR}

release-linux: release-dir clean
	odin build . -out=build/${BIN}-lin
	cp -r ./res ./build/
	zip -r ./release/linux.zip ./build

release-darwin: release-dir clean
	odin build . -out=build/${BIN}-mac
	cp -r ./res ./build/
	zip -r ./release/macos.zip ./build
