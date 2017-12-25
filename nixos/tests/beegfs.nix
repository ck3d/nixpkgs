import ./make-test.nix ({ pkgs, ... } :

let
  client = { config, pkgs, lib, ... } : {
      networking.firewall.enable = false;
      services.beegfsEnable = true;
      services.beegfs.default = {
        mgmtHost = "mgmt";
        client.enable = true;
      };
    };

    
  server = service : { config, pkgs, lib, ... } : {
      networking.firewall.enable = false;
      boot.initrd.postDeviceCommands = ''
        ${pkgs.e2fsprogs}/bin/mkfs.ext4 -f -L aux /dev/vdb
      '';

      virtualisation.emptyDiskImages = [ 4096 ];

      fileSystems = pkgs.lib.mkVMOverride
        [ { mountPoint = "/data";
            device = "/dev/disk/by-label/aux";
            fstype = "ext4";
          }
        ];

      environment.systemPackages = with pkgs; [ beegfs ];

      services.beegfsEnable = true;
      services.beegfs.default."${service}" = {
        enable = true;
        storeDir = "/data";
      };
    };
   
in
{
  name = "beegfs";
  
  nodes = {
#admon = admon;
    meta = server "meta";
    mgmt = server "mgmt";
    storage = server "storage";
    client1 = client;
    client2 = client;
  };

  testScript = ''
    # Initalize the data directories
    $mgmt->waitForUnit("default.target");
    $mgmt->succeed("beegfs-setup-mgmtd -C -p /data");
    $mgmt->succeed("systemctl start beegfs-mgmtd-default");
    
    $mgmt->waitForUnit("default.target");
    $mgmt->succeed("beegfs-setup-meta -C -s 1 -p /data");
    $mgmt->succeed("systemctl start beegfs-meta-default");
    
    $storage->waitForUnit("default.target");
    $storage->succeed("beegfs-setup-storage -C -s 1 -i 1 -p /data");
    $storage->succeed("systemctl start beegfs-storage-default");

    startAll;

    $client1->waitForUnit("beegfs.mount");
    $client1->succeed("echo test > /beegfs/test");
    $client2->waitForUnit("beegfs.mount");
    $client2->succeed("test -e /beegfs/test");
  '';
})
    
