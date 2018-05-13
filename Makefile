.PHONY: clean deps docker prepare rel test

clean:
	rm -rf _build

deps:
	mix deps.get

docker:
	docker build . -t breaking-pp

prepare:
	mix local.hex --force
	mix local.rebar --force

rel:
	MIX_ENV=prod mix release

test:
	mix test $(file)
