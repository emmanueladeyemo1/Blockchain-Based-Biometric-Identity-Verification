;; Verification Request Contract
;; Manages confirmation needs and verification requests

(define-data-var admin principal tx-sender)

;; Status codes for verification requests
(define-constant STATUS-PENDING u1)
(define-constant STATUS-APPROVED u2)
(define-constant STATUS-REJECTED u3)
(define-constant STATUS-EXPIRED u4)

;; Map of verification requests
(define-map verification-requests
  uint
  {
    user-id: (string-ascii 64),
    requester: principal,
    provider: principal,
    status: uint,
    created-at: uint,
    updated-at: uint,
    expiration: uint
  }
)

;; Counter for request IDs
(define-data-var request-counter uint u0)

;; Public function to create a verification request
(define-public (create-request
                (user-id (string-ascii 64))
                (provider principal)
                (expiration-blocks uint))
  (let ((request-id (+ (var-get request-counter) u1)))
    (begin
      (var-set request-counter request-id)
      (map-set verification-requests
        request-id
        {
          user-id: user-id,
          requester: tx-sender,
          provider: provider,
          status: STATUS-PENDING,
          created-at: block-height,
          updated-at: block-height,
          expiration: (+ block-height expiration-blocks)
        }
      )
      (ok request-id)
    )
  )
)

;; Public function for providers to approve a verification request
(define-public (approve-request (request-id uint))
  (begin
    (match (map-get? verification-requests request-id)
      request-data
        (begin
          (asserts! (is-eq tx-sender (get provider request-data)) (err u300))
          (asserts! (is-eq (get status request-data) STATUS-PENDING) (err u301))
          (asserts! (< block-height (get expiration request-data)) (err u302))

          (map-set verification-requests
            request-id
            (merge request-data
              {
                status: STATUS-APPROVED,
                updated-at: block-height
              }
            )
          )
          (ok true)
        )
      (err u303)
    )
  )
)

;; Public function for providers to reject a verification request
(define-public (reject-request (request-id uint))
  (begin
    (match (map-get? verification-requests request-id)
      request-data
        (begin
          (asserts! (is-eq tx-sender (get provider request-data)) (err u300))
          (asserts! (is-eq (get status request-data) STATUS-PENDING) (err u301))
          (asserts! (< block-height (get expiration request-data)) (err u302))

          (map-set verification-requests
            request-id
            (merge request-data
              {
                status: STATUS-REJECTED,
                updated-at: block-height
              }
            )
          )
          (ok true)
        )
      (err u303)
    )
  )
)

;; Read-only function to check request status
(define-read-only (get-request-status (request-id uint))
  (match (map-get? verification-requests request-id)
    request-data
      (if (and (is-eq (get status request-data) STATUS-PENDING)
               (>= block-height (get expiration request-data)))
        STATUS-EXPIRED
        (get status request-data))
    u0
  )
)

;; Read-only function to get request details
(define-read-only (get-request-details (request-id uint))
  (map-get? verification-requests request-id)
)
