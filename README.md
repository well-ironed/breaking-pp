# Distributed tests of Phoenix PubSub

[![Build Status](https://travis-ci.org/distributed-owls/breaking-pp.svg?branch=master)](https://travis-ci.org/distributed-owls/breaking-pp)


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
