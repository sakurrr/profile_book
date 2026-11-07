-- profiles に出身地、血液型、これからのこと、どっち派？の回答を足す。どれも任意。
-- どっち派？は質問を増やしてもカラムを足さずに済むよう、{"質問のid": "選んだ選択肢のid"} で持つ。
-- 質問と選択肢はアプリ側（lib/data/mock_data.dart の whichOneQuestions）で定義する。

alter table public.profiles
  add column hometown       text,
  add column blood_type     text check (blood_type in ('A', 'B', 'O', 'AB')),
  add column goal_this_year text,
  add column want_to_go     text,
  add column want_to_try    text,
  add column which_one      jsonb check (jsonb_typeof(which_one) = 'object');

grant update (
  hometown, blood_type, goal_this_year, want_to_go, want_to_try, which_one
) on public.profiles to authenticated;
