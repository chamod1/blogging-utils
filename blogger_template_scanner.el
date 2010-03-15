;; -*-mode: lisp-interaction; -*-

(defun bg-safe-require (library-name)
  (if (locate-library library-name )
      (require (intern library-name))
    (error "You must have %s installed. Google it!" library-name)))

(bg-safe-require "nxml-mode")

(defun bg-blogger-util-get-selector-prior-to-point (&optional up-list)
  (save-excursion
    (and up-list (backward-up-list 1))
    (let ((end (point)))
      (if (re-search-backward (rx (or "*/"
				      "}"))
			      nil t)
	  (match-end 0)
	(error "No beginning of selector prior to point at %S" end))
      (split-string
       (replace-regexp-in-string
	(rx (+ (or white ",")) eos) ""
	(replace-regexp-in-string
	 (rx bos (+ white)) ""
	 (replace-regexp-in-string
	  (rx white) " "
	  (buffer-substring-no-properties (match-end 0) end))))
       " ,"))))

(defun bg-blogger-util-get-template-variable-references (file variable-type)
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((variable-section-begin-regexp (rx "<Variable name="
					     "\""
					     (group (+ (not (any "\""))))
					     "\""
					     ))
	  (variable-section-end-regexp (rx
					(+ white)
					(+ (not (any "=")))
					(* white)
					"="
					(* white)
					"\""
					(+ (not (any "\"")))
					"\""
					(* white)
					">"))
	  (type-match-regexp (rx "type"
				 (* white)
				 "="
				 (* white)
				 "\""
				 (eval variable-type)
				 "\""))
	  names)
      ;; TODO: use nxml-mode's functions to pull out the XML element in a
      ;; cleaner fashion than using a regular expression:
      (while (re-search-forward variable-section-begin-regexp nil t)
	(let ((name (match-string-no-properties 1))
	      (beg-variable-def-point (match-beginning 0))
	      (end-variable-def-point
	       (if (re-search-forward variable-section-end-regexp nil t)
		   (point)
		 (error "Could not find end of variable definition for variable named %S" name))))
	  (when (string-match type-match-regexp
			      (buffer-substring-no-properties beg-variable-def-point end-variable-def-point))
	    (push name names))))
      (let ((elems (mapcar (lambda (name)
			     (save-excursion
			       (let ((ref-regexp (concat (regexp-quote "$")
							 (regexp-quote name)
							 (rx (not (any "a-z" "A-Z" "0-9" "_")))))
				     refs)
				 (while (re-search-forward ref-regexp nil t)

				   (add-to-list 'refs (bg-blogger-util-get-selector-prior-to-point t)))
				 (list name (sort (apply 'append refs) 'string-lessp)))))
			   (nreverse names))))
	elems))))

(defun bg-blogger-util-scan-css-properties (file prop-name-list)
  (with-temp-buffer
    (insert-file-contents file)
    (let* ((beg (progn
		  (goto-char (point-min))
		  (if (re-search-forward (rx "<b:skin>")
					 nil t)
		      (match-end 0)
		    (error "cannot find <b:skin> tag"))))
	   (end (progn
		  (goto-char beg)
		  (if (re-search-forward (rx "</b:skin>")
					 nil t)
		      (match-beginning 0)
		    (error "cannot find </b:skin> tag")))))
      (mapcar (lambda (prop-name)
		(goto-char beg)
		(let ((prop-regexp (rx (* white)
				       (eval prop-name)
				       (* white)
				       ":"
				       (* white)
				       (group (+ (not (any white "," ";"))))))
		      elems)
		  (while (re-search-forward prop-regexp end t)
		    (let ((prop-value (match-string-no-properties 1))
			  (selector (bg-blogger-util-get-selector-prior-to-point t)))
		      (push (list selector prop-name prop-value) elems)))
		  elems))
	      prop-name-list))))

(defun bg-blogger-get-section-to-var-name-hash (references)
  (let ((references-section-to-var-hash (make-hash-table :test 'equal)))
    (mapc (lambda (var-elem)
	    (let ((variable-name (car var-elem))
		  (sections (cadr var-elem)))
	      (mapc (lambda (section)
		      (error "Stopped here: This is wrong: There could be sections that reference multiple colors in different ways for foreground and background colors.")
		      (puthash section variable-name references-section-to-var-hash))
		    sections)))
	  references)
    references-section-to-var-hash))


;; Just a "nil" block to allow me to eval the entire buffer of this file to get
;; the definitions. I then can use C-j after the expressions within the nil
;; block to see the result, given that this file is still in lisp-interaction
;; mode (see top of the file):
(when nil
  ;; -----------------------------------------------------------------------------------------
  (mapconcat
   (lambda (elem)
     (pp-to-string elem))
   (bg-blogger-util-get-template-variable-references "template-stretch-denim-brents-color-scheme.xml" "color")
   "\n")
  ;; -----------------------------------------------------------------------------------------
  (mapconcat
   (lambda (elem)
     (pp-to-string elem))
   (bg-blogger-util-get-template-variable-references "template-stretch-denim-brents-color-scheme.xml" "color")
   "\n")
  ;; -----------------------------------------------------------------------------------------
  (insert (mapconcat
	   (lambda (elem)
	     (pp-to-string elem))
	   (bg-blogger-util-get-template-variable-references "template-Son_of_Moto_Mean_Green_Blogging_Machine_variation.xml" "color")
	   "\n"))
  ;; -----------------------------------------------------------------------------------------
  (insert (pp (bg-blogger-util-get-template-variable-references "template-stretch-denim-brents-color-scheme.xml" "color")))
  ;; -----------------------------------------------------------------------------------------
  (insert (pp (bg-blogger-util-get-template-variable-references "template-Son_of_Moto_Mean_Green_Blogging_Machine_variation.xml" "color")))
  ;; -----------------------------------------------------------------------------------------
  (let ((vars-white )
	(vars-green-section-to-var-hash (bg-blogger-get-section-to-var-name-hash
					 (bg-blogger-util-get-template-variable-references "template-stretch-denim-brents-color-scheme.xml" "color")))
	(vars-white-section-to-var-hash (bg-blogger-get-section-to-var-name-hash
					 (bg-blogger-util-get-template-variable-references "template-Son_of_Moto_Mean_Green_Blogging_Machine_variation.xml" "color"))))
    (maphash (lambda (section variable-name)
	       (list section variable-name))
	     vars-green-section-to-var-hash))
  ;; -----------------------------------------------------------------------------------------
  ;; Scan for property names given by prop-name-list, find the values associated
  ;; with them and the selectors they are used in:
  (let* ((prop-name-list (list "background"
			       "background-color"
			       "color"))
	 (props-green (bg-blogger-util-scan-css-properties "template-stretch-denim-brents-color-scheme.xml" prop-name-list))
	 (values-hash (make-hash-table :test 'equal)))
    (mapcar (lambda (prop)
	      (mapc (lambda (value)
		      (puthash (nth 2 value) t values-hash))
		    prop))
	    props-green)
    (let (values)
      (maphash (lambda (k v)
		 (push k values))
	       values-hash)
      (mapconcat 'identity values "\n")))
  ;;
  )








