# User Invite Flow Guide — Authentik Built-in System

This guide shows how to configure a user invite flow using Authentik's built-in invitation system on the `auth-web-api` deployment. No custom code required — everything is configured via the Admin UI and optionally automated via the REST API.

---

## Stage 1: Invite Creation

How admins generate invite tokens/links.

| Option | Method | Best For | Scalability |
|---|---|---|---|
| **Admin UI — Single** | Admin > Directory > Invitations > Create | Ad-hoc invites (1–5 users) | Low |
| **Admin UI — Repeated** | Create multiple invites manually | Small batches | Low |
| **API — Single** | `POST /api/v3/stages/invitation/invitations/` | Scripted/automated invites | High |
| **API — Bulk** | Script looping over user list calling the API | Onboarding waves (10–100+) | High |

### Invitation Object Fields

| Field | Type | Description | Recommended |
|---|---|---|---|
| `name` | string | Label, e.g. `invite-jane-2026-03` | Use naming convention |
| `expires` | datetime | When link expires. `null` = never | 7 days |
| `single_use` | boolean | Consumed after first use | **`false`** — see warning below |
| `fixed_data` | JSON | Attributes passed to enrollment flow | `{"email": "jane@co.com", "username": "jane@co.com"}` |
| `flow` | UUID | Override enrollment flow (optional) | Leave unset for default |

### Warning: Authentik Invitation Flow is Broken (as of 2025.10; re-test after the 2026.5 upgrade — the behavior may have changed in 2025.12+)

Authentik's invitation system has a critical bug: **invitations are deleted on first page load regardless of the `single_use` setting**. Even with `single_use: false`, the invite is consumed the moment the link is opened — not when registration completes.

Known upstream issues (all closed without fix):
- [#12770](https://github.com/goauthentik/authentik/issues/12770) — Invitations deleted after first use even with single_use disabled
- [#16587](https://github.com/goauthentik/authentik/issues/16587) — Single-use invite consumed on page load, not on registration
- [#7119](https://github.com/goauthentik/authentik/issues/7119) — Policy errors after invite stage deletes the invite

**Recommended alternative:** Skip the invite flow entirely. Instead, use the Authentik API to create users directly and trigger a password reset email, or build a custom onboarding service that calls the `/api/v3/core/users/` endpoint.

**Invite URL format:** `https://auth.artisan-tools.com/if/flow/enrollment-invite/?itoken=<pk>`

---

## Stage 2: Invite Delivery

How the invite link reaches the user.

| Option | How | Pros | Cons | Recommended |
|---|---|---|---|---|
| **Manual link sharing** | Copy URL, send via Slack/email | Zero config, immediate | No audit trail | Small teams |
| **Notification Rule** | Authentik notification triggered on invite creation | Automated, audited | Limited email template control | Admin alerts |
| **Custom script + API** | Script creates invite, sends branded email via SendGrid/SES | Full branding control, batch-capable | More moving parts | Polished onboarding |

### Email Template Customization

Templates are Jinja2-based, mounted via the `artisan-auth-templates` Docker volume at `/templates/`.

| Template File | Purpose |
|---|---|
| `email/account_confirmation.html` | Email verification during enrollment |
| `email/password_reset.html` | Password recovery |
| `email/setup.html` | Initial account setup |

**Dev testing:** All emails go to Mailpit at `http://localhost:8025`.

---

## Stage 3: Enrollment Flow (User Experience)

What the user sees after clicking the invite link. Configured at **Admin > Flows and Stages**.

### Flow: `enrollment-invite`

| Setting | Value |
|---|---|
| Designation | Enrollment |
| Title | "Join Artisan Tools" |
| Authentication | Require no authentication |
| Denied action | Show "Invalid or expired invite" |

### Stage Binding Order

| Order | Stage Name | Type | Purpose |
|---|---|---|---|
| 10 | `enrollment-invitation` | Invitation Stage | Validate `itoken` |
| 20 | `enrollment-prompt` | Prompt Stage | Password only (email + username come from invite `fixed_data`) |
| 30 | `enrollment-user-write` | User Write Stage | Create active account |

The admin sets `email` and `username` in the invite's `fixed_data` (Attributes field in the UI). These flow through as `prompt_data` automatically — the user only sees a password screen.

### Stage Options Detail

#### Invitation Stage (Order 10)

| Option | Description | Recommended |
|---|---|---|
| Continue without invite | If `true`, anyone can enroll without token | `false` (require invite) |
| Pre-fill from fixed_data | Auto-available as `prompt_data` in later stages | Used to set email + username |

#### Prompt Stage (Order 20) — Minimal Password-Only

Only two fields — email and username are auto-set from `fixed_data`.

| Field | Key | Type | Required | Notes |
|---|---|---|---|---|
| Password | `password` | Password | Yes | — |
| Confirm Password | `password_repeat` | Password | Yes | Must match |

**Setting `fixed_data` in Admin UI:** When creating an invite at Admin > Directory > Invitations > Create, enter this in the **Attributes** JSON field:

```json
{
  "email": "jane@company.com",
  "username": "jane@company.com"
}
```

#### Password Policy Options

| Policy Setting | Options | Recommended |
|---|---|---|
| Min length | 8, 10, 12, 16 | 10 |
| Zxcvbn score | 0–4 | 2+ |
| Check Have I Been Pwned | Yes/No | Yes (needs internet) |
| Character classes | Upper, Lower, Digit, Symbol | At least 2 categories |

#### User Write Stage (Order 30)

| Option | Values | Recommended |
|---|---|---|
| User creation mode | Always create / Link only / Never create | Always create |
| Create as inactive | Yes/No | **No** — account is active immediately (no email verification) |
| User type | Internal / External | Internal (team) |
| User path | Default: `users` | Default |

---

## Stage 4: Post-Enrollment

What happens after the user account is created.

| Action | Method | Configuration |
|---|---|---|
| **Group assignment (manual)** | Admin adds user to group | Admin > Directory > Users > (user) > Groups |
| **Group assignment (via invite)** | Include group in `fixed_data` + Expression Policy on User Write | Invite: `{"groups": ["team-members"]}` |
| **Role assignment** | Via group membership (RBAC) | Admin > Directory > Groups > (group) > Roles |
| **Application access** | Bind group to app policy | Admin > Applications > (app) > Policy Bindings |
| **Welcome redirect** | Set flow redirect or add Redirect Stage | Redirect to app dashboard URL |

### Redirect Options

| Target | URL | Use Case |
|---|---|---|
| App dashboard | `/application/launch/<app-slug>/` | Send to main app |
| User settings | `/if/user/` | Let user review profile |
| Default | (empty) | Authentik default page |

---

## Stage 5: Management and Monitoring

| Task | Method | Path |
|---|---|---|
| View all invites | Admin UI | Admin > Directory > Invitations |
| View invite status | Admin UI (shows used/expired) | Click specific invitation |
| Revoke invite | Delete invitation object | Admin UI or `DELETE /api/v3/stages/invitation/invitations/<pk>/` |
| Audit log | Filter events | Admin > Events > Logs |
| Notify on signup | Notification Rule on `user_write` event | Admin > Events > Notification Rules |

### Key Events to Monitor

| Event | Meaning |
|---|---|
| `invitation_used` | Invite link consumed |
| `user_write` | New user created |
| `login` | First login after enrollment |
| `email_sent` | Verification email dispatched |

### API Endpoints Summary

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v3/stages/invitation/invitations/` | GET/POST | List/create invitations |
| `/api/v3/stages/invitation/invitations/<pk>/` | GET/DELETE | Get/revoke invitation |
| `/api/v3/core/users/` | GET | List users |
| `/api/v3/events/events/` | GET | Query audit logs |

---

## Quick Setup Checklist

### One-Time Setup (Admin UI)

1. Create **Password Policy** (min 10 chars, zxcvbn 2+)
2. Create **Prompts** (password, password_repeat only)
3. Create **Stages** (invitation, prompt, user write)
4. Create **Flow** `enrollment-invite` (designation: Enrollment)
5. **Bind stages** to flow in order 10, 20, 30
6. Create **Group** `team-members`
7. **Bind group** to applications via policies

### Per-Invite Workflow

1. Create invitation (UI or API) with name, expiry, and Attributes: `{"email": "jane@company.com", "username": "jane@company.com"}`
2. Copy/send invite URL to user
3. User clicks link, sets password, account is immediately active
4. Add user to appropriate group (manual or automated)

### Dev Testing

1. `./scripts/up dev all`
2. Open `https://localhost` and set up flow and stages
3. Create test invitation with `fixed_data` containing email + username
4. Open invite link in incognito
5. Set password — user should be created and active immediately
6. Confirm user appears in Admin > Directory > Users with correct email/username
