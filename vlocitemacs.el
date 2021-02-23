;;; vlocitemacs.el --- Vlocity Build Tool :: Emacs integration

;;; Commentary:
;;
;; Essentially the following commands are abstracted into elisp and made dynamic:
;;
;; vlocity packDeploy -propertyfile build.properties -job job.yaml -key VlocityUITemplate/Test-test
;; vlocity packExport -propertyfile build.properties -job job.yaml -key VlocityUITemplate/Test-test
;;
;;
;;; Code:

(require 'transient)
(require 'json)


(defvar vlo/project-file-name ".vemacs.txt"
  "The name of the VlocitEmacs configuration file.

This file exists for the purpose of locating the project folder as there is no
good way of knowing you are in the root vlocity project.  It also contains the
list of environments to be used for deployments/exports.")

(defvar vlo/project-jobfile-template "projectPath: ."
  "Bare-bones template to use for =job.yaml=.")


;; DONE
(defun vlo/generate-project-file ()
  "Create the project file and append it to .gitignore if file exists."
  (interactive)
  (let* ((dir (read-directory-name "Choose Project Root: "))
         (project-file (concat dir vlo/project-file-name))
         (job-file (concat dir "job.yaml"))
         (gitignore (concat dir ".gitignore")))
    ;; Create job.yaml if it doesn't exist
    (when (not (file-exists-p job-file))
      (with-temp-file job-file (insert vlo/project-jobfile-template)))
    ;; Create .vemacs.txt
    (with-temp-file project-file (insert ""))
    ;; Insert username into .vemacs.txt
    (let ((current-user (vlo/prompt-org-list)))
      (with-temp-file project-file (insert current-user))
      )
    ;; Add .vemacs.txt to .gitignore
    (when (file-exists-p gitignore)
      (append-to-file vlo/project-file-name nil gitignore))))

;; DONE
(defun vlo/prompt-org-list ()
  "Get a list of authenticated orgs via SFDX cli and store the selected user in the project file."
  (interactive)
  (let* ((project-file (concat (vlo/project-path) vlo/project-file-name))
         (temp-json-file
          (make-temp-file "sfdx-org-list" nil ".json"
                          (shell-command-to-string "sfdx force:org:list --json")))
         (json-object-type 'hash-table)
         (json-array-type 'list)
         (json-key-type 'string)
         (json (json-read-file temp-json-file))
         (result (gethash "result" json))
         (orgs (gethash "nonScratchOrgs" result))
         (usernames '())
         )
    (dolist (org orgs)
      (add-to-list 'usernames (gethash "username" org)))
    (let ((current-user (completing-read "SFDX user: " usernames)))
      (with-temp-file project-file current-user)
      current-user)))

;; DONE
(defun vlo/in-vlocity-project ()
  "Check if you are currently inside a vlocity project."
  (if (vlo/project-path)
      t
    nil))

;; DONE
(defun vlo/project-path ()
  "Return path to the project file, or nil.

If project file exists in the current working directory, or a
parent directory recursively, return its path.  Otherwise, return
nil."
  (locate-dominating-file default-directory vlo/project-file-name))

;; DONE
(defun vlo/get-project-user ()
  "Return the user stored in the project file."
  (if (vlo/in-vlocity-project)
      (let ((project-dir (concat (vlo/project-path) vlo/project-file-name)))
        (with-temp-buffer (insert-file-contents project-dir) (buffer-string)))
    nil))

;; DONE
(defun vlo/get-jobfile-name ()
  "The name of the job.yaml file."
  "job.yaml")

;; DONE
(defun vlo/get-deployment-key ()
  "Return the Name of the component dynamically from the =_DataPpack.json= file."
  (let ((datapack-file (expand-file-name (concat (file-name-base) "_DataPack.json"))))
    (if (file-exists-p datapack-file)
        (let* ((json-object-type 'hash-table)
               (json-array-type 'list)
               (json-key-type 'string)
               (json (json-read-file datapack-file))
               (component-name (gethash "Name" json)))
          (concat "VlocityUITemplate/" component-name))
      nil)))

;; DONE
(defun vlo/exec-process (cmd name &optional comint)
  "Execute a process running CMD and use NAME to generate a unique buffer name and optionally pass COMINT as t to put buffer in `comint-mode'."
  (let ((compilation-buffer-name-function
         (lambda (mode)
           (format "*%s*" name))))
    (message (concat "Running " cmd))
    (compile cmd comint)))

;; DONE
(defun vlo/packExport (username job &optional key)
  "Run the packExport command with sfdx USERNAME or alias using the JOB file.

Optionally specifying KEY to export.  If KEY is nil, this command will run
packExport using job.yaml provided (i.e. export all)."
  (if (and (vlo/in-vlocity-project)
           (file-exists-p (concat (vlo/project-path) job)))
      (let ((cmd
             (if key
                 (format "cd %s; vlocity packExport -sfdx.username %s -job %s -key %s"
                         (vlo/project-path)
                         username
                         job
                         key)
               (format "cd %s; vlocity packExport -sfdx.username %s -job %s"
                       (vlo/project-path)
                       username
                       job)
               )))
        (vlo/exec-process cmd "vlocity:retrieve" t))
    (message "ERROR Exporting:: project: %s, user: %s, job: %s, key: %s"
             (vlo/project-path)
             username
             job
             key)))

;; DONE
(defun vlo/packDeploy (username job &optional key)
  "Run the packDeploy command with sfdx USERNAME or alias using the JOB file.

Optionally specifying KEY to export.  If KEY is nil, this command will run
packDeploy using job.yaml provided (i.e. deploy all)."
  (if (and (vlo/in-vlocity-project)
           (file-exists-p (concat (vlo/project-path) job)))
      (let ((cmd
             (if key
                 (format "cd %s; vlocity packDeploy -sfdx.username %s -job %s -key %s"
                         (vlo/project-path)
                         username
                         job
                         key)
               (format "cd %s; vlocity packDeploy -sfdx.username %s -job %s"
                       (vlo/project-path)
                       username
                       job)
               )))
        (vlo/exec-process cmd "vlocity:retrieve" t))
    (message "ERROR Deploying:: project: %s, user: %s, job: %s, key: %s"
             (vlo/project-path)
             username
             job
             key)))


(defun vlo/prompt-tabulated-list (&optional result)
  "A wrapper function to `vlocitemacs' from async call which passes a RESULT."
  (vlocitemacs))


;; FIXME :: This isn't triggering `vlocitemacs' as it should after building the list.
(defun vlo/get-available-exports (username job)
  "Run the packGetAllAvailableExports command with USERNAME and JOB file.

Returns a list into VlocityBuildLog.yaml.  Upon completing the async process
`vlocitemacs' is run."
  (if (and (vlo/in-vlocity-project)
           (file-exists-p (concat (vlo/project-path) job)))

      ;; this following 'if' is essentially a cache
      (if (not (string= (shell-command-to-string (format "cat %sVlocityBuildLog.yaml | grep 'manifest'" (vlo/project-path))) ""))
          (vlocitemacs)
        (progn
          (message "Generating list...")
          (async-start-process "vlocity:getlist" "sh" (lambda (res) (vlocitemacs)) "-c" (format "cd %s; vlocity packGetAllAvailableExports -sfdx.username %s -job %s -type VlocityUITemplate; exit" (vlo/project-path) username job))))
    (message "Cannot get available exports!")))

(defun vlo/createDatapack ()
  "Description."
  (interactive)
  (message "TODO :: Creating..."))

;; DONE
(defun vlo/search ()
  "Description."
  (interactive)
  (vlo/get-available-exports (vlo/get-project-user) (vlo/get-jobfile-name)))

;; DONE
(defun vlo/exportThisAction ()
  "Destructively retrieve this component."
  (interactive)
  (let ((key (vlo/get-deployment-key)))
    (if (yes-or-no-p (format "Retrieve \"%s\"? (THIS WILL OVERWRITE LOCAL CHANGES!) " key))
        (progn
          (message "Retrieving \"%s\"..." key)
          (vlo/packExport (vlo/get-project-user) (vlo/get-jobfile-name) key))
      (message "Cancelled Retrieve"))))

;; DONE
(defun vlo/exportAllAction ()
  "Description."
  (interactive)
  (if (yes-or-no-p "Retrieve ALL DataPacks in Manifest? (THIS WILL OVERWRITE LOCAL CHANGES!) ")
      (progn
        (message "Retrieving ALL DataPacks in Manifest file...")
        (vlo/packExport (vlo/get-project-user) (vlo/get-jobfile-name)))
    (message "Cancelled Retrieve")))

;; DONE
(defun vlo/deployThisAction ()
  "Description."
  (interactive)
  (let ((key (vlo/get-deployment-key)))
    (if key
        (progn
          (vlo/packDeploy (vlo/get-project-user) (vlo/get-jobfile-name) key)
          (message "Deploying \"%s\"..." key))
      (message "No DataPack file found for this component!"))))

;; DONE
(defun vlo/deployAllAction ()
  "Description."
  (interactive)
  (if (yes-or-no-p "Are you sure you wish to deploy everything? ")
      (vlo/packDeploy (vlo/get-project-user) (vlo/get-jobfile-name))
    (message "Cancelled")))




;; TODO : could check if file is installed locally and then either prompt to overwrite or goto item
(defun vlo/get-item-at-point (&optional arg)
  "Get the DataPack under cursor ARG."
  (interactive "P")
  (let ((item (aref (tabulated-list-get-entry) 0)))
    (message "Item Selected: %s and arg %s" item arg)
    (vlo/packExport (vlo/get-project-user) (vlo/get-jobfile-name) (concat "VlocityUITemplate/" item))))

;; DONE
(defvar vlocitemacs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'vlo/get-item-at-point)
    map)
  "Keymap for `vlocitemacs-mode'.")

;; DONE
(define-derived-mode vlocitemacs-mode tabulated-list-mode "VlocitEmacs"
  "A custom mode for interacting with the Vlocity Build Tool CLI."

  (let (
        (columns [("Choose DataPack" 100)])
        (rows (mapcar (lambda(x) `(nil [,x]))
                      (split-string (shell-command-to-string (format "cat %sVlocityBuildLog.yaml | grep ' - ' | sed 's/ - VlocityUITemplate\\///'" (vlo/project-path)))))))
    (buffer-disable-undo)
    (kill-all-local-variables)
    (setq truncate-lines t)
    (setq mode-name "VlocitEmacs")
    (setq major-mode 'vlocitemacs-mode)
    (setq tabulated-list-format columns)
    (setq tabulated-list-entries rows)
    (use-local-map vlocitemacs-mode-map)
    (tabulated-list-init-header)
    (tabulated-list-print)
    (run-mode-hooks 'vlocitemacs-mode-hook)))

;; DONE
(defun vlocitemacs ()
  "Invoke the VlocitEmacs buffer."
  (interactive)
  (switch-to-buffer "*vlocitemacs*")
  (vlocitemacs-mode))






;; DONE
(defun vlo/transient-action ()
  "Dynamically choose which transient to show based on if currently in a project."
  (interactive)
  (if (vlo/in-vlocity-project)
      (vlo/transient-project-action)
    (vlo/transient-init-action)))

(define-transient-command vlo/transient-init-action ()
  "Vlocity Build Tool CLI Actions"
  ["Vlocity Project file not created"
   ("i" "Initialize Vlocity Project" vlo/generate-project-file)])

(define-transient-command vlo/transient-project-action ()
  "Vlocity Build Tool CLI Actions"
  ["Create"
   ("c" "Create a new datapack (dynamically)"       vlo/createDatapack)]
  ["Retrieve"
   ("s" "Search for new datapack"                   vlo/search)
   ("r" "Refresh this datapack (destructive)"       vlo/exportThisAction)
   ("R" "Refresh all local datapacks (destructive)" vlo/exportAllAction)
   ]
  ["Deploy"
   ("d" "Deploy this datapack"                      vlo/deployThisAction)
   ("D" "Deploy all local datapacks"                vlo/deployAllAction)
   ])



(provide 'vlocitemacs)
;;; vlocitemacs.el ends here
