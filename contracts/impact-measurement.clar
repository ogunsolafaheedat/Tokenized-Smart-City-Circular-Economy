;; Impact Measurement Contract
;; Tracks circular economy benefits and environmental impact

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-not-found (err u401))
(define-constant err-invalid-metric (err u402))

;; Impact metrics
(define-constant METRIC-CO2-REDUCTION u1)
(define-constant METRIC-WASTE-DIVERTED u2)
(define-constant METRIC-ENERGY-SAVED u3)
(define-constant METRIC-WATER-CONSERVED u4)

;; Data structures
(define-map impact-records
  { record-id: uint }
  {
    contributor: principal,
    metric-type: uint,
    value: uint,
    unit: (string-ascii 20),
    description: (string-ascii 100),
    verified: bool,
    created-at: uint
  }
)

(define-map user-impact-totals
  { user: principal, metric-type: uint }
  { total-value: uint }
)

(define-map global-impact-totals
  { metric-type: uint }
  { total-value: uint }
)

(define-map record-counter { id: uint } { count: uint })

;; Initialize counter
(map-set record-counter { id: u0 } { count: u0 })

;; Read-only functions
(define-read-only (get-impact-record (record-id uint))
  (map-get? impact-records { record-id: record-id })
)

(define-read-only (get-user-impact-total (user principal) (metric-type uint))
  (default-to u0 (get total-value (map-get? user-impact-totals { user: user, metric-type: metric-type })))
)

(define-read-only (get-global-impact-total (metric-type uint))
  (default-to u0 (get total-value (map-get? global-impact-totals { metric-type: metric-type })))
)

(define-read-only (is-valid-metric (metric-type uint))
  (or (is-eq metric-type METRIC-CO2-REDUCTION)
      (is-eq metric-type METRIC-WASTE-DIVERTED)
      (is-eq metric-type METRIC-ENERGY-SAVED)
      (is-eq metric-type METRIC-WATER-CONSERVED))
)

;; Public functions
(define-public (record-impact (metric-type uint) (value uint) (unit (string-ascii 20)) (description (string-ascii 100)))
  (let
    (
      (current-count (default-to u0 (get count (map-get? record-counter { id: u0 }))))
      (new-id (+ current-count u1))
      (current-user-total (get-user-impact-total tx-sender metric-type))
      (current-global-total (get-global-impact-total metric-type))
    )
    (asserts! (is-valid-metric metric-type) err-invalid-metric)

    ;; Record the impact
    (map-set impact-records
      { record-id: new-id }
      {
        contributor: tx-sender,
        metric-type: metric-type,
        value: value,
        unit: unit,
        description: description,
        verified: false,
        created-at: block-height
      }
    )

    ;; Update user total
    (map-set user-impact-totals
      { user: tx-sender, metric-type: metric-type }
      { total-value: (+ current-user-total value) }
    )

    ;; Update global total
    (map-set global-impact-totals
      { metric-type: metric-type }
      { total-value: (+ current-global-total value) }
    )

    (map-set record-counter { id: u0 } { count: new-id })
    (ok new-id)
  )
)

(define-public (verify-impact (record-id uint))
  (let
    (
      (record (unwrap! (map-get? impact-records { record-id: record-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    (map-set impact-records
      { record-id: record-id }
      (merge record { verified: true })
    )
    (ok true)
  )
)

(define-public (calculate-impact-score (user principal))
  (let
    (
      (co2-total (get-user-impact-total user METRIC-CO2-REDUCTION))
      (waste-total (get-user-impact-total user METRIC-WASTE-DIVERTED))
      (energy-total (get-user-impact-total user METRIC-ENERGY-SAVED))
      (water-total (get-user-impact-total user METRIC-WATER-CONSERVED))
    )
    ;; Simple scoring algorithm: sum all impacts with weights
    (ok (+ (* co2-total u10) (* waste-total u5) (* energy-total u3) (* water-total u2)))
  )
)
