;;; -*- coding: utf-8; mode: emacs-lisp; -*-
(eval-when-compile (require 'cl))
(require 'helm)
(require 'helm-ag)

(defvar helm-ag-by-process-directory '())
(defvar helm-ag-base-command-list `(,helm-ag-base-command))

(defvar helm-ag-by-process-source
  '((name . "helm-ag-by-process")
    (candidates-process . (lambda ()
                            (funcall helm-ag-by-process-function)))
    (candidates-in-buffer)
    (delayed)))

(defvar helm-ag-by-process-actions
  '((:open
     (("Open File" . (lambda (c)
                       (helm-ag-find-file-action c 'find-file)))
      ("Open File Other Window" .
       (lambda (c)
         (helm-ag-find-file-action c 'find-file-other-window)))))
    (:move
     (("Move the line" . (lambda (line)
                           (string-match "^\\([0-9]*\\):" line)
                           (goto-char (point-min))
                           (forward-line (1- (string-to-number
                                              (match-string 1 line))))))))))

(defvar helm-ag-by-process-get-command
  (lambda (pattern)
    (let*
        ((set-attribute
          (lambda (attr)
            (helm-attrset 'action
                               (car
                                (assoc-default attr helm-ag-by-process-actions))
                               helm-ag-by-process-source)))
         (patterns (split-string pattern))
         (directory helm-ag-by-process-directory)
         (create-ag-command
          (lambda (minibuffer-patterns)
            (loop with ag = helm-ag-base-command
                  for search-word in minibuffer-patterns
                  for dir = directory then ""
                  collect (concat ag " \"" search-word "\" " dir " | "))))
         (ag-commands
          (replace-regexp-in-string
           " | $" ""
           (mapconcat 'identity (funcall create-ag-command patterns) ""))))
      (if (< 1 (length patterns))
          (funcall set-attribute :open)
        (funcall set-attribute :move))
      ag-commands)))

(defvar helm-ag-by-process-function
  (lambda ()
    (start-process
     "emacs-helm-ag-process" nil "/bin/sh" "-c"
     (funcall helm-ag-by-process-get-command helm-pattern))))

(defvar helm-ag-by-process-keymap
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map helm-map)
    (define-key map (kbd "C-o") 'helm-ag-by-process-change-option)
    map))

(defun helm-ag-by-process (&optional directory)
  (interactive)
  (setq helm-ag-by-process-directory (or directory default-directory))
  (helm :sources helm-ag-by-process-source
        :prompt "ag: "
        :buffer "*helm ag process*"
        :keymap helm-ag-by-process-keymap))

(defun helm-ag-by-process-change-option ()
  (interactive)
  (setq helm-ag-base-command
        (loop with length = (length helm-ag-base-command-list)
              for i from 0 to (1- length)
              for num = (if (equal (1- length) i)
                            0
                          (1+ i))
              for next-command = (nth num helm-ag-base-command-list)
              for old-command =  (nth i helm-ag-base-command-list)
              if (equal helm-ag-base-command old-command)
              do (return next-command))))

(defun helm-ag-by-process-from-current-file ()
  (interactive)
  (helm-attrset 'action
                (car (assoc-default :move helm-ag-by-process-actions))
                helm-ag-by-process-source)
  (helm-ag-by-process buffer-file-name))

(provide 'helm-ag-by-process)
