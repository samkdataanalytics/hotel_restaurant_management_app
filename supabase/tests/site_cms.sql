-- Regression checks for 20261023000001_site_cms.sql.
--
-- Paste the whole file into the SQL editor and run it, AFTER the migrations
-- (20261023000001_site_cms.sql and 20261023000003_site_conflict_code.sql). It
-- picks a superadmin and an ordinary profile itself, needs no edits, and ALWAYS
-- ends in an error on purpose, so nothing it does can commit. The error message
-- is the report: expect every line to read PASS.
--
-- Verified 2026-10-23 on a local Postgres 17 with stand-in auth/storage schemas and
-- the anon / authenticated roles: all 33 checks PASS. Not yet run on hotrest_dev
-- (the migration has not been applied there).
--
-- Covers: who can read published / draft / revision content, that writes only go
-- through the functions, draft-version conflict, publish -> revision, restore
-- going to the draft and not live, discard, the content check (script schemes,
-- shape, size), and media registration.
do $$
declare
  normal_id uuid; admin_id uuid;
  r text := '';
  n int; v int; msg text; st text; big jsonb;
  ok constant jsonb := '{"schema":1,"sections":[{"id":"a","type":"faq","content":{"title":"Hello"}}]}';

begin
  select id into normal_id from public.profiles
    where not is_superadmin and coalesce(is_deleted, false) = false order by created_at limit 1;
  select id into admin_id from public.profiles where is_superadmin limit 1;
  if normal_id is null or admin_id is null then
    raise exception 'Need at least one superadmin and one ordinary profile to run these checks.';
  end if;

  -- helper idiom: act as <uid> with role <role>
  -- (set_config is transaction-local; "reset role" returns to the owner)

  -- 1. superadmin saves a draft, version 1
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.site_save_draft('page:test', ok, 0);
  r := r || case when v = 1 then E'1  PASS  superadmin created a draft (v1)\n' else format(E'1  FAIL  got version %s\n', v) end;

  -- 2. a stale save is a conflict (CF409; see 20261023000003_site_conflict_code.sql)
  begin
    perform public.site_save_draft('page:test', ok, 0);
    r := r || E'2  FAIL  stale save accepted\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = 'CF409' then E'2  PASS  stale save refused as a conflict\n' else format(E'2  FAIL  unexpected %s\n', st) end;
  end;

  -- 3. the right expected version advances it
  v := public.site_save_draft('page:test', ok, 1);
  r := r || case when v = 2 then E'3  PASS  save with the current version -> v2\n' else format(E'3  FAIL  got %s\n', v) end;

  -- 4. publish makes it live, records a revision
  v := public.site_publish('page:test', 'first');
  select count(*) into n from public.site_revisions where key = 'page:test';
  r := r || case when v = 1 and n = 1 then E'4  PASS  publish -> live v1 and one revision\n' else format(E'4  FAIL  v=%s revisions=%s\n', v, n) end;
  reset role;

  -- 5. anon can read published content, and sees it
  set local role anon;
  select count(*) into n from public.site_documents where key = 'page:test';
  r := r || case when n = 1 then E'5  PASS  anon reads published content\n' else format(E'5  FAIL  anon saw %s rows\n', n) end;

  -- 6. anon cannot read drafts or revisions
  begin
    perform 1 from public.site_drafts limit 1;
    r := r || E'6a FAIL  anon read site_drafts\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'6a PASS  anon denied site_drafts\n' else format(E'6a FAIL  unexpected %s\n', st) end;
  end;
  begin
    perform 1 from public.site_revisions limit 1;
    r := r || E'6b FAIL  anon read site_revisions\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'6b PASS  anon denied site_revisions\n' else format(E'6b FAIL  unexpected %s\n', st) end;
  end;
  reset role;

  -- 7. an ordinary signed-in user sees no drafts or revisions (RLS), only published
  perform set_config('request.jwt.claims', json_build_object('sub', normal_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.site_drafts;
  r := r || case when n = 0 then E'7a PASS  ordinary user sees no drafts\n' else format(E'7a FAIL  saw %s drafts\n', n) end;
  select count(*) into n from public.site_revisions;
  r := r || case when n = 0 then E'7b PASS  ordinary user sees no revisions\n' else format(E'7b FAIL  saw %s\n', n) end;
  select count(*) into n from public.site_documents;
  r := r || case when n >= 1 then E'7c PASS  ordinary user can read published\n' else E'7c FAIL  published unreadable\n' end;

  -- 8. ... and cannot call the write functions
  begin
    perform public.site_save_draft('page:test', ok, 2);
    r := r || E'8a FAIL  ordinary user saved a draft\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'8a PASS  save refused to an ordinary user\n' else format(E'8a FAIL  unexpected %s\n', st) end;
  end;
  begin
    perform public.site_publish('page:test', '');
    r := r || E'8b FAIL  ordinary user published\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'8b PASS  publish refused to an ordinary user\n' else format(E'8b FAIL  unexpected %s\n', st) end;
  end;

  -- 9. nobody can write the tables directly
  begin
    insert into public.site_documents (key, content) values ('page:evil', ok);
    r := r || E'9a FAIL  direct insert into site_documents\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'9a PASS  direct insert refused\n' else format(E'9a FAIL  unexpected %s\n', st) end;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    update public.site_documents set content = '{}' where key = 'page:test';
    r := r || E'9b FAIL  superadmin updated site_documents directly\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'9b PASS  even a superadmin must go through site_publish\n' else format(E'9b FAIL  unexpected %s\n', st) end;
  end;
  reset role;
  set local role anon;
  begin
    perform public.site_publish('page:test', '');
    r := r || E'9c FAIL  anon could execute site_publish\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'9c PASS  anon cannot execute site_publish\n' else format(E'9c FAIL  unexpected %s\n', st) end;
  end;
  reset role;

  -- 10. the content check
  perform set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.site_save_draft('page:test', ok, 2);   -- keep the draft moving
  declare bad jsonb; label text;
  begin
    foreach label in array array['javascript','data-uri','vbscript','no-sections','sections-not-array','not-object'] loop
      bad := case label
        when 'javascript'  then '{"sections":[{"id":"a","type":"faq","content":{"link":{"type":"external","value":"javascript:alert(1)"}}}]}'
        when 'data-uri'    then '{"sections":[{"id":"a","type":"faq","content":{"x":"  data:text/html;base64,AAAA"}}]}'
        when 'vbscript'    then '{"sections":[{"id":"a","type":"faq","content":{"x":"VBScript:msgbox"}}]}'
        when 'no-sections' then '{"schema":1}'
        when 'sections-not-array' then '{"sections":"x"}'
        else '[]' end::jsonb;
      begin
        v := public.site_save_draft('page:test', bad, v);
        r := r || format(E'10 FAIL  accepted %s\n', label);
      exception when check_violation then
        r := r || format(E'10 PASS  rejected %s\n', label);
      when others then
        get stacked diagnostics st = returned_sqlstate;
        r := r || format(E'10 FAIL  %s: unexpected %s\n', label, st);
      end;
    end loop;
  end;

  -- 11. legal copy that merely starts a sentence with "Data:" is fine
  v := public.site_save_draft('page:test',
    '{"sections":[{"id":"a","type":"legalDoc","content":{"sections":[{"blocks":[{"text":"Data: we keep it 7 years."}]}]}}]}'::jsonb, v);
  r := r || E'11 PASS  "Data: ..." prose accepted\n';

  -- 12. oversized page rejected
  begin
    big := jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('id','a','type','richText','content',
             jsonb_build_object('body', repeat('x', 300000)))));
    v := public.site_save_draft('page:test', big, v);
    r := r || E'12 FAIL  300 KB page accepted\n';
  exception when check_violation then
    r := r || E'12 PASS  300 KB page rejected\n';
  when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || format(E'12 FAIL  unexpected %s\n', st);
  end;

  -- 13. restore loads an old revision into the DRAFT, leaving live alone
  v := public.site_save_draft('page:test', '{"sections":[{"id":"b","type":"faq","content":{"title":"Second"}}]}'::jsonb, v);
  perform public.site_publish('page:test', 'second');
  v := public.site_restore_revision('page:test', 1);
  select content #>> '{sections,0,id}' into msg from public.site_drafts where key = 'page:test';
  select content #>> '{sections,0,id}' into st from public.site_documents where key = 'page:test';
  r := r || case when msg = 'a' and st = 'b' then E'13 PASS  restore went to the draft; live still has the newer content\n'
                 else format(E'13 FAIL  draft=%s live=%s\n', msg, st) end;

  -- 14. discard removes the working copy only
  perform public.site_discard_draft('page:test');
  select count(*) into n from public.site_drafts where key = 'page:test';
  r := r || case when n = 0 then E'14 PASS  discard removed the draft\n' else E'14 FAIL  draft remains\n' end;

  -- 15. publishing with no draft fails cleanly
  begin
    perform public.site_publish('page:test', '');
    r := r || E'15 FAIL  published with no draft\n';
  exception when others then
    r := r || E'15 PASS  nothing to publish -> error\n';
  end;

  -- 16. media registration
  begin
    perform public.site_media_register('x.svg', 'https://x/x.svg', 1, 1, 10, 'image/svg+xml', '', 'x.svg');
    r := r || E'16a FAIL  SVG accepted\n';
  exception when others then
    r := r || E'16a PASS  SVG refused\n';
  end;
  perform public.site_media_register('test-aa.png', 'https://x/test-aa.png', 10, 10, 100, 'image/png', 'alt', 'a.png');
  select count(*) into n from public.site_media where path = 'test-aa.png';
  r := r || case when n = 1 then E'16b PASS  PNG registered\n' else E'16b FAIL\n' end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', normal_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.site_media_register('test-bb.png', 'https://x/b.png', 1, 1, 10, 'image/png', '', 'b.png');
    r := r || E'16c FAIL  ordinary user registered media\n';
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    r := r || case when st = '42501' then E'16c PASS  media registration refused to an ordinary user\n' else format(E'16c FAIL  unexpected %s\n', st) end;
  end;
  select count(*) into n from public.site_media;
  r := r || case when n = 0 then E'16d PASS  ordinary user cannot list the library\n' else E'16d FAIL  library visible\n' end;
  reset role;

  -- 17. the bucket
  select count(*) into n from storage.buckets
    where id = 'site-media' and public and file_size_limit = 5242880
      and allowed_mime_types @> array['image/jpeg','image/png','image/webp','image/gif']
      and not (allowed_mime_types @> array['image/svg+xml']);
  r := r || case when n = 1 then E'17 PASS  site-media bucket: public, 5 MB, no SVG\n' else E'17 FAIL  bucket not as specified\n' end;
  select count(*) into n from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'site-media%';
  r := r || case when n = 4 then E'18 PASS  four site-media storage policies\n' else format(E'18 FAIL  %s policies\n', n) end;

  raise exception E'\n%\n(rolled back on purpose)', r;
end $$;
