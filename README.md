# Obol distributed validator package for Holesky network

This package includes 5 services "cluster-validator". Each one can take part in an Obol cluster.

The package supports both Teku and Lodestar validator clients. In order to use Lodestar, you need to use the `Dockerfile.lodestar` file instead of the `Dockerfile.teku` file in each service of the `docker-compose.yml` file. Also, you need to set the desired validator client version for the build args, called `VALIDATOR_CLIENT_VERSION`.
