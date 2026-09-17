let
  ds = {
    type = "prometheus";
    uid = "mission-prometheus";
  };

  fsFilter = ''job="node", instance=~"$host", fstype!~"tmpfs|devtmpfs|overlay|squashfs", mountpoint!~"/run.*|/sys.*|/proc.*|/dev.*"'';
  smartFilter = ''job="smartctl", instance=~"$host"'';

  usageThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "green";
        value = null;
      }
      {
        color = "yellow";
        value = 70;
      }
      {
        color = "red";
        value = 90;
      }
    ];
  };

  tsCustom = {
    axisBorderShow = false;
    axisCenteredZero = false;
    axisColorMode = "text";
    axisGridShow = true;
    axisPlacement = "auto";
    drawStyle = "line";
    fillOpacity = 12;
    gradientMode = "opacity";
    lineInterpolation = "smooth";
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

  tsLegend = {
    calcs = ["lastNotNull" "min" "max"];
    displayMode = "table";
    placement = "bottom";
    showLegend = true;
  };

  tsTooltip = {
    mode = "multi";
    sort = "desc";
  };
in {
  annotations.list = [];
  editable = false;
  fiscalYearStartMonth = 0;
  graphTooltip = 1;
  links = [];
  liveNow = false;
  panels = [
    {
      id = 1;
      title = "$host";
      type = "stat";
      datasource = ds;
      gridPos = {
        h = 6;
        w = 6;
        x = 0;
        y = 0;
      };
      maxPerRow = 4;
      repeat = "host";
      repeatDirection = "h";
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = usageThresholds;
          unit = "percent";
        };
        overrides = [];
      };
      options = {
        colorMode = "background_gradient";
        graphMode = "area";
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
          expr = ''100 * (1 - node_filesystem_avail_bytes{${fsFilter}, mountpoint="/"} / node_filesystem_size_bytes{${fsFilter}, mountpoint="/"})'';
          legendFormat = "{{instance}}";
          refId = "A";
        }
      ];
    }
    {
      id = 2;
      title = "Filesystem Usage";
      type = "bargauge";
      datasource = ds;
      gridPos = {
        h = 10;
        w = 24;
        x = 0;
        y = 6;
      };
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = usageThresholds;
          unit = "percent";
        };
        overrides = [];
      };
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        reduceOptions = {
          calcs = ["lastNotNull"];
          fields = "";
          values = false;
        };
        showUnfilled = true;
        valueMode = "color";
      };
      targets = [
        {
          expr = ''100 * (1 - node_filesystem_avail_bytes{${fsFilter}} / node_filesystem_size_bytes{${fsFilter}})'';
          legendFormat = "{{instance}} {{mountpoint}}";
          refId = "A";
        }
      ];
    }
    {
      id = 3;
      title = "Disks";
      type = "table";
      datasource = ds;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 16;
      };
      fieldConfig = {
        defaults = {
          custom = {
            align = "auto";
            cellOptions.type = "auto";
            inspect = false;
          };
        };
        overrides = [
          {
            matcher = {
              id = "byName";
              options = "Size";
            };
            properties = [
              {
                id = "unit";
                value = "bytes";
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "RPM";
            };
            properties = [
              {
                id = "mappings";
                value = [
                  {
                    type = "value";
                    options."0" = {
                      text = "SSD";
                      color = "blue";
                    };
                  }
                ];
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "SMART";
            };
            properties = [
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
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Power-On";
            };
            properties = [
              {
                id = "unit";
                value = "s";
              }
            ];
          }
        ];
      };
      options = {
        cellHeight = "sm";
        showHeader = true;
      };
      targets = [
        {
          expr = ''smartctl_device{${smartFilter}}'';
          format = "table";
          instant = true;
          refId = "A";
        }
        {
          expr = ''smartctl_device_capacity_blocks{${smartFilter}} * on(instance, device) group_left() smartctl_device_block_size{${smartFilter}, block_type="logical"}'';
          format = "table";
          instant = true;
          refId = "B";
        }
        {
          expr = ''smartctl_device_rotation_rate{${smartFilter}}'';
          format = "table";
          instant = true;
          refId = "C";
        }
        {
          expr = ''smartctl_device_smart_status{${smartFilter}}'';
          format = "table";
          instant = true;
          refId = "D";
        }
        {
          expr = ''smartctl_device_power_on_seconds{${smartFilter}}'';
          format = "table";
          instant = true;
          refId = "E";
        }
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
              job = true;
            };
            indexByName = {};
            renameByName = {
              instance = "Host";
              device = "Device";
              model_name = "Model";
              serial_number = "Serial";
              "Value #B" = "Size";
              "Value #C" = "RPM";
              "Value #D" = "SMART";
              "Value #E" = "Power-On";
            };
          };
        }
      ];
    }
    {
      id = 4;
      title = "Disk Temperature";
      type = "timeseries";
      datasource = ds;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 24;
      };
      fieldConfig = {
        defaults = {
          color.mode = "palette-classic";
          custom = tsCustom;
          unit = "celsius";
        };
        overrides = [];
      };
      options = {
        legend = tsLegend;
        tooltip = tsTooltip;
      };
      targets = [
        {
          expr = ''smartctl_device_temperature{${smartFilter}}'';
          legendFormat = "{{instance}} {{device}}";
          refId = "A";
        }
      ];
    }
    {
      id = 5;
      title = "NVMe Wear";
      type = "stat";
      datasource = ds;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 24;
      };
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = null;
              }
              {
                color = "yellow";
                value = 80;
              }
              {
                color = "red";
                value = 95;
              }
            ];
          };
          unit = "percent";
        };
        overrides = [];
      };
      options = {
        colorMode = "value";
        graphMode = "area";
        justifyMode = "center";
        orientation = "auto";
        reduceOptions = {
          calcs = ["lastNotNull"];
          fields = "";
          values = false;
        };
        textMode = "value_and_name";
      };
      targets = [
        {
          expr = ''smartctl_device_percentage_used{${smartFilter}}'';
          legendFormat = "{{instance}} {{device}}";
          refId = "A";
        }
      ];
    }
    {
      id = 6;
      title = "Disk Usage";
      type = "timeseries";
      datasource = ds;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 32;
      };
      fieldConfig = {
        defaults = {
          color.mode = "palette-classic";
          custom = tsCustom;
          unit = "bytes";
        };
        overrides = [];
      };
      options = {
        legend = tsLegend;
        tooltip = tsTooltip;
      };
      targets = [
        {
          expr = ''node_filesystem_size_bytes{${fsFilter}} - node_filesystem_avail_bytes{${fsFilter}}'';
          legendFormat = "{{instance}} {{mountpoint}}";
          refId = "A";
        }
      ];
    }
    {
      id = 7;
      title = "Nix Store Size";
      type = "timeseries";
      datasource = ds;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 32;
      };
      fieldConfig = {
        defaults = {
          color.mode = "palette-classic";
          custom = tsCustom;
          unit = "bytes";
        };
        overrides = [];
      };
      options = {
        legend = tsLegend;
        tooltip = tsTooltip;
      };
      targets = [
        {
          expr = ''nix_store_size_bytes{job="node", instance=~"$host"}'';
          legendFormat = "{{instance}}";
          refId = "A";
        }
      ];
    }
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
  version = 1;
  weekStart = "";
}
