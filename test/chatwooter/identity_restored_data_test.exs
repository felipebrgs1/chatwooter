defmodule Chatwooter.IdentityRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.Accounts.{Account, AccountUser, User}

  test "raw upstream identity rows preserve BCrypt, locale, flags, enums and micros" do
    created = ~N[2026-09-24 10:30:00.123456]
    password = "Synthetic password 123"
    hash = Bcrypt.hash_pwd_salt(password)

    Repo.query!(
      "INSERT INTO accounts (id, name, locale, feature_flags, settings, created_at, updated_at) VALUES (91001, 'Restored', 16, 4294967296, $1, $2, $2)",
      [["synthetic"], created]
    )

    Repo.query!(
      "INSERT INTO users (id, uid, provider, name, email, encrypted_password, tokens, created_at, updated_at) VALUES (91002, 'restored@example.test', 'email', 'Restored', 'restored@example.test', $1, $2, $3, $3)",
      [hash, [%{"client" => "synthetic"}], created]
    )

    Repo.query!(
      "INSERT INTO account_users (id, account_id, user_id, role, availability, created_at, updated_at) VALUES (91003, 91001, 91002, 1, 2, $1, $1)",
      [created]
    )

    account = Repo.get!(Account, 91_001)
    user = Repo.get!(User, 91_002)
    membership = Repo.get!(AccountUser, 91_003)
    assert account.locale == 16
    assert account.settings == ["synthetic"]
    assert account.feature_flags == 4_294_967_296
    assert user.hashed_password == hash
    assert User.valid_password?(user, password)
    assert user.tokens == [%{"client" => "synthetic"}]
    assert user.inserted_at == DateTime.from_naive!(created, "Etc/UTC")
    assert membership.role == :administrator
    assert membership.availability == :busy
    assert membership.auto_offline
    refute inspect(user) =~ hash
    refute inspect(user) =~ "synthetic"
  end

  test "upstream email is nonunique and nullable while provider identity remains unique" do
    for id <- [91_004, 91_005] do
      Repo.query!(
        "INSERT INTO users (id, uid, provider, name, email, created_at, updated_at) VALUES ($1, $2, 'email', 'Restored', 'same@example.test', now(), now())",
        [id, "unique-#{id}"]
      )
    end

    assert Chatwooter.Accounts.get_user_by_email("SAME@example.test") == nil

    Repo.query!(
      "INSERT INTO users (id, uid, name, created_at, updated_at) VALUES (91006, 'nil-email', 'Restored', now(), now())"
    )

    assert Repo.get!(User, 91_006).email == nil
    assert Repo.get!(User, 91_006).hashed_password == nil

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO users (uid, provider, name, created_at, updated_at) VALUES ('nil-email', 'email', 'Duplicate', now(), now())"
             )
  end
end
