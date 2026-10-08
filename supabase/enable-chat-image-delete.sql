-- Allow authenticated users to delete only their own Sanad AI chat images.
do $policy$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'sanad_ai_chat_images_delete_own'
  ) then
    execute $create_policy$
      create policy sanad_ai_chat_images_delete_own
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'sanad-ai-chat-images'
        and (storage.foldername(name))[1] = (select auth.uid())::text
      )
    $create_policy$;
  end if;
end
$policy$;
