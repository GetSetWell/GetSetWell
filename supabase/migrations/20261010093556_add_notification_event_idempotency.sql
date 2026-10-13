
-- Optional event identifier for notification deduplication.
-- Existing notifications remain unchanged.

alter table public.notifications
add column if not exists event_key text;

-- Prevent multiple notifications for the same event.
-- PostgreSQL permits multiple NULL values in a unique index,
-- preserving compatibility with historical notifications.

create unique index if not exists
  notifications_event_key_unique_idx
on public.notifications (event_key)
where event_key is not null;
