defmodule Chatwooter.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "users" do
    field :provider, :string, default: "email"
    field :uid, :string, default: ""

    field :hashed_password, Chatwooter.Types.PasswordHash,
      source: :encrypted_password,
      redact: true

    field :reset_password_token, :string, redact: true
    field :reset_password_sent_at, :utc_datetime_usec
    field :remember_created_at, :utc_datetime_usec
    field :sign_in_count, :integer
    field :current_sign_in_at, :utc_datetime_usec
    field :last_sign_in_at, :utc_datetime_usec
    field :current_sign_in_ip, :string
    field :last_sign_in_ip, :string
    field :confirmation_token, :string, redact: true
    field :confirmed_at, :utc_datetime_usec
    field :confirmation_sent_at, :utc_datetime_usec
    field :unconfirmed_email, :string
    field :name, :string, default: ""
    field :display_name, :string
    field :email, :string
    field :tokens, Chatwooter.Types.JsonValue, redact: true
    field :pubsub_token, :string, redact: true
    field :availability, :integer
    field :ui_settings, Chatwooter.Types.JsonValue
    field :custom_attributes, Chatwooter.Types.JsonValue
    field :type, :string
    field :message_signature, :string
    field :otp_secret, :string, redact: true
    field :consumed_timestep, :integer
    field :otp_required_for_login, :boolean
    field :otp_backup_codes, :string, redact: true
    field :device_trust_version, :integer
    field :password, :string, virtual: true, redact: true
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> synchronize_uid()
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> validate_email_uniqueness()
      |> unique_constraint(:email, name: :index_users_on_uid_and_provider)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp synchronize_uid(changeset) do
    case get_change(changeset, :email) do
      email when is_binary(email) -> put_change(changeset, :uid, String.downcase(email))
      _ -> changeset
    end
  end

  defp validate_email_uniqueness(changeset) do
    email = get_field(changeset, :email)
    id = changeset.data.id

    if is_binary(email) do
      query =
        from(user in __MODULE__,
          where: fragment("lower(?)", user.email) == ^String.downcase(email)
        )

      query = if id, do: where(query, [user], user.id != ^id), else: query

      if Chatwooter.Repo.exists?(query),
        do: add_error(changeset, :email, "has already been taken"),
        else: changeset
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Changeset for agent profile (name + email), mirroring Chatwoot's
  `AgentBuilder` (blank name defaults to the email prefix).
  """
  def agent_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:name, :email])
    |> synchronize_uid()
    |> default_name_from_email()
    |> validate_required([:name, :email])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> validate_email_uniqueness()
      |> unique_constraint(:email, name: :index_users_on_uid_and_provider)
    else
      changeset
    end
  end

  defp default_name_from_email(changeset) do
    current = get_field(changeset, :name)
    had_name = changeset.data.name not in [nil, ""]
    email = get_change(changeset, :email) || get_field(changeset, :email)

    if current in [nil, ""] and not had_name and is_binary(email) do
      put_change(changeset, :name, email |> String.split("@") |> hd())
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now()
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Chatwooter.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
