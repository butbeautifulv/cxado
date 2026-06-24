"""Optional gRPC client for auth-broker (requires grpcio)."""

from __future__ import annotations

try:
    import grpc
except ImportError as exc:  # pragma: no cover
    raise ImportError("grpcio is required for cxado_auth_client.grpc_client") from exc


class AuthBrokerGRPCClient:
    """Placeholder for generated gRPC stubs."""

    def __init__(self, target: str, service_token: str, service_id: str = "default") -> None:
        self.target = target
        self.service_token = service_token
        self.service_id = service_id
        self._channel = grpc.insecure_channel(target)

    def close(self) -> None:
        self._channel.close()
