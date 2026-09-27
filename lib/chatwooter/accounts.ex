defmodule Chatwooter.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias Chatwooter.Accounts.{
    Account,
    AccountUser,
    Team,
    TeamMember,
    User,
    UserNotifier,
    UserToken
  }

  alias Chatwooter.Repo

  defdelegate list_custom_filters(scope, account, type \\ 0),
    to: Chatwooter.Accounts.CustomFilters,
    as: :list

  defdelegate get_custom_filter(scope, account, id),
    to: Chatwooter.Accounts.CustomFilters,
    as: :get

  defdelegate create_custom_filter(scope, account, attrs),
    to: Chatwooter.Accounts.CustomFilters,
    as: :create

  defdelegate update_custom_filter(scope, account, id, attrs),
    to: Chatwooter.Accounts.CustomFilters,
    as: :update

  defdelegate delete_custom_filter(scope, account, id),
    to: Chatwooter.Accounts.CustomFilters,
    as: :delete

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    find_user_by_email(email)
  end

  defp find_user_by_email(email) do
    users =
      Repo.all(
        from(user in User,
          where: fragment("lower(?)", user.email) == ^String.downcase(email),
          limit: 2
        )
      )

    # Restored providers can share email; never authenticate an arbitrary matching identity.
    case users do
      [user] -> user
      _ -> nil
    end
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = find_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Chatwooter.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Chatwooter.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/app/settings/profile/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Accounts (multi-tenant)

  @doc """
  Creates an account and assigns the given user as `admin` owner,
  atomically.

  ## Examples

      iex> create_account(%{name: "Acme"}, owner)
      {:ok, %Account{}}

      iex> create_account(%{name: ""}, owner)
      {:error, %Ecto.Changeset{}}

  """
  def create_account(attrs, %User{} = owner) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:account, Account.changeset(%Account{}, attrs))
    |> Ecto.Multi.insert(:membership, fn %{account: account} ->
      AccountUser.changeset(%AccountUser{}, %{
        account_id: account.id,
        user_id: owner.id,
        role: :administrator
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{account: account}} -> {:ok, account}
      {:error, :account, changeset, _} -> {:error, changeset}
      {:error, :membership, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Lists the memberships of an account (with users preloaded).
  """
  def list_account_users(%Account{id: account_id}) do
    Repo.all(from m in AccountUser, where: m.account_id == ^account_id, preload: [:user])
  end

  @doc """
  Lists the accounts a user belongs to (tenant scoping).
  """
  def list_user_accounts(%User{id: user_id}) do
    Repo.all(from a in Account, join: m in assoc(a, :account_users), where: m.user_id == ^user_id)
  end

  @doc "Vínculos do usuário com a conta carregada, por nome da conta (seletor de conta)."
  def list_user_memberships(%User{id: user_id}) do
    Repo.all(
      from m in AccountUser,
        join: a in assoc(m, :account),
        where: m.user_id == ^user_id,
        order_by: [asc: a.name],
        preload: [account: a]
    )
  end

  @doc "Vínculo do usuário com a conta, ou `nil` se não for membro."
  def get_membership(%Account{id: account_id}, %User{id: user_id}) do
    Repo.get_by(AccountUser, account_id: account_id, user_id: user_id)
  end

  @doc """
  Disponibilidade do agente na conta (`availability` e `auto_offline`), como
  o `profile/availability` e `profile/auto_offline` do Chatwoot. Não mexe no papel.
  """
  def update_availability(%Account{} = account, %User{} = user, attrs) do
    case get_membership(account, user) do
      %AccountUser{} = membership ->
        membership
        |> AccountUser.membership_changeset(Map.take(attrs, ~w(availability auto_offline)))
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  @doc "Mescla chaves em `ui_settings` do usuário (preferências de UI, como `sidebar_width`)."
  def update_ui_settings(%User{id: id}, settings) when is_map(settings) do
    # relê do banco: o struct da sessão (current_scope) pode estar desatualizado
    user = Repo.get!(User, id)

    user
    |> Ecto.Changeset.change(ui_settings: Map.merge(user.ui_settings || %{}, settings))
    |> Repo.update()
  end

  @doc "Busca uma conta por id (ingest de webhooks)."
  def get_account!(id), do: Repo.get!(Account, id)

  @doc "Checks membership without allowing a user from a different account through."
  def member?(%Account{id: account_id}, user_id) do
    Repo.exists?(
      from m in AccountUser, where: m.account_id == ^account_id and m.user_id == ^user_id
    )
  end

  def list_teams(%Account{id: account_id}) do
    Repo.all(from t in Team, where: t.account_id == ^account_id, order_by: [asc: t.name])
  end

  @doc "Times da conta dos quais o usuário é membro (sidebar: `teams/getMyTeams`)."
  def list_user_teams(%Account{id: account_id}, %User{id: user_id}) do
    Repo.all(
      from t in Team,
        join: m in TeamMember,
        on: m.team_id == t.id,
        where: t.account_id == ^account_id and m.user_id == ^user_id,
        order_by: [asc: t.name]
    )
  end

  def get_team!(%Account{id: account_id}, id),
    do: Repo.get_by!(Team, id: id, account_id: account_id)

  def get_team(%Account{id: account_id}, id),
    do: Repo.get_by(Team, id: id, account_id: account_id)

  def create_team(%Account{} = account, attrs) do
    %Team{account_id: account.id}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  def add_team_member(%Account{} = account, team_id, user_id) do
    if Repo.exists?(from t in Team, where: t.id == ^team_id and t.account_id == ^account.id) and
         member?(account, user_id) do
      %TeamMember{}
      |> TeamMember.changeset(%{team_id: team_id, user_id: user_id})
      |> Repo.insert()
    else
      {:error, :not_found}
    end
  end

  def list_team_members(%Account{} = account, team_id) do
    get_team!(account, team_id)
    Repo.all(from m in TeamMember, where: m.team_id == ^team_id, preload: [:user])
  end

  ## Account settings (Chatwoot-style)

  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def add_member(%Account{} = account, %User{} = user, role \\ "agent") do
    %AccountUser{}
    |> AccountUser.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert()
  end

  @doc """
  Changes a member role. Refuses to demote the last admin.
  """
  def update_member_role(%Account{} = account, %User{} = user, role) do
    case Repo.get_by(AccountUser, account_id: account.id, user_id: user.id) do
      nil ->
        {:error, :not_found}

      %AccountUser{role: :administrator} = membership ->
        if to_string(role) != "administrator" and admin_count(account) <= 1 do
          {:error, :last_admin}
        else
          update_membership_role(membership, role)
        end

      %AccountUser{} = membership ->
        update_membership_role(membership, role)
    end
  end

  @doc """
  Removes a member. Refuses to remove the last admin.
  """
  def remove_member(%Account{} = account, %User{} = user) do
    case Repo.get_by(AccountUser, account_id: account.id, user_id: user.id) do
      nil ->
        {:error, :not_found}

      %AccountUser{role: :administrator} = membership ->
        if admin_count(account) <= 1 do
          {:error, :last_admin}
        else
          Repo.delete(membership)
        end

      %AccountUser{} = membership ->
        Repo.delete(membership)
    end
  end

  defp admin_count(%Account{id: account_id}) do
    Repo.aggregate(
      from(m in AccountUser, where: m.account_id == ^account_id and m.role == :administrator),
      :count
    )
  end

  defp update_membership_role(membership, role) do
    membership
    |> AccountUser.changeset(%{role: role})
    |> Repo.update()
  end

  @doc """
  Creates an agent like Chatwoot's `AgentBuilder`: reuses the user by email
  (blank name defaults to the email prefix), otherwise registers them, then
  adds the membership with role/availability. The caller sends the login email.
  """
  def create_agent(%Account{} = account, attrs) do
    email = attrs[:email] || attrs["email"]

    case email && get_user_by_email(email) do
      %User{} = user -> add_existing_agent(account, user, attrs)
      _ -> add_new_agent(account, attrs)
    end
  end

  defp add_existing_agent(account, user, attrs) do
    with {:ok, _} <-
           %AccountUser{}
           |> AccountUser.changeset(%{
             account_id: account.id,
             user_id: user.id,
             role: attrs[:role] || attrs["role"] || "agent",
             availability: attrs[:availability] || attrs["availability"] || "offline",
             auto_offline: attrs[:auto_offline] || attrs["auto_offline"] || false
           })
           |> Repo.insert() do
      {:ok, user}
    end
  end

  defp add_new_agent(account, attrs) do
    with {:ok, user} <- %User{} |> User.agent_changeset(attrs) |> Repo.insert(),
         {:ok, _} <-
           %AccountUser{}
           |> AccountUser.changeset(%{
             account_id: account.id,
             user_id: user.id,
             role: attrs[:role] || attrs["role"] || "agent",
             availability: attrs[:availability] || attrs["availability"] || "offline",
             auto_offline: attrs[:auto_offline] || attrs["auto_offline"] || false
           })
           |> Repo.insert() do
      {:ok, user}
    end
  end

  @doc """
  Updates an agent like Chatwoot's agents controller: the user name plus the
  membership role/availability. Refuses to demote the last admin.
  """
  def update_agent(%Account{} = account, %User{} = user, attrs) do
    membership = Repo.get_by(AccountUser, account_id: account.id, user_id: user.id)

    with %AccountUser{} <- membership || {:error, :not_found},
         :ok <- check_last_admin(account, membership, attrs),
         {:ok, user} <- user |> User.agent_changeset(attrs) |> Repo.update(),
         {:ok, _} <- membership |> AccountUser.membership_changeset(attrs) |> Repo.update() do
      {:ok, user}
    end
  end

  defp check_last_admin(account, %AccountUser{role: :administrator}, attrs) do
    role = attrs[:role] || attrs["role"]

    if (role && to_string(role) != "administrator") and admin_count(account) <= 1 do
      {:error, :last_admin}
    else
      :ok
    end
  end

  defp check_last_admin(_account, _membership, _attrs), do: :ok

  @doc """
  Invites someone by email: reuses the user if they exist, otherwise
  registers them, then adds as `agent`. The caller sends the login email.
  """
  def invite_member(%Account{} = account, email) when is_binary(email) do
    create_agent(account, %{email: email})
  end
end
