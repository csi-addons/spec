# Container Storage Interface Addons

The CSI-Addons project hosts extensions to the [CSI specification][csi_spec]
that provide advanced storage operations.

## Reclaim Space

The [Reclaim Space](reclaimspace/README.md) specification defines an extension
to the CSI Specification that will enable storage vendors (SP) to develop
controllers/plugins that can free unused storage allocations from existing
volumes.

## Volume Replication

The [Volume Replication](replication/README.md) specification provides a
mechanism that Storage Providers can implement to support async-replication
which can be used for disaster recovery operations.

[csi_spec]: https://github.com/container-storage-interface/spec
