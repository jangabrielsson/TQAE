;;; backquote.el --- Full backquote support for elisp.  Reverse compatible too.

(provide 'backquote)

;; Keywords: extensions

;;; Synched up with: Not synched with FSF.

;;; The bulk of the code is originally from CMU Common Lisp (original notice
;;; below).
;;;
;;; It correctly supports nested backquotes and backquoted vectors.
;;;
;;; Converted to work with elisp by Miles Bader <miles@cogsci.ed.ac.uk>
;;;
;;; Changes by Jonathan Stigelman <Stig@hackvan.com>:
;;;   - Documentation added
;;;   - support for old-backquote-compatibility-hook nixed because the
;;;	old-backquote compatibility is now done in the reader...
;;;   - nixed support for |,.| because
;;;	(a) it's not in CLtl2
;;;	(b) ",.foo" is the same as ". ,foo"
;;;	(c) because RMS isn't interested in using this version of backquote.el 
;;;
;;; wing@666.com; added ,. support back in:
;;;     (a) yes, it is in CLtl2.  Read closely on page 529.
;;;     (b) RMS in 19.30 adds C support for ,. even if it's not really
;;;         handled.
;;;
;;; **********************************************************************
;;; This code was written as part of the CMU Common Lisp project at
;;; Carnegie Mellon University, and has been placed in the public domain.
;;; If you want to use this code or any part of CMU Common Lisp, please contact
;;; Scott Fahlman or slisp-group@cs.cmu.edu.
;;;
;;; **********************************************************************
;;;
;;;    BACKQUOTE: Code Spice Lispified by Lee Schumacher.
;;;
;;; The flags passed back by BQ-PROCESS-2 can be interpreted as follows:
;;;
;;;   |`,|: [a] => a
;;;    NIL: [a] => a		;the NIL flag is used only when a is NIL
;;;      T: [a] => a		;the T flag is used when a is self-evaluating
;;;  QUOTE: [a] => (QUOTE a)
;;; APPEND: [a] => (APPEND . a)
;;;  NCONC: [a] => (NCONC . a) 
;;;   LIST: [a] => (LIST . a)
;;;  LIST*: [a] => (LIST* . a)
;;;
;;; The flags are combined according to the following set of rules:
;;;  ([a] means that a should be converted according to the previous table)
;;;
;;;   \ car  ||   otherwise    |   QUOTE or     |    |`,@|      |    |`,.|     
;;;cdr \     ||                |   T or NIL     |               |              
;;;============================================================================
;;;  |`,|    ||LIST* ([a] [d]) |LIST* ([a] [d]) |APPEND (a [d]) |NCONC  (a [d])
;;;  NIL     ||LIST    ([a])   |QUOTE    (a)    |<hair>    a    |<hair>    a   
;;;QUOTE or T||LIST* ([a] [d]) |QUOTE  (a . d)  |APPEND (a [d]) |NCONC (a [d]) 
;;; APPEND   ||LIST* ([a] [d]) |LIST* ([a] [d]) |APPEND (a . d) |NCONC (a [d]) 
;;; NCONC    ||LIST* ([a] [d]) |LIST* ([a] [d]) |APPEND (a [d]) |NCONC (a . d) 
;;;  LIST    ||LIST  ([a] . d) |LIST  ([a] . d) |APPEND (a [d]) |NCONC (a [d]) 
;;;  LIST*   ||LIST* ([a] . d) |LIST* ([a] . d) |APPEND (a [d]) |NCONC  (a [d])
;;;
;;;<hair> involves starting over again pretending you had read ".,a)" instead
;;; of ",@a)"
;;;

;;;   
;;;   
;;;   
;;;   
;;;   
;;;   
;;;   
;;;   
;;;   
;;;   

;;; These are the forms it expects:  |backquote|  |`|  |,|  |,@| and |,.|.
(defconst bq-backquote-marker '*back-quote*) 
(defconst bq-backtick-marker '*back-tick*)	; remnant of the old lossage
(defconst bq-comma-marker '*back-comma*)    ; ,X
(defconst bq-at-marker '*back-comma-at*)    ; ,@X
(defconst bq-dot-marker '*back-comma-dot*)  ; ,.X

;;; ----------------------------------------------------------------
;
;(fset '\` 'backquote)
;
(defmacro backquote (template)
;  "Expand the internal representation of a backquoted TEMPLATE into a lisp form.
;
;The backquote character is like the quote character in that it prevents the
;template which follows it from being evaluated, except that backquote
;permits you to evaluate portions of the quoted template.  A comma character
;inside TEMPLATE indicates that the following item should be evaluated.  A
;comma character may be followed by an at-sign, which indicates that the form
;which follows should be evaluated and inserted and \"spliced\" into the
;template.  Forms following ,@ must evaluate to lists.

;Here is how to use backquotes:
;  (setq p 'b
;        q '(c d e))
;  `(a ,p ,@q)   -> (a b c d e)
;  `(a . b)      -> (a . b)
;  `(a . ,p)     -> (a . b)
;
;The XEmacs lisp reader expands lisp backquotes as it reads them.
;Examples:
;  `atom             is read as (backquote atom)
;  `(a ,b ,@(c d e)) is read as (backquote (a (\\, b) (\\,\\@ (c d e))))
;  `(a . ,p)         is read as (backquote (a \\, p))

;\(backquote TEMPLATE) is a macro that produces code to construct TEMPLATE.
;Note that this is very slow in interpreted code, but fast if you compile.
;TEMPLATE is one or more nested lists or vectors, which are `almost quoted'.
;They are copied recursively, with elements preceded by comma evaluated.
; (backquote (a b))     == (list 'a 'b)  
; (backquote (a [b c])) == (list 'a (vector 'b 'c)) 

;However, certain special lists are not copied.  They specify substitution.
;Lists that look like (\\, EXP) are evaluated and the result is substituted.
; (backquote (a (\\, (+ x 5)))) == (list 'a (+ x 5))

;Elements of the form (\\,\\@ EXP) are evaluated and then all the elements
;of the result are substituted.  This result must be a list; it may
;be `nil'.

;Elements of the form (\\,\\. EXP) are evaluated and then all the elements
;of the result are concatenated to the list of preceding elements in the list.
;They must occur as the last element of a list (not a vector).
;EXP may evaluate to nil.

;As an example, a simple macro `push' could be written:
;   (defmacro push (v l)
;     `(setq ,l (cons ,@(list v l))))
;or as
;   (defmacro push (v l)
;     `(setq ,l (cons ,v ,l)))

;For backwards compatibility, old-style emacs-lisp backquotes are still read.
;     OLD STYLE                        NEW STYLE
;     (` (foo (, bar) (,@ bing)))      `(foo ,bar ,@bing)

;Because of the old-style backquote support, you cannot use a new-style
;backquoted form as the first element of a list.  Perhaps some day this
;restriction will go away, but for now you should be wary of it:
;    (`(this ,will ,@fail))
;    ((` (but (, this) will (,@ work))))
;This is an extremely rare thing to need to do in lisp."
   (bq-process template))

;;; ----------------------------------------------------------------

(defconst bq-comma-flag 'unquote)
(defconst bq-at-flag 'unquote-splicing)
(defconst bq-dot-flag 'unquote-nconc-splicing)

(defun bq-process (form)
  (let* ((flag-result (bq-process-2 form))
	       (flag (car flag-result))
	       (result (cdr flag-result)))
    (cond ((eq flag bq-at-flag)
	   (error ",@ after ` in form: %s" form))
	  ((eq flag bq-dot-flag)
	   (error ",. after ` in form: %s" form))
	  (t
	   (bq-process-1 flag result)))))

;;; ----------------------------------------------------------------

(defun bq-vector-contents (vec)
  (let ((contents nil)
	(n (length vec)))
    (while (> n 0)
      (setq n (- n 1))
      (setq contents (cons (aref vec n) contents)))
    contents))

;;; This does the expansion from table 2.
(defun bq-process-2 (code)
  (cond ((vectorp code)
	 (let* ((dflag-d
		 (bq-process-2 (bq-vector-contents code))))
	   (cons 'vector (bq-process-1 (car dflag-d) (cdr dflag-d)))))  
	((atom code)
	 (cond ((null code) (cons nil nil))
	       ((or (numberp code) (eq code t))
		(cons t code))
	       (t (cons 'quote code))))
	((eq (car code) bq-at-marker)
	 (cons bq-at-flag (nth 1 code)))
	((eq (car code) bq-dot-marker)
	 (cons bq-dot-flag (nth 1 code)))
	((eq (car code) bq-comma-marker)
	 (bq-comma (nth 1 code)))
	((or (eq (car code) bq-backquote-marker)
	     (eq (car code) bq-backtick-marker))	; old lossage
	 (bq-process-2 (bq-process (nth 1 code))))
	(t (let* ((aflag-a (bq-process-2 (car code)))
		  (aflag (car aflag-a))
		  (a (cdr aflag-a)))
	     (let* ((dflag-d (bq-process-2 (cdr code)))
		    (dflag (car dflag-d))
		    (d (cdr dflag-d)))
	       (if (eq dflag bq-at-flag)
		   ;; get the errors later.
		   (error ",@ after dot in %s" code))
	       (if (eq dflag bq-dot-flag)
		   (error ",. after dot in %s" code))
	       (cond
		((eq aflag bq-at-flag)
		 (if (null dflag)
		     (bq-comma a)
		     (cons 'append
			   (cond ((eq dflag 'append)
				  (cons a d ))
				 (t (list a (bq-process-1 dflag d)))))))
                ((eq aflag bq-dot-flag)
                 (if (null dflag)
                     (bq-comma a)
                     (cons 'nconc
                           (cond ((eq dflag 'nconc)
                                  (cons a d))
                                 (t (list a (bq-process-1 dflag d)))))))
		((null dflag)
		 (if (memq aflag '(quote t nil))
		     (cons 'quote (list a))
		     (cons 'list (list (bq-process-1 aflag a)))))
		((memq dflag '(quote t))
		 (if (memq aflag '(quote t nil))
		     (cons 'quote (cons a d ))
		     (cons 'list* (list (bq-process-1 aflag a)
					(bq-process-1 dflag d)))))
		(t (setq a (bq-process-1 aflag a))
		   (if (memq dflag '(list list*))
		       (cons dflag (cons a d))
		       (cons 'list*
			     (list a (bq-process-1 dflag d)))))))))))

;;; This handles the <hair> cases 
(defun bq-comma (code)
  (cond ((atom code)
	 (cond ((null code)
		(cons nil nil))
	       ((or (numberp code) (eq code 't))
		(cons t code))
	       (t (cons bq-comma-flag code))))
	((eq (car code) 'quote)
	 (cons (car code) (car (cdr code))))
	((memq (car code) '(append list list* nconc))
	 (cons (car code) (cdr code)))
	((eq (car code) 'cons)
	 (cons 'list* (cdr code)))
	(t (cons bq-comma-flag code))))

;;; This handles table 1.
(defun bq-process-1 (flag thing)
  (cond ((or (eq flag bq-comma-flag)
	     (memq flag '(t nil)))
	 thing)
	((eq flag 'quote)
	 (list  'quote thing))
	((eq flag 'vector)
	 (list 'apply '(function vector) thing))
	(t (cons (cdr
		  (assq flag
			'((cons . cons)
			  (list* . bq-list*)
			  (list . list)
			  (append . append)
			  (nconc . nconc))))
		 thing))))

;;; ----------------------------------------------------------------

(defmacro bq-list* (&rest args)
;  "Returns a list of its arguments with last cons a dotted pair."
  (setq args (reverse args))
  (let ((result (car args)))
    (setq args (cdr args))
    (while args
      (setq result (list 'cons (car args) result))
      (setq args (cdr args)))
    result))
