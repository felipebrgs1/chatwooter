-- name: CountCompanies :one
SELECT count(*) FROM companies
WHERE account_id = @account_id AND (sqlc.arg(search)::text = '' OR name ILIKE '%' || sqlc.arg(search)::text || '%' OR domain ILIKE '%' || sqlc.arg(search)::text || '%');

-- name: ListCompanies :many
SELECT * FROM companies
WHERE account_id = @account_id AND (sqlc.arg(search)::text = '' OR name ILIKE '%' || sqlc.arg(search)::text || '%' OR domain ILIKE '%' || sqlc.arg(search)::text || '%')
ORDER BY
 CASE WHEN @sort::text = 'name' THEN name END ASC,
 CASE WHEN @sort::text = '-name' THEN name END DESC,
 CASE WHEN @sort::text = 'domain' THEN domain END ASC,
 CASE WHEN @sort::text = '-domain' THEN domain END DESC,
 CASE WHEN @sort::text = 'created_at' THEN created_at END ASC,
 CASE WHEN @sort::text = '-created_at' THEN created_at END DESC,
 CASE WHEN @sort::text = 'last_activity_at' THEN last_activity_at END ASC NULLS LAST,
 CASE WHEN @sort::text = '-last_activity_at' THEN last_activity_at END DESC NULLS LAST,
 CASE WHEN @sort::text = 'contacts_count' THEN contacts_count END ASC NULLS LAST,
 CASE WHEN @sort::text = '-contacts_count' THEN contacts_count END DESC NULLS LAST,
 id ASC
LIMIT sqlc.arg(page_limit) OFFSET sqlc.arg(page_offset);

-- name: GetCompany :one
SELECT * FROM companies WHERE account_id = @account_id AND id = @id;

-- name: CreateCompany :one
INSERT INTO companies (account_id, name, domain, description, additional_attributes, custom_attributes, created_at, updated_at)
VALUES (@account_id, @name, sqlc.narg(domain), sqlc.narg(description), @additional_attributes, @custom_attributes, now(), now())
RETURNING *;

-- name: LockCompany :one
SELECT * FROM companies WHERE account_id = @account_id AND id = @id FOR UPDATE;

-- name: UpdateCompany :one
UPDATE companies SET name = @name, domain = sqlc.narg(domain), description = sqlc.narg(description),
 additional_attributes = @additional_attributes, custom_attributes = @custom_attributes, updated_at = now()
WHERE account_id = @account_id AND id = @id RETURNING *;

-- name: SyncCompanyContactNames :exec
UPDATE contacts SET additional_attributes = COALESCE(additional_attributes, '{}'::jsonb) || jsonb_build_object('company_name', sqlc.arg(company_name)::text)
WHERE account_id = @account_id AND company_id = @company_id;

-- name: UnlinkCompanyContacts :exec
UPDATE contacts SET company_id = NULL, additional_attributes = COALESCE(additional_attributes, '{}'::jsonb) - 'company_name'
WHERE account_id = @account_id AND company_id = @company_id;

-- name: DeleteCompany :exec
DELETE FROM companies WHERE account_id = @account_id AND id = @id;

-- name: CountCompanyContacts :one
SELECT count(*) FROM contacts WHERE account_id= @account_id AND (CASE WHEN @searching::boolean THEN (company_id IS NULL OR company_id != @company_id) AND (name ILIKE '%' || @term::text || '%' OR email ILIKE '%' || @term::text || '%' OR phone_number ILIKE '%' || @term::text || '%' OR identifier ILIKE '%' || @term::text || '%') ELSE company_id= @company_id END);

-- name: ListCompanyContactIDs :many
SELECT id FROM contacts WHERE account_id= @account_id AND (CASE WHEN @searching::boolean THEN (company_id IS NULL OR company_id != @company_id) AND (name ILIKE '%' || @term::text || '%' OR email ILIKE '%' || @term::text || '%' OR phone_number ILIKE '%' || @term::text || '%' OR identifier ILIKE '%' || @term::text || '%') ELSE company_id= @company_id END) ORDER BY name, id LIMIT 15 OFFSET @page_offset;

-- name: GetContactCompanyID :one
SELECT company_id FROM contacts WHERE account_id= @account_id AND id= @id;

-- name: LockCompanyContact :one
SELECT * FROM contacts WHERE account_id= @account_id AND id= @id FOR UPDATE;

-- name: AssignContactCompany :exec
UPDATE contacts SET company_id=sqlc.narg(company_id), additional_attributes=(COALESCE(additional_attributes,'{}'::jsonb) - 'company_name') || CASE WHEN sqlc.narg(company_name)::text IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('company_name',sqlc.narg(company_name)::text) END, updated_at=now()
WHERE account_id= @account_id AND id= @id;

-- name: RefreshCompanyContactCount :exec
UPDATE companies SET contacts_count=(SELECT count(*) FROM contacts WHERE contacts.account_id= @account_id::integer AND contacts.company_id=companies.id), last_activity_at=GREATEST(last_activity_at, sqlc.narg(activity)::timestamp) WHERE companies.account_id= @account_id::integer AND companies.id= @id;

-- name: CompanyConversationIDs :many
SELECT c.display_id FROM conversations c JOIN contacts ct ON ct.id=c.contact_id AND ct.account_id=c.account_id
WHERE c.account_id= @account_id AND ct.company_id= @company_id AND (@is_admin::boolean OR c.inbox_id IN (SELECT im.inbox_id FROM inbox_members im JOIN inboxes i ON i.id=im.inbox_id WHERE im.user_id= @user_id AND i.account_id= @account_id))
ORDER BY c.last_activity_at DESC,c.id DESC LIMIT 20;

-- name: CompanyNoteIDs :many
SELECT n.id,ct.id AS contact_id FROM notes n JOIN contacts ct ON ct.id=n.contact_id AND ct.account_id=n.account_id WHERE n.account_id= @account_id AND ct.company_id= @company_id ORDER BY n.created_at DESC,n.id DESC LIMIT 20;

-- name: CompanyAvatar :one
SELECT b.* FROM active_storage_blobs b JOIN active_storage_attachments a ON a.blob_id=b.id JOIN companies c ON c.id=a.record_id WHERE c.account_id = @account_id AND c.id = @id AND a.record_type='Company' AND a.name='avatar' AND b.service_name='chatwooter_local';

-- name: CreateAvatarBlob :one
INSERT INTO active_storage_blobs (key,filename,content_type,metadata,byte_size,checksum,created_at,service_name)
VALUES (@key,@filename,@content_type,'{}',@byte_size,@checksum,now(),'chatwooter_local') RETURNING id;

-- name: AttachCompanyAvatar :exec
INSERT INTO active_storage_attachments (name,record_type,record_id,blob_id,created_at) VALUES ('avatar','Company',@record_id,@blob_id,now());

-- name: DetachCompanyAvatar :exec
DELETE FROM active_storage_attachments WHERE record_type='Company' AND record_id = @record_id AND name='avatar';

-- name: DeleteAvatarBlob :exec
DELETE FROM active_storage_blobs WHERE active_storage_blobs.id = @id AND service_name='chatwooter_local' AND NOT EXISTS (SELECT 1 FROM active_storage_attachments WHERE blob_id = @id);
