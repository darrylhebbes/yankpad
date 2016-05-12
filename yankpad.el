;;; yankpad.el --- Paste snippets from an org-mode file

;; Copyright (C) 2016 Erik Sjöstrand
;; MIT License

;; Author: Erik Sjöstrand
;; URL: http://github.com/Kungsgeten/yankpad
;; Version: 1.00
;; Keywords: abbrev convenience
;; Package-Requires: ((emacs "24.4"))

;;; Commentary:

;; A way to insert text snippets from an org-mode file.  The org-mode file in
;; question is defined in `yankpad-file' and is set to "yankpad.org" in your
;; `org-directory' by default.  In this file, each heading specifies a snippet
;; category and each subheading of that category defines a snippet.  This way
;; you can have different yankpads for different occasions.
;;
;; If you have yasnippet installed, yankpad will try to use it when pasting
;; snippets.  This means that you can use the features that yasnippet provides
;; (tab stops, elisp, etc).  You can use yankpad without yasnippet, and then the
;; snippet will simply be inserted as is.
;;
;; To insert a snippet from the yankpad, use `yankpad-insert'.  If you need to
;; change the category, use `yankpad-set-category'.  Here's an example of what
;; yankpad.org could look like:
;;  
;; * Category 1
;; ** Snippet 1
;; 
;;    This is a snippet.
;; 
;; ** Snippet 2
;;
;;    This is another snippet
;; * Category 2
;; ** Snippet 1
;;
;;    This is yet another snippet, in a different category.

;;; Code:

(require 'org-element)
(require 'subr-x)

(defvar yankpad-file (expand-file-name "yankpad.org" org-directory)
  "The path to your yankpad.")
(defvar yankpad-category nil
  "The current yankpad category.  Change with `yankpad-set-category'.")
(defvar yankpad-category-heading-level 1
  "The org-mode heading level of categories in the `yankpad-file'.")
(defvar yankpad-snippet-heading-level 2
  "The org-mode heading level of snippets in the `yankpad-file'.")

(defun yankpad-set-category ()
  "Change the yankpad category."
  (interactive)
  (setq yankpad-category
        (completing-read "Category: " (yankpad--categories))))

;;;###autoload
(defun yankpad-insert ()
  "Insert an entry from the yankpad.
Uses `yankpad-category', and prompts for it if it isn't set."
  (interactive)
  (unless yankpad-category
    (or (yankpad-local-category-to-major-mode)
        (yankpad-set-category)))
  (yankpad-insert-from-category yankpad-category))

(defun yankpad-insert-from-category (category)
  "Insert a yankpad entry from CATEGORY.
Does not change `yankpad-category'."
  (let* ((snippets (yankpad--snippets category))
         (snippet (completing-read "Snippet: " snippets))
         (text (cadr (assoc snippet snippets))))
    (if (require 'yasnippet nil t)
        (if (region-active-p)
            (yas-expand-snippet text (region-beginning) (region-end))
          (yas-expand-snippet text))
      (insert text))))

(defun yankpad-edit ()
  "Open the yankpad file for editing."
  (interactive)
  (find-file yankpad-file))

(defun yankpad--file-elements ()
  "Run `org-element-parse-buffer' on the `yankpad-file'."
  (with-temp-buffer
    (delay-mode-hooks
      (org-mode)
      (insert-file-contents yankpad-file)
      (org-element-parse-buffer))))

(defun yankpad--categories ()
  "Get the yankpad categories as a list."
  (let ((data (yankpad--file-elements)))
    (org-element-map data 'headline
      (lambda (h)
        (when (equal (org-element-property :level h)
                     yankpad-category-heading-level)
          (org-element-property :raw-value h))))))

(defun yankpad--snippets (category-name)
  "Get an alist of the snippets in CATEGORY-NAME.
The car is the snippet name and the cdr is the snippet string." 
  (let ((data (yankpad--file-elements)))
    (org-element-map data 'headline
      (lambda (h)
        (let ((parent (org-element-property :parent h)))
          (when (and (equal (org-element-property :level h)
                            yankpad-snippet-heading-level)
                     (equal (org-element-property :raw-value parent) category-name))
            (cons (org-element-property :raw-value h)
                  (org-element-map h 'section #'org-element-interpret-data))))))))

(defun yankpad-local-category-to-major-mode ()
  "Try to change `yankpad-category' to match the buffer's major mode.
If successful, make `yankpad-category' buffer-local."
  (when-let ((category (car (member (symbol-name major-mode)
                                    (yankpad--categories)))))
    (set (make-local-variable 'yankpad-category) category)))

(add-hook 'after-change-major-mode-hook #'yankpad-local-category-to-major-mode)

(defun yankpad-local-category-to-projectile ()
  "Try to change `yankpad-category' to match the `projectile-project-name'.
If successful, make `yankpad-category' buffer-local."
  (when (require 'projectile nil t)
    (when-let ((category (car (member (projectile-project-name)
                                      (yankpad--categories)))))
      (set (make-local-variable 'yankpad-category) category))))

(add-hook 'projectile-find-file-hook #'yankpad-local-category-to-projectile)

(provide 'yankpad)
;;; yankpad.el ends here
