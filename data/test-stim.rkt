#!/usr/bin/env racket
#lang racket

;; Test script for STIM-to-CHP circuits
;; Runs each .stim file and verifies against expected results

(require racket/system)
(require racket/file)
(require racket/string)
(require racket/match)
(require racket/port)

;; Configuration
(define stim-dir "stim-circuits")
(define verbose-mode (make-parameter #f))

;; Colors for terminal output
(define (green msg) (format "\033[32m~a\033[0m" msg))
(define (red msg) (format "\033[31m~a\033[0m" msg))
(define (yellow msg) (format "\033[33m~a\033[0m" msg))
(define (cyan msg) (format "\033[36m~a\033[0m" msg))

;; Run simulator on a STIM file
(define (run-simulator stim-file)
  (define cmd 
    (format "cd .. && cabal run --verbose=0 symplectic-chp -- data/~a/~a 2>&1" 
            stim-dir stim-file))
  
  (define output 
    (with-output-to-string
      (lambda ()
        (parameterize ([current-error-port (open-output-string)])
          (system cmd)))))
  
  ;; Extract just the results section (from first "====" onwards)
  (define lines (string-split output "\n"))
  (define result-start 
    (for/first ([(line idx) (in-indexed lines)]
                #:when (and (> (string-length line) 0)
                           (char=? (string-ref line 0) #\=)))
      idx))
  
  (if result-start
      (string-join (drop lines result-start) "\n")
      output))

;; Parse measurement outcomes from simulator output
(define (parse-measurements output)
  (define lines (string-split output "\n"))
  (for/list ([line lines]
             #:when (regexp-match #rx"^  M[0-9]+: ([+-])1" line))
    (define sign (regexp-match #rx"^  M[0-9]+: ([+-])1" line))
    (string=? (cadr sign) "+")))

;; Check if measurements are correlated (all same)
(define (measurements-correlated? outcomes)
  (or (null? outcomes)
      (null? (cdr outcomes))
      (let ([first (car outcomes)])
        (andmap (lambda (x) (eq? x first)) outcomes))))

;; Load expected results from .expected file
(define (load-expected base-name)
  (define expected-file (format "~a/~a.expected" stim-dir base-name))
  (and (file-exists? expected-file)
       (file->string expected-file)))

;; Check if error is expected
(define (expect-error? expected-content)
  (and expected-content
       (regexp-match #rx"error_expected:" expected-content)))

;; Check if expected file specifies correlations
(define (expect-correlated? expected-content)
  (and expected-content
       (regexp-match #rx"measurements_correlated:[[:space:]]*true" expected-content)))

;; Parse expected measurement outcomes
(define (parse-expected-outcomes expected-content)
  (define match (regexp-match #rx"measurement_outcomes:[[:space:]]*(\\[[^]]*\\])" expected-content))
  (and match
       (call-with-input-string (cadr match) read)))

;; Run a single test
(define (run-test stim-file)
  (define base-name (regexp-replace #rx"\\.stim$" stim-file ""))
  (define expected-content (load-expected base-name))
  
  (printf "Testing ~a... " (cyan stim-file))
  (flush-output)
  
  (define output (run-simulator stim-file))
  
  ;; Debug output if verbose
  (when (verbose-mode)
    (displayln "")
    (displayln "=== Raw output ===")
    (displayln output)
    (displayln "=================="))
  
  ;; Check for expected errors
  (define error-expected? (expect-error? expected-content))
  
  ;; Check for actual errors
  (define translation-error? (string-contains? output "Translation error"))
  (define parse-error? (string-contains? output "Parse error"))
  (define build-error? (string-contains? output "is not recognized"))
  
  (cond
    [build-error?
     (printf "~a\n" (red "BUILD ERROR (need to build first)"))
     #f]
    [error-expected?
     (if (or translation-error? parse-error?)
         (begin
           (printf "~a (expected error caught)\n" (green "PASS"))
           #t)
         (begin
           (printf "~a (expected error but got none)\n" (red "FAIL"))
           #f))]
    [translation-error?
     (printf "~a ~a\n" (red "ERROR:") 
             (regexp-match #rx"Translation error:[^\n]+" output))
     #f]
    [parse-error?
     (printf "~a\n" (red "PARSE ERROR"))
     #f]
    [else
     ;; Parse results
     (define outcomes (parse-measurements output))
     (define valid? (string-contains? output "Tableau valid: True"))
     
     ;; Build list of checks
     (define checks '())
     
     ;; Check tableau validity
     (set! checks (cons (cons "Tableau valid" valid?) checks))
     
     ;; Check measurement correlations if expected
     (when (expect-correlated? expected-content)
       (set! checks (cons (cons "Measurements correlated"
                                 (measurements-correlated? outcomes))
                          checks)))
     
     ;; Check specific outcomes if specified
     (define expected-outcomes (parse-expected-outcomes expected-content))
     (when expected-outcomes
       (set! checks (cons (cons "Exact outcomes match"
                                 (equal? outcomes expected-outcomes))
                          checks)))
     
     ;; Print results
     (define all-pass (andmap cdr (reverse checks)))
     (if all-pass
         (begin
           (printf "~a (~a measurements)\n" 
                   (green "PASS")
                   (length outcomes))
           #t)
         (begin
           (printf "~a\n" (red "FAIL"))
           (for ([check (reverse checks)])
             (unless (cdr check)
               (printf "  ~a: ~a\n" (car check) (red "failed"))))
           #f))]))

;; Main function
(define (main)
  (define files (directory-list stim-dir #:build? #f))
  (define stim-files 
    (sort (filter (lambda (f) (regexp-match #rx"\\.stim$" (path->string f))) files)
          string<?
          #:key path->string))
  
  (when (null? stim-files)
    (displayln (red "No .stim files found in stim-circuits/ directory"))
    (exit 1))
  
  (printf "\n~a\n" (make-string 60 #\=))
  (printf "STIM-to-CHP Circuit Tests\n")
  (printf "Found ~a test circuits\n" (length stim-files))
  (printf "~a\n\n" (make-string 60 #\=))
  
  (define results
    (for/list ([f stim-files])
      (run-test (path->string f))))
  
  (define passed (count identity results))
  (define total (length results))
  
  (printf "\n~a\n" (make-string 60 #\=))
  (printf "Results: ~a/~a tests passed\n" passed total)
  (if (= passed total)
      (printf "~a\n" (green "All tests passed!"))
      (printf "~a\n" (red "Some tests failed.")))
  (printf "~a\n" (make-string 60 #\=))
  
  (if (= passed total) 0 1))

;; Parse command line
(command-line
 #:program "test-stim"
 #:once-each
 [("-v" "--verbose") "Enable verbose output (show simulator output)"
                     (verbose-mode #t)])

;; Run main
(exit (main))
