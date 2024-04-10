# Obol Dappnode Package Guide

The Obol Dappnode Package is designed to help users run a distributed validator setup with specific requirements. This guide explains the key aspects of the package and how to use it effectively.

## Cluster Configuration

1. **Maximum Clusters**: The package supports a maximum of 5 clusters.

2. **Services**: Each cluster requires two dedicated services: Charon and validator client.

## Getting the ENR

3. **ENR for Clusters**: You will receive an ENR (Ethereum Name Record) for each cluster in the package. You can find these ENRs in the [Info tab](http://my.dappnode/packages/my/holesky-obol.dnp.dappnode.eth/info). These ENRs are needed to register each cluster as an operator before running the DKG (Distributed Key Generation) ceremony.

4. **First Installation**: During the first installation, it's essential to leave all definition file inputs blank in the setup wizard. This allows you to obtain the ENR for each Charon node, which is necessary for the DKG process.

## Managing Containers

5. **Container State**: It's normal to see stopped containers for clusters that are not currently active. The package is designed to stop containers for clusters that are not in use to save system resources.

## Backup

6. **Download a backup**: It's recommended to save a backup of the relevant data of each cluster. You can download it from the [Backup tab](http://my.dappnode/packages/my/holesky-obol.dnp.dappnode.eth/backup) of the package.

7. **Restore a backup**: If you are setting up or recovering an existing setup, you should provide the `definition-file-url` in the setup wizard or in the [Config tab](http://my.dappnode/packages/my/holesky-obol.dnp.dappnode.eth/config) of the package. Then, restore your backup in the [Backup tab](http://my.dappnode/packages/my/holesky-obol.dnp.dappnode.eth/backup) of the package.

_Note: The `definition-file-url` in the setup wizard with your cluster's specific URL in the following format:_

```markdown
https://api.obol.tech/dv/0xf9632c4333e4d67373b383da56dfb764df47268881d3412a1eef1a0247dc7367
```

## Upload a Node Artifact

If you have been given a Node Artifact (e.g. `node0.zip`) you can either import it on install (by choosing "File upload" mode) or import it later in the [File Manager tab](http://my.dappnode/packages/my/holesky-obol.dnp.dappnode.eth/file-manager) by choosing the service you want to import it to (`charon-validator-<number>`) and setting `/import/` as the destination path before clicking "Upload".
