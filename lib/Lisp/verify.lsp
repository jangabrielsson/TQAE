
(defmacro verify(test res)
  `(let ((t0 ',test)(t1 ,test)(r1 ,res))
     (strformat "%s = %s" t0 (if (equal t1 r1) "OK" (concat "FAIL:" t1)))))
     
(verify (+ 2 3) 5)
(verify (+ 0 1) 1)
(verify (- 2 3) -1)
(verify (/ 3 2) 1.5)
(verify (* 2 3) 6)
(verify (null t) nil)
(verify (null nil) t)
(verify (list 2 3) '(2 3))
(verify (not 2) nil)
(verify (not nil) t)
(verify (and nil 8) nil)
(verify (and 7 8) 8)
(verify (or nil 9) 9)
(verify (or 9 nil) 9)
(verify (or nil nil) nil)
(verify (equal nil nil) t)
(verify (equal nil t) nil)
(verify (equal 5 5) t)
(verify (equal 'a 'a) t)
(verify (equal '(a b) '(a b)) t)
(verify (cond (t 7)) 7)
(verify (cond (nil 8)(t 7)) 7)
(verify (cond (t 8)(t 7)) 8)
(verify (when t 6) 6)
(verify (when nil 6) nil)
(verify (when t 6 7) 7)
(verify (append '(a b) '(c d)) '(a b c d))
(verify (reverse '(1 2 3)) '(3 2 1))
(verify (memq 'b '(a b c)) '(b c))
(verify (nth 2 '(a b c)) 'c)
(verify (list* 1 2 3) '( 1 2 . 3))
(verify (last '(a b c)) '(c))






