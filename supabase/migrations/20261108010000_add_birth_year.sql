-- profiles に誕生年を足す。年は任意で、入力するときは月日も必要。

alter table public.profiles
  add column birth_year smallint check (birth_year between 1900 and 2100),
  add check (birth_year is null or birth_month is not null);

grant update (birth_year) on public.profiles to authenticated;
