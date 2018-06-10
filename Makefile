.PHONY: clean clean-propcheck deps docker prepare props rel test

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

props: clean-propcheck runs
	mix test --only=property $(file) | tee runs/$(shell date +%s)

runs:
	mkdir -p runs

rel:
	MIX_ENV=prod mix release

test:
	mix test $(file)
