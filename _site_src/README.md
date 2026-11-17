# Container Storage Interface Addons

The CSI-Addons project hosts extensions to the [CSI specification][csi_spec]
that provide advanced storage operations.

## Identity

The [Identity](identity/README.md) specification defines the service that every
CSI-driver MUST implement so that the CSI-Addons plugin can discover the
CSI-driver, probe its health, and detect which CSI-Addons operations it
supports.

## Network Fencing

The [Network Fencing](fence/README.md) specification provides a
mechanism that Storage Providers can implement to network-fence any
client using corresponding CIDR blocks.

## Reclaim Space

The [Reclaim Space](reclaimspace/README.md) specification defines an extension
to the CSI Specification that will enable storage vendors to develop
controllers/plugins that can free unused storage allocations from existing
volumes.

## Volume Replication

The [Volume Replication](replication/README.md) specification provides a
mechanism that Storage Providers can implement to support async-replication
which can be used for disaster recovery operations.

## Volume Group

The [Volume Group](volumegroup/README.md) specification provides a
standard that will enable storage vendors to develop
controllers/plugins for managing VolumeGroups.

## Encryption Key Rotation

The [Encryption Key Rotation](encryptionkeyrotation/README.md) specification
defines an extension to the CSI Specification that will enable storage vendors
to develop controllers/plugins that can rotate the Key Encryption Keys of
existing encrypted volumes.

[csi_spec]: https://github.com/container-storage-interface/spec
