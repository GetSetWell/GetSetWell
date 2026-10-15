-- GetSetWell does not meet trainers in person (decision 14 Oct 2026).
-- Remove every "Met in person" verification row and stop new ones being
-- added, so no trainer profile can ever claim an in-person check.

delete from public.trainer_verification_checks
where check_type = 'in_person';

do $$
declare
  v_constraint text;
begin
  select con.conname
  into v_constraint
  from pg_constraint con
  join pg_attribute att
    on att.attrelid = con.conrelid
   and att.attnum = any (con.conkey)
  where con.conrelid = 'public.trainer_verification_checks'::regclass
    and con.contype = 'c'
    and att.attname = 'check_type'
  limit 1;

  if v_constraint is not null then
    execute format(
      'alter table public.trainer_verification_checks drop constraint %I',
      v_constraint
    );
  end if;
end;
$$;

alter table public.trainer_verification_checks
  add constraint trainer_verification_checks_check_type_check
  check (
    check_type in (
      'identity',
      'primary_certification',
      'additional_certification',
      'first_aid_cpr',
      'experience',
      'reference',
      'other'
    )
  );
