# CryptoScholarship DAO Smart Contract

A decentralized scholarship fund protocol where donors pool resources and vote on student grant applications, built on the Stacks blockchain.

## Overview

CryptoScholarship DAO is a community-driven scholarship fund that enables donors to contribute funds, submit grant applications for students, and collectively vote on funding decisions. The contract manages the entire lifecycle of scholarship applications in a transparent and democratic manner.

## Key Features

- **Donor-Powered Fund**: Contributors deposit STX to build the scholarship pool
- **Democratic Decision Making**: Grant applications are approved through donor voting
- **Time-bound Eligibility**: Application submission rights are active for a limited period
- **Transparent Fund Management**: All scholarship decisions are made collectively

## Contract Constants

| Constant | Description |
|----------|-------------|
| `VOTING_PERIOD` | Application review duration (~24 hours) |
| `ELIGIBILITY_PERIOD` | Period donors can submit applications (~10 days) |
| `MAX_GRANT_SIZE` | Maximum scholarship award limit |

## Core Functions

### For Donors

#### `make_donation`
Join the scholarship fund by contributing STX tokens.
```clarity
(make_donation (donation_size uint))
```
- **Parameters**: `donation_size` - Amount of STX to contribute
- **Returns**: `(ok true)` on success
- **Errors**:
  - `ERR_VALIDATION_FAILED` - Invalid input values
  - `ERR_INSUFFICIENT_DONATION` - Zero amount not allowed
  - STX transfer failures

#### `submit_application`
File a scholarship application for a student.
```clarity
(submit_application (student_wallet principal) (requested_grant uint))
```
- **Parameters**: 
  - `student_wallet` - Principal address of the student
  - `requested_grant` - Requested scholarship amount
- **Returns**: `(ok application_id)` with the new application ID
- **Errors**:
  - `ERR_UNAUTHORIZED` - Caller not an active donor
  - `ERR_VALIDATION_FAILED` - Invalid student principal
  - `ERR_AMOUNT_TOO_LOW` - Invalid grant amount
  - `ERR_VOTING_CLOSED` - Eligibility period expired

#### `cast_vote`
Vote on a pending scholarship application.
```clarity
(cast_vote (application_id uint) (support bool))
```
- **Parameters**:
  - `application_id` - ID of the application to review
  - `support` - Boolean indicating approval/rejection
- **Returns**: `(ok true)` on successful vote
- **Errors**:
  - `ERR_APPLICATION_NOT_FOUND` - Invalid application ID
  - `ERR_UNAUTHORIZED` - Caller not a donor
  - `ERR_VOTING_CLOSED` - Review period ended
  - `ERR_ALREADY_VOTED` - Already cast a vote

### System Functions

#### `advance_semester`
Updates the system's semester counter.
```clarity
(advance_semester)
```
- **Returns**: `(ok updated_semester)` with the new semester value
- **Errors**:
  - `ERR_RAPID_SUCCESSION` - Repeated calls from same donor

#### `get_current_semester`
Read-only function to check the current semester.
```clarity
(get_current_semester)
```
- **Returns**: Current semester value

## Error Codes

| Code | Description |
|------|-------------|
| `ERR_UNAUTHORIZED (u1)` | Caller lacks necessary permissions |
| `ERR_INSUFFICIENT_DONATION (u2)` | Contribution amount too low |
| `ERR_INVALID_APPLICATION (u3)` | Application parameters invalid |
| `ERR_ALREADY_VOTED (u4)` | Already voted on this application |
| `ERR_VOTING_CLOSED (u5)` | Voting period has expired |
| `ERR_RAPID_SUCCESSION (u6)` | Sequential updates from same donor not allowed |
| `ERR_VALIDATION_FAILED (u7)` | Input validation failed |
| `ERR_AMOUNT_TOO_LOW (u8)` | Amount below minimum threshold |
| `ERR_APPLICATION_NOT_FOUND (u9)` | Referenced application doesn't exist |

## Implementation Details

### Data Structures

The contract uses three primary data maps:
1. `scholarship_donors` - Tracks donor contributions and status
2. `grant_applications` - Stores scholarship application details
3. `voting_history` - Records voting activity per donor per application

### Security Considerations

- Sequential update protection prevents semester manipulation
- Comprehensive input validation for all public functions
- Protection against duplicate voting
- Time-bound actions with deadline enforcement

## Usage Example

1. Become a donor:
```clarity
;; Contribute 100 STX to the scholarship fund
(contract-call? .crypto-scholarship make_donation u100000000)
```

2. Submit a student application:
```clarity
;; Submit application for student SP123... requesting 50 STX
(contract-call? .crypto-scholarship submit_application 'SP123456789ABCDEFGHJKL u50000000)
```

3. Vote on an application:
```clarity
;; Support application #5
(contract-call? .crypto-scholarship cast_vote u5 true)
```

4. Check current semester:
```clarity
(contract-call? .crypto-scholarship get_current_semester)
```
