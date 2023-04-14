;;;; Standard lisp functions
(setq *trace-level* 0)
(setq *log-level* 2)

(defmacro defparameter(var val)(list 'setq var val))
(defmacro defvar(var val)(list 'setq var val))
(defmacro defconst(var val)(list 'setq var val))

(defun null(x) (eq x nil))
(defun list (&rest l) l)
(defun not(x) (if x nil t))
(defmacro and(x y) (list 'if x y nil))
(defmacro or(x y) (list 'if x x y)) ;; redefined later

(defun equal(x y)
   (if (eq x y) t
       (if (and (consp x) (consp y))
           (and (equal (car x)(car y))
           		(equal (cdr x)(cdr y))))))

;;; (cond(test1 res1)(test2 res2)...) -> (if test1 res1 (if (test2 res2 ...)))

(defmacro cond (&rest body)
   (let* ((fc #'(fn (bl)
                  (if (eq bl nil) nil
                         (list 'if (car (car bl)) (cons 'progn (cdr (car bl)))
                                  (fc (cdr bl)))))))
       (fc body)))

(defmacro when (test &rest body)
    (list 'if test (cons 'progn body)))

(defun append(x y)
  (if (eq x '()) y
      (cons (car x)(append (cdr x) y))))

(defun reverse(x) 
   (if (consp x)
      (append (reverse (cdr x))(list (car x)))
      x))

(defun memq (a l)
   (if (eq l nil) nil
       (if (eq a (car l)) l
           (memq a (cdr l)))))
 
(defvar *libraries* nil)
(defun provide (lib)
	(if (memq lib *libraries*) nil
	    (setq *libraries* (cons lib *libraries*))))

(defun require (lib path)
	(if (memq lib *libraries*) nil
		(readfile path)))

;; Setup for backquote...	
(defun assq (x y)
	(cond ((null y) nil)
		((eq x (car (car y))) (car y))
		(t (assq x (cdr y))) ))

(defun putprop(props key val) 
   (cond ((null props) (list (list key val)))
         ((eq (car (car props)) key) (cons (list key val) (cdr props)))
         (t (cons (car props) (putprop (cdr props) key val)))))
         
(defun nth (i l)
   (if (eq l nil) nil
       (if (eq i 0) (car l)
           (nth (- i 1) (cdr l)))))

(defun list* (&rest l)
	(let* ((fun (fn (x)
			(if (null x) x
			   (if (null (cdr x)) (car x)
			      (cons (car x) (fun (cdr x))))))))
	 (fun l)))

(defun last (l)
    (if (null l) l
        (if (null (cdr l)) l
            (last (cdr l)))))
            
(defun nconc (&rest l)
    (if (null l) l
        (if (null (car l)) (nconc (cdr l))
            (if (null (cdr l)) (car l)
                (if (null (cdr (cdr l))) (progn (rplacd (last (car l)) (car (cdr l))) (car l))
                    (nconc (nconc (car l) (car (cdr l))) (cdr (cdr l))))))))

(defun vectorp (expr) nil)

(defmacro error (format &rest msgs)
   (list '*error* (cons 'strformat (cons format msgs))))

(require 'backquote "lib/Lisp/backquote.lsp")

(defmacro unless (condition &rest body)
  `(if (not ,condition) (progn ,@body)))

(defmacro or(x y) (let ((s (gensym))) `(let ((,s ,x)) (if ,s ,s ,y))))
(defmacro first(x)`(car ,x))
(defmacro rest(x)`(cdr ,x))
(defmacro second(x)`(car (cdr ,x)))
(defmacro third(x)`(car (cdr (cdr ,x))))
(defmacro caar(x)`(car (car ,x)))
(defmacro cadr(x)`(car (cdr ,x)))
(defmacro cdar(x)`(cdr (car ,x)))
(defmacro cddr(x)`(cdr (cdr ,x)))
(defmacro cdddr(x) `(cdr (cdr (cdr ,x))))
(defmacro cadar(x)`(car (cdr (car ,x))))

(defmacro funcall(f &rest args) `(apply ,f (list ,@args)))

(defmacro dolist(params &rest body)
	(let ((ll (gensym)))
	`(let ((,ll ,(second params)))
	   (while ,ll
	    (setq ,(first params) (first ,ll))
	    (setq ,ll (rest ,ll))
	    ,@body))))

(defmacro dotimes(params &rest body)
	(let ((var (first params))(ll (gensym)))
	`(let ((,ll ,(second params)))
	   (setq ,var 0)
	   (while (< ,var ,ll)
	    (setq ,var (+ ,var 1))
	    ,@body))))

(defmacro setf (var value)
	`(setq ,var ,value))
	
(defmacro incf (var &optional (value 1))
	`(setq ,var (+ ,var ,value)))
	
(defmacro decf (var &optional (value 1))
	`(setq ,var (- ,var ,value)))
	
(defun map(f l)
  (let* ((fun (fn (l)
		  (if l
		      (cons (f (car l)) (fun (cdr l)))))))
	(fun l)))

(defun foldl(f e l)
  (let* ((fun (fn (l)
		  (if l
		      (f (car l) (fun(cdr l)))
		    e))))
	(fun l)))
       
(defun add (&rest lst) (foldl #'+ 0 lst)) ;
			
;;; (case expr (val1 res1) (val2 res2) ...) -> (let ((test expr)) (cond ((eq test val1) res1) ...
(defmacro case (&rest body)
   (let* ((case1 #'(fn(x)
                       (if (null x) nil
                         (cons (cons (list 'eq '*temp* (caar x))
                                 (cdar x))
                           (case1 (cdr x)))))))
      (list 'let (list (list '*temp* (car body)))
             (cons 'cond (case1 (cdr body))))))  
   
(defmacro defun2(name params &rest body)
   (list 'funset name (cons 'lambda (cons params body))))
		
(defparameter *read-macros* nil)
(defun set-macro-character(c fun)
	(setq *read-macros* (putprop '*read-macros* c fun)))

;(set-macro-character 'foo ;#\$
;   #'(lambda(stream char) 
;      (list 'backquote (read stream t nil t))))

(defun verify() (readfile "lib/Lisp/verify.lsp"))

(defmacro time (expr)
  (let ((tt (gensym)) (res (gensym)))
    `(progn (setq ,tt (clock) ,res ,expr ,tt (- (clock) ,tt)) (format t "%.5f seconds\n" ,tt) ,res)))
    
(defun format (stream format &rest args)
	(print (apply #'strformat (cons format args))))

(defvar * nil)
(defvar ** nil)
(defvar *** nil)

(defun toploop()
  (setq *trace-silent* T) 
	(print "Lisp>")
	(flush)
	(setq expr (read))
	(setq *trace-silent* NIL res (catch 'NIL (eval expr)))
  (setq *trace-silent* T) 
	(when (not (memq expr '(* ** ***)))
		(setq *** **)
		(setq ** *)
		(setq * res))
	(format t "%s\n" res)
	(toploop)
)