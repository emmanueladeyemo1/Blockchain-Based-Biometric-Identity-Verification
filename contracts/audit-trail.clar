;; Audit Trail Contract
;; Records authentication attempts and maintains an immutable audit log

(define-data-var admin principal tx-sender)

;; Event types
(define-constant EVENT-REGISTRATION u1)
(define-constant EVENT-AUTHENTICATION u2)
(define-constant EVENT-TEMPLATE-UPDATE u3)
(define-constant EVENT-CHALLENGE-COMPLETED u4)
(define-constant EVENT-VERIFICATION-REQUEST u5)

;; Result types
(define-constant RESULT-SUCCESS u1)
(define-constant RESULT-FAILURE u2)

;; Map of audit events
(define-map audit-events
  uint
  {
    user-id: (string-ascii 64),
    event-type: uint,
    result: uint,
    timestamp: uint,
    actor: principal,
    details: (string-utf8 256)
  }
)

;; Counter for event IDs
(define-data-var event-counter uint u0)

;; Public function to record an audit event
(define-public (record-event
                (user-id (string-ascii 64))
                (event-type uint)
                (result uint)
                (details (string-utf8 256)))
  (let ((event-id (+ (var-get event-counter) u1)))
    (begin
      (var-set event-counter event-id)
      (map-set audit-events
        event-id
        {
          user-id: user-id,
          event-type: event-type,
          result: result,
          timestamp: block-height,
          actor: tx-sender,
          details: details
        }
      )
      (ok event-id)
    )
  )
)

;; Read-only function to get event details
(define-read-only (get-event-details (event-id uint))
  (map-get? audit-events event-id)
)

;; Read-only function to get the latest event ID
(define-read-only (get-latest-event-id)
  (var-get event-counter)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin new-admin)
    (ok true)
  )
)
