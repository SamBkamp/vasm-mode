;;; vasm-mode.el --- vasm 6502 assembly major mode -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Christopher Wellons <wellons@nullprogram.com> (2015 - 2026)
;; Author: Sam Bonnekamp <sam@bonnekamp.com> (2026 - )
;; URL: https://github.com/sambkamp/vasm-mode
;; Version: 1.1.1
;; Package-Requires: ((emacs "24.3"))

;;; Commentary:

;; forked from nasm-mode, originally authored by Christopher Wellons. Adapted to vasm by Sam Bonnekamp
;; nasm-mode URL: https://github.com/skeeto/nasm-mode
;; VASM Home: http://www.compilers.de/vasm.html

;;; Code:

(require 'imenu)

(defgroup vasm-mode ()
  "Options for `vasm-mode'."
  :group 'languages)

(defgroup vasm-mode-faces ()
  "Faces used by `vasm-mode'."
  :group 'vasm-mode)

(defcustom vasm-basic-offset (default-value 'tab-width)
  "Indentation level for `vasm-mode'."
  :type 'integer
  :group 'vasm-mode)

(defcustom vasm-after-mnemonic-whitespace :tab
  "In `vasm-mode', determines the whitespace to use after mnemonics.
This can be :tab, :space, or nil (do nothing)."
  :type '(choice (const :tab) (const :space) (const nil))
  :group 'vasm-mode)

(defface vasm-registers
  '((t :inherit (font-lock-variable-name-face)))
  "Face for registers."
  :group 'vasm-mode-faces)

(defface vasm-prefix
  '((t :inherit (font-lock-builtin-face)))
  "Face for prefix."
  :group 'vasm-mode-faces)

(defface vasm-types
  '((t :inherit (font-lock-type-face)))
  "Face for types."
  :group 'vasm-mode-faces)

(defface vasm-instructions
  '((t :inherit (font-lock-builtin-face)))
  "Face for instructions."
  :group 'vasm-mode-faces)

(defface vasm-directives
  '((t :inherit (font-lock-keyword-face)))
  "Face for directives."
  :group 'vasm-mode-faces)

(defface vasm-preprocessor
  '((t :inherit (font-lock-preprocessor-face)))
  "Face for preprocessor directives."
  :group 'vasm-mode-faces)

(defface vasm-labels
  '((t :inherit (font-lock-function-name-face)))
  "Face for nonlocal labels."
  :group 'vasm-mode-faces)

(defface vasm-local-labels
  '((t :inherit (font-lock-function-name-face)))
  "Face for local labels."
  :group 'vasm-mode-faces)

(defface vasm-section-name
  '((t :inherit (font-lock-type-face)))
  "Face for section name face."
  :group 'vasm-mode-faces)

(defface vasm-numbers
  '((t :inherit (font-lock-type-face)))
  "Face for section name face."
  :group 'vasm-mode-faces)

(defface vasm-constant
  '((t :inherit (font-lock-constant-face)))
  "Face for constant."
  :group 'vasm-mode-faces)

(defface vasm-imm
  '((t :inherit (font-lock-keyword-face)))
  "Face for constant."
  :group 'vasm-mode-faces)

(eval-and-compile
  (defconst vasm-registers
    '("a" "x" "y")
    "NASM registers (reg.c) for `vasm-mode'."))

(eval-and-compile
  (defconst vasm-directives
    '("absolute" "bits" "common" "cpu" "debug" "default" "extern"
      "float" "global" "list" "section" "segment" "warning" "sectalign"
      "export" "group" "import" "library" "map" "module" "org" "osabi"
      "safeseh" "uppercase")
    "NASM directives (directiv.c) for `vasm-mode'."))

(eval-and-compile
  (defconst vasm-instructions
    '("adc" "and" "asl" "bbr" "bbs" "bcc" "bcs" "beq" "bit" "bmi" "bne"
      "bpl" "bra" "brk" "bvc" "bvs" "clc" "cld" "cli" "clv" "cmp" "cpx"
      "cpy" "dec" "dex" "dey" "eor" "inc" "inx" "iny" "jmp" "jsr" "lda"
      "ldx" "ldy" "lsr" "nop" "ora" "pha" "php" "phx" "phy" "plx" "ply"
      "rmb" "pla" "plp" "rol" "ror" "rti" "rts" "sbc" "sec" "sed" "sei"
      "smb" "stp" "sta" "stx" "sty" "tax" "tay" "trb" "tsb" "tsx" "txa" "txs" "tya" "wai")
    "NASM instructions (tokhash.c) for `vasm-mode'."))

(eval-and-compile
  (defconst vasm-types
    '("1to16" "1to2" "1to4" "1to8" "__float128h__" "__float128l__"
      "__float16__" "__float32__" "__float64__" "__float80e__"
      "__float80m__" "__float8__" "__infinity__" "__nan__" "__qnan__"
      "__snan__" "__utf16__" "__utf16be__" "__utf16le__" "__utf32__"
      "__utf32be__" "__utf32le__" "abs" "byte" "dword" "evex" "far"
      "long" "near" "nosplit" "oword" "qword" "rel" "seg" "short"
      "strict" "to" "tword" "vex2" "vex3" "word" "wrt" "yword"
      "zword")
    "NASM types (tokens.dat) for `vasm-mode'."))

(eval-and-compile
  (defconst vasm-prefix
    '()
    "NASM prefixes (nasmlib.c) for `vasm-mode'."))

(eval-and-compile
  (defconst vasm-pp-directives
    '(".abyte" ".addr" ".align" ".asc" ".ascii" ".asciiz" ".org")
    "NASM preprocessor directives (pptok.c) for `vasm-mode'."))

(defconst vasm-nonlocal-label-rexexp
  "\\(\\_<[a-zA-Z_?][a-zA-Z0-9_#@~?]*\\_>\\)\\s-*:"
  "Regexp for `vasm-mode' for matching nonlocal labels.")

(defconst vasm-local-label-regexp
  "\\(\\_<\\.[a-zA-Z_?][a-zA-Z0-9_#@~?]*\\_>\\)\\(?:\\s-*:\\)?"
  "Regexp for `vasm-mode' for matching local labels.")

(defconst vasm-label-regexp
  (concat vasm-nonlocal-label-rexexp "\\|" vasm-local-label-regexp)
  "Regexp for `vasm-mode' for matching labels.")

(defconst vasm-constant-regexp
  "^[ \t]*\\([a-zA-Z_][a-zA-Z0-9_]*\\)[ \t]*\\(?:=\\|equ\\|EQU\\)[ \t]"
  "Regexp for `vasm-mode' for matching numeric constants.")

(defconst vasm-number-regexp
  "\\(?:\\$[0-9A-Fa-f]+\\|%[01]+\\|[^a-zA-Z][0-9]+\\)"
  "Regexp for `vasm-mode' for matching number types.")

(defconst vasm-imm-regexp
  "\\(?:#\\)"
  "Regexp for `vasm-mode' for matching imm mode numbers.")

(defconst vasm-section-name-regexp
  "^\\s-*section[ \t]+\\(\\_<\\.[a-zA-Z0-9_#@~.?]+\\_>\\)"
  "Regexp for `vasm-mode' for matching section names.")

(defmacro vasm--opt (keywords)
  "Prepare KEYWORDS for `looking-at'."
  `(eval-when-compile
     (regexp-opt ,keywords 'symbols)))

(defconst vasm-imenu-generic-expression
  `((nil ,(concat "^\\s-*" vasm-nonlocal-label-rexexp) 1)
    (nil ,(concat (vasm--opt '("%define" "%macro"))
                  "\\s-+\\([a-zA-Z0-9_$#@~.?]+\\)") 2))
  "Expressions for `imenu-generic-expression'.")

(defconst vasm-full-instruction-regexp
  (eval-when-compile
    (let ((pfx (vasm--opt vasm-prefix))
          (ins (vasm--opt vasm-instructions)))
      (concat "^\\(" pfx "\\s-+\\)?" ins "$")))
  "Regexp for `vasm-mode' matching a valid full NASM instruction field.
This includes prefixes or modifiers (eg \"mov\", \"rep mov\", etc match)")

(defconst vasm-font-lock-keywords
  `((,vasm-section-name-regexp (1 'vasm-section-name))
    (,(vasm--opt vasm-registers) . 'vasm-registers)
    (,(vasm--opt vasm-prefix) . 'vasm-prefix)
    (,(vasm--opt vasm-types) . 'vasm-types)
    (,(vasm--opt vasm-instructions) . 'vasm-instructions)
    (,(vasm--opt vasm-pp-directives) . 'vasm-preprocessor)
    (,(concat "^\\s-*" vasm-nonlocal-label-rexexp) (1 'vasm-labels))
    (,(concat "^\\s-*" vasm-local-label-regexp) (1 'vasm-local-labels))
    (,vasm-imm-regexp . 'vasm-imm)
    (,vasm-constant-regexp . 'vasm-constant)
    (,vasm-number-regexp . 'vasm-numbers)
    (,(vasm--opt vasm-directives) . 'vasm-directives))
  "Keywords for `vasm-mode'.")

(defconst vasm-mode-syntax-table
  (with-syntax-table (copy-syntax-table)
    (modify-syntax-entry ?_  "_")
    (modify-syntax-entry ?#  "_")
    (modify-syntax-entry ?@  "_")
    (modify-syntax-entry ?\? "_")
    (modify-syntax-entry ?~  "_")
    (modify-syntax-entry ?\. "w")
    (modify-syntax-entry ?\; "<")
    (modify-syntax-entry ?\n ">")
    (modify-syntax-entry ?\" "\"")
    (modify-syntax-entry ?\' "\"")
    (modify-syntax-entry ?\` "\"")
    (syntax-table))
  "Syntax table for `vasm-mode'.")

(defvar vasm-mode-map
  (let ((map (make-sparse-keymap)))
    (prog1 map
      (define-key map (kbd ":") #'vasm-colon)
      (define-key map (kbd ";") #'vasm-comment)
      (define-key map [remap join-line] #'vasm-join-line)))
  "Key bindings for `vasm-mode'.")

(defun vasm-colon ()
  "Insert a colon and convert the current line into a label."
  (interactive)
  (call-interactively #'self-insert-command)
  (vasm-indent-line))

(defun vasm-indent-line ()
  "Indent current line (or insert a tab) as NASM assembly code.
This will be called by `indent-for-tab-command' when TAB is
pressed.  We indent the entire line as appropriate whenever POINT
is not immediately after a mnemonic; otherwise, we insert a tab."
  (interactive)
  (let ((before      ; text before point and after indentation
         (save-excursion
           (let ((point (point))
                 (bti (progn (back-to-indentation) (point))))
             (buffer-substring-no-properties bti point)))))
    (if (string-match vasm-full-instruction-regexp before)
        ;; We are immediately after a mnemonic
        (cl-case vasm-after-mnemonic-whitespace
          (:tab   (insert "\t"))
          (:space (insert-char ?\s vasm-basic-offset)))
      ;; We're literally anywhere else, indent the whole line
      (let ((orig (- (point-max) (point))))
        (back-to-indentation)
        (if (or (looking-at (vasm--opt vasm-directives))
                (looking-at (vasm--opt vasm-pp-directives))
                (looking-at "\\[")
                (looking-at ";;+")
                (looking-at vasm-label-regexp))
            (indent-line-to 0)
          (indent-line-to vasm-basic-offset))
        (when (> (- (point-max) orig) (point))
          (goto-char (- (point-max) orig)))))))

(defun vasm--current-line ()
  "Return the current line as a string."
  (save-excursion
    (let ((start (progn (beginning-of-line) (point)))
          (end (progn (end-of-line) (point))))
      (buffer-substring-no-properties start end))))

(defun vasm--empty-line-p ()
  "Return non-nil if current line has non-whitespace."
  (not (string-match-p "\\S-" (vasm--current-line))))

(defun vasm--line-has-comment-p ()
  "Return non-nil if current line contains a comment."
  (save-excursion
    (end-of-line)
    (nth 4 (syntax-ppss))))

(defun vasm--line-has-non-comment-p ()
  "Return non-nil of the current line has code."
  (let* ((line (vasm--current-line))
         (match (string-match-p "\\S-" line)))
    (when match
      (not (eql ?\; (aref line match))))))

(defun vasm--inside-indentation-p ()
  "Return non-nil if point is within the indentation."
  (save-excursion
    (let ((point (point))
          (start (progn (beginning-of-line) (point)))
          (end (progn (back-to-indentation) (point))))
      (and (<= start point) (<= point end)))))

(defun vasm-comment-indent ()
  "Compute desired indentation for comment on the current line."
  comment-column)

(defun vasm-insert-comment ()
  "Insert a comment if the current line doesn’t contain one."
  (let ((comment-insert-comment-function nil))
    (comment-indent)))

(defun vasm-comment (&optional arg)
  "Begin or edit a comment with context-sensitive placement.

The right-hand comment gutter is far away from the code, so this
command uses the mark ring to help move back and forth between
code and the comment gutter.

* If no comment gutter exists yet, mark the current position and
  jump to it.
* If already within the gutter, pop the top mark and return to
  the code.
* If on a line with no code, just insert a comment character.
* If within the indentation, just insert a comment character.
  This is intended prevent interference when the intention is to
  comment out the line.

With a prefix ARG, kill the comment on the current line with
`comment-kill'."
  (interactive "p")
  (if (not (eql arg 1))
      (comment-kill nil)
    (cond
     ;; Empty line, or inside a string? Insert.
     ((or (vasm--empty-line-p) (nth 3 (syntax-ppss)))
      (insert ";"))
     ;; Inside the indentation? Comment out the line.
     ((vasm--inside-indentation-p)
      (insert ";"))
     ;; Currently in a right-side comment? Return.
     ((and (vasm--line-has-comment-p)
           (vasm--line-has-non-comment-p)
           (nth 4 (syntax-ppss)))
      (goto-char (mark))
      (pop-mark))
     ;; Line has code? Mark and jump to right-side comment.
     ((vasm--line-has-non-comment-p)
      (push-mark)
      (comment-indent))
     ;; Otherwise insert.
     ((insert ";")))))

(defun vasm-join-line (&optional arg)
  "Join this line to previous, but use a tab when joining with a label.
With prefix ARG, join the current line to the following line.  See `join-line'
for more information."
  (interactive "*P")
  (join-line arg)
  (if (looking-back vasm-label-regexp (line-beginning-position))
      (let ((column (current-column)))
        (cond ((< column vasm-basic-offset)
               (delete-char 1)
               (insert-char ?\t))
              ((and (= column vasm-basic-offset) (eql ?: (char-before)))
               (delete-char 1))))
    (vasm-indent-line)))

;;;###autoload
(define-derived-mode vasm-mode prog-mode "VASM"
  "Major mode for editing NASM assembly programs."
  :group 'vasm-mode
  (make-local-variable 'indent-line-function)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-insert-comment-function)
  (make-local-variable 'comment-indent-function)
  (setf font-lock-defaults '(vasm-font-lock-keywords nil :case-fold)
        indent-line-function #'vasm-indent-line
        comment-start ";"
        comment-indent-function #'vasm-comment-indent
        comment-insert-comment-function #'vasm-insert-comment
        imenu-generic-expression vasm-imenu-generic-expression))

(provide 'vasm-mode)

;;; vasm-mode.el ends here
