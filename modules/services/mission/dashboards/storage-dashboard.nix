let
  ds = {
    type = "prometheus";
    uid = "mission-prometheus";
  };

  fsFilter = ''job="node", instance=~"$host", fstype!~"tmpfs|devtmpfs|overlay|squashfs|ramfs|efivarfs|autofs|fuse.*", mountpoint!~"/run.*|/sys.*|/proc.*|/dev.*|/nix/store"'';
  diskFilter = ''job="node", instance=~"$host", device!~"dm-.*|sr.*"'';
  smartFilter = ''job="smartctl", instance=~"$host"'';

  thresholds = steps: {
    mode = "absolute";
    inherit steps;
  };

  step = color: value: {inherit color value;};

  usageThresholds = thresholds [
    (step "green" null)
    (step "yellow" 70)
    (step "red" 90)
  ];

  temperatureThresholds = thresholds [
    (step "green" null)
    (step "yellow" 50)
    (step "red" 60)
  ];

  wearThresholds = thresholds [
    (step "green" null)
    (step "yellow" 80)
    (step "red" 95)
  ];

  errorThresholds = thresholds [
    (step "green" null)
    (step "red" 1)
  ];

  gridPos = x: y: w: h: {inherit x y w h;};

  byName = name: properties: {
    matcher = {
      id = "byName";
      options = name;
    };
    inherit properties;
  };

  instantTable = refId: expr: {
    inherit expr refId;
    format = "table";
    instant = true;
    range = false;
  };

  stat = {
    id,
    title,
    pos,
    expr,
    unit,
    thresholds,
    noValue ? null,
  }: {
    inherit id title;
    type = "stat";
    datasource = ds;
    gridPos = pos;
    fieldConfig = {
      defaults =
        {
          color.mode = "thresholds";
          decimals = 0;
          inherit unit thresholds;
        }
        // (
          if noValue == null
          then {}
          else {inherit noValue;}
        );
      overrides = [];
    };
    options = {
      colorMode = "background";
      graphMode = "none";
      justifyMode = "center";
      orientation = "auto";
      reduceOptions = {
        calcs = ["lastNotNull"];
        fields = "";
        values = false;
      };
      textMode = "value";
    };
    targets = [
      {
        inherit expr;
        instant = true;
        range = false;
        refId = "A";
      }
    ];
  };

  timeseries = {
    id,
    title,
    pos,
    unit,
    targets,
    defaults ? {},
    overrides ? [],
    timeFrom ? null,
    drawStyle ? "line",
    lineInterpolation ? "smooth",
  }:
    {
      inherit id title targets;
      type = "timeseries";
      datasource = ds;
      gridPos = pos;
      fieldConfig = {
        defaults =
          {
            color.mode = "palette-classic";
            custom = {
              axisBorderShow = false;
              axisCenteredZero = false;
              axisColorMode = "text";
              axisGridShow = true;
              axisPlacement = "auto";
              inherit drawStyle lineInterpolation;
              fillOpacity = 12;
              gradientMode = "opacity";
              lineWidth = 2;
              pointSize = 5;
              showPoints = "never";
              spanNulls = true;
              stacking = {
                group = "A";
                mode = "none";
              };
              thresholdsStyle.mode = "off";
            };
            inherit unit;
          }
          // defaults;
        inherit overrides;
      };
      options = {
        legend = {
          calcs = ["lastNotNull" "max"];
          displayMode = "table";
          placement = "right";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    }
    // (
      if timeFrom == null
      then {}
      else {inherit timeFrom;}
    );
in {
  annotations.list = [];
  editable = false;
  fiscalYearStartMonth = 0;
  graphTooltip = 1;
  links = [];
  liveNow = false;
  panels = [
    (stat {
      id = 1;
      title = "Fullest Filesystem";
      pos = gridPos 0 0 4 4;
      expr = ''max(100 * (1 - node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}}))'';
      unit = "percent";
      thresholds = usageThresholds;
    })
    (stat {
      id = 2;
      title = "Nearest Full";
      pos = gridPos 4 0 4 4;
      expr = ''min((node_filesystem_avail_bytes{${fsFilter}} / -deriv(node_filesystem_avail_bytes{${fsFilter}}[24h])) > 0)'';
      unit = "s";
      noValue = "Stable";
      thresholds = thresholds [
        (step "red" null)
        (step "yellow" 604800)
        (step "green" 2592000)
      ];
    })
    (stat {
      id = 3;
      title = "SMART Failing";
      pos = gridPos 8 0 4 4;
      expr = ''count(smartctl_device_smart_status{${smartFilter}} == 0) or vector(0)'';
      unit = "none";
      thresholds = errorThresholds;
    })
    (stat {
      id = 4;
      title = "Media Errors";
      pos = gridPos 12 0 4 4;
      expr = ''sum(smartctl_device_media_errors{${smartFilter}} or smartctl_device_attribute{${smartFilter}, attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}) or vector(0)'';
      unit = "none";
      thresholds = errorThresholds;
    })
    (stat {
      id = 5;
      title = "Hottest Disk";
      pos = gridPos 16 0 4 4;
      expr = ''max(smartctl_device_temperature{${smartFilter}, temperature_type="current"})'';
      unit = "celsius";
      thresholds = temperatureThresholds;
    })
    (stat {
      id = 6;
      title = "Worst NVMe Wear";
      pos = gridPos 20 0 4 4;
      expr = ''max(smartctl_device_percentage_used{${smartFilter}})'';
      unit = "percent";
      thresholds = wearThresholds;
    })
    {
      id = 7;
      title = "Filesystems";
      type = "table";
      datasource = ds;
      gridPos = gridPos 0 4 12 9;
      fieldConfig = {
        defaults.custom = {
          align = "auto";
          cellOptions.type = "auto";
          inspect = false;
        };
        overrides = [
          (byName "Size" [
            {
              id = "unit";
              value = "bytes";
            }
          ])
          (byName "Free" [
            {
              id = "unit";
              value = "bytes";
            }
          ])
          (byName "Used" [
            {
              id = "unit";
              value = "percent";
            }
            {
              id = "min";
              value = 0;
            }
            {
              id = "max";
              value = 100;
            }
            {
              id = "decimals";
              value = 0;
            }
            {
              id = "thresholds";
              value = usageThresholds;
            }
            {
              id = "color";
              value.mode = "thresholds";
            }
            {
              id = "custom.cellOptions";
              value = {
                type = "gauge";
                mode = "basic";
                valueDisplayMode = "text";
              };
            }
          ])
        ];
      };
      options = {
        cellHeight = "sm";
        showHeader = true;
        sortBy = [
          {
            displayName = "Used";
            desc = true;
          }
        ];
      };
      targets = [
        (instantTable "A" ''node_filesystem_size_bytes{${fsFilter}}'')
        (instantTable "B" ''node_filesystem_avail_bytes{${fsFilter}}'')
        (instantTable "C" ''100 * (1 - node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}})'')
      ];
      transformations = [
        {
          id = "merge";
          options = {};
        }
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              job = true;
              device = true;
              fstype = true;
            };
            indexByName = {
              instance = 0;
              mountpoint = 1;
              "Value #A" = 2;
              "Value #B" = 3;
              "Value #C" = 4;
            };
            renameByName = {
              instance = "Host";
              mountpoint = "Mount";
              "Value #A" = "Size";
              "Value #B" = "Free";
              "Value #C" = "Used";
            };
          };
        }
      ];
    }
    {
      id = 8;
      title = "Disks";
      type = "table";
      datasource = ds;
      gridPos = gridPos 12 4 12 9;
      fieldConfig = {
        defaults.custom = {
          align = "auto";
          cellOptions.type = "auto";
          inspect = false;
        };
        overrides = [
          (byName "Size" [
            {
              id = "unit";
              value = "bytes";
            }
          ])
          (byName "Temp" [
            {
              id = "unit";
              value = "celsius";
            }
            {
              id = "thresholds";
              value = temperatureThresholds;
            }
            {
              id = "color";
              value.mode = "thresholds";
            }
            {
              id = "custom.cellOptions";
              value.type = "color-text";
            }
          ])
          (byName "Wear" [
            {
              id = "unit";
              value = "percent";
            }
            {
              id = "thresholds";
              value = wearThresholds;
            }
            {
              id = "color";
              value.mode = "thresholds";
            }
            {
              id = "custom.cellOptions";
              value.type = "color-text";
            }
          ])
          (byName "Power-On" [
            {
              id = "unit";
              value = "s";
            }
            {
              id = "decimals";
              value = 1;
            }
          ])
          (byName "SMART" [
            {
              id = "mappings";
              value = [
                {
                  type = "value";
                  options = {
                    "0" = {
                      text = "FAIL";
                      color = "red";
                    };
                    "1" = {
                      text = "OK";
                      color = "green";
                    };
                  };
                }
              ];
            }
            {
              id = "custom.cellOptions";
              value.type = "color-background";
            }
          ])
        ];
      };
      options = {
        cellHeight = "sm";
        showHeader = true;
      };
      targets = [
        (instantTable "A" ''max by (instance, device, model_name) (smartctl_device{${smartFilter}})'')
        (instantTable "B" ''max by (instance, device) (smartctl_device_capacity_bytes{${smartFilter}})'')
        (instantTable "C" ''max by (instance, device) (smartctl_device_temperature{${smartFilter}, temperature_type="current"})'')
        (instantTable "D" ''max by (instance, device) (smartctl_device_percentage_used{${smartFilter}})'')
        (instantTable "E" ''max by (instance, device) (smartctl_device_power_on_seconds{${smartFilter}})'')
        (instantTable "F" ''max by (instance, device) (smartctl_device_smart_status{${smartFilter}})'')
      ];
      transformations = [
        {
          id = "merge";
          options = {};
        }
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              "Value #A" = true;
            };
            indexByName = {
              instance = 0;
              device = 1;
              model_name = 2;
              "Value #B" = 3;
              "Value #C" = 4;
              "Value #D" = 5;
              "Value #E" = 6;
              "Value #F" = 7;
            };
            renameByName = {
              instance = "Host";
              device = "Device";
              model_name = "Model";
              "Value #B" = "Size";
              "Value #C" = "Temp";
              "Value #D" = "Wear";
              "Value #E" = "Power-On";
              "Value #F" = "SMART";
            };
          };
        }
      ];
    }
    (timeseries {
      id = 9;
      title = "Disk Temperature";
      pos = gridPos 0 13 12 6;
      unit = "celsius";
      targets = [
        {
          expr = ''smartctl_device_temperature{${smartFilter}, temperature_type="current"}'';
          legendFormat = "{{instance}} {{device}}";
          refId = "A";
        }
      ];
    })
    (timeseries {
      id = 10;
      title = "Nix Store Size";
      pos = gridPos 12 13 12 6;
      unit = "bytes";
      timeFrom = "7d";
      lineInterpolation = "stepAfter";
      targets = [
        {
          expr = ''nix_store_size_bytes{job="node", instance=~"$host"}'';
          legendFormat = "{{instance}}";
          refId = "A";
        }
      ];
    })
    (timeseries {
      id = 11;
      title = "Disk Throughput";
      pos = gridPos 0 19 12 6;
      unit = "Bps";
      targets = [
        {
          expr = ''sum by (instance) (rate(node_disk_read_bytes_total{${diskFilter}}[$__rate_interval]))'';
          legendFormat = "{{instance}} read";
          refId = "A";
        }
        {
          expr = ''sum by (instance) (rate(node_disk_written_bytes_total{${diskFilter}}[$__rate_interval]))'';
          legendFormat = "{{instance}} write";
          refId = "B";
        }
      ];
      overrides = [
        {
          matcher = {
            id = "byRegexp";
            options = ".* write$";
          };
          properties = [
            {
              id = "custom.transform";
              value = "negative-Y";
            }
          ];
        }
      ];
    })
    (timeseries {
      id = 12;
      title = "Disk Busy";
      pos = gridPos 12 19 12 6;
      unit = "percentunit";
      defaults = {
        min = 0;
        max = 1;
      };
      targets = [
        {
          expr = ''rate(node_disk_io_time_seconds_total{${diskFilter}}[$__rate_interval])'';
          legendFormat = "{{instance}} {{device}}";
          refId = "A";
        }
      ];
    })
  ];
  refresh = "1m";
  schemaVersion = 42;
  tags = ["storage"];
  templating.list = [
    {
      current = {
        selected = true;
        text = ["All"];
        value = ["$__all"];
      };
      datasource = ds;
      definition = ''label_values(node_filesystem_size_bytes{job="node", mountpoint="/"}, instance)'';
      hide = 0;
      includeAll = true;
      multi = true;
      name = "host";
      options = [];
      query = {
        query = ''label_values(node_filesystem_size_bytes{job="node", mountpoint="/"}, instance)'';
        refId = "StandardVariableQuery";
      };
      refresh = 1;
      type = "query";
    }
  ];
  time = {
    from = "now-24h";
    to = "now";
  };
  timepicker = {};
  timezone = "browser";
  title = "Storage";
  uid = "storage";
  version = 2;
  weekStart = "";
}
