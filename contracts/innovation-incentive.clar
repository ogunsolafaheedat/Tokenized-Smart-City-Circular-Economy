;; Innovation Incentive Contract
;; Rewards circular economy innovations and sustainable practices

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-not-found (err u501))
(define-constant err-insufficient-funds (err u502))
(define-constant err-already-claimed (err u503))
(define-constant err-invalid-innovation (err u504))

;; Innovation categories
(define-constant INNOVATION-WASTE-REDUCTION u1)
(define-constant INNOVATION-ENERGY-EFFICIENCY u2)
(define-constant INNOVATION-RESOURCE-SHARING u3)
(define-constant INNOVATION-CIRCULAR-DESIGN u4)

;; Reward amounts (in micro-STX)
(define-constant REWARD-TIER-1 u1000000) ;; 1 STX
(define-constant REWARD-TIER-2 u2000000) ;; 2 STX
(define-constant REWARD-TIER-3 u5000000) ;; 5 STX

;; Data structures
(define-map innovations
  { innovation-id: uint }
  {
    innovator: principal,
    category: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    impact-score: uint,
    reward-tier: uint,
    approved: bool,
    reward-claimed: bool,
    created-at: uint
  }
)

(define-map innovation-votes
  { innovation-id: uint, voter: principal }
  { vote: bool }
)

(define-map innovation-vote-counts
  { innovation-id: uint }
  { yes-votes: uint, no-votes: uint }
)

(define-map innovation-counter { id: uint } { count: uint })

;; Initialize counter
(map-set innovation-counter { id: u0 } { count: u0 })

;; Read-only functions
(define-read-only (get-innovation (innovation-id uint))
  (map-get? innovations { innovation-id: innovation-id })
)

(define-read-only (get-vote-counts (innovation-id uint))
  (map-get? innovation-vote-counts { innovation-id: innovation-id })
)

(define-read-only (has-voted (innovation-id uint) (voter principal))
  (is-some (map-get? innovation-votes { innovation-id: innovation-id, voter: voter }))
)

(define-read-only (get-reward-amount (tier uint))
  (if (is-eq tier u1)
    REWARD-TIER-1
    (if (is-eq tier u2)
      REWARD-TIER-2
      (if (is-eq tier u3)
        REWARD-TIER-3
        u0
      )
    )
  )
)

;; Public functions
(define-public (submit-innovation (category uint) (title (string-ascii 100)) (description (string-ascii 500)))
  (let
    (
      (current-count (default-to u0 (get count (map-get? innovation-counter { id: u0 }))))
      (new-id (+ current-count u1))
    )
    (asserts! (or (is-eq category INNOVATION-WASTE-REDUCTION)
                  (is-eq category INNOVATION-ENERGY-EFFICIENCY)
                  (is-eq category INNOVATION-RESOURCE-SHARING)
                  (is-eq category INNOVATION-CIRCULAR-DESIGN)) err-invalid-innovation)

    (map-set innovations
      { innovation-id: new-id }
      {
        innovator: tx-sender,
        category: category,
        title: title,
        description: description,
        impact-score: u0,
        reward-tier: u1, ;; Default to tier 1
        approved: false,
        reward-claimed: false,
        created-at: block-height
      }
    )

    ;; Initialize vote counts
    (map-set innovation-vote-counts
      { innovation-id: new-id }
      { yes-votes: u0, no-votes: u0 }
    )

    (map-set innovation-counter { id: u0 } { count: new-id })
    (ok new-id)
  )
)

(define-public (vote-on-innovation (innovation-id uint) (vote bool))
  (let
    (
      (innovation (unwrap! (map-get? innovations { innovation-id: innovation-id }) err-not-found))
      (current-counts (unwrap! (map-get? innovation-vote-counts { innovation-id: innovation-id }) err-not-found))
    )
    (asserts! (not (has-voted innovation-id tx-sender)) err-already-claimed)

    ;; Record vote
    (map-set innovation-votes
      { innovation-id: innovation-id, voter: tx-sender }
      { vote: vote }
    )

    ;; Update vote counts
    (if vote
      (map-set innovation-vote-counts
        { innovation-id: innovation-id }
        (merge current-counts { yes-votes: (+ (get yes-votes current-counts) u1) })
      )
      (map-set innovation-vote-counts
        { innovation-id: innovation-id }
        (merge current-counts { no-votes: (+ (get no-votes current-counts) u1) })
      )
    )

    (ok true)
  )
)

(define-public (approve-innovation (innovation-id uint) (impact-score uint) (reward-tier uint))
  (let
    (
      (innovation (unwrap! (map-get? innovations { innovation-id: innovation-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= reward-tier u3) err-invalid-innovation)

    (map-set innovations
      { innovation-id: innovation-id }
      (merge innovation {
        approved: true,
        impact-score: impact-score,
        reward-tier: reward-tier
      })
    )
    (ok true)
  )
)

(define-public (claim-reward (innovation-id uint))
  (let
    (
      (innovation (unwrap! (map-get? innovations { innovation-id: innovation-id }) err-not-found))
      (reward-amount (get-reward-amount (get reward-tier innovation)))
    )
    (asserts! (is-eq tx-sender (get innovator innovation)) err-owner-only)
    (asserts! (get approved innovation) err-invalid-innovation)
    (asserts! (not (get reward-claimed innovation)) err-already-claimed)

    ;; Mark reward as claimed
    (map-set innovations
      { innovation-id: innovation-id }
      (merge innovation { reward-claimed: true })
    )

    ;; Transfer reward (simplified - in real implementation would use STX transfer)
    (ok reward-amount)
  )
)
