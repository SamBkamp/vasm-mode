.POSIX:
.SUFFIXES: .el .elc
EMACS = emacs

compile: vasm-mode.elc

clean:
	rm -f vasm-mode.elc

.el.elc:
	$(EMACS) -Q -batch -f batch-byte-compile $<
