{ pkgs, ... }:

let
  elementConfig = {
    default_server_config = {
      "m.homeserver" = {
        base_url = "https://ohana-matrix.xyz";
        server_name = "ohana-matrix.xyz";
      };
    };
    brand = "Element";
    disable_custom_urls = false;
    disable_guests = true;
    disable_3pid_login = true;
    default_theme = "dark";
    room_directory = {
      servers = [ "ohana-matrix.xyz" ];
    };
    element_call = {
      url = "https://call.element.io";
      use_exclusively = false;
    };
  };

  element-web-ohana = pkgs.element-web.override {
    conf = elementConfig;
  };
in
{
  # Expose the package so caddy.nix can reference it
  nixpkgs.overlays = [
    (final: prev: {
      inherit element-web-ohana;
    })
  ];
}
