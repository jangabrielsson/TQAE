(let ((a 7))
   (lambda (b) (+ a b))
  )
  
(let ((a 7))
   (lambda (b) (+ b b))
  )
  
(let ((a 7))
   (lambda (b) (+ b c))
  )
  
(let ((a 7))
   ((lambda (b) 
     (setq l1 (lambda(c) a))
   ) 7)
)
l1