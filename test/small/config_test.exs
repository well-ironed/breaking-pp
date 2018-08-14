defmodule BreakingPP.ConfigTest do
  use ExUnit.Case, async: false
  import Mock

  test "It crashes if TRACKER is not set" do
    with_mock System, [get_env: fn("TRACKER") -> nil end] do
      assert_raise RuntimeError, fn -> BreakingPP.Config.tracker_module() end
    end
  end

  test "It returns ETS tracker if TRACKER is ETS in env" do
    with_mock System, [get_env: fn("TRACKER") -> "ETS" end] do
      assert BreakingPP.Tracker.ETS  = BreakingPP.Config.tracker_module()
    end
  end

  test "ETS tracker has an empty list of opts" do
    with_mock System, [get_env: fn("TRACKER") -> "ETS" end] do
      assert {BreakingPP.Tracker.ETS,[]} = BreakingPP.Config.tracker_mod_opts()
    end
  end

  test "It returns Phoenix Tracker if TRACKER is set to pp" do
    with_mock System, [get_env: fn("TRACKER") -> "PP" end] do
      assert BreakingPP.Tracker.PP = BreakingPP.Config.tracker_module()
    end
  end

  test "Phoenix Tracker has appropriate opts" do
    with_mock System, [get_env: fn("TRACKER") -> "PP" end] do
      assert {BreakingPP.Tracker.PP, opts} = BreakingPP.Config.tracker_mod_opts()
      assert opts == [name: BreakingPP.Tracker.PP, pubsub_server: BreakingPP.PubSub]
    end
  end


end
