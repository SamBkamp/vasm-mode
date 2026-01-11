# vasm-mode

`vasm-mode` is a major mode for editing [VASM][vasm] 6502 assembly
programs. It includes syntax highlighting, automatic indentation, and
imenu integration. Unlike Emacs' generic `asm-mode`, it understands
VASM-specific syntax. Requires Emacs 24.3 or higher.

The instruction and keyword lists are from NASM 2.12.01.

forked from [nasm-mode][nasm-mode-url]

## Known Issues

* Due to limitations of Emacs' syntax tables, like many other major
  modes, double and single quoted strings don't properly handle
  backslashes, which, unlike backquoted strings, aren't escapes in
  NASM syntax.


[vasm]: http://www.compilers.de/vasm.html
[nasm-mode-url]: https://github.com/skeeto/nasm-mode