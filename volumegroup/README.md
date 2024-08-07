# CSI-Addons Operation: VolumeGroup

based on deleted [3476-volume-group kep](https://github.com/kubernetes/enhancements/blob/590aa4eecb192d96e538020fc888459d9413221a/keps/sig-storage/3476-volume-group/README.md)

## Container Storage Interface

Define a standard that will enable storage vendors (SP) to develop
controllers/plugins for managing VolumeGroups.

### RPC Interface

```protobuf
syntax = "proto3";
package volumegroup;

import "github.com/container-storage-interface/spec/lib/go/csi/csi.proto";

option go_package = ".;volumegroup";

// Controller holds the RPC methods for volumeGroup and all the methods it
// exposes should be idempotent.
service Controller {
  // CreateVolumeGroup RPC call to create a volume group.
  rpc CreateVolumeGroup(CreateVolumeGroupRequest)
      returns (CreateVolumeGroupResponse) {}
  // ModifyVolumeGroupMembership RPC call to modify a volume group.
  rpc ModifyVolumeGroupMembership(ModifyVolumeGroupMembershipRequest)
      returns (ModifyVolumeGroupMembershipResponse) {}
  // DeleteVolumeGroup RPC call to delete a volume group.
  rpc DeleteVolumeGroup(DeleteVolumeGroupRequest)
      returns (DeleteVolumeGroupResponse) {}
  // ListVolumeGroups RPC call to list volume groups.
  rpc ListVolumeGroups(ListVolumeGroupsRequest)
      returns (ListVolumeGroupsResponse) {}
  // ControllerGetVolumeGroup RPC call to get a volume group.
  rpc ControllerGetVolumeGroup(ControllerGetVolumeGroupRequest)
      returns (ControllerGetVolumeGroupResponse) {}
}
```

#### `CreateVolumeGroup`

A Controller Plugin MUST implement this RPC call if it has `VOLUME_GROUP` controller capability.

This RPC will be called by the CO to create a new volume group on behalf of a user. This operation MUST be idempotent.
If a volume group corresponding to the specified volume group name already exists, is compatible with the specified
parameters in the CreateVolumeGroupRequest, the Plugin MUST reply 0 OK with the corresponding CreateVolumeGroupResponse.
CSI Plugins MAY create the following types of volume groups:

Create a new empty volume group or a group with specific volumes. Note that N volumes with some backend label Y could be considered to be in "group Y"
which might not be a physical group on the storage backend. In this case, an empty group can still be created by the CO
to hold volumes. After the empty group is created, create a new volume. CO may call ModifyVolumeGroupMembership to add new volumes to the group.

At restore time, create a single volume from individual snapshot and then join an existing group. Create an empty group.
Create a volume from snapshot.

Future goals:
Create a new volume group from a source group snapshot. Create a new volume group from a source group. Create a new
volume group and add a list of existing volumes to the group.

```protobuf
// CreateVolumeGroupRequest holds the required information to
// create a volume group
message CreateVolumeGroupRequest {
  // suggested name for volume group (required for idempotency)
  // This field is REQUIRED.
  string name = 1;

  // params passed to the plugin to create the volume group.
  // This field is OPTIONAL.
  map<string, string> parameters = 2;

  // Secrets required by plugin to complete volume group creation
  // request.
  // This field is OPTIONAL. Refer to the `Secrets Requirements`
  // section on how to use this field.
  map<string, string> secrets = 3 [(csi.v1.csi_secret) = true];

  // Specify volume_ids that will be added to the volume group.
  // This field is OPTIONAL.
  repeated string volume_ids = 4;
}
// CreateVolumeGroupResponse holds the information to send when
// volumeGroup is successfully created.
message CreateVolumeGroupResponse {
  // Contains all attributes of the newly created volume group.
  // This field is REQUIRED.
  VolumeGroup volume_group = 1;
}
// Information about a specific volumeGroup.
message VolumeGroup {
  // The identifier for this volume group, generated by the plugin.
  // This field is REQUIRED.
  string volume_group_id = 1;

  // Opaque static properties of the volume group.
  // This field is OPTIONAL.
  map<string, string> volume_group_context = 2;

  // Underlying volumes in this group. The same definition in CSI
  // Volume.
  // This field is OPTIONAL.
  // To support the creation of an empty group, this list can be empty.
  // However, this field is not empty in the following cases:
  // - Response from ListVolumeGroups or ControllerGetVolumeGroup if the
  //   VolumeGroup is not empty.
  // - Response from ModifyVolumeGroupMembership if the
  //   VolumeGroup is not empty after modification.
  repeated csi.v1.Volume volumes = 3;
}
```

##### CreateVolumeGroup Errors

If the plugin is unable to complete the CreateVolumeGroup call successfully, it MUST return a non-ok gRPC code in the
gRPC status. If the conditions defined below are encountered, the plugin MUST return the specified gRPC error code. The
CO MUST implement the specified error recovery behavior when it encounters the gRPC error code.

| Condition                                       | gRPC Code          | Description                                                                                                                                                                                                | Recovery Behavior                                                        |
| ----------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Not supported                                   | 3 INVALID_ARGUMENT | Indicates that a new volume group can not be provisioned with the specified parameters because it is not supported. More human-readable information SHOULD be provided in the gRPC `status.message` field. | Caller MUST use different parameters.                                    |
| Volume group already exists but is incompatible | 6 ALREADY_EXISTS   | Indicates that a volume group corresponding to the specified volume group `name` already exists but is incompatible with the specified `parameters`.                                                       | Caller MUST fix the arguments or use a different `name` before retrying. |
| Volumes cannot be grouped together | 7 FAILED_PRECONDITION   | Indicates that a volumes cannot be grouped together because volumes are not configured properly based on requirements from the SP.                                                       | Caller MUST fix the configuration of the volumes so that they meet the requirements for grouping before retrying. |

#### `DeleteVolumeGroup`

A Controller Plugin MUST implement this RPC call if it has `VOLUME_GROUP` capability.

This RPC will be called by the CO to delete a volume group on behalf of a user. This operation MUST be idempotent.

If a volume group corresponding to the specified `volume_group_id` does not exist or the artifacts associated with the
volume group do not exist anymore, the Plugin MUST reply `0 OK`.

A volume cannot be deleted individually when it is part of the group. It has to be removed from the group first. Delete
a volume group will delete all volumes in the group.

```protobuf
// DeleteVolumeGroupRequest holds the required information to
// delete a volume group
message DeleteVolumeGroupRequest {
  // The ID of the volume group to be deleted.
  // This field is REQUIRED.
  string volume_group_id = 1;

  // Secrets required by plugin to complete volume group
  // deletion request.
  // This field is OPTIONAL. Refer to the `Secrets Requirements`
  // section on how to use this field.
  map<string, string> secrets = 2 [(csi.v1.csi_secret) = true];
}
// DeleteVolumeGroupResponse holds the information to send when
// volumeGroup is successfully deleted.
message DeleteVolumeGroupResponse {
}
```

##### DeleteVolumeGroup Errors

If the plugin is unable to complete the DeleteVolumeGroup call successfully, it MUST return a non-ok gRPC code in the
gRPC status. If the conditions defined below are encountered, the plugin MUST return the specified gRPC error code. The
CO MUST implement the specified error recovery behavior when it encounters the gRPC error code.

| Condition           | gRPC Code             | Description                                                                                                                                                                                                                | Recovery Behavior                                                                                                                                     |
| ------------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Volume group in use | 9 FAILED_PRECONDITION | Indicates that the volume group corresponding to the specified `volume_group_id` could not be deleted because it is in use by another resource or has snapshots and the plugin doesn't treat them as independent entities. | Caller SHOULD ensure that there are no other resources using the volume group and that it has no snapshots, and then retry with exponential back off. |

#### `ModifyVolumeGroupMembership`

This RPC will be called by the CO to modify an existing volume group on behalf of a user. volume_ids provided in the
ModifyVolumeGroupMembershipRequest will be compared to the ones in the existing volume group. New volume_ids in the
modified volume group will be added to the volume group. Existing volume_ids not in the modified volume group will be
removed from the volume group. If volume_ids is empty, the volume group will be removed of all existing volumes. This
operation MUST be idempotent.

File-based storage systems usually do not support this PRC. Block-based storage systems usually support this PRC.

By adding an existing volume to a group, however, there is no way to pass in parameters to influence placement when
provisioning a volume.

It is out of the scope of the CSI spec to determine whether a group is consistent or not. It is up to the storage
provider to clarify that in the vendor specific documentation. This is true either when creating a new volume with a
group id or adding an existing volume to a group.

CSI drivers supporting MODIFY_VOLUME_GROUP MUST implement ModifyVolumeGroupMembership RPC.

```protobuf
// ModifyVolumeGroupMembershipRequest holds the required
// information to modify a volume group
message ModifyVolumeGroupMembershipRequest {
  // The ID of the volume group to be modified.
  // This field is REQUIRED.
  string volume_group_id = 1;

  // Specify volume_ids that will be in the modified volume group.
  // This list will be compared with the volume_ids in the existing
  // group.
  // New ones will be added and missing ones will be removed.
  // If no volume_ids are provided, all existing volumes will
  // be removed from the group.
  // This field is OPTIONAL.
  repeated string volume_ids = 2;

  // Secrets required by plugin to complete volume group
  // modification request.
  // This field is OPTIONAL. Refer to the `Secrets Requirements`
  // section on how to use this field.
  map<string, string> secrets = 3 [(csi.v1.csi_secret) = true];

  // parameters passed to the plugin to modify the volume group
  // or to modify the volumes in the group.
  // This field is OPTIONAL.
  map<string, string> parameters = 4;
}
// ModifyVolumeGroupMembershipResponse holds the information to
// send when volumeGroup is successfully modified.
message ModifyVolumeGroupMembershipResponse {
  // Contains all attributes of the modified volume group.
  // This field is REQUIRED.
  VolumeGroup volume_group = 1;
}
```

##### ModifyVolumeGroupMembership Errors

If the plugin is unable to complete the ModifyVolumeGroupMembership call successfully, it MUST return a non-ok gRPC code
in the gRPC status. If the conditions defined below are encountered, the plugin MUST return the specified gRPC error
code. The CO MUST implement the specified error recovery behavior when it encounters the gRPC error code.

| Condition                                            | gRPC Code            | Description                                                                                                                                                                                                                                                                                                                | Recovery Behavior                                                                                                                                    |
| ---------------------------------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Volumes incompatible or not supported                | 3 INVALID_ARGUMENT   | Besides the general cases, this code MUST also be used to indicate when plugin supporting MODIFY_VOLUME_GROUP cannot modify a volume group because a volume to be added is incompatible with other volumes in the group. More human-readable information SHOULD be provided in the gRPC `status.message` field. | On volumes incompatibility related issues, caller MUST use different volume ids as the input parameter.                                              |
| Volume id or volume group does not exist             | 5 NOT_FOUND          | Indicates that one of the specified volume ids or the volume group itself does not exist.                                                                                                                                                                                                                                  | Caller MUST verify that the `volume_ids` is correct and the volume group exists, and has not been deleted before retrying with exponential back off. |
| Unable to add volumes because the maximum is reached | 8 RESOURCE_EXHAUSTED | Indicates that group can not add more volumes because the maximum limit is reached. More human-readable information MAY be provided in the gRPC `status.message` field.                                                                                                                                                    | Caller MUST ensure that whatever is preventing volume group from being modified is addressed before retrying with exponential backoff.               |

#### `ControllerGetVolumeGroup`

This optional RPC MAY be called by the CO to fetch current information about a volume group.

A Controller Plugin MUST implement this `ControllerGetVolumeGroup` RPC call if it has `GET_VOLUME_GROUP` capability.

`ControllerGetVolumeGroupResponse` should contain current information of a volume group if it exists. If the volume
group does not exist any more, `ControllerGetVolumeGroup` should return gRPC error code `NOT_FOUND`.

```protobuf
// ControllerGetVolumeGroupRequest holds the required
// information to get information on volume group
message ControllerGetVolumeGroupRequest {
  // The ID of the volume group to fetch current volume group
  // information for.
  // This field is REQUIRED.
  string volume_group_id = 1;

  // Secrets required by plugin to complete ControllerGetVolumeGroup
  // request.
  // This field is OPTIONAL. Refer to the `Secrets Requirements`
  // section on how to use this field.
  map<string, string> secrets = 2 [(csi.v1.csi_secret) = true];
}
// ControllerGetVolumeGroupResponse holds the information to
// send when volumeGroup information was successfully gathered.
message ControllerGetVolumeGroupResponse {
  // This field is REQUIRED
  VolumeGroup volume_group = 1;
}
```

##### ControllerGetVolumeGroup Errors

If the plugin is unable to complete the ControllerGetVolumeGroup call successfully, it MUST return a non-ok gRPC code in
the gRPC status. If the conditions defined below are encountered, the plugin MUST return the specified gRPC error code.
The CO MUST implement the specified error recovery behavior when it encounters the gRPC error code.

| Condition                   | gRPC Code   | Description                                                                                    | Recovery Behavior                                                                                                                                                    |
| --------------------------- | ----------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Volume group does not exist | 5 NOT_FOUND | Indicates that a volume group corresponding to the specified `volume_group_id` does not exist. | Caller MUST verify that the `volume_group_id` is correct and that the volume group is accessible and has not been deleted before retrying with exponential back off. |

#### `ListVolumeGroups`

A Controller Plugin MUST implement this RPC call if it has `LIST_VOLUME_GROUPS` capability. The Plugin SHALL return the
information about all the volume groups that it knows about. If volume groups are created and/or deleted while the CO is
concurrently paging through `ListVolumeGroups` results then it is possible that the CO MAY either witness duplicate
volume groups in the list, not witness existing volume groups, or both. The CO SHALL NOT expect a consistent "view" of
all volume groups when paging through the volume group list via multiple calls to `ListVolumeGroups`.

```protobuf
// ListVolumeGroupsRequest holds the required
// information to get information on list of volume groups.
message ListVolumeGroupsRequest {
  // If specified (non-zero value), the Plugin MUST NOT return more
  // entries than this number in the response. If the actual number of
  // entries is more than this number, the Plugin MUST set `next_token`
  // in the response which can be used to get the next page of entries
  // in the subsequent `ListVolumeGroups` call. This field is OPTIONAL.
  // If not specified (zero value), it means there is no restriction on
  // the number of entries that can be returned.
  // The value of this field MUST NOT be negative.
  int32 max_entries = 1;

  // A token to specify where to start paginating. Set this field to
  // `next_token` returned by a previous `ListVolumeGroups` call to get
  // the next page of entries. This field is OPTIONAL.
  // An empty string is equal to an unspecified field value.
  string starting_token = 2;

  // Secrets required by plugin to complete ListVolumeGroup request.
  // This field is OPTIONAL. Refer to the `Secrets Requirements`
  // section on how to use this field.
  map<string, string> secrets = 3 [(csi.v1.csi_secret) = true];
}
// ListVolumeGroupsResponse holds the information to
// send when list of volumeGroups information was successfully gathered.
message ListVolumeGroupsResponse {
  // Represents each volume group.
  message Entry {
    // This field is REQUIRED
    VolumeGroup volume_group = 1;
  }
  // Represents each volume group entry
  repeated Entry entries = 1;

  // This token allows you to get the next page of entries for
  // `ListVolumeGroups` request. If the number of entries is larger than
  // `max_entries`, use the `next_token` as a value for the
  // `starting_token` field in the next `ListVolumeGroups` request. This
  // field is OPTIONAL.
  // An empty string is equal to an unspecified field value.
  string next_token = 2;
}
```

##### ListVolumeGroups Errors

If the plugin is unable to complete the ListVolumeGroups call successfully, it MUST return a non-ok gRPC code in the
gRPC status. If the conditions defined below are encountered, the plugin MUST return the specified gRPC error code. The
CO MUST implement the specified error recovery behavior when it encounters the gRPC error code.

| Condition                | gRPC Code  | Description                                   | Recovery Behavior                                                                          |
| ------------------------ | ---------- | --------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Invalid `starting_token` | 10 ABORTED | Indicates that `starting_token` is not valid. | Caller SHOULD start the `ListVolumeGroups` operation again with an empty `starting_token`. |
