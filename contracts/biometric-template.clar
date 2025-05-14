;; Biometric Template Contract
;; Securely stores authentication data (hashed biometric templates)

(define-data-var admin principal tx-sender)

;; Map of user biometric templates (hashed)
(define-map biometric-templates
  { user-id: (string-ascii 64) }
  {
    template-hash: (buff 64),
    provider: principal,
    created-at: uint,
    updated-at: uint,
    version: uint
  }
)

;; List of authorized providers that can store templates
(define-map authorized-providers
  principal
  bool
)

;; Public function to register a biometric template
(define-public (register-template
                (user-id (string-ascii 64))
                (template-hash (buff 64))
                (provider principal))
  (begin
    (asserts! (default-to false (map-get? authorized-providers provider)) (err u200))

    (map-set biometric-templates
      { user-id: user-id }
      {
        template-hash: template-hash,
        provider: provider,
        created-at: block-height,
        updated-at: block-height,
        version: u1
      }
    )
    (ok true)
  )
)

;; Public function to update a biometric template
(define-public (update-template
                (user-id (string-ascii 64))
                (template-hash (buff 64))
                (provider principal))
  (begin
    (asserts! (default-to false (map-get? authorized-providers provider)) (err u200))

    (match (map-get? biometric-templates { user-id: user-id })
      existing-data
        (begin
          (asserts! (is-eq (get provider existing-data) provider) (err u201))
          (map-set biometric-templates
            { user-id: user-id }
            {
              template-hash: template-hash,
              provider: provider,
              created-at: (get created-at existing-data),
              updated-at: block-height,
              version: (+ (get version existing-data) u1)
            }
          )
          (ok true)
        )
      (err u202)
    )
  )
)

;; Read-only function to verify a template hash
(define-read-only (verify-template (user-id (string-ascii 64)) (template-hash (buff 64)))
  (match (map-get? biometric-templates { user-id: user-id })
    existing-data (is-eq (get template-hash existing-data) template-hash)
    false
  )
)

;; Admin function to authorize a provider
(define-public (authorize-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (map-set authorized-providers provider true)
    (ok true)
  )
)

;; Admin function to revoke a provider
(define-public (revoke-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (map-set authorized-providers provider false)
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
