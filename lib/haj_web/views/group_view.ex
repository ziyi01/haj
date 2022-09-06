defmodule HajWeb.GroupView do
  use HajWeb, :view

  def table(assigns), do: HajWeb.LiveComponents.Table.table(assigns)

  def is_chef_for(show_group, user) do
    show_group.group_memberships
    |> Enum.any?(fn %{user_id: id, role: role} ->
      role == :chef && id == user.id
    end)
  end

  defp all_groups(application) do
    Enum.map(application.application_show_groups, fn %{show_group: %{group: group}} ->
      group.name
    end)
    |> Enum.join(", ")
  end
end
