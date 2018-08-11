# Distributed tests of Phoenix PubSub

## Quick Start

Build a docker image used in all tests:
```bash
make docker
```

Run basic tests and extracted counterexamples:
```bash
make test
```

Run property tests. Currently, you can customize number of tests in the test file:
```bash
make props
```
