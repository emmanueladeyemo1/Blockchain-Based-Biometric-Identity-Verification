;; Liveness Detection Contract
;; Prevents spoofing attacks by validating liveness challenges

(define-data-var admin principal tx-sender)

;; Map of liveness challenge types
(define-map challenge-types
  uint
  {
    name: (string-ascii 64),
    difficulty: uint,
    active: bool
  }
)

;; Map of completed liveness challenges
(define-map completed-challenges
  {
    user-id: (string-ascii 64),
    challenge-id: uint
  }
  {
    challenge-type: uint,
    timestamp: uint,
    verifier: principal,
    proof-hash: (buff 64),
    valid-until: uint
  }
)

;; Counter for challenge IDs
(define-data-var challenge-counter uint u0)

;; Map of authorized verifiers
(define-map authorized-verifiers
  principal
  bool
)

;; Initialize challenge types
(begin
  (map-set challenge-types u1
    { name: "facial-movement", difficulty: u1, active: true })
  (map-set challenge-types u2
    { name: "voice-recognition", difficulty: u2, active: true })
  (map-set challenge-types u3
    { name: "multi-factor", difficulty: u3, active: true })
)

;; Public function to register a completed challenge
(define-public (register-challenge
                (user-id (string-ascii 64))
                (challenge-type uint)
                (proof-hash (buff 64))
                (valid-blocks uint))
  (let ((challenge-id (+ (var-get challenge-counter) u1)))
    (begin
      (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) (err u400))
      (asserts! (is-some (map-get? challenge-types challenge-type)) (err u401))

      (var-set challenge-counter challenge-id)
      (map-set completed-challenges
        {
          user-id: user-id,
          challenge-id: challenge-id
        }
        {
          challenge-type: challenge-type,
          timestamp: block-height,
          verifier: tx-sender,
          proof-hash: proof-hash,
          valid-until: (+ block-height valid-blocks)
        }
      )
      (ok challenge-id)
    )
  )
)

;; Read-only function to verify if a user has a valid liveness challenge
(define-read-only (has-valid-challenge (user-id (string-ascii 64)) (challenge-id uint))
  (match (map-get? completed-challenges { user-id: user-id, challenge-id: challenge-id })
    challenge-data
      (and
        (< block-height (get valid-until challenge-data))
        (match (map-get? challenge-types (get challenge-type challenge-data))
          type-data (get active type-data)
          false
        )
      )
    false
  )
)

;; Admin function to add a new challenge type
(define-public (add-challenge-type (type-id uint) (name (string-ascii 64)) (difficulty uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (not (is-some (map-get? challenge-types type-id))) (err u402))

    (map-set challenge-types
      type-id
      {
        name: name,
        difficulty: difficulty,
        active: true
      }
    )
    (ok true)
  )
)

;; Admin function to authorize a verifier
(define-public (authorize-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (map-set authorized-verifiers verifier true)
    (ok true)
  )
)

;; Admin function to revoke a verifier
(define-public (revoke-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (map-set authorized-verifiers verifier false)
    (ok true)
  )
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin new-admin)
    (ok true)
  )
)
