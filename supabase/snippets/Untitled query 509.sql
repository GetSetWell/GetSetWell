select
  tc.table_name,
  kcu.column_name,
  ccu.table_name as references_table,
  ccu.column_name as references_column,
  rc.delete_rule
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
  and tc.constraint_schema = kcu.constraint_schema
join information_schema.constraint_column_usage ccu
  on tc.constraint_name = ccu.constraint_name
  and tc.constraint_schema = ccu.constraint_schema
join information_schema.referential_constraints rc
  on tc.constraint_name = rc.constraint_name
  and tc.constraint_schema = rc.constraint_schema
where tc.constraint_type = 'FOREIGN KEY'
  and ccu.table_schema = 'public'
  and ccu.table_name in ('booking_requests', 'sessions')
order by references_table, tc.table_name;