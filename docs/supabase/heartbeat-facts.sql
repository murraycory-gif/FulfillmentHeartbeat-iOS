-- Run in Supabase SQL editor when we move facts off JSON into tables.
-- Until then the app publishes facts.json into heartbeat-packs.

create table if not exists roster (
  store text primary key,
  division text not null default '',
  district text not null default '',
  om text not null default '',
  name text
);

create table if not exists lost_revenue (
  store text primary key references roster(store),
  division text not null default '',
  district text not null default '',
  om text not null default '',
  ecomm_sales double precision,
  lost_revenue double precision,
  lost_revenue_pct double precision,
  post_sub_oos_foregone double precision,
  refund_lost double precision,
  missed_sales double precision,
  cancelled_lost double precision,
  kill_switch_lost double precision,
  updated_at timestamptz not null default now()
);

create table if not exists sales_store (
  store text primary key references roster(store),
  division text not null default '',
  district text not null default '',
  payload jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists five_star (
  store text primary key references roster(store),
  division text not null default '',
  district text not null default '',
  payload jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

alter table roster enable row level security;
alter table lost_revenue enable row level security;
alter table sales_store enable row level security;
alter table five_star enable row level security;

drop policy if exists roster_read on roster;
create policy roster_read on roster for select using (true);
drop policy if exists lost_revenue_read on lost_revenue;
create policy lost_revenue_read on lost_revenue for select using (true);
drop policy if exists sales_store_read on sales_store;
create policy sales_store_read on sales_store for select using (true);
drop policy if exists five_star_read on five_star;
create policy five_star_read on five_star for select using (true);
