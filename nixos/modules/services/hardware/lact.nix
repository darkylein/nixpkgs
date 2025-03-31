{
  config,
  lib,
  pkgs,
  ...
}:
let
  # TODO: Add missing descriptions and options.
  # TODO: Check all comments.
  cfg = config.services.lact;
in
{
  options.services.lact = {
    # LACT is not AMD exclusive anymore, so I've used the generic name from their README.
    enable = lib.mkEnableOption "LACT Linux GPU Control Application";

    package = lib.mkPackageOption pkgs "LACT" { default = [ "lact" ]; };

    serviceRenice = lib.mkOption {
      default = -10;
      example = 0;
      type = lib.types.numbers.between (-20) 19;
    };

    # Since LACT is not an AMD only tool anymore I've renamed the gpuOverclock option accordingly,
    # so Nvidia and Intel users do not get confused. Also the description is slightly adjusted.
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
          type = lib.types.nullOr (
            lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  fan_control_enabled = lib.mkOption {
                    default = false;
                    example = true;
                    type = lib.types.bool;
                  };

                  fan_control_settings = lib.mkOption {
                    default = null;
                    type = lib.types.nullOr (
                      lib.types.submodule {
                        options = {
                          mode = lib.mkOption {
                            default = "curve";
                            example = "static";
                            type = lib.types.enum [
                              "curve"
                              "static"
                            ];
                          };

                          static_speed = lib.mkOption {
                            default = 0.5;
                            example = 1.0;
                            type = lib.types.numbers.between 0 1;
                          };

                          temperature_key = lib.mkOption {
                            default = "edge";
                            example = "junction";
                            type = lib.types.enum [
                              "edge"
                              "junction"
                            ];
                          };

                          interval_ms = lib.mkOption {
                            default = 500;
                            example = 1000;
                            type = lib.types.ints.positive;
                          };

                          curve = lib.mkOption {
                            # Can the key be type checked to be a stringified integer?
                            default = {
                              "40" = 0.2;
                              "50" = 0.35;
                              "60" = 0.5;
                              "70" = 0.75;
                              "80" = 1.0;
                            };
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
                            example = 5000;
                            type = lib.types.ints.between 0 29990;
                          };

                          change_threshold = lib.mkOption {
                            default = 0;
                            example = 3;
                            type = lib.types.ints.between 0 9;
                          };
                        };
                      }
                    );
                  };

                  power_cap = lib.mkOption {
                    default = null;
                    example = 320.0;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  performance_level = lib.mkOption {
                    default = "auto";
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
                    example = 1;
                    type = lib.types.nullOr lib.types.ints.unsigned; # How many indices are there?
                  };

                  min_core_clock = lib.mkOption {
                    default = null;
                    example = 300;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  min_memory_clock = lib.mkOption {
                    default = null;
                    example = 500;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  min_voltage = lib.mkOption {
                    default = null;
                    example = 900;
                    type = lib.types.nullOr lib.types.ints.unsigned;
                  };

                  max_core_clock = lib.mkOption {
                    default = null;
                    example = 1630;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  max_memory_clock = lib.mkOption {
                    default = null;
                    example = 800;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  max_voltage = lib.mkOption {
                    default = null;
                    example = 1200;
                    type = lib.types.nullOr lib.types.ints.positive;
                  };

                  voltage_offset = lib.mkOption {
                    default = null;
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
        visible = "shallow";
        type = lib.types.submodule {
          options = {
            # Configuration Version number was added in LACT version 0.7.
            # version = lib.mkOption {
            #   default = 2;
            #   description = "Config version number.";
            #   readOnly = true;
            #   visible = false;
            #   type = lib.types.numbers.positive;
            # };
            daemon = {
              log_level = lib.mkOption {
                default = "info";
                type = lib.types.enum [
                  "error"
                  "warn"
                  "info"
                  "debug"
                  "trace"
                ];
              };

              admin_groups = lib.mkOption {
                default = [
                  "sudo"
                  "wheel"
                ];
                example = [ "sudo" ];
                type = lib.types.listOf lib.types.str;
              };

              disable_clocks_cleanup = lib.mkOption {
                default = false;
                example = true;
                type = lib.types.bool;
              };
            };

            apply_settings_timer = lib.mkOption {
              default = 5;
              example = 10;
              type = lib.types.ints.unsigned;
            };

            gpus = gpusType;

            profiles = lib.mkOption {
              default = null;
              type = lib.types.nullOr (
                lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      gpus = gpusType;

                      # Rules are not yet supported by the current LACT version in nixpkgs.
                      # rules = lib.mkOption {
                      #   default = null;
                      #   type = lib.types.nullOr (
                      #     lib.types.submodule {
                      #       options = {
                      #         type = lib.mkOption {
                      #           example = "process";
                      #           type = lib.types.enum [
                      #             "gamemode"
                      #             "process"
                      #           ];
                      #         };
                      #
                      #         rule = lib.mkOption {
                      #           default = null;
                      #           type = lib.types.nullOr (
                      #             lib.types.submodule {
                      #               options = {
                      #                 name = lib.mkOption {
                      #                   example = "vkcube";
                      #                   type = lib.types.str;
                      #                 };
                      #
                      #                 args = lib.mkOption {
                      #                   default = null;
                      #                   example = "--my-arg";
                      #                   type = lib.types.nullOr lib.types.str;
                      #                 };
                      #               };
                      #             }
                      #           );
                      #         };
                      #       };
                      #     }
                      #   );
                      # };
                    };
                  }
                )
              );
            };

            auto_switch_profiles = lib.mkOption {
              default = false;
              example = true;
              type = lib.types.bool;
            };
          };
        };
      };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = lib.mkIf (cfg.amdgpuOverclock == true) [
      "amdgpu.ppfeaturemask=${cfg.amdgpuOverclock.ppfeaturemask}"
    ];

    environment = {
      etc."lact/config.yaml" = lib.mkIf (cfg.settings != { }) {
        # Setting mode "0644" instead of "symlink" ensures that LACT can modify the config file.
        # This prevents the 'Error: Could not write config. Read-only file system (os error 30)`
        # which happens during LACT profile switch or migration between version.
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
              # Workaround for lact’s strict integer key requirement. This converts every numeric
              # key into an integer.
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
        Nice = cfg.serviceRenice;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
