-- GetSetWell: Account deletion tracking
-- Records deletion progress without deleting customer history.

create table public.customer_account_deletions (
  id uuid primary key default gen_random_uuid(),

  customer_id uuid not null
    references public.customer_identities(id)
    on delete restrict,

  firebase_uid text,

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'identity_detached',
        'firebase_deleted',
        'cleanup_pending',
        'completed',
        'needs_review'
      )
    ),

  attempt_count integer not null default 0
    check (attempt_count >= 0),

  last_error_code text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

-- Only one deletion-tracking record per customer.
create unique index customer_account_deletions_customer_uidx
  on public.customer_account_deletions (customer_id);

-- Prevent ordinary client access.
-- Only trusted backend operations should manage deletion records.
alter table public.customer_account_deletions
  enable row level security;

revoke all on table public.customer_account_deletions
  from anon, authenticated;