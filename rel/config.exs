use Mix.Releases.Config,
  default_release: :breaking_pp,
  default_environment: :prod

environment :prod do
  set include_erts: true
  set include_system_libs: true
end

release :breaking_pp do
  set version: current_version(:breaking_pp)
  set vm_args: "rel/vm.args"
end
