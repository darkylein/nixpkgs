{
  config,
  lib,
  pkgs,
  ...
}:
let
  # TODO: Add missing options
  cfg = config.services.lact;
in
{
  options.services.lact = {
    enable = lib.mkEnableOption "LACT Linux GPU Control Application";

    package = lib.mkPackageOption pkgs "LACT" { default = [ "lact" ]; };

    nice = lib.mkOption {
      default = -10;
      description = "Niceness of the LACT daemon.";
      example = 0;
      type = lib.types.ints.between (-20) 19;
    };

    amdgpuOverclock = {
      enable = lib.mkEnableOption "AMD GPU overclocking";
      ppfeaturemask = lib.mkOption {
        type = lib.types.str;
        default = "0xfffd7fff";
        example = "0xffffffff";
        description = ''
          Sets the `amdgpu.ppfeaturemask` kernel option. This is ONLY useful for AMD GPU's.
          In particular, it is used here to set the overdrive bit. Recommended is `0xfffd7fff` as it
          is less likely to cause flicker issues. Setting it to `0xffffffff` enables all features.
        '';
      };
    };

    settings =
      let
        gpusType = lib.mkOption {
          default = null;
          description = ''
            An attributes set of gpus. The attribute name is a GPU ID which is formed with a
            combination of a PCI device id, PCI subsystem id and PCI slot name to uniquely identify
            each GPU in the system, even if there are multiple of the same model.

            You can discover the id of your GPU by either:
            - Changing a setting in the UI, so it's written to the LACT config
            - Using `lact cli list-gpus`
          '';
          example = {
            gpus = {
              "1002:73EF-1043:05E3-0000:03:00.0" = {
                fan_control_enabled = true;
                fan_control_settings = {
                  curve = {
                    "39" = 0.0;
                    "40" = 0.3;
                    "45" = 0.34;
                    "50" = 0.42;
                    "55" = 0.54;
                    "60" = 0.7;
                    "65" = 0.9;
                    "70" = 1.0;
                  };
                  spindown_delay_ms = 5000;
                  change_threshold = 2;
                };
                voltage_offset = -70;
              };
            };
          };
          type = lib.types.nullOr (
            lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  fan_control_enabled = lib.mkOption {
                    default = false;
                    description = ''
                      Whether the daemon should touch fan control settings at all. Setting this to
                      `true` requires the `fan_control_settings` field to be present as well.
                    '';
                    example = true;
                    type = lib.types.bool;
                  };

                  fan_control_settings = lib.mkOption {
                    default = null;
                    description = "Configuration for advanced gpu fan control.";
                    type = lib.types.nullOr (
                      lib.types.submodule {
                        options = {
                          mode = lib.mkOption {
                            default = "curve";
                            description = "Fan control mode. Can be either `curve` or `static`.";
                            example = "static";
                            type = lib.types.enum [
                              "curve"
                              "static"
                            ];
                          };

                          static_speed = lib.mkOption {
                            default = 0.5;
                            description = ''
                              Static fan speed from 0 to 1. Used when `mode` is `static`.
                            '';
                            example = 1.0;
                            type = lib.types.numbers.between 0 1;
                          };

                          temperature_key = lib.mkOption {
                            default = "edge";
                            description = ''
                              The temperature sensor name to be used with a custom fan curve.
                              This can be used to base the fan curve off  the`junction` (hotspot)
                              temperature instead of the default overall ("edge") temperature.
                              Applicable on most Vega and newer AMD GPUs.
                            '';
                            example = "junction";
                            type = lib.types.enum [
                              "edge"
                              "junction"
                            ];
                          };

                          interval_ms = lib.mkOption {
                            default = 500;
                            description = ''
                              Interval in milliseconds for how often the GPU temperature should be
                              checked when adjusting the fan curve.
                            '';
                            example = 1000;
                            type = lib.types.ints.positive;
                          };

                          curve = lib.mkOption {
                            default = {
                              "40" = 0.2;
                              "50" = 0.35;
                              "60" = 0.5;
                              "70" = 0.75;
                              "80" = 1.0;
                            };
                            description = ''
                              Custom fan curve used with `mode` set to `curve`.
                              The format of the map is temperature to fan speed from 0 to 1.
                              Note: on RDNA3+ AMD GPUs this must have 5 entries.
                            '';
                            example = {
                              "40" = 0.2;
                              "50" = 0.35;
                              "60" = 0.5;
                              "70" = 0.75;
                              "80" = 1.0;
                            };
                            type = lib.types.attrsOf lib.types.numbers.nonnegative;
                          };

                          spindown_delay_ms = lib.mkOption {
                            default = 0;
                            description = ''
                              Hysteresis setting: when spinning down fans after a temperature drop,
                              the target speed needs to be lower for at least this many
                              milliseconds for the fan to actually slow down.
                              This lets you avoid fan speed jumping around during short drops of
                              load (e.g. loading screen in a game).
                            '';
                            example = 5000;
                            type = lib.types.ints.between 0 29990;
                          };

                          change_threshold = lib.mkOption {
                            default = 0;
                            description = ''
                              Hysteresis setting: the minimum temperature change in degrees to
                              affect the fan speed. Also used to avoid rapid fan speed changes when
                              the temperature only changes e.g. 1 degree.
                            '';
                            example = 3;
                            type = lib.types.ints.between 0 9;
                          };
                        };
                      }
                    );
                  };

                  power_cap = lib.mkOption {
                    default = null;
                    description = "Power limit in watts.";
                    example = 320.0;
                    type = lib.types.nullOr lib.types.numbers.positive;
                  };

                  performance_level = lib.mkOption {
                    default = "auto";
                    description = ''
                      Performance level option for AMD GPUs.
                      Can be `auto`, `low`, `high` or `manual`.
                    '';
                    example = "manual";
                    type = lib.types.nullOr (
                      lib.types.enum [
                        "auto"
                        "low"
                        "high"
                        "manual"
                      ]
                    );
                  };

                  power_profile_mode_index = lib.mkOption {
                    default = null;
                    description = ''
                      Index of an AMD power profile mode.
                      Setting this requires `performance_level` to be set to `manual`.
                    '';
                    example = 1;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  min_core_clock = lib.mkOption {
                    default = null;
                    description = ''
                      Minimum GPU clockspeed in MHz.
                      On Nvidia, min and max values always have to be set together.
                    '';
                    example = 300;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  min_memory_clock = lib.mkOption {
                    default = null;
                    description = ''
                      Minimum VRAM clockspeed in MHz.
                      On Nvidia, min and max values always have to be set together.
                    '';
                    example = 500;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  min_voltage = lib.mkOption {
                    default = null;
                    description = ''
                      Minimum GPU voltage in mV. Applicable to AMD only.
                    '';
                    example = 900;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  max_core_clock = lib.mkOption {
                    default = null;
                    description = ''
                      Maximum GPU clockspeed in MHz.
                      On Nvidia, min and max values always have to be set together.
                    '';
                    example = 1630;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  max_memory_clock = lib.mkOption {
                    default = null;
                    description = ''
                      Maximum VRAM clockspeed in MHz.
                      On Nvidia, min and max values always have to be set together.
                    '';
                    example = 800;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  max_voltage = lib.mkOption {
                    default = null;
                    description = ''
                      Maximum GPU voltage in mV. Applicable to Vega and earlier AMD GPUs.
                    '';
                    example = 1200;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  voltage_offset = lib.mkOption {
                    default = null;
                    description = "Voltage offset value in mV for RDNA and newer AMD GPUs.";
                    example = -50;
                    type = lib.types.nullOr lib.types.int;
                  };
                };
              }
            )
          );
        };
      in
      lib.mkOption {
        default = { };
        description = ''
          Configuration for LACT. The attributes are serialized to YAML used as `config.yaml`. See
          https://github.com/ilya-zlobintsev/LACT/blob/master/docs/CONFIG.md
        '';
        type = lib.types.submodule {
          options = {
            version = lib.mkOption {
              default = 4;
              description = "Configuration version number. Changing this is not recommended.";
              type = lib.types.ints.positive;
            };
            daemon = {
              log_level = lib.mkOption {
                default = "info";
                description = "The logging level of the daemon.";
                type = lib.types.enum [
                  "error"
                  "warn"
                  "info"
                  "debug"
                  "trace"
                ];
              };

              admin_group = lib.mkOption {
                default = "wheel";
                description = ''
                  User group that owns the daemon socket. Any user in this group will be able to
                  use the daemon. Access can also be granted with the `admin_user` setting.
                '';
                example = "sudo";
                type = lib.types.str;
              };

              # TODO: Remove admin_groups entirely if 0.7.3 is already out.
              admin_groups =
                lib.warn
                  "services.lact.settings.admin_groups is deprecated. Use services.lact.settings.admin_group instead."
                  lib.mkOption
                  {
                    default = [
                      "wheel"
                      "sudo"
                    ];
                    description = ''
                      User groups who should have access to the daemon.
                      ONLY the first group from this list that is found on the system is used!
                    '';
                    example = "sudo";
                    type = lib.types.str;
                  };

              admin_user = lib.mkOption {
                default = null;
                description = ''
                  User that owns the daemon socket. This user will have access to the daemon, even
                  if they are not in the part of the `admin_group` group.
                '';
                example = "foo";
                type = lib.types.nullOr lib.types.str;
              };

              disable_clocks_cleanup = lib.mkOption {
                default = false;
                description = ''
                  If set to `true`, this setting makes the LACT daemon not reset
                  GPU clocks when changing other settings or when turning off the daemon.
                  Can be used to work around a few very specific issues with
                  some settings not applying on AMD GPUs.
                '';
                example = true;
                type = lib.types.bool;
              };

              tcp_listen_address = lib.mkOption {
                default = null;
                description = ''
                  Daemon's TCP listening address. Not specified by default.
                  By default TCP access is disabled, and only a unix socket is present.
                  Specifying this option enables the TCP listener.
                '';
                example = "127.0.0.1:12853";
                type = lib.types.nullOr lib.types.str;
              };
            };

            apply_settings_timer = lib.mkOption {
              default = 5;
              description = ''
                Period in seconds for how long settings should wait to be confirmed.
                Most GPU setting change commands require a confirmation command to be used
                in order to save these settings to the config.
                If a confirm command is not issued within the configured period (default: 5 seconds)
                the setting will be reverted.
              '';
              example = 10;
              type = lib.types.ints.unsigned;
            };

            gpus = gpusType;

            profiles = lib.mkOption {
              default = null;
              description = ''
                An attributes set of LACT profiles. The attribute name is is the profile name.
              '';
              example = {
                profiles = {
                  vkcube = {
                    gpus = {
                      "1002:73EF-1043:05E3-0000:03:00.0" = {
                        fan_control_enabled = true;
                        static_speed = 1.0;
                      };
                    };
                    rule = {
                      type = "process";
                      filter = {
                        name = "vkcube";
                      };
                      args = [ "--my-arg" ];
                    };
                  };
                };
              };
              type = lib.types.nullOr (
                lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      gpus = gpusType;

                      rule = lib.mkOption {
                        default = null;
                        description = ''
                          Profile activation rule for when this profile should be activated
                          when using automatic profile switching.
                        '';
                        type = lib.types.nullOr (
                          lib.types.submodule {
                            options = {
                              type = lib.mkOption {
                                example = "process";
                                description = "Type of the rule.";
                                type = lib.types.enum [
                                  "gamemode"
                                  "process"
                                ];
                              };

                              filter = lib.mkOption {
                                default = null;
                                description = ''
                                  Process filter. This is not required when using the gamemode rule
                                  type.
                                '';
                                type = lib.types.nullOr (
                                  lib.types.submodule {
                                    options = {
                                      name = lib.mkOption {
                                        example = "vkcube";
                                        description = "Name of the process.";
                                        type = lib.types.str;
                                      };

                                      args = lib.mkOption {
                                        default = null;
                                        description = "Process arguments. Not required.";
                                        example = "--my-arg";
                                        type = lib.types.nullOr lib.types.str;
                                      };
                                    };
                                  }
                                );
                              };
                            };
                          }
                        );
                      };
                    };
                  }
                )
              );
            };

            auto_switch_profiles = lib.mkOption {
              default = false;
              description = ''
                If profiles should automatically switch based on their configured rules.
              '';
              example = true;
              type = lib.types.bool;
            };
          };
        };
      };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = lib.mkIf (cfg.amdgpuOverclock.enable == true) [
      "amdgpu.ppfeaturemask=${cfg.amdgpuOverclock.ppfeaturemask}"
    ];

    environment = {
      etc."lact/config.yaml" = lib.mkIf (cfg.settings != { }) {
        # Setting mode to "0644" instead of "symlink" creates a file instead of a symlink to the
        # nix-store. This ensures that LACT can modify the config file.
        mode = "0644";
        source =
          pkgs.runCommand "lact-config.yaml"
            {
              yaml = pkgs.writers.writeYAML "config.yaml" (
                # Filter out attributes with null value.
                lib.filterAttrsRecursive (n: v: v != null) cfg.settings
              );
            }
            ''
              # Workaround for lact’s strict integer key requirement. This converts a valid
              # numeric key into an integer.
              ${lib.getExe pkgs.yj} -yy -k < $yaml > $out
            '';
      };
      systemPackages = [ cfg.package ];
    };

    systemd.services.lactd = {
      after = [ "multi-user.target" ];
      description = "LACT Linux GPU Control Application";
      path = with pkgs; [ lact ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/lact daemon";
        Nice = cfg.nice;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
