.PHONY: deps docker prepare rel test

deps:
	mix deps.get

docker:
	docker build . -t breaking-pp

prepare:
	mix local.hex --force

rel:
	MIX_ENV=prod mix release

test:
	mix test $(file)
