{ lib, pkgs, config, ... }:
with lib;                      
let
  cfg = config.services.factorio-server;
in {
  options.services.factorio-server = {

    enable = mkEnableOption "factorio server";

    package = mkOption {
      type = types.package;
      default = pkgs.factorio-headless;
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/factorio-server";
    };

    user = mkOption {
      type = types.str;
      default = "factorio-server";
      description = lib.mdDoc ''
        User account under which factorio-server runs.
      '';
    };

    socketUser = mkOption {
      type = types.str;
      default = cfg.user;
    };

    group = mkOption {
      type = types.str;
      default = "factorio-server";
      description = lib.mdDoc ''
        Group under which factorio-server runs.
      '';
    };

    mapCreationArgs = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };

    extraConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };

  };

  config = let

    defaultGameConfig = pkgs.writeTextFile {
       name = "factorio-server-config.ini";
       text = ''  
         [path]
         read-data=${cfg.package}/share/factorio/data/
         write-data=${cfg.dataDir}

         [other]
         check_updates=false
      '';
    };

    defaultServerSettings = 
      builtins.fromJSON
        (builtins.readFile ./default-server-settings.json);

    serverSettings = pkgs.writeTextFile {
      name = "factorio-server-server-settings.json";
      text = builtins.toJSON
        (recursiveUpdate defaultServerSettings cfg.extraConfig);    
    };

    mapPath = "${cfg.dataDir}/map.zip";

    baseServerCmd = concatStringsSep " " [
      "${cfg.package}/bin/factorio"
      (cli.toGNUCommandLineShell {} {
        config = defaultGameConfig;
        server-settings = serverSettings;
      })
    ];        

    mapCreationCmd = let
      args = { create = true; } // cfg.mapCreationArgs;
    in concatStringsSep " " [
      baseServerCmd
      (cli.toGNUCommandLineShell {} args)
      mapPath
    ];

    serverStartCmd = concatStringsSep " " [
      baseServerCmd
      (cli.toGNUCommandLineShell {} {
        start-server = mapPath;
      })
    ];
  
  in mkIf cfg.enable {

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ 34197 ];

    my.home.packages = let
      factorio-cmd = pkgs.writeShellScriptBin "factorio-cmd" ''
        echo $@ >> /tmp/factorio-server.stdin
      '';
    in [
      cfg.package
      factorio-cmd
    ];

    users.groups = mkIf (cfg.group == "factorio-server") {
      factorio-server = {};
    };

    users.users = mkIf (cfg.user == "factorio-server") {
      factorio-server = {
        group = cfg.group;
        shell = pkgs.bashInteractive;
        home = cfg.dataDir;
        description = "factorio-server Daemon user";
        isSystemUser = true;
      };
    };
  
    systemd = {
      sockets.factorio-server = {
        wantedBy = [ "sockets.target" ];
        socketConfig = {
          ListenFIFO = "/tmp/factorio-server.stdin";
          SocketUser = cfg.socketUser;
          SocketGroup = cfg.group;
          RemoveOnStop = true;
        };
      };
    
      services.factorio-server = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        path = [ cfg.package pkgs.bash ];

        # requisite = [ "factorio-server.socket" ];
      
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          Type = "simple";
          WorkingDirectory = cfg.dataDir;
          ExecStartPre = ''
            ${getExe pkgs.bash} -c "if ! test -e ${mapPath}; then ${mapCreationCmd}; fi"
          '';
          ExecStart = serverStartCmd;
          Sockets = "factorio-server.socket";
          StandardInput = "socket";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      tmpfiles.rules = [ "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} -" ];

    };
  };
}