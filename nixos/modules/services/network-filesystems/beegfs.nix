{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.beegfs;

  # functions for the generations of config files
  
  configMgmtd = name: cfg: pkgs.writeText "mgmt-${name}.conf" ''
    storeMgmtdDirectory = ${cfg.mgmtd.storeDir}
    storeAllowFirstRunInit = false
    connAuthFile = ${cfg.connAuthFile}
    connPortShift = ${toString cfg.connPortShift}
    
    ${cfg.mgmtd.extraConfig}
  '';

  configAdmon = name: cfg: pkgs.writeText "admon-${name}.conf" ''
    sysMgmtdHost = ${cfg.mgmtdHost}
    connAuthFile = ${cfg.connAuthFile}
    connPortShift = ${toString cfg.connPortShift}
    
    ${cfg.admon.extraConfig}
  '';

  configMeta = name: cfg: pkgs.writeText "meta-${name}.conf" ''
    storeMetaDirectory = ${cfg.meta.storeDir}
    sysMgmtdHost = ${cfg.mgmtdHost}
    connAuthFile = ${cfg.connAuthFile}
    connPortShift = ${toString cfg.connPortShift}
    storeAllowFirstRunInit = false

    ${cfg.mgmtd.extraConfig}
  '';

  configStorage = name: cfg: pkgs.writeText "storage-${name}.conf" ''
    storeStorageDirectory = ${cfg.storage.storeDir}
    sysMgmtdHost = ${cfg.mgmtdHost}
    connAuthFile = ${cfg.connAuthFile}
    connPortShift = ${toString cfg.connPortShift}
    storeAllowFirstRunInit = false

    ${cfg.storage.extraConfig}
  '';

  configHelperd = name: cfg: pkgs.writeText "helperd-${name}.conf" ''
    connAuthFile = ${cfg.connAuthFile}
    ${cfg.helperd.extraConfig}
  '';

  configClientFilename = name : "/etc/beegfs/client-${name}.conf";

  configClient = name: cfg: ''
    sysMgmtdHost = ${cfg.mgmtdHost}
    connAuthFile = ${cfg.connAuthFile}
    connPortShift = ${toString cfg.connPortShift}
    
    ${cfg.client.extraConfig}
  '';

  serviceList = [
    { service = "admon"; cfgFile = configAdmon; }
    { service = "meta"; cfgFile = configMeta; }
    { service = "mgmtd"; cfgFile = configMgmtd; }
    { service = "storage"; cfgFile = configStorage; }
  ];

  # functions to generate systemd.service entries

  systemdEntry = service: cfgFile: (mapAttrs' ( name: cfg:
    (nameValuePair "beegfs-${service}-${name}" (mkIf cfg."${service}".enable {
    path = with pkgs; [ beegfs ]; # does beegfs-service need beegfs in PATH?
    wantedBy = [ "multi-user.target" ];
    requires = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple"; # I think not needed, because it is the default
      ExecStart = ''
        ${pkgs.beegfs}/bin/beegfs-${service} \
          cfgFile=${cfgFile name cfg} \
          pidFile=/run/beegfs-${service}-${name}.pid # you can say pidFile=${PIDfile} (but needs rec)
      '';
      PIDFile = "/run/beegfs-${service}-${name}.pid"; 
      TimeoutStopSec = "300";
    };
  }))) cfg);

  systemdHelperd =  mapAttrs' ( name: cfg:
    (nameValuePair "beegfs-helperd-${name}" (mkIf cfg.client.enable {
    path = with pkgs; [ beegfs ]; # does beegfs-helperd need beegfs in PATH?
    wantedBy = [ "multi-user.target" ];
    requires = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple"; # I think not needed, because it is the default
      ExecStart = ''
        ${pkgs.beegfs}/bin/beegfs-helperd \
          cfgFile=${configHelperd name cfg} \
          pidFile=/run/beegfs-helperd-${name}.pid # you can say pidFile=${PIDFile} (but needs rec)
      '';
      PIDFile = "/run/beegfs-helperd-${name}.pid"; 
      TimeoutStopSec = "300";
    };
   }))) cfg;

  utilWrappers = mapAttrsToList ( name: cfg:
      pkgs.stdenv.mkDerivation { # have a lock to runCommand
        name = "beegfs-utils-${name}";
        phases = [ "installPhase" ];
        buildInputs = [ pkgs.beegfs ]; # not needed
        installPhase = ''
          mkdir -p $out/bin

          echo "creating wrappers in $out"
          cat << EOF > $out/bin/beegfs-ctl-${name}
          #!${pkgs.stdenv.shell}
          ${pkgs.beegfs}/bin/beegfs-ctl --cfgFile=${configClientFilename name} \$@
          EOF
          chmod +x $out/bin/beegfs-ctl-${name}

          cat << EOF > $out/bin/beegfs-check-servers-${name}
          #!${pkgs.stdenv.shell}
          ${pkgs.beegfs}/bin/beegfs-check-servers -c ${configClientFilename name} \$@
          EOF
          chmod +x $out/bin/beegfs-check-servers-${name}

          cat << EOF > $out/bin/beegfs-df-${name}
          beegfs-ctl  --cfgFile=${configClientFilename name} \ # path to beegfs-ctl is missing
            --listtargets --hidenodeid --pools --spaceinfo \$@
          EOF
          chmod +x $out/bin/beegfs-df-${name}
        '';
    }) cfg;
in
{
  ###### interface 

  options = {
    services.beegfsEnable = mkEnableOption "BeeGFS";

    services.beegfs = mkOption {
      default = {};
      description = ''
        BeeGFS configurations. Every mount point requires a seperate configuration.
      '';
      type = with types; attrsOf (submodule ({ config, ... } : {
        options = {      
          mgmtdHost = mkOption { # modatory option?
            type = types.str;
            default = null; # null is not a string, you could extend type by nullable string or use empty string ""
            example = "master";
            description = ''Hostname of managament host'';  
          };
 
          connAuthFile = mkOption { # mandatory option?
            type = types.str; # there is a type path
            default = null; # same as above
            example = "/etc/my.key";
            description = "File containing shared secret authentication";  
          };
 
          connPortShift = mkOption {
            type = types.int;
            default = 0;
            example = 5;
            description = ''
              For each additional beegfs configuration shift all
              service TCP/UDP ports by at least 5. 
            '';
          };
 
          client = {
            enable = mkEnableOption "BeeGFS client";
            
            mount = mkOption { 
              type = types.bool;
              default = true;
              description = "Create fstab entry automatically";
            };
 
            mountPoint = mkOption {  # mandatory option?
              type = types.str; # there is a type called ath
              default = "/beegfs"; # I think /run/beegfs would be better, but never mind
              description = ''
                Mount point under which the beegfs filesytem should be mounted.
                If mounted manually the a mount option specifing the config file
                is needed:
                cfgFile=/etc/beegfs/beegfs-client-<name>.conf
              '';
            };
          
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = ''
                Additional lines for beegfs-client.conf.
                See documentation for further details.
             '';
            };
          };
 
          helperd = {
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = ''
                Additional lines for beegfs-helperd.conf. See documentation
                for further details.
              '';
            };
          };
 
          mgmtd = {
            enable = mkEnableOption "BeeGFS mgmtd daemon";
          
            storeDir = mkOption {
              type = types.str; # type path
              default = null; # madatory option?
              example = "/data/beegfs-mgmtd";
              description = ''
                Data directory for mgmtd.
                Must not be shared with other beegfs daemons.
                This directory must exist and it must be initialized
                with beegfs-setup-mgmtd, e.g. "beegfs-setup-mgmtd -C -p <storeDir>"
              '';
            };
            
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = ''
                Additional lines for beegfs-mgmtd.conf. See documentation
                for further details.
              '';
            };  
          };
 
          admon = {
            enable = mkEnableOption "BeeGFS admon daemon";
          
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = ''
                Additional lines for beegfs-admon.conf. See documentation
                for further details.
              '';
            };
          };    
 
          meta = {
            enable = mkEnableOption "BeeGFS meta data daemon";
          
            storeDir = mkOption {
              type = types.str;
              default = null;
              example = "/data/beegfs-meta";
              description = ''
                Data directory for meta data service.
                Must not be shared with other beegfs daemons.
                The underlying filesystem must be mounted with xattr turned on.
                This directory must exist and it must be initialized
                with beegfs-setup-meta, e.g.
                "beegfs-setup-meta -C -s <serviceID> -p <storeDir>"
              '';
            };
          
            extraConfig = mkOption {
              type = types.str;
              default = "";
              description = ''
                Additional lines for beegfs-meta.conf. See documentation
                for further details.
              '';
            };
          };
 
          storage = {
            enable = mkEnableOption "BeeGFS storage daemon";
          
            storeDir = mkOption { # same comments as above
              type = types.str;
              default = null;
              example = "/data/beegfs-storage";
              description = ''
                Data directories for storage service.
                Must not be shared with other beegfs daemons.
                The underlying filesystem must be mounted with xattr turned on.
                This directory must exist and it must be initialized
                with beegfs-setup-storage, e.g.
                "beegfs-setup-storage -C -s <serviceID> -i <storageTargetID> -p <storeDir>"
              '';
            };
          
            extraConfig = mkOption {
              type = types.str;
              default = "";
              description = ''
                Addional lines for beegfs-storage.conf. See documentation
                for further details.
              '';
            };
          };
        };
      }));
    };
  };    

  ###### implementation

  config = 
    mkIf config.services.beegfsEnable {

    environment.systemPackages = utilWrappers; # why is beegfs not included?

    # Put the client.conf files in /etc since they are needed
    # by the commandline need them 
    environment.etc = mapAttrs' ( name: cfg:
      (nameValuePair "beegfs/client-${name}.conf" (mkIf (cfg.client.enable)
    {
      enable = true;
      text = configClient name cfg;
    }))) cfg;

    # Kernel module, we need it only once per host.
    boot = mkIf (
      foldr (a: b: a || b) false 
        (map (x: x.client.enable) (collect (x: x ? client) cfg)))
    {
      kernelModules = [ "beegfs" ];
      extraModulePackages = [ pkgs.linuxPackages.beegfs-module ];
    };

    # generate fstab entries
    fileSystems = mapAttrs' (name: cfg:
      (nameValuePair cfg.client.mountPoint (if cfg.client.mount then (mkIf cfg.client.enable { # you can use optionalAttrs instead of if .. then .. else {}
      device = "beegfs_nodev";
      fsType = "beegfs";
      mountPoint = cfg.client.mountPoint;
      options = [ "cfgFile=${configClientFilename name}" "_netdev" ];
    }) else {}) )) cfg;

    # generate systemd services 
    systemd.services = systemdHelperd // 
      foldr (a: b: a // b) {} # I would exspect, there is already a helper function for it, but cool
        (map (x: systemdEntry x.service x.cfgFile) serviceList);
  };
}

