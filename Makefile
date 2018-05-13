.PHONY: clean clean-propcheck deps docker prepare rel test

clean:
	rm -rf _build

clean-propcheck:
	rm -rf _build/propcheck.ctex

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
