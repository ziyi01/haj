defmodule HajWeb.ShowLive.Show do
  use HajWeb, :live_view

  alias Haj.Spex
  alias HajWeb.Endpoint
  alias Haj.Policy

  def mount(%{"show_id" => show_id}, _session, socket) do
    show = Spex.get_show!(show_id)
    members = Spex.list_members_for_show(show_id) |> Spex.preload_user_groups(show_id: show_id)

    groups =
      Spex.get_show_groups_for_show(show_id)
      |> Enum.map(fn %{id: id, group: g} -> [key: g.name, value: id] end)

    {:ok,
     assign(socket,
       show: show,
       page_title: "METAspexet #{show.year.year}",
       show_id: show_id,
       query: nil,
       groups: groups,
       group: nil,
       members: members
     )}
  end

  def handle_event("filter", %{"search_form" => %{"q" => query, "group" => group}}, socket) do
    members =
      case {group, query} do
        {"", ""} ->
          Spex.list_members_for_show(socket.assigns.show_id)

        {group, ""} ->
          Spex.get_show_group_members(group)

        {"", query} ->
          Spex.search_show_members(socket.assigns.show_id, query)

        {group, query} ->
          Spex.search_group_members(group, query)
      end
      |> Spex.preload_user_groups(show_id: socket.assigns.show_id)

    {:noreply, assign(socket, members: members, query: query, group: group)}
  end

  @colors ~w"#8dd3c7 #ffffb3 #bebada #fb8072 #80b1d3 #fdb462 #b3de69 #fccde5 #d9d9d9 #bc80bd #ccebc5 #ffed6f"

  defp get_color(:bg, index), do: Enum.at(@colors, rem(index - 1, 12), "#4e79a7")
end
