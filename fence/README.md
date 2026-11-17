# Network Fencing

## Notational Conventions

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" are to be
interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119).

## Terminology

| Term     | Definition                                                                            |
| -------- | ------------------------------------------------------------------------------------- |
| CO       | Container Orchestration system that communicates with plugins using CSI service RPCs. |
| SP       | Storage Provider, the vendor of a CSI plugin implementation.                          |
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

## Architecture

A user instructs the CSI-Addons CO plugin to fence or unfence a set of clients.
The CO plugin inspects the capabilities advertised by the CSI-driver (see the
[Identity](../identity/README.md) `NetworkFence` capability) and relays the
request as a gRPC call to the CSI-driver. Because fencing is network based, the
operation is served by the CSI Controller.

## Error Handling

All RPCs defined in this specification return a standard
[gRPC status](https://github.com/grpc/grpc/blob/master/src/proto/grpc/status/status.proto).
The status `code` MUST be a
[canonical gRPC error code](https://github.com/grpc/grpc-go/blob/master/codes/codes.go);
the CO MUST handle all valid error codes. When the `code` is not `OK`, the status
`message` MUST contain a human-readable description of the error, which MAY be
surfaced by the CO to end users. The status `details` MUST be empty.

Each RPC below documents, in its Errors table, the gRPC codes the CSI-driver
returns for the listed conditions and the recovery behavior the caller is
expected to implement.

The following error codes are common to all RPCs in this specification. In
addition to the conditions below, each RPC MAY define further codes in its own
Errors section.

| Condition | gRPC Code | Description | Recovery Behavior |
| --------- | --------- | ----------- | ----------------- |
| Missing required field | 3 INVALID_ARGUMENT | Indicates that a required field is missing from the request. | Caller MUST fix the request by adding the missing required field before retrying. |
| Invalid or unsupported field in the request | 3 INVALID_ARGUMENT | Indicates that one or more fields in the request is either not allowed by the CSI-driver or has an invalid value. | Caller MUST fix the field before retrying. |
| Operation pending | 10 ABORTED | Indicates that there is already an operation pending for the specified resource. The CSI-driver SHOULD handle this as gracefully as possible, and MAY return this error code to reject secondary calls. | Caller SHOULD ensure that there are no other calls pending for the specified resource, and then retry with exponential back off. |
| Call not implemented | 12 UNIMPLEMENTED | The invoked RPC is not implemented by the CSI-driver or disabled in its current mode of operation. | Caller MUST NOT retry. |
| Not authenticated | 16 UNAUTHENTICATED | The invoked RPC does not carry secrets that are valid for authentication. | Caller SHALL either fix the secrets provided in the RPC, or otherwise regalvanize said secrets such that they pass authentication by the CSI-driver for the attempted RPC, after which point the caller MAY retry the attempted RPC. |
| Error is Unknown | 2 UNKNOWN | Indicates that an unknown error occurred. | Caller MUST study the logs before retrying. |

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

  // GetFenceClients RPC calls to get the client information to use in a
  // FenceClusterNetwork or UnfenceClusterNetwork RPC.
  rpc GetFenceClients(GetFenceClientsRequest)
  returns (GetFenceClientsResponse){}
}
```

### FenceClusterNetwork

The Controller plugin MUST implement this RPC call if it has the `NETWORK_FENCE`
capability. This RPC is called by the CO to block access to the storage cluster
for the clients identified by the provided list of CIDR blocks. This operation
MUST be idempotent: fencing a client that is already fenced MUST succeed and
reply `0 OK`. The operation affects only the clients identified by the provided
CIDR blocks; clients that were already fenced remain fenced. If the operation
fails, or the CO does not know whether it succeeded, it MAY call
`FenceClusterNetwork` again.

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

#### FenceClusterNetwork Errors

If the CSI-driver is unable to complete the FenceClusterNetwork call successfully, it MUST
return a non-ok gRPC code in the gRPC status. This RPC defines no error codes
beyond those common to all RPCs; see the [Error Handling](#error-handling)
section.

### UnfenceClusterNetwork

The Controller plugin MUST implement this RPC call if it has the `NETWORK_FENCE`
capability. This RPC is called by the CO to remove the provided list of CIDR
blocks from the set of fenced/blocklisted clients, restoring their access to the
storage cluster. This operation MUST be idempotent: unfencing a client that is
not currently fenced MUST succeed and reply `0 OK`. The operation restores access
only for the clients identified by the provided CIDR blocks; clients not in the
list are unaffected.

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

#### UnfenceClusterNetwork Errors

If the CSI-driver is unable to complete the UnfenceClusterNetwork call successfully, it MUST
return a non-ok gRPC code in the gRPC status. This RPC defines no error codes
beyond those common to all RPCs; see the [Error Handling](#error-handling)
section.

### ListClusterFence

The Controller plugin MUST implement this RPC call if it has the `NETWORK_FENCE`
capability. This RPC is called by the CO to retrieve the list of CIDR blocks
that are currently fenced/blocklisted by the CSI-driver. This is a read-only
operation. The response contains the CIDR blocks currently fenced by the
CSI-driver, and is empty when no client is fenced.

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

#### ListClusterFence Errors

If the CSI-driver is unable to complete the ListClusterFence call successfully, it MUST
return a non-ok gRPC code in the gRPC status. This RPC defines no error codes
beyond those common to all RPCs; see the [Error Handling](#error-handling)
section.

### CIDR blocks

```protobuf
// CIDR holds a CIDR block.
message CIDR {
  // CIDR block
  string cidr = 1;
}
```

### GetFenceClients

The Controller plugin MUST implement this RPC call if it has the
`GET_CLIENTS_TO_FENCE` capability. This RPC is called by the CO to discover the
clients, along with their addresses, that need to be fenced. The returned
`ClientDetails` can then be used to build the list of CIDR blocks passed to a
subsequent `FenceClusterNetwork` or `UnfenceClusterNetwork` call. This is a
read-only operation.

```protobuf
// GetFenceClientsRequest contains the necessary information to identify
// the clients that need fencing.
message GetFenceClientsRequest {
  // Plugin-specific parameters passed in as opaque key-value pairs.
  map<string, string> parameters = 1;
  // Secrets required by the plugin to complete the request.
  map<string, string> secrets = 2 [(csi.v1.csi_secret) = true];
}

// GetFenceClientsResponse holds the information about clients that require
// fencing.
message GetFenceClientsResponse {
  // List of clients that need to be fenced.
  repeated ClientDetails clients = 1;
}
```

### ClientDetails

`ClientDetails` describes a single client returned by `GetFenceClients`. It
carries the client's unique identifier and the list of addresses (as CIDR
blocks) used to fence or unfence that client.

```protobuf
// ClientDetails holds the information about the client that requires fencing.
message ClientDetails {
  // id represents the unique identifier of the client.
  // Required field.
  string id = 1;
  // list of IP addresses that represent the client's local addresses.
  // Required field.
  repeated CIDR addresses = 2;
}
```

#### GetFenceClients Errors

If the CSI-driver is unable to complete the GetFenceClients call successfully, it MUST
return a non-ok gRPC code in the gRPC status. This RPC defines no error codes
beyond those common to all RPCs; see the [Error Handling](#error-handling)
section.
