.PHONY: deps test

deps:
	mix deps.get

test:
	mix test
