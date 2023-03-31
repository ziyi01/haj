defmodule HajWeb.GroupAdminLive do
  use HajWeb, :live_view

  alias Haj.Spex
  alias Haj.Repo

  def mount(%{"show_group_id" => show_group_id}, _session, socket) do
    show_group = Spex.get_show_group!(show_group_id)
    changeset = Spex.change_show_group(show_group)
    user = socket.assigns[:current_user]

    case is_admin?(socket, show_group) do
      true ->
        socket =
          socket
          |> stream(
            :members,
            show_group.group_memberships
            |> Enum.sort_by(fn %{role: role} -> role end)
          )
          |> assign(
            current_user: user,
            changeset: changeset,
            show_group: show_group,
            page_title: show_group.group.name,
            query: nil,
            loading: false,
            matches: [],
            roles: [:gruppis, :chef],
            role: :gruppis
          )

        {:ok, socket}

      false ->
        # Redirect to normal group page
        {:ok, redirect(socket, to: Routes.group_path(socket, :group, show_group.id))}
    end
  end

  def handle_event("suggest", %{"search_form" => %{"q" => query}}, socket) do
    users = Haj.Accounts.search_users(query)

    {:noreply, assign(socket, matches: users)}
  end

  def handle_event("update_role", %{"role_form" => %{"role" => role}}, socket) do
    {:noreply, assign(socket, role: role, matches: [])}
  end

  def handle_event("add_user", _, %{assigns: %{matches: []}} = socket) do
    {:noreply, socket}
  end

  def handle_event("add_user", _, %{assigns: %{matches: [user | _]}} = socket) do
    case Enum.any?(socket.assigns.show_group.group_memberships, fn member ->
           member.user_id == user.id
         end) do
      true ->
        {:noreply,
         socket |> put_flash(:error, "Användaren är redan med i gruppen.") |> assign(matches: [])}

      false ->
        {:ok, member} =
          Haj.Spex.create_group_membership(%{
            user_id: user.id,
            show_group_id: socket.assigns.show_group.id,
            role: socket.assigns.role
          })

        member = Repo.preload(member, :user)

        if member.role == :chef do
          {:noreply, stream_insert(socket, :members, member, at: 0) |> assign(matches: [])}
        else
          {:noreply, stream_insert(socket, :members, member, at: -1) |> assign(matches: [])}
        end
    end
  end

  def handle_event("save", %{"show_group" => show_group}, socket) do
    case Spex.update_show_group(socket.assigns.show_group, show_group) do
      {:ok, show_group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sparat.")
         |> assign(changeset: Spex.change_show_group(show_group))}

      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, "Något gick fel.") |> assign(changeset: changeset)}
    end
  end

  def handle_event("remove_user", %{"id" => id}, socket) do
    membership = Haj.Spex.get_group_membership!(id)
    {:ok, _} = Haj.Spex.delete_group_membership(membership)
    {:noreply, stream_delete(socket, :members, membership)}
  end

  def render(assigns) do
    ~H"""
    <h1 class="font-bold mt-4 text-3xl">
      Redigera <span class="text-burgandy-600"><%= @page_title %></span>
    </h1>
    <.form :let={f} for={@changeset} phx-submit="save" class="flex flex-col pb-2">
      <%= label(f, :application_description, "Beskrivning av gruppen",
        class: "text-zinc-600 mt-4 font-medium"
      ) %>
      <%= textarea(f, :application_description,
        class: "mb-2 rounded-lg border-1 border-zinc-300 bg-zinc-50"
      ) %>

      <%= label(
        f,
        :application_extra_question,
        "Extra fråga i ansökan. Om du lämnar detta blankt kommer ingen extra fråga visas.",
        class: "text-zinc-600 mt-2 font-medium"
      ) %>
      <%= textarea(f, :application_extra_question,
        class: "mb-2 rounded-lg border-1 border-zinc-300 bg-zinc-50"
      ) %>

      <div class="mb-2 flex items-center gap-2">
        <%= checkbox(f, :application_open) %>
        <%= label(f, :application_open, "Gruppen går att söka") %>
      </div>

      <%= submit("Spara",
        class: "self-start bg-burgandy-500 hover:bg-burgandy-400 px-16 py-2 rounded-md text-white"
      ) %>
    </.form>
    <h2 class="uppercase mt-6 font-bold text-burgandy-500">Lägg till medlemmar</h2>
    <p class="py-2 text-zinc-600 font-regular">
      Välj vilken typ av medlem (chef/gruppis), sök på användare och lägg sedan till!
    </p>
    <div class="flex flex-row items-stretch gap-2">
      <.form :let={f} for={%{}} as={:role_form} phx-change="update_role">
        <%= select(f, :role, @roles, class: "h-full rounded-md border-zinc-400", value: @role) %>
      </.form>

      <.form
        :let={f}
        for={%{}}
        as={:search_form}
        phx-change="suggest"
        phx-submit="add_user"
        autocomplete={:off}
        class="flex-grow"
      >
        <%= text_input(f, :q, value: @query, class: "w-full rounded-md border-zinc-400") %>
      </.form>
    </div>

    <ol id="matches" class="flex flex-col bg-slate-100 rounded-md mt-2">
      <li :for={{user, i} <- Enum.with_index(@matches)}>
        <%= if i == 0 do %>
          <button
            value={user.id}
            class="px-3 py-2 text-black opacity-50 hover:opacity-100 cursor-pointer w-full text-left"
            phx-click="add_user"
            phx-value-user={user.id}
          >
            <%= "#{user.first_name} #{user.last_name}" %>
          </button>
        <% else %>
          <button
            value={user.id}
            class="px-3 py-2 text-black opacity-50 hover:opacity-100 cursor-pointer border-t "
            phx-click="add_user"
            phx-value-user={user.id}
          >
            <%= "#{user.first_name} #{user.last_name}" %>
          </button>
        <% end %>
      </li>
    </ol>
    <h3 class="uppercase font-semibold text-sm mb-[-8px] mt-4 ml-2">Gruppisar</h3>
    <.table id="members-table" rows={@streams.members}>
      <:col :let={{_id, member}} label="Namn">
        <.user_card user={member.user} />
      </:col>
      <:col :let={{_id, member}} label="Mail">
        <%= member.user.email %>
      </:col>
      <:col :let={{_id, member}} label="Roll">
        <p>
          <%= if member.role == :chef do %>
            <span class="bg-burgandy-50 px-1 rounded-md text-burgandy-400">Chef</span>
          <% else %>
            Gruppis
          <% end %>
        </p>
      </:col>
      <:action :let={{id, member}}>
        <button
          class="bg-burgandy-500 text-white px-2 py-0.5 rounded-md hover:bg-burgandy-400"
          phx-click={JS.push("remove_user", value: %{id: member.id}) |> hide("##{id}")}
        >
          Ta bort
        </button>
      </:action>
    </.table>
    """
  end

  defp is_admin?(socket, show_group) do
    socket.assigns.current_user.role == :admin ||
      show_group.group_memberships
      |> Enum.any?(fn %{user_id: id, role: role} ->
        role == :chef && id == socket.assigns.current_user.id
      end)
  end
end
