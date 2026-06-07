# Business Requirements — Keycloak Integration

> **Document type:** Agile Business Requirements (Epics & User Stories)
> **Product:** Keycloak Integration (HunterKillTree)
> **Last updated:** 2026-06-07
> **Status legend:** ✅ Implemented · 🚧 Stubbed (TODO in code) · 🆕 New / proposed

## 1. Product Overview

The Keycloak Integration product provides a **centralized identity and profile-management service** for HunterKillTree applications. It delegates authentication and credential storage to a [Keycloak](https://www.keycloak.org/) identity provider (IdP) while maintaining an application-side **user profile store** in MongoDB.

The system has two components:

- **`keycloak-be`** — a Spring Boot REST service. It acts as an OAuth2 *resource server* (validating Keycloak-issued JWTs) and as an *admin client* to Keycloak (creating users, fetching user records via the Keycloak Admin API using a `client_credentials` service token). Profiles are persisted in MongoDB.
- **`web-app`** — a React single-page application using `keycloak-js` to drive the login/SSO flow and call the backend with the user's bearer token.

### 1.1 Business Goals

1. Provide a single, reusable authentication and profile foundation so individual product teams do not re-implement login, registration, or credential storage.
2. Externalize credential security (password hashing, token issuance, session management, social login) to a hardened IdP rather than the application database.
3. Maintain an application-owned profile record per user so business data (name, date of birth, email) lives alongside, but separate from, the identity record.
4. Support role-based access control so privileged operations (delete user, change role) are restricted to administrators.

### 1.2 Personas / Stakeholders

| Persona | Description | Key needs |
|---|---|---|
| **Visitor** | Unauthenticated person | Register an account, log in |
| **Member** | Authenticated end user | View and update own profile, change own password, log out |
| **Super-user / Admin** | Privileged operator | List all profiles, delete profiles, change a user's role |
| **Product engineer** | Consumer of this service | Stable, documented API and SSO integration |

### 1.3 In Scope

Current implemented features and the four credential/profile operations currently stubbed in `ProfileService` (`updateProfile`, `updatePassword`, `deleteProfile`, `updateRole`).

### 1.4 Out of Scope (this iteration)

Multi-realm support, multi-tenancy, billing, MFA enrollment UX, and audit-log dashboards. Some appear as future considerations in §7.

---

## 2. Epic A — User Registration ✅

**Goal:** A visitor can create an account that is provisioned in Keycloak and mirrored as a local profile.

*Backed by:* `POST /profile/register` (public endpoint), `ProfileService.register`, `IdentityClient.createUser`, React `Registration` page.

### Story A1 — Self-service registration ✅

> **As a** visitor
> **I want** to register with my username, password, email, first name, last name, and date of birth
> **so that** I can obtain an account and sign in.

**Acceptance criteria**

```gherkin
Scenario: Successful registration
  Given I am an unauthenticated visitor
  And I provide a unique username and email with a valid password
  When I submit the registration form
  Then a user is created in Keycloak via the Admin API
  And a Profile record is stored in MongoDB linked to the Keycloak userId
  And the API returns my profile in a standard ApiResponse envelope

Scenario: Registration endpoint is public
  Given the security configuration
  Then "/register" must NOT require a bearer token
  And all other endpoints MUST require authentication
```

### Story A2 — Duplicate and invalid input handling ✅

> **As a** visitor
> **I want** clear errors when my username/email is taken or my input is invalid
> **so that** I can correct and retry.

**Acceptance criteria**

```gherkin
Scenario: Duplicate email
  When I register with an email that already exists
  Then I receive error EMAIL_EXISTED (1008) with HTTP 400

Scenario: Duplicate username
  When I register with a username that already exists
  Then I receive error USER_EXISTED (1009) with HTTP 400

Scenario: Validation failure
  When my username or password is shorter than the minimum length
  Then I receive INVALID_USERNAME (1003) or INVALID_PASSWORD (1004) with HTTP 400
```

> **Note (tech debt):** Keycloak errors are translated by `ErrorNormalizer`. The minimum-length constraints referenced by `INVALID_USERNAME`/`INVALID_PASSWORD` should be enforced by bean validation on `RegistrationRequest` (verify `@Size` annotations exist).

---

## 3. Epic B — Authentication & Session ✅

**Goal:** Users authenticate against Keycloak and the SPA manages the session/token.

*Backed by:* React `keycloak-js` flow (`keycloak.js`, `ProtectedRoute`), `authenticationService.logOut`, backend OAuth2 resource-server config. The backend `GET /login` (`ProfileService.login`) is **deprecated** in favor of the Keycloak browser flow.

### Story B1 — Single sign-on via Keycloak ✅

> **As a** visitor
> **I want** to log in through Keycloak's hosted login
> **so that** my credentials are never handled by the application directly.

**Acceptance criteria**

```gherkin
Scenario: Protected route redirects to login
  Given I am not authenticated
  When I navigate to a protected route ("/")
  Then I am redirected to the Keycloak login flow

Scenario: Authenticated access
  Given I have completed Keycloak login
  Then the SPA holds a valid access token
  And API calls include "Authorization: Bearer <token>"
  And the backend validates the JWT against issuer "…/realms/hunterkilltree"
```

### Story B2 — Logout ✅

> **As a** member
> **I want** to log out
> **so that** my session and tokens are cleared.

**Acceptance criteria**

```gherkin
Scenario: Logout clears session
  When I log out
  Then keycloak.logout is invoked and I am redirected to the app origin
  And local/session stored tokens are removed
```

### Story B3 — Retire deprecated password-grant login 🚧

> **As a** product engineer
> **I want** the deprecated `GET /login` password-grant endpoint removed or clearly gated
> **so that** we do not expose a Resource Owner Password Credentials path.

**Acceptance criteria**

```gherkin
Scenario: Deprecated endpoint
  Given GET /login uses the password grant and is marked deprecated
  Then it must be removed, or restricted to non-production, or replaced by the standard browser flow
  And documentation must state SSO browser flow is the supported login path
```

> **Note:** This story documents existing code marked "Deprecated". Treat as a cleanup/security item, not a feature.

---

## 4. Epic C — Profile Retrieval ✅

**Goal:** Users and admins can read profile data.

*Backed by:* `GET /profile/my-profile`, `GET /profile/profiles`, `ProfileService.getMyProfile` / `getAllProfiles`.

### Story C1 — View my profile ✅

> **As a** member
> **I want** to view my own profile
> **so that** I can confirm my account details.

**Acceptance criteria**

```gherkin
Scenario: Profile exists locally
  Given I am authenticated
  When I call GET /my-profile
  Then my Profile is returned from MongoDB

Scenario: Profile not yet stored (e.g., social/SSO sign-up)
  Given I authenticated but have no local Profile
  When I call GET /my-profile
  Then the service obtains a client_credentials token
  And fetches my user record from Keycloak by userId
  And persists it as a new Profile, then returns it
```

### Story C2 — List all profiles (admin) ✅ → needs authorization 🚧

> **As a** super-user
> **I want** to list all profiles
> **so that** I can administer users.

**Acceptance criteria**

```gherkin
Scenario: List profiles
  When an authenticated user calls GET /profiles
  Then all profiles are returned

Scenario: Restrict to admins (GAP)
  Given listing all users is an administrative action
  Then GET /profiles MUST require an admin/super-user role
  And a non-admin caller receives UNAUTHORIZED (1007) HTTP 403
```

> **Gap:** Currently `/profiles` only requires authentication, not an admin role. Authorization is captured in Epic F.

---

## 5. Epic D — Profile Self-Management 🚧

**Goal:** Members can maintain their own profile information and credentials. *These operations are stubbed in `ProfileService` and return `null` / do nothing today.*

### Story D1 — Update my profile 🚧

> **As a** member
> **I want** to update my profile fields (first name, last name, email, date of birth)
> **so that** my information stays accurate.

**Acceptance criteria**

```gherkin
Scenario: Update own profile
  Given I am authenticated as the profile owner
  When I submit updated profile fields
  Then the MongoDB Profile is updated
  And changes that belong to the identity record (e.g., email) are propagated to Keycloak via the Admin API
  And the updated profile is returned

Scenario: Cannot edit another user's profile
  Given I am not the owner and not an admin
  When I attempt to update a profile that is not mine
  Then I receive UNAUTHORIZED (1007) HTTP 403

Scenario: Email uniqueness preserved
  When I change my email to one already in use
  Then I receive EMAIL_EXISTED (1008) HTTP 400
```

**Implementation note:** finish `ProfileService.updateProfile(Profile)`; add a `PUT /my-profile` (or `PUT /profiles/{userId}`) controller method; sync mutable identity attributes to Keycloak.

### Story D2 — Change my password 🚧

> **As a** member
> **I want** to change my password
> **so that** I can keep my account secure.

**Acceptance criteria**

```gherkin
Scenario: Change own password
  Given I am authenticated
  When I submit a new password meeting the password policy
  Then the password is reset in Keycloak via the Admin API (non-temporary credential)
  And no password is ever stored in MongoDB

Scenario: Weak password rejected
  When the new password violates the policy
  Then I receive INVALID_PASSWORD (1004) HTTP 400
```

**Implementation note:** finish `ProfileService.updatePassword(...)`; route credential reset to Keycloak `PUT /admin/realms/{realm}/users/{id}/reset-password`; never persist credentials locally.

---

## 6. Epic E — Administrative User Management 🚧

**Goal:** Super-users manage the lifecycle of other users.

### Story E1 — Delete a profile (super-user) 🚧

> **As a** super-user
> **I want** to delete a user's profile and identity
> **so that** I can offboard accounts.

**Acceptance criteria**

```gherkin
Scenario: Admin deletes a user
  Given I am authenticated as a super-user
  When I delete a user by userId
  Then the Keycloak user is deleted (or disabled) via the Admin API
  And the corresponding MongoDB Profile is removed

Scenario: Non-admin blocked
  Given I am not a super-user
  When I attempt to delete a profile
  Then I receive UNAUTHORIZED (1007) HTTP 403

Scenario: Unknown user
  When I delete a userId that does not exist
  Then I receive USER_NOT_EXISTED (1011) HTTP 400
```

**Implementation note:** finish `ProfileService.deleteProfile(String userId)`; add `DELETE /profiles/{userId}`; guard with admin role.

### Story E2 — Change a user's role (super-user) 🚧

> **As a** super-user
> **I want** to assign or change a user's role
> **so that** I can grant or revoke privileges.

**Acceptance criteria**

```gherkin
Scenario: Admin changes a role
  Given I am authenticated as a super-user
  When I assign a role to a userId
  Then the role mapping is applied in Keycloak via the Admin API
  And the change is reflected in the user's subsequent JWT roles

Scenario: Non-admin blocked
  Given I am not a super-user
  When I attempt to change a role
  Then I receive UNAUTHORIZED (1007) HTTP 403
```

**Implementation note:** finish `ProfileService.updateRole(String userId, String role)`; add `PUT /profiles/{userId}/role`; use Keycloak role-mapping Admin API.

---

## 7. Epic F — Authorization & Security (cross-cutting) 🚧

**Goal:** Enforce role-based access so privileged stories (C2, D1-cross-user, E1, E2) are correctly restricted.

### Story F1 — Role-based access control 🚧

> **As a** product owner
> **I want** endpoints protected by role
> **so that** only authorized users perform privileged actions.

**Acceptance criteria**

```gherkin
Scenario: Role mapping from JWT
  Given Keycloak realm/client roles are present in the access token
  Then the resource server maps them to Spring Security authorities

Scenario: Method/endpoint authorization
  Then admin endpoints (list all, delete, change role) require a super-user authority
  And self-service endpoints require the authenticated owner
  And "/register" remains public
```

> **Current state:** `SecurityConfig` permits `/register` and requires authentication for everything else, but performs **no role checks**. A JWT-authorities converter and method/endpoint-level rules are required.

### Story F2 — Secrets & configuration hygiene 🆕

> **As a** product engineer
> **I want** the Keycloak client secret and DB credentials externalized
> **so that** secrets are not committed to source.

**Acceptance criteria**

```gherkin
Scenario: No hard-coded secrets
  Given application.yml currently contains a client-secret and Mongo credentials
  Then these MUST be sourced from environment variables / a secret manager in non-local environments
  And the committed file MUST NOT contain real production secrets
```

> **Note:** `application.yml` currently hard-codes `idp.client-secret` and Mongo root credentials. This is acceptable for local demo only.

---

## 8. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-1 | Security | All non-public endpoints require a valid Keycloak JWT; passwords are never stored in MongoDB; secrets externalized in non-local envs (F2). |
| NFR-2 | API consistency | All responses use the `ApiResponse<T>` envelope; all errors flow through `GlobalExceptionHandler` with codes from `ErrorCode`. |
| NFR-3 | Data integrity | Each Profile is uniquely linked to a Keycloak `userId`; email and username uniqueness enforced. |
| NFR-4 | Interoperability | Backend integrates with Keycloak 25.0.0 Admin & OIDC APIs; frontend uses `keycloak-js` browser flow. |
| NFR-5 | Configurability | Realm, IdP URL, client id/secret, and Mongo URI are configuration-driven (no code change to retarget environments). |
| NFR-6 | CORS | The SPA origin is permitted via `CorsConfiguration`; CSRF disabled (stateless REST + token auth). |
| NFR-7 | Observability | Key identity operations (token exchange, user creation, profile fetch) are logged without leaking secrets/tokens at INFO level. |

> **NFR-7 caveat:** current code logs token info at INFO (`log.info("TokenInfo {}", token)`). Tokens/secrets should be redacted from logs.

---

## 9. Traceability Matrix

| Story | Type | Code anchor |
|---|---|---|
| A1, A2 | ✅ | `POST /register`, `ProfileService.register`, `IdentityClient.createUser` |
| B1, B2 | ✅ | `keycloak.js`, `ProtectedRoute`, `authenticationService.logOut`, `SecurityConfig` |
| B3 | 🚧 | `GET /login` (`ProfileService.login`, marked Deprecated) |
| C1 | ✅ | `GET /my-profile`, `ProfileService.getMyProfile` |
| C2 | ✅/🚧 | `GET /profiles`, `getAllProfiles` (needs role guard) |
| D1 | 🚧 | `ProfileService.updateProfile` (TODO) |
| D2 | 🚧 | `ProfileService.updatePassword` (TODO) |
| E1 | 🚧 | `ProfileService.deleteProfile` (TODO) |
| E2 | 🚧 | `ProfileService.updateRole` (TODO) |
| F1 | 🚧 | `SecurityConfig` (no role mapping yet) |
| F2 | 🆕 | `application.yml` (hard-coded secrets) |

---

## 10. Suggested Backlog Ordering

1. **F1 — RBAC foundation** (unblocks C2, D1 cross-user, E1, E2)
2. **D1 — Update my profile** and **D2 — Change my password** (core self-service)
3. **E1 — Delete profile** and **E2 — Change role** (admin lifecycle)
4. **C2 — Add admin guard to list-all**
5. **B3 — Retire deprecated login** and **F2 — Secrets hygiene** (security cleanup)

---

## 11. Future Considerations (not committed)

Email verification enforcement, multi-factor authentication, social/identity-provider login UX, refresh-token rotation handling in the SPA, audit logging of admin actions, and pagination/search on the list-all endpoint.
