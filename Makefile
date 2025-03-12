BIN_DIR := ./bin
BIN := ${BIN_DIR}/tm2000
SRC := ./src

run: bin-dir
	odin run ${SRC} -out=${BIN}

debug: build-debug
	lldb ${BIN}-debug

build: bin-dir
	odin run ${SRC} -out=${BIN}

build-debug: bin-dir
	odin run ${SRC} -out=${BIN}-debug

bin-dir:
	@mkdir -p ${BIN_DIR}

clean:
	rm -rf ${BIN_DIR}
