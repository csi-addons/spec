# Network Fencing

## Terminology

| Term     | Definition                                                                            |
| -------- | ------------------------------------------------------------------------------------- |
| CO       | Container Orchestration system that communicates with plugins using CSI service RPCs. |
| SP       | Storage Provider, the vendor of a CSI plugin implementation.                          |
| DR       | Disaster Recovery.                                                                    |
| RPC      | [Remote Procedure Call](https://en.wikipedia.org/wiki/Remote_procedure_call).         |

## Objective

Define a standard that will enable storage providers (SP) to
perform node level fencing using corresponding CIDR blocks.

### Goals in MVP

The new extension will define a procedure that allows SP to block
access to any client using corresponding CIDR blocks, and unblock
as per the requirement.

If multiple COs are accessing a shared resource provided by the SP, and a node
failure takes place, this procedure will allow the SP to block access from any
node of CO, and thus preventing further access and corruption of data.

### Non-Goals in MVP

* Application level fencing, i.e blocklisting by maintaining a list of applications
  that are to be denied access.

## Solution Overview

This specification defines an interface along with the minimum operational and
packaging recommendations for a storage provider (SP) to implement fencing operation.
The interface declares the RPCs that a plugin MUST expose.

Since the fencing is network based, the fencing mechanism will be most aptly implemented
by the CSI Controller.

## RPC Interface

* **FenceController Service**: The Controller plugin MUST implement these sets of
  RPCs.

```protobuf
syntax = "proto3";
package fence;

import "github.com/container-storage-interface/spec/lib/go/csi/csi.proto";
import "google/protobuf/descriptor.proto";

option go_package = "github.com/csi-addons/spec/lib/go/fence";

// FenceController holds the RPC method for performing fencing operations.
service FenceController {
  // FenceClusterNetwork RPC call to perform a fencing operation.
  rpc FenceClusterNetwork (FenceClusterNetworkRequest)
  returns (FenceClusterNetworkResponse) {}

  // UnfenceClusterNetwork RPC call to remove a list of CIDR blocks from the
  // list of blocklisted/fenced clients.
  rpc UnfenceClusterNetwork (UnfenceClusterNetworkRequest)
  returns (UnfenceClusterNetworkResponse) {}

  // ListClusterFence RPC call to provide a list of blocklisted/fenced clients.
  rpc ListClusterFence(ListClusterFenceRequest)
  returns (ListClusterFenceResponse){}
}
```

### FenceClusterNetwork

```protobuf
// FenceClusterNetworkRequest contains the information needed to identify
// the storage cluster so that the appropriate fencing operation can be
// performed.
message FenceClusterNetworkRequest {
  // Plugin specific parameters passed in as opaque key-value pairs.
  map<string, string> parameters = 1;
  // Secrets required by the plugin to complete the request.
  map<string, string> secrets = 2 [(csi.v1.csi_secret) = true];
  // list of CIDR blocks on which the fencing operation is expected to be
  // performed.
  repeated CIDR cidrs = 3;
}

// FenceClusterNetworkResponse is returned by the CSI-driver as a result of
// the FenceClusterNetworkRequest call.
message FenceClusterNetworkResponse {
  // Intentionally empty.
}
```

### UnfenceClusterNetwork

```protobuf
// UnfenceClusterNetworkRequest contains the information needed to identify
// the cluster so that the appropriate fence operation can be
// disabled.
message UnfenceClusterNetworkRequest {
  // Plugin specific parameters passed in as opaque key-value pairs.
  map<string, string> parameters = 1;
  // Secrets required by the plugin to complete the request.
  map<string, string> secrets = 2 [(csi.v1.csi_secret) = true];
  // list of CIDR blocks on which the fencing operation is expected to be
  // performed.
  repeated CIDR cidrs = 3;
}

// UnfenceClusterNetworkResponse is returned by the CSI-driver as a result of
// the UnfenceClusterNetworkRequest call.
message UnfenceClusterNetworkResponse {
  // Intentionally empty.
}
```

### ListClusterFence

```protobuf
// ListClusterFenceRequest contains the information needed to identify
// the cluster so that the appropriate fenced clients can be listed.
message ListClusterFenceRequest {
  // Plugin specific parameters passed in as opaque key-value pairs.
  map<string, string> parameters = 1;
  // Secrets required by the plugin to complete the request.
  map<string, string> secrets = 2 [(csi.v1.csi_secret) = true];
}

// ListClusterFenceResponse holds the information about the result of the
// ListClusterFenceResponse call.
message ListClusterFenceResponse {
  // list of IPs that are blocklisted by the SP.
  repeated CIDR cidrs = 1;
}
```

### CIDR blocks

```protobuf
// CIDR holds a CIDR block.
message CIDR {
  // CIDR block
  string cidr = 1;
}
```

#### Error Scheme

| Condition                    | gRPC Code             | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Recovery Behavior                                                                                                                                                                                                                     |
| ---------------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Missing required field       | 3 INVALID_ARGUMENT    | Indicates that a required field is missing from the request.                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Caller MUST fix the request by adding the missing required field before retrying.                                                                                                                                                     |
| Invalid or unsupported field in the request | 3 INVALID_ARGUMENT | Indicates that the one or more fields in this field is either not allowed by the CSI-driver or has an invalid value. | Caller MUST fix the field before retrying. |                                                                                               |
| Call not implemented         | 12 UNIMPLEMENTED      | The invoked RPC is not implemented by the CSI-driver or disabled in the driver's current mode of operation.                                                                                                                                                                                                                                                                                                                                                                                                                                   | Caller MUST NOT retry.                                                                                                                                                                                                                |
| Not authenticated            | 16 UNAUTHENTICATED    | The invoked RPC does not carry secrets that are valid for authentication.                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Caller SHALL either fix the secrets provided in the RPC, or otherwise regalvanize said secrets such that they will pass authentication by the CSI-driver for the attempted RPC, after which point the caller MAY retry the attempted RPC. |
| Error is Unknown             | 2 UNKNOWN             | Indicates that a unknown error is generated                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Caller MUST study the logs before retrying                                                                                                                                                                                            |
