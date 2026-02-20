{ ... }:

{
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
      factor = "4";
    };
    ignoreIP = [
      "127.0.0.0/8"
      "::1"
    ];
  };
}
