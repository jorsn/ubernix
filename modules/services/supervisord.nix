{ config, lib, pkgs, ...}:


let
  cfg = config.services.supervisord;
  inherit (lib) filterAttrs flip mkEnableOption mkIf mkOption;
  gen = lib.generators;
  T = lib.types;

  toINI = {}: attrsOfAttrs: 
    flip gen.toINI (lib.filterAttrsRecursive (n: v: v != null) attrsOfAttrs) {
      mkKeyValue = flip gen.mkKeyValueDefault "=" {
        mkValueString = v:
               if v == true     then "yes"
          else if v == false    then "no"
          else if lib.isAttrs v then lib.concatStringsSep "," (lib.mapAttrsToList (n: v: "${n}=\"${v}\"") v)
          else gen.mkValueStringDefault {} v;
      };
    };

  mkEnvOption = context: { default ? null, ... }@args: mkOption (args // {
    inherit default;
    type = T.nullOr (T.attrsOf T.str);
    description = "environment variables for ${context}";
  });

  mkBoolOption = default: args: mkOption (args // { inherit default; type = T.bool; });
  mkBoolOption' = b: mkBoolOption b {};

  mkServerOption = name: default: mkOption {
    inherit default;
    type = T.str;
    description =
      "passthrough, see http://supervisord.org/configuration.html#supervisord-section-settings";
  };

  serverDefaults = {
    logfile="%(ENV_HOME)s/logs/supervisord-nix.log";
    logfile_maxbytes="20MB";
    logfile_backups="3";
    loglevel="debug";
    pidfile="/dev/null";
    childlogdir="%(ENV_HOME)s/tmp";
    directory="%(ENV_HOME)s";
    identifier="supervisor_%(ENV_USER)s";
    nodaemon="true";
    strip_ansi="true";
  };

  serverOptions = lib.mapAttrs mkServerOption serverDefaults // {
    environment = mkEnvOption "supervisord" {
      default = {
        PATH = "/home/%(ENV_USER)s/bin:/home/%(ENV_USER)s/.local/bin:/opt/uberspace/etc/%(ENV_USER)s/binpaths/ruby:%(ENV_PATH)s";
      };
    };
  };

  serviceModule = { name, ... }: {
    options = {
      command = mkOption {
        type = T.str;
        description = "command to start service '${name}'";
      };
      autostart   = mkBoolOption' true;
      autorestart = mkBoolOption' true;
      stopasgroup = mkBoolOption' true;
      killasgroup = mkBoolOption' true;
      settings = mkOption {
        type = T.attrs;
        description =
          "additional passthrough options, see http://supervisord.org/configuration.html";
        default = {};
        example = { stopsignal = "INT"; };
      };
    };
  };

  supervisorService = (m: m.config.supervisord-nix) (lib.evalModules {
    modules = [{
      options.supervisord-nix = mkOption {
        type = T.submodule serviceModule;
      };
      config.supervisord-nix.command = "nix-init supervisord --configuration=${configFile}";
    }];
  });

  serviceModuleConfig = module:
    module.settings
    // lib.filterAttrs (n: v: n != "_module" && n != "settings") module;

  configAttrs = {
    unix_http_server = {
      file = cfg.socket;
      username = "dummy";
      password = "dummy";
    };
    "rpcinterface:supervisor" = {
      "supervisor.rpcinterface_factory" = "supervisor.rpcinterface:make_main_rpcinterface";
    };
    supervisord = cfg.options; 
    include = { files = ''${config.xdg.configHome}/${servicesDir}/*.ini''; };
  };

  configFile = pkgs.writeText "supervisord.ini" (toINI {} configAttrs);

  supervisorctlBin = pkgs.writeShellScriptBin "supervisorctl-nix"
    ''exec supervisorctl --serverurl "unix://${cfg.socket}" "$@"'';

  serverConfigDir = "supervisord-nix";
  servicesDir = "${serverConfigDir}/services.d";
  serverServiceTarget = "${serverConfigDir}/supervisord-nix.ini.example";

in {
  options.services.supervisord = {
    enable = mkEnableOption ''
      manage nix services with supervisord

      For the supervisord managed by nix to be supervised by the supervisord
      for your uberspace, copy '${config.xdg.configHome}/${serverServiceTarget}'
      to '~/etc/services.d/supervisord-nix.ini'.
    '';

    socket = mkOption {
      type = T.str;
      description = "socket for the nix supervisord";
      default = "/run/supervisord/${config.home.username}/supervisor-nix.sock";
    };

    options = serverOptions;

    services = mkOption {
      type = T.attrsOf (T.submodule serviceModule);
      description = "A set of services";
      default = {};
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ supervisorctlBin ];
    xdg.configFile = {
      "${serverServiceTarget}" = {
        text =
          #''# copy this to ~/etc/services.d/supervisord-nix.ini 
          ''# This file is generated by home-manager/nix. Changes will be overwritten.
          '' + toINI {} {
            "program:supervisord-nix" = serviceModuleConfig supervisorService;
          };
        onChange =
          let
            target = "${config.home.homeDirectory}/etc/services.d/supervisord-nix.ini";
          in ''
            echo "supervisord-nix config has changed. Copying to ${target}..." >&2
            cp "${config.xdg.configHome}/${serverServiceTarget}" "${target}"
            echo "Updating services..." >&2
            supervisorctl reread
            supervisorctl update
            sleep 3s
            supervisorctl-nix reread
            supervisorctl-nix update
          '';
      };
    } // flip lib.mapAttrs' cfg.services (n: v: lib.nameValuePair "${servicesDir}/${n}.ini" {
      text = toINI {} { "program:${n}" = serviceModuleConfig v; };
      onChange = ''
        echo "Updating services..." >&2
        supervisorctl-nix reread
        supervisorctl-nix update
      '';
    });
  };
}
