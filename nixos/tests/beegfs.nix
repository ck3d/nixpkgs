import ./make-test.nix ({ pkgs, ... } :

let
  client = { config, pkgs, lib, ... } : {
      networking.firewall.enable = false;
      services.beegfsEnable = true;
      services.beegfs.default = {
        mgmtdHost = "mgmt";
        client = {
          mount = false; 
          enable = true;
        };
      };
      
      fileSystems = pkgs.lib.mkVMOverride # FIXME: this should be creatd by the module
        [ { mountPoint = "/beegfs";
            device = "default";
            fsType = "beegfs";
            options = [ "cfgFile=/etc/beegfs/beegfs-client-default.conf" "_netdev" ];
          }
        ];
    };

    
  server = service : { config, pkgs, lib, ... } : {
      networking.firewall.enable = false;
      boot.initrd.postDeviceCommands = ''
        ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L data /dev/vdb
      '';

      virtualisation.emptyDiskImages = [ 4096 ];

      fileSystems = pkgs.lib.mkVMOverride
        [ { mountPoint = "/data";
            device = "/dev/disk/by-label/data";
            fsType = "ext4";
          }
        ];

      environment.systemPackages = with pkgs; [ beegfs ];

      services.beegfsEnable = true;
      services.beegfs.default = {
        mgmtdHost = "mgmt";
        "${service}" = {
          enable = true;
          storeDir = "/data";
        };  
      };
    };
   
in
{
  name = "beegfs";
  
  nodes = {
#admon = admon;
    meta = server "meta";
    mgmt = server "mgmtd";
    storage = server "storage";
    client1 = client;
    client2 = client;
  };

  testScript = ''
    # Initalize the data directories
    $mgmt->waitForUnit("default.target");
    $mgmt->succeed("beegfs-setup-mgmtd -C -f -p /data");
    $mgmt->succeed("systemctl start beegfs-mgmtd-default");
    
    $meta->waitForUnit("default.target");
    $meta->succeed("beegfs-setup-meta -C -f -s 1 -p /data");
    $meta->succeed("systemctl start beegfs-meta-default");
    
    $storage->waitForUnit("default.target");
    $storage->succeed("beegfs-setup-storage -C -f -s 1 -i 1 -p /data");
    $storage->succeed("systemctl start beegfs-storage-default");

    $client1->waitForUnit("beegfs.mount");
    $client1->succeed("echo test > /beegfs/test");
    $client2->waitForUnit("beegfs.mount");
    $client2->succeed("test -e /beegfs/test");
    $client2->succeed("cat /beegfs/test | grep test");
  '';
})
    
