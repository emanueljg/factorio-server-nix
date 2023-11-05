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
      type = types.string;
      default = "/var/lib/factorio-server";
    };

    user = mkOption {
      type = types.str;
      default = "factorio-server";
      description = lib.mdDoc ''
        User account under which factorio-server runs.
      '';
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

    extraConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };

  };

  config = let

    defaultGameConfig = writeTextFile {
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

    serverSettings = writeTextFile {
      name = "factorio-server-server-settings.json";
      text = builtins.toJSON
        (recursiveUpdate defaultServerSettings cfg.extraConfig);    
    };

    baseServerCmd = concatStringsSep " " [
      (lib.getExe cfg.package)
      (toGNUCommandLineShell {} {
        config = defaultGameConfig;
        server-settings = serverSettings;
      })
    ];        

    mapCreationCmd = let
      args = { create = true; } // cfg.mapCreationArgs;
    in concatStringsSep " " [
      baseServerCmd
      (toGNUCommandLineShell {} args)
      "${cfg.dataDir}/map.zip"
    ];

    serverStartCmd = concatStringsSep " " [
      baseServerCmd
      "--start-server"
    ];
  
  in mkIf cfg.enable {

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
  
    systemd.services.factorio-server = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      path = [ cfg.package cfg.bash ];
      
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Type = "simple";
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = ''
          ${getExe bash} -c "if ! test -e ${dataDir}/map.zip; then ${mapCreationCmd}; fi"
        '';
        ExecStart = serverStartCmd;
      };

    };
  };
}