# Obol Dappnode Package Guide

The Obol Dappnode Package is designed to help users run a distributed validator setup with specific requirements. This guide explains the key aspects of the package and how to use it effectively.

## Cluster Configuration

1. **Maximum Clusters**: The package supports a maximum of 5 clusters.

2. **Services**: Each cluster requires two dedicated services: Charon and validator service.

## Getting the ENR

3. **ENR for Clusters**: You will receive an ENR (Ethereum Name Record) for each cluster in the package. You can find these ENRs in the [Info tab](http://my.dappnode/#/packages/holesky-obol.dnp.dappnode.eth/info). These ENRs are needed to register each cluster as an operator before running the DKG (Distributed Key Generation) ceremony.

4. **First Installation**: During the first installation, it's essential to leave all definition file inputs blank in the setup wizard. This allows you to obtain the ENR for each Charon node, which is necessary for the DKG process.

## Managing Containers

5. **Container State**: It's normal to see stopped containers, especially for clusters that are not currently active. The package is designed to stop containers for clusters that are not in use to save system resources.

## Recovering an Existing Setup

6. **Recovery Process**: If you are setting up or recovering an existing setup, you should provide the `definition-file-url` in the setup wizard. This URL should point to the definition file for your cluster, which you should have noted down after registering all the operators, performing the DKG ceremony, and running a command similar to the following:

   ```bash
   docker run --rm -v "$(pwd)/:/opt/charon" obolnetwork/charon:v0.12.0 dkg --definition-file="https://api.obol.tech/dv/0xf9632c4333e4d67373b777da56dfb764df47268881d3412a1eef1a0247dc7367/"
   ```

Replace the `definition-file-url` in the setup wizard with your cluster's specific URL in the following format:

```markdown
https://api.obol.tech/dv/0xf9632c4333e4d67373b383da56dfb764df47268881d3412a1eef1a0247dc7367
```

By following these steps and guidelines, you can effectively use the Obol Dappnode Package to manage your distributed validator clusters and participate in the DKG ceremony.
