# Supabase local migration runbook

These scripts target a **dedicated Perpus Supabase project**. Keep the application on its current backend until the migrations and integration checks have passed in a separate local/development project. Do not apply to a shared production database.

## Order

1. Run `preflight.sql` in Supabase Studio and confirm the expected Auth schema, tables, and auth trigger state. Resolve any collision before continuing.
2. Apply `migrations/202609280001_identity_inventory.sql`.
3. Apply `migrations/202609290001_staff_admin_operations.sql`.
4. Apply `migrations/202609290002_staff_invites.sql`.
5. Apply `migrations/202609290003_operator_provisioned_auth_users.sql`.
6. Apply `migrations/202609280002_transactions.sql`.
7. Apply `migrations/202609290004_archive_book.sql` to add the admin-only soft-archive RPC for a book and its QR copies.
8. Run `verify_migration.sql` and `verify_staff_admin.sql`; they check staff separation, invitation token privacy, RLS, restricted direct writes, RPC presence, and the private evidence bucket.
9. Run `seed.sql` only in a disposable development project. It creates sample inventory, not real members.

PowerShell/Node SQL smoke tests for both migrations are available at `scripts/sql-tests` (`npm ci`, then `npm test`). They use PGlite and mocked Auth/Storage schemas. They do not prove GoTrue email delivery, the real Storage API, signed URLs, or multi-connection concurrency. Verify those against a disposable Supabase stack before a server migration.

## Transaction and role boundaries

- `student_registry` and `staff_registry` hold separate identities. A profile is either a member linked to a student or an admin linked to a staff record. `profiles.role` cannot be changed by a client update. Create admins through a controlled database operation, never public role metadata.
- Members can read their own transaction rows; admins can review all rows. Transaction tables grant clients `SELECT` only. Changes go through authenticated RPCs that verify the caller and own the stock transition.
- Evidence belongs in the private `loan-evidence` bucket. Members can upload/read only within their own user folder; admins can read evidence for review. There is no client delete policy.
- Admins may archive an available copy with `archive_available_copy`; loan transitions remain exclusive to transaction RPCs. Library settings and audit-log access remain restricted by admin RLS.
- Member signup remains available in the app and requires a preloaded student identity. Admins cannot self-register; new staff can only activate an email-bound, single-use invite created by an active admin, then wait for email confirmation and approval.
- Provision the first admin through Studio: run `bootstrap_first_admin.sql`, invite the same email under Authentication > Users, confirm that email, then run `activate_first_admin.sql` after replacing its email placeholder. The script links only a confirmed Auth user to the matching, unexpired staff invite and activates it; the invitation secret stays in the database.
- Studio-created Auth users without signup metadata do not get a profile or permissions until a trusted operator links them. This allows controlled provisioning while leaving member signup explicitly tagged and validated.
- Request and review RPCs recheck ownership, account status, inventory, overdue loans and limits. Evidence cleanup still needs a trusted scheduled worker that deletes Storage objects only after `delete_after` and records `deleted_at`.

## Current boundary

The transaction migration implements request/approval, per-item return review, loss reporting/resolution, evidence retention deadlines, and RLS. The app has role-separated catalog/member/inventory screens, admin settings and audit views, staff invites, QR display, pending-loan review, and member loan history. Member evidence capture/request, admin return/loss workflows, scheduled retention cleanup, notifications, reports, and archives remain before the PRD MVP is ready. The SQL smoke tests run locally and do not contact the home LAN server.
