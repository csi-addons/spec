# Container Storage Interface Addons

The CSI-Addons project hosts extensions to the [CSI specification][csi_spec]
that provide advanced storage operations.

## Network Fencing

The [Network Fencing](fence/README.md) specification provides a
mechanism that Storage Providers can implement to network-fence any
client using corresponding CIDR blocks.

## Reclaim Space

The [Reclaim Space](reclaimspace/README.md) specification defines an extension
to the CSI Specification that will enable storage vendors (SP) to develop
controllers/plugins that can free unused storage allocations from existing
volumes.

## Volume Replication

The [Volume Replication](replication/README.md) specification provides a
mechanism that Storage Providers can implement to support async-replication
which can be used for disaster recovery operations.

## Volume Group

The [Volume Group](volumegroup/README.md) specification provides a
standard that will enable storage vendors (SP) to develop
controllers/plugins for managing VolumeGroups.

[csi_spec]: https://github.com/container-storage-interface/spec
