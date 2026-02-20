{ ... }:

{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      8448  # Matrix federation
      7881  # LiveKit TCP fallback
    ];
    allowedUDPPorts = [
      443   # QUIC
    ];
    allowedUDPPortRanges = [
      { from = 50000; to = 50200; } # LiveKit WebRTC media
    ];
  };
}
