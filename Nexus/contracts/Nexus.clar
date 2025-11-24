;; CryptoScholarship DAO Contract
;; Description: A decentralized scholarship fund where donors pool resources and vote on student grant applications

;; Contract constants
(define-constant ADMIN_ADDRESS tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_INSUFFICIENT_DONATION (err u2))
(define-constant ERR_INVALID_APPLICATION (err u3))
(define-constant ERR_ALREADY_VOTED (err u4))
(define-constant ERR_VOTING_CLOSED (err u5))
(define-constant ERR_RAPID_SUCCESSION (err u6))
(define-constant ERR_VALIDATION_FAILED (err u7))
(define-constant ERR_AMOUNT_TOO_LOW (err u8))
(define-constant ERR_APPLICATION_NOT_FOUND (err u9))

;; Manual Block Height Tracking
(define-data-var current_semester uint u0)
(define-data-var last_contributor principal tx-sender)

;; Semester Counter Update Function
(define-public (advance_semester)
    (begin
        ;; Prevent same donor from updating twice in a row
        (asserts! 
            (not (is-eq (var-get last_contributor) tx-sender)) 
            ERR_RAPID_SUCCESSION
        )

        ;; Increment semester counter
        (var-set current_semester 
            (+ (var-get current_semester) u1)
        )

        ;; Record last updater
        (var-set last_contributor tx-sender)

        (ok (var-get current_semester))
    )
)

;; Storage for donor contributions
(define-map scholarship_donors 
    {donor: principal} 
    {
        contribution_size: uint,
        is_active_donor: bool,
        join_semester: uint
    }
)

;; Storage for scholarship applications
(define-map grant_applications
    {application_id: uint}
    {
        student_wallet: principal,
        requested_grant: uint,
        total_votes: uint,
        support_votes: uint,
        is_finalized: bool,
        submission_semester: uint,
        vote_deadline: uint
    }
)

;; Track individual donor votes on applications
(define-map voting_history
    {donor: principal, application_id: uint}
    {has_voted: bool}
)

;; Track total scholarship fund and next application ID
(define-data-var total_fund_balance uint u0)
(define-data-var next_application_id uint u1)

;; Voting period constants
(define-constant VOTING_PERIOD u144) ;; Approximately 24 hours 
(define-constant ELIGIBILITY_PERIOD u1440) ;; Approximately 10 days
(define-constant MAX_GRANT_SIZE u1000000000) ;; Maximum grant amount

;; Validation helper functions
(define-read-only (is_valid_application (id uint))
    (is-some (map-get? grant_applications {application_id: id}))
)

(define-read-only (is_valid_student (student principal))
    (and 
        (not (is-eq student (as-contract tx-sender)))
        (not (is-eq student 'SP000000000000000000002Q6VF78))
    )
)

(define-read-only (is_valid_grant_amount (amount uint))
    (and (> amount u0) (<= amount MAX_GRANT_SIZE))
)

;; Donor contribution function
(define-public (make_donation (donation_size uint))
    (let 
        (
            (semester (var-get current_semester))
        )
        (begin
            ;; Validate input
            (asserts! (is_valid_grant_amount donation_size) ERR_VALIDATION_FAILED)
            
            ;; Ensure minimum donation
            (asserts! (> donation_size u0) ERR_INSUFFICIENT_DONATION)

            ;; Transfer STX to contract
            (try! (stx-transfer? donation_size tx-sender (as-contract tx-sender)))

            ;; Update donor record
            (map-set scholarship_donors 
                {donor: tx-sender} 
                {
                    contribution_size: donation_size,
                    is_active_donor: true,
                    join_semester: semester
                }
            )

            ;; Increment total fund
            (var-set total_fund_balance 
                (+ (var-get total_fund_balance) donation_size)
            )

            (ok true)
        )
    )
)

;; Submit scholarship application
(define-public (submit_application 
    (student_wallet principal) 
    (requested_grant uint)
)
    (let 
        (
            (app_id (var-get next_application_id))
            (semester (var-get current_semester))
            (donor_info 
                (unwrap! 
                    (map-get? scholarship_donors {donor: tx-sender}) 
                    ERR_UNAUTHORIZED
                )
            )
            (deadline (+ semester VOTING_PERIOD))
        )
        ;; Validate inputs
        (asserts! (is_valid_student student_wallet) ERR_VALIDATION_FAILED)
        (asserts! (is_valid_grant_amount requested_grant) ERR_AMOUNT_TOO_LOW)

        ;; Ensure donor is active
        (asserts! (get is_active_donor donor_info) ERR_UNAUTHORIZED)

        ;; Ensure application within eligibility window
        (asserts! 
            (<= 
                (- semester (get join_semester donor_info)) 
                ELIGIBILITY_PERIOD
            ) 
            ERR_VOTING_CLOSED
        )

        ;; Create application
        (map-set grant_applications 
            {application_id: app_id}
            {
                student_wallet: student_wallet,
                requested_grant: requested_grant,
                total_votes: u0,
                support_votes: u0,
                is_finalized: false,
                submission_semester: semester,
                vote_deadline: deadline
            }
        )

        ;; Increment application counter
        (var-set next_application_id (+ app_id u1))

        (ok app_id)
    )
)

;; Vote on scholarship application
(define-public (cast_vote 
    (application_id uint) 
    (support bool)
)
    (let 
        (
            (semester (var-get current_semester))
            (validated_id (asserts! (is_valid_application application_id) ERR_APPLICATION_NOT_FOUND))
            (app_data 
                (unwrap! 
                    (map-get? grant_applications {application_id: application_id}) 
                    ERR_INVALID_APPLICATION
                )
            )
            (donor_info 
                (unwrap! 
                    (map-get? scholarship_donors {donor: tx-sender}) 
                    ERR_UNAUTHORIZED
                )
            )
        )

        ;; Ensure voting period is active
        (asserts! (< semester (get vote_deadline app_data)) ERR_VOTING_CLOSED)

        ;; Prevent duplicate votes
        (asserts! 
            (not (default-to false 
                (get has_voted (map-get? voting_history {donor: tx-sender, application_id: application_id}))
            )) 
            ERR_ALREADY_VOTED
        )

        ;; Update vote counts
        (map-set grant_applications 
            {application_id: application_id}
            (merge app_data 
                {
                    total_votes: (+ (get total_votes app_data) u1),
                    support_votes: (if support 
                        (+ (get support_votes app_data) u1)
                        (get support_votes app_data)
                    )
                }
            )
        )

        ;; Record vote
        (map-set voting_history 
            {donor: tx-sender, application_id: application_id}
            {has_voted: true}
        )

        (ok true)
    )
)

;; Read-only function to get current semester
(define-read-only (get_current_semester)
  (var-get current_semester)
)