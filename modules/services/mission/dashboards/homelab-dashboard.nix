let
  rack = {
    left = 140;
    top = 18;
    width = 500;
    unitHeight = 28;
  };

  fixedColor = fixed: {inherit fixed;};

  rectangle = {
    name,
    text ? "",
    left,
    top,
    width,
    height,
    background ? "transparent",
    border ? "transparent",
    borderWidth ? 0,
    radius ? 0,
    size ? 12,
    align ? "center",
    valign ? "middle",
    textColor ? "#e5e7eb",
  }: {
    inherit name;
    type = "rectangle";
    constraint = {
      horizontal = "left";
      vertical = "top";
    };
    placement = {inherit left top width height;};
    background.color = fixedColor background;
    border = {
      color = fixedColor border;
      width = borderWidth;
      inherit radius;
    };
    config = {
      text = {
        mode = "fixed";
        fixed = text;
      };
      color = fixedColor textColor;
      inherit size align valign;
    };
  };

  ellipse = {
    name,
    left,
    top,
    size,
    color,
  }: {
    inherit name;
    type = "ellipse";
    constraint = {
      horizontal = "left";
      vertical = "top";
    };
    placement = {
      inherit left top;
      width = size;
      height = size;
    };
    background.color = color;
    border = {
      color = fixedColor "#000000";
      width = 1;
    };
    config = {
      text = {
        mode = "fixed";
        fixed = "";
      };
      color = fixedColor "#ffffff";
      align = "center";
      valign = "middle";
    };
  };

  unitTop = startU: heightU:
    rack.top + (33 - startU - heightU) * rack.unitHeight;

  mkDevice = {
    name,
    label,
    startU,
    heightU,
    width ? rack.width - 24,
    left ? rack.left + 12,
    statusField ? null,
    face ? "#171717",
  }: let
    top = unitTop startU heightU + 2;
    height = heightU * rack.unitHeight - 4;
    statusColor =
      if statusField == null
      then fixedColor "#737373"
      else {
        field = statusField;
        fixed = "#dc2626";
      };
  in [
    {
      inherit name;
      type = "rectangle";
      constraint = {
        horizontal = "left";
        vertical = "top";
      };
      placement = {inherit left top width height;};
      background.color = fixedColor face;
      border = {
        color = statusColor;
        width = 3;
        radius = 3;
      };
      config = {
        text = {
          mode = "fixed";
          fixed = label;
        };
        color = fixedColor "#fafafa";
        size =
          if heightU == 1
          then 10
          else 14;
        align = "center";
        valign = "middle";
      };
    }
    (ellipse {
      name = "${name} status";
      left = left + width - 16;
      top =
        if heightU == 1
        then top + 2
        else top + 6;
      size = 9;
      color = statusColor;
    })
  ];

  unitElements = builtins.concatLists (builtins.genList (index: let
      unit = 32 - index;
      top = rack.top + index * rack.unitHeight;
      shade =
        if builtins.elem unit [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
        then "#080808"
        else "#101010";
    in [
      (rectangle {
        name = "Rack U${toString unit}";
        text = "";
        left = rack.left;
        inherit top;
        width = rack.width;
        height = rack.unitHeight;
        background = shade;
        border = "#262626";
        borderWidth = 1;
      })
      (rectangle {
        name = "Rack U${toString unit} label";
        text = toString unit;
        left = rack.left - 34;
        inherit top;
        width = 28;
        height = rack.unitHeight;
        textColor = "#a3a3a3";
        size = 10;
        align = "right";
      })
      (ellipse {
        name = "Rack U${toString unit} left mount";
        left = rack.left + 4;
        top = top + 6;
        size = 5;
        color = fixedColor "#525252";
      })
      (ellipse {
        name = "Rack U${toString unit} right mount";
        left = rack.left + rack.width - 9;
        top = top + 6;
        size = 5;
        color = fixedColor "#525252";
      })
    ])
    32);

  deviceElements = builtins.concatLists [
    (mkDevice {
      name = "backup-server";
      label = "Backup Server";
      startU = 1;
      heightU = 1;
      face = "#1f1f1f";
    })
    (mkDevice {
      name = "poweredge-r720";
      label = "Dell PowerEdge R720";
      startU = 2;
      heightU = 2;
      face = "#141414";
    })
    (mkDevice {
      name = "v3x-mediabus";
      label = "v3x-mediabus";
      startU = 4;
      heightU = 3;
      statusField = "mediabus";
      face = "#0f0f0f";
    })
    (mkDevice {
      name = "v3x-point";
      label = "v3x-point";
      startU = 7;
      heightU = 1.5;
      width = 210;
      left = rack.left + 12;
      statusField = "point";
      face = "#1a1a1a";
    })
    (mkDevice {
      name = "rack-ups";
      label = "UPS";
      startU = 10;
      heightU = 1;
      face = "#191919";
    })
    (mkDevice {
      name = "v3x-synergy";
      label = "v3x-synergy";
      startU = 11;
      heightU = 4;
      width = 381;
      face = "#202020";
    })
    (mkDevice {
      name = "rack-drawer";
      label = "Drawer";
      startU = 16;
      heightU = 1;
      face = "#181818";
    })
    (mkDevice {
      name = "v3x-alternator";
      label = "v3x-alternator";
      startU = 17;
      heightU = 3;
      width = 210;
      left = rack.left + 30;
      statusField = "alternator";
      face = "#0f0f0f";
    })
    (mkDevice {
      name = "v3x-generator";
      label = "v3x-generator";
      startU = 17;
      heightU = 3;
      width = 210;
      left = rack.left + 260;
      statusField = "generator";
      face = "#0f0f0f";
    })
    (mkDevice {
      name = "v3x-watch";
      label = "v3x-watch";
      startU = 20;
      heightU = 1;
      width = 210;
      left = rack.left + 12;
      statusField = "watch";
      face = "#1a1a1a";
    })
    (mkDevice {
      name = "openviro";
      label = "openviro";
      startU = 21;
      heightU = 1;
      width = 210;
      left = rack.left + rack.width - 222;
      statusField = "openviro";
      face = "#1a1a1a";
    })
    (mkDevice {
      name = "nvr";
      label = "NVR";
      startU = 22;
      heightU = 1;
      face = "#191919";
    })
    (mkDevice {
      name = "patch-panel-u23";
      label = "Patch Panel";
      startU = 23;
      heightU = 1;
      face = "#141414";
    })
    (mkDevice {
      name = "switch-u25";
      label = "Switch";
      startU = 25;
      heightU = 1;
      face = "#141414";
    })
    (mkDevice {
      name = "patch-panel-u26";
      label = "Patch Panel";
      startU = 26;
      heightU = 1;
      face = "#141414";
    })
    (mkDevice {
      name = "switch-u27";
      label = "Switch";
      startU = 27;
      heightU = 1;
      face = "#141414";
    })
    (mkDevice {
      name = "switch-u29";
      label = "Switch";
      startU = 29;
      heightU = 1;
      face = "#141414";
    })
    (mkDevice {
      name = "patch-panel-u30";
      label = "Patch Panel";
      startU = 30;
      heightU = 1;
      face = "#141414";
    })
    (mkDevice {
      name = "power-distribution";
      label = "Power Distribution";
      startU = 32;
      heightU = 1;
      face = "#141414";
    })
  ];

  rackElements =
    [
      (rectangle {
        name = "Rack frame";
        text = "";
        left = 90;
        top = 4;
        width = 568;
        height = 924;
        background = "#000000";
        border = "#525252";
        borderWidth = 4;
        radius = 8;
      })
    ]
    ++ unitElements ++ deviceElements;

  statPanel = {
    id,
    title,
    expr,
    x,
    width,
    thresholds,
  }: {
    inherit id title;
    type = "stat";
    datasource = {
      type = "prometheus";
      uid = "mission-prometheus";
    };
    gridPos = {
      h = 4;
      w = width;
      inherit x;
      y = 0;
    };
    fieldConfig = {
      defaults = {
        color.mode = "thresholds";
        decimals = 1;
        unit = "celsius";
        thresholds = {
          mode = "absolute";
          steps = thresholds;
        };
      };
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
      title = "32U Rack Elevation";
      type = "canvas";
      datasource = {
        type = "prometheus";
        uid = "mission-prometheus";
      };
      gridPos = {
        h = 26;
        w = 10;
        x = 0;
        y = 0;
      };
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          mappings = [
            {
              type = "value";
              options = {
                "0" = {
                  color = "red";
                  index = 0;
                  text = "DOWN";
                };
                "1" = {
                  color = "green";
                  index = 1;
                  text = "UP";
                };
              };
            }
          ];
          thresholds = {
            mode = "absolute";
            steps = [
              {color = "red";}
              {
                color = "green";
                value = 1;
              }
            ];
          };
        };
        overrides = [];
      };
      options = {
        inlineEditing = false;
        panZoom = false;
        showAdvancedTypes = false;
        zoomToContent = true;
        tooltip = {
          mode = "none";
          disableForOneClick = false;
        };
        root = {
          name = "32U rack";
          type = "frame";
          elements = rackElements;
        };
      };
      targets = [
        {
          expr = ''gatus_results_endpoint_success{name="v3x-mediabus"}'';
          instant = true;
          range = false;
          legendFormat = "mediabus";
          refId = "A";
        }
        {
          expr = ''gatus_results_endpoint_success{name="v3x-point"}'';
          instant = true;
          range = false;
          legendFormat = "point";
          refId = "B";
        }
        {
          expr = ''gatus_results_endpoint_success{name="v3x-alternator"}'';
          instant = true;
          range = false;
          legendFormat = "alternator";
          refId = "C";
        }
        {
          expr = ''gatus_results_endpoint_success{name="v3x-generator"}'';
          instant = true;
          range = false;
          legendFormat = "generator";
          refId = "D";
        }
        {
          expr = ''gatus_results_endpoint_success{name="v3x-watch"}'';
          instant = true;
          range = false;
          legendFormat = "watch";
          refId = "E";
        }
        {
          expr = ''(count(rack_top_temperature_celsius{instance="10.0.0.145"} or rack_bottom_temperature_celsius{instance="10.0.0.145"}) > bool 0) or vector(0)'';
          instant = true;
          range = false;
          legendFormat = "openviro";
          refId = "F";
        }
      ];
    }
    (statPanel {
      id = 2;
      title = "Rack Top";
      expr = ''rack_top_temperature_celsius{instance="10.0.0.145"}'';
      x = 10;
      width = 5;
      thresholds = [
        {color = "green";}
        {
          color = "yellow";
          value = 27;
        }
        {
          color = "red";
          value = 32;
        }
      ];
    })
    (statPanel {
      id = 3;
      title = "Rack Bottom";
      expr = ''rack_bottom_temperature_celsius{instance="10.0.0.145"}'';
      x = 15;
      width = 5;
      thresholds = [
        {color = "green";}
        {
          color = "yellow";
          value = 27;
        }
        {
          color = "red";
          value = 32;
        }
      ];
    })
    (statPanel {
      id = 4;
      title = "Top / Bottom Delta";
      expr = ''rack_top_temperature_celsius{instance="10.0.0.145"} - rack_bottom_temperature_celsius{instance="10.0.0.145"}'';
      x = 20;
      width = 4;
      thresholds = [
        {color = "green";}
        {
          color = "yellow";
          value = 3;
        }
        {
          color = "red";
          value = 6;
        }
      ];
    })
    {
      id = 5;
      title = "24h Rack Temperature";
      type = "timeseries";
      datasource = {
        type = "prometheus";
        uid = "mission-prometheus";
      };
      gridPos = {
        h = 22;
        w = 14;
        x = 10;
        y = 4;
      };
      fieldConfig = {
        defaults = {
          color.mode = "palette-classic";
          custom = {
            axisBorderShow = false;
            axisCenteredZero = false;
            axisColorMode = "text";
            axisGridShow = true;
            axisLabel = "Temperature";
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
          decimals = 1;
          unit = "celsius";
        };
        overrides = [];
      };
      options = {
        legend = {
          calcs = ["lastNotNull" "min" "max"];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
      targets = [
        {
          expr = ''rack_top_temperature_celsius{instance="10.0.0.145"}'';
          legendFormat = "Rack top";
          refId = "A";
        }
        {
          expr = ''rack_bottom_temperature_celsius{instance="10.0.0.145"}'';
          legendFormat = "Rack bottom";
          refId = "B";
        }
      ];
    }
  ];
  refresh = "30s";
  schemaVersion = 42;
  tags = ["mission" "homelab" "rack" "uptime"];
  time = {
    from = "now-24h";
    to = "now";
  };
  timepicker = {};
  timezone = "browser";
  title = "Local Homelab Uptime";
  uid = "homelab-uptime";
  version = 4;
  weekStart = "";
}
