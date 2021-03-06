;;; elisp.el --- Some helper functions -*- lexical-binding: t -*-

;; Copyright (C) Jeremy Bi

;; Author: Jeremy Bi <bixuanzju@qq.com>
;; Maintainer: Jeremy Bi <bixuanzju@qq.com>
;; Created:  2 Jan 2014
;; Keywords: convenience editing
;; URL: https://github.com/bixuanzju/emacs.d

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Code:

(defmacro my-delq-multi (list &rest elems)
  "Delete ELEMS from LIST."
  (let ((result (mapcar (lambda (elem)
                          `(setq ,list (delq ,elem ,list)))
                        elems)))
    `(progn ,@result)))

(defun goto-line-with-feedback ()
  "Show line numbers temporarily, while prompting for the line
  number input."
  (interactive)
  (unwind-protect
      (progn
        (linum-mode 1)
        (call-interactively 'goto-line))
    (linum-mode -1)))

(defun prelude-get-positions-of-line-or-region ()
  "Return positions (beg . end) of the current line or region."
  (let (beg end)
    (if (and mark-active (> (point) (mark)))
        (exchange-point-and-mark))
    (setq beg (line-beginning-position))
    (if mark-active
        (exchange-point-and-mark))
    (setq end (line-end-position))
    (cons beg end)))

(defun duplicate-comment-current-line-or-region (arg)
  "Duplicates and/or comments the current line. If there's no
region, the current line will be duplicated.  However, if there's
a region, all lines that region covers will be duplicated."
  (interactive "P")
  (pcase-let* ((origin (- (point) (line-beginning-position)))
               (`(,beg . ,end) (prelude-get-positions-of-line-or-region))
               (region (buffer-substring-no-properties beg end)))
    (if arg
        (comment-or-uncomment-region beg end))
    (setq end (line-end-position))
    (goto-char end)
    (newline)
    (insert region)
    (goto-char (+ (line-beginning-position) origin))))

(defun my/forward-line-by-many ()
  "Move line forward by multiple times."
  (interactive)
  (forward-line 4))

(defun my/backward-line-by-many ()
  "Move line backward by multiple times."
  (interactive)
  (forward-line -4))

;; borrowed from Emacs 25
(when (= emacs-major-version 24)
  (defun my/comment-line (n)
    "Comment or uncomment current line and leave point after it.
With positive prefix, apply to N lines including current one.
With negative prefix, apply to -N lines above.  Also, further
consecutive invocations of this command will inherit the negative
argument.

If region is active, comment lines in active region instead.
Unlike `comment-dwim', this always comments whole lines."
    (interactive "p")
    (if (use-region-p)
        (comment-or-uncomment-region
         (save-excursion
           (goto-char (region-beginning))
           (line-beginning-position))
         (save-excursion
           (goto-char (region-end))
           (line-end-position)))
      (when (and (eq last-command 'comment-line-backward)
                 (natnump n))
        (setq n (- n)))
      (let ((range
             (list (line-beginning-position)
                   (goto-char (line-end-position n)))))
        (comment-or-uncomment-region
         (apply #'min range)
         (apply #'max range)))
      (forward-line 1)
      (back-to-indentation)
      (unless (natnump n) (setq this-command 'comment-line-backward))))
  (bind-key [?\C-\;] 'my/comment-line ctl-x-map))

;; copy from http://xuchunyang.me/Opening-iTerm-From-an-Emacs-Buffer/
(defun my/iterm-shell-command (command &optional prefix)
  "cd to `default-directory' then run COMMAND in iTerm.
With PREFIX, cd to project root."
  (interactive (list (read-shell-command
                      "iTerm Shell Command: ")
                     current-prefix-arg))
  (let* ((dir (if prefix (my/project-root)
                default-directory))
         ;; if COMMAND is empty, just change directory
         (cmd (format "cd %s ;%s" dir command)))
    (do-applescript
     (format
      "
  tell application \"iTerm\"
       activate
       set _session to current session of current terminal
       tell _session
            set command to get the clipboard
            write text \"%s\"
       end tell
  end tell
  " cmd))))

(defun my/project-root ()
  "Return the project root for current buffer."
  (let ((directory default-directory))
    (or (locate-dominating-file directory ".git")
        (locate-dominating-file directory ".svn")
        (locate-dominating-file directory ".hg"))))

;;; copy from https://github.com/purcell/emacs.d
(defun sanityinc/maybe-set-bundled-elisp-readonly ()
  "If this elisp appears to be part of Emacs, then disallow editing."
  (when (and (buffer-file-name)
             (string-match-p "\\.el\\.gz\\'" (buffer-file-name)))
    (setq buffer-read-only t)
    (view-mode +1)))

(add-hook 'emacs-lisp-mode-hook 'sanityinc/maybe-set-bundled-elisp-readonly)


;; Courtesy from http://endlessparentheses.com/emacs-narrow-or-widen-dwim.html
(defun narrow-or-widen-dwim (p)
  "Widen if buffer is narrowed, narrow-dwim otherwise.
Dwim means: region, org-src-block, org-subtree, or defun,
whichever applies first. Narrowing to org-src-block actually
calls `org-edit-src-code'.

With prefix P, don't widen, just narrow even if buffer is
already narrowed."
  (interactive "P")
  (declare (interactive-only))
  (cond ((and (buffer-narrowed-p) (not p)) (widen))
        ((region-active-p)
         (narrow-to-region (region-beginning) (region-end)))
        ((derived-mode-p 'org-mode)
         ;; `org-edit-src-code' is not a real narrowing
         ;; command. Remove this first conditional if you
         ;; don't want it.
         (cond ((ignore-errors (org-edit-src-code))
                (delete-other-windows))
               ((ignore-errors (org-narrow-to-block) t))
               (t (org-narrow-to-subtree))))
        ((derived-mode-p 'latex-mode)
         (LaTeX-narrow-to-environment))
        (t (narrow-to-defun))))

(add-hook 'LaTeX-mode-hook
          (lambda () (define-key LaTeX-mode-map "\C-xn" nil)))

(provide 'elisp)


;;; elisp.el ends here
