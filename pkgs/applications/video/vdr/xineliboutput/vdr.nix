{ config, lib, pkgs, ... }:
{
  hardware.pulseaudio.enable = true;
  #hardware.pulseaudio.systemWide = true;

  #hardware.pulseaudio.daemon.config = {
  #  high-priority = "yes";

    # currenct latency is 20ms; no setting could reduce it
  #  default-fragments = "3";
  #  default-fragment-size-msec = "10";
  #};

  security.sudo = {
    enable = true;
    configFile = ''
      vdr ALL=(root) NOPASSWD:${pkgs.utillinux}/bin/rtcwake
    '';
  };

  services = {
    lirc = {
      configs = [
        # (builtins.readFile ./lircd.conf)
      ];
      #extraArguments = [ "--loglevel=debug" ];
      options = ''
        [lircd]
      '';
    };

    vdr = let
      shutdown = pkgs.writeScript "vdr-shutdown" ''
        #!${pkgs.stdenv.shell} -eu
        next="$2"
        if [ "$next" -eq 0 ]; then # no timer
          next=86400 # one day
        elif [ "$next" -lt 0 ]; then # recording is running
          next=60 # one minute
        fi
        /run/wrappers/bin/sudo ${pkgs.utillinux}/bin/rtcwake -m off -s "$next"
      '';
    in {
      enable = true; 

      package = pkgs.wrapVdr.override {
        plugins = with pkgs.vdrPlugins; [
          epgsearch
          markad
          pkgs.vdr-xinelibout
        ];
      };

      extraArguments = [
        "--log=3"
        "-Pxineliboutput -l sxfe --truecolor"
        "-Pepgsearch"
        "-Pmarkad"
        "--shutdown=${shutdown}"
      ];
    };
  };
  
  systemd.services.vdr = {
    after = [ "pulseaudio.service" "display-manager.service" ];
    wants = [ "pulseaudio.service" ];
    bindsTo = [ "display-manager.service" ];
  };

  users.users.vdr.extraGroups = [ "audio" "video" ];
}
