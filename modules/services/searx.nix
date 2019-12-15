{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption;
  T = lib.types;
  cfgDev = config.services.searx;
  cfgUwsgi = config.services.uwsgi.searx;

  searxOptions = description: {
      enable = mkEnableOption
        "The ${description}. See https://github.com/asciimoo/searx";

      configFile = mkOption {
        type = T.nullOr T.path;
        default = null;
        description = ''
          The path of the configuration file. If no file is specified, a default
          file is used (default config file has debug mode enabled).
        '';
      };

      package = mkOption {
        type = T.package;
        default = pkgs.searx;
        defaultText = "pkgs.searx";
        description = "The searx package to use.";
      };
    };
in {
  options = {
    services.searx = searxOptions "searX development server";
    services.uwsgi.searx = searxOptions "searX uwsgi server" // {
      listenAt = mkOption {
        type = T.attrsOf T.str;
        description = ''
          The socket or http port to listen to.
          Format: { <type> = <value>; }
          Possible types: See https://uwsgi.readthedocs.io/en/latest/Options.html.
        '';
        default = { http = "0.0.0.0:8888"; };
        example = { socket = "/tmp/searx.sock"; };
      };
      settings = mkOption {
        type = T.attrs;
	default = {};
      };
    };
  };

  config = {
    services.supervisord.services.searx = mkIf cfgDev.enable {
      command = "${cfgDev.package}/bin/searx-run";
      settings.environment = mkIf (cfgDev.configFile != null) {
        SEARX_SETTINGS_PATH = "${cfgDev.configFile}";
      };
    };
    services.uwsgi = mkIf cfgUwsgi.enable (
      config.lib.uwsgi.mkVassal "searx" cfgUwsgi (cfg:
        {
          pythonPackages = p: [ (p.toPythonModule cfg.package) ];
          plugins = [ "python3" ];
          single-interpreter = true;
          master = true;
          lazy-apps = true;
          enable-threads = true;
          module = "searx.webapp";
          env = [ "SEARX_SETTINGS_PATH=${cfgUwsgi.configFile}" ];

          workers = 10;
          disable-logging = true;
        }
        // cfg.listenAt
        // cfg.settings
      )
    );
  };
}
