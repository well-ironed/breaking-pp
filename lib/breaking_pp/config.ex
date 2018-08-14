defmodule BreakingPP.Config do
  @ets_tracker BreakingPP.Tracker.ETS
  @pp_tracker BreakingPP.Tracker.PP
  @pp_opts name: @pp_tracker, pubsub_server: BreakingPP.PubSub


  def tracker_mod_opts() do
    case tracker_env_var() do
      :ets -> {@ets_tracker, []}
      :pp -> {@pp_tracker, @pp_opts}
      _ -> raise RuntimeError, "Missing TRACKER env var := {ets|pp}"
    end
  end

  def tracker_module() do
    tracker_mod_opts() |> elem(0)
  end

  defp tracker_env_var() do
    case System.get_env("TRACKER") do
      nil -> nil
      s ->  String.downcase(s) |> String.to_atom()
    end
  end

end
