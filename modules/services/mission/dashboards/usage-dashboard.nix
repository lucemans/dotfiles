let
  ds = {
    type = "yesoreyeram-infinity-datasource";
    uid = "metered-usage";
  };

  window = "from=\${__from:date:iso}&to=\${__to:date:iso}&time_zone=Europe/Amsterdam";

  gridPos = x: y: w: h: {inherit x y w h;};

  column = selector: text: type: {inherit selector text type;};

  query = {
    url,
    rootSelector,
    columns,
  }: {
    inherit url columns;
    refId = "A";
    datasource = ds;
    type = "json";
    source = "url";
    format = "table";
    parser = "jq-backend";
    root_selector = rootSelector;
    url_options = {
      method = "GET";
      data = "";
    };
    filters = [];
  };

  byName = name: properties: {
    matcher = {
      id = "byName";
      options = name;
    };
    inherit properties;
  };

  unitOverride = name: unit:
    byName name [
      {
        id = "unit";
        value = unit;
      }
    ];

  stat = {
    id,
    title,
    x,
    selector,
    unit,
    color,
    decimals ? null,
  }: {
    inherit id title;
    type = "stat";
    datasource = ds;
    gridPos = gridPos x 0 3 4;
    fieldConfig = {
      defaults =
        {
          color = {
            mode = "fixed";
            fixedColor = color;
          };
          inherit unit;
        }
        // (
          if decimals == null
          then {}
          else {inherit decimals;}
        );
      overrides = [];
    };
    options = {
      colorMode = "value";
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
      (query {
        url = "/analytics/summary?${window}";
        rootSelector = "{value: (${selector})}";
        columns = [(column "value" title "number")];
      })
    ];
  };

  timeseries = {
    id,
    title,
    pos,
    unit,
    targets,
    stacked ? false,
    bars ? false,
    displayName ? null,
    transformations ? [],
    averaged ? false,
  }: {
    inherit id title targets transformations;
    type = "timeseries";
    datasource = ds;
    gridPos = pos;
    fieldConfig = {
      defaults =
        {
          color.mode = "palette-classic";
          custom = {
            axisBorderShow = false;
            axisPlacement = "auto";
            drawStyle =
              if bars
              then "bars"
              else "line";
            lineInterpolation = "smooth";
            fillOpacity =
              if bars
              then 80
              else 12;
            gradientMode = "opacity";
            lineWidth =
              if bars
              then 0
              else 2;
            showPoints = "never";
            spanNulls = true;
            stacking = {
              group = "A";
              mode =
                if stacked
                then "normal"
                else "none";
            };
            thresholdsStyle.mode = "off";
          };
          min = 0;
          inherit unit;
        }
        // (
          if displayName == null
          then {}
          else {inherit displayName;}
        );
      overrides = [];
    };
    options = {
      legend = {
        calcs =
          if averaged
          then ["mean"]
          else ["sum"];
        displayMode = "table";
        placement = "right";
        showLegend = true;
        sortBy =
          if averaged
          then "Mean"
          else "Total";
        sortDesc = true;
      };
      tooltip = {
        mode = "multi";
        sort = "desc";
      };
    };
  };

  byModel = {
    id,
    title,
    pos,
    metric,
    rankBy,
    unit,
  }:
    timeseries {
      inherit id title pos unit;
      stacked = true;
      bars = true;
      displayName = "\${__field.labels.model}";
      transformations = [
        {
          id = "prepareTimeSeries";
          options.format = "multi";
        }
      ];
      targets = [
        (query {
          url = "/analytics/series?${window}&bucket=$bucket&group_by=model&top=8&rank_by=${rankBy}";
          rootSelector = ".buckets | map({time: .start, model: .key, value: .metrics.${metric}})";
          columns = [
            (column "time" "time" "timestamp")
            (column "model" "model" "string")
            (column "value" "value" "number")
          ];
        })
      ];
    };

  ungrouped = {
    id,
    title,
    pos,
    unit,
    metrics,
    stacked ? false,
    averaged ? false,
  }:
    timeseries {
      inherit id title pos unit stacked averaged;
      targets = [
        (query {
          url = "/analytics/series?${window}&bucket=$bucket";
          rootSelector = ".buckets | map({time: .start, ${builtins.concatStringsSep ", " (
            builtins.map (metric: ''"${metric.text}": .metrics.${metric.selector}'') metrics
          )}})";
          columns =
            [(column "time" "time" "timestamp")]
            ++ builtins.map (metric: column metric.text metric.text "number") metrics;
        })
      ];
    };

  costBar = {
    id,
    title,
    pos,
    groupBy,
  }: {
    inherit id title;
    type = "bargauge";
    datasource = ds;
    gridPos = pos;
    fieldConfig = {
      defaults = {
        color.mode = "continuous-BlPu";
        min = 0;
        unit = "currencyUSD";
        decimals = 2;
      };
      overrides = [];
    };
    options = {
      displayMode = "gradient";
      orientation = "horizontal";
      namePlacement = "top";
      showUnfilled = true;
      valueMode = "color";
      reduceOptions = {
        calcs = [];
        fields = "/^cost$/";
        values = true;
      };
    };
    targets = [
      (query {
        url = "/analytics/breakdown?${window}&group_by=${groupBy}&limit=10";
        rootSelector = ".rows | map({name: (.label // .key), cost: .metrics.list_cost_usd})";
        columns = [
          (column "name" "name" "string")
          (column "cost" "cost" "number")
        ];
      })
    ];
  };

  # The backend parser emits columns in key order, so the table restores the declared order.
  table = {
    id,
    title,
    pos,
    url,
    rootSelector,
    columns,
    overrides,
    sortBy ? [],
  }: {
    inherit id title;
    type = "table";
    datasource = ds;
    gridPos = pos;
    fieldConfig = {
      defaults.custom = {
        align = "auto";
        cellOptions.type = "auto";
        inspect = false;
      };
      inherit overrides;
    };
    options = {
      cellHeight = "sm";
      showHeader = true;
      inherit sortBy;
    };
    transformations = [
      {
        id = "organize";
        options.indexByName = builtins.listToAttrs (builtins.genList (index: {
          name = (builtins.elemAt columns index).text;
          value = index;
        }) (builtins.length columns));
      }
    ];
    targets = [(query {inherit url rootSelector columns;})];
  };
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
      title = "List Cost";
      x = 0;
      selector = ".metrics.list_cost_usd";
      unit = "currencyUSD";
      color = "green";
      decimals = 2;
    })
    (stat {
      id = 2;
      title = "Daily Burn";
      x = 3;
      selector = ".daily_burn.list_cost_usd";
      unit = "currencyUSD";
      color = "green";
      decimals = 2;
    })
    (stat {
      id = 3;
      title = "Requests";
      x = 6;
      selector = ".metrics.requests";
      unit = "short";
      color = "blue";
    })
    (stat {
      id = 4;
      title = "Tokens";
      x = 9;
      selector = ".metrics.total_tokens";
      unit = "short";
      color = "blue";
    })
    (stat {
      id = 5;
      title = "Cache Hit Rate";
      x = 12;
      selector = ".cache_hit_rate";
      unit = "percentunit";
      color = "purple";
      decimals = 1;
    })
    (stat {
      id = 6;
      title = "Failure Rate";
      x = 15;
      selector = "if .metrics.requests > 0 then .metrics.failures / .metrics.requests else 0 end";
      unit = "percentunit";
      color = "red";
      decimals = 1;
    })
    (stat {
      id = 7;
      title = "Avg TTFT";
      x = 18;
      selector = ".metrics.avg_ttft_ms";
      unit = "ms";
      color = "orange";
      decimals = 2;
    })
    (stat {
      id = 8;
      title = "Output Speed";
      x = 21;
      selector = ".metrics.output_tokens_per_second";
      unit = "suffix: tok/s";
      color = "orange";
      decimals = 0;
    })
    (byModel {
      id = 9;
      title = "List Cost by Model";
      pos = gridPos 0 4 12 9;
      metric = "list_cost_usd";
      rankBy = "list_cost_usd";
      unit = "currencyUSD";
    })
    (byModel {
      id = 10;
      title = "Tokens by Model";
      pos = gridPos 12 4 12 9;
      metric = "total_tokens";
      rankBy = "total_tokens";
      unit = "short";
    })
    (ungrouped {
      id = 11;
      title = "Requests";
      pos = gridPos 0 13 8 8;
      unit = "short";
      metrics = [
        {
          selector = "requests";
          text = "Requests";
        }
        {
          selector = "failures";
          text = "Failures";
        }
      ];
    })
    (ungrouped {
      id = 12;
      title = "Token Mix";
      pos = gridPos 8 13 8 8;
      unit = "short";
      stacked = true;
      metrics = [
        {
          selector = "uncached_input_tokens";
          text = "Uncached Input";
        }
        {
          selector = "cache_read_tokens";
          text = "Cache Read";
        }
        {
          selector = "cache_write_tokens";
          text = "Cache Write";
        }
        {
          selector = "output_tokens";
          text = "Output";
        }
      ];
    })
    (ungrouped {
      id = 13;
      title = "Latency";
      pos = gridPos 16 13 8 8;
      unit = "ms";
      averaged = true;
      metrics = [
        {
          selector = "avg_ttft_ms";
          text = "Avg TTFT";
        }
        {
          selector = "avg_latency_ms";
          text = "Avg Latency";
        }
      ];
    })
    (table {
      id = 14;
      title = "Models";
      pos = gridPos 0 21 12 9;
      url = "/analytics/breakdown?${window}&group_by=model&limit=20";
      rootSelector = ".rows | map({model: .key, requests: .metrics.requests, failures: .metrics.failures, tokens: .metrics.total_tokens, cost: .metrics.list_cost_usd, ttft: .metrics.avg_ttft_ms, speed: .metrics.output_tokens_per_second})";
      columns = [
        (column "model" "Model" "string")
        (column "requests" "Requests" "number")
        (column "failures" "Failures" "number")
        (column "tokens" "Tokens" "number")
        (column "cost" "List Cost" "number")
        (column "ttft" "TTFT" "number")
        (column "speed" "Speed" "number")
      ];
      overrides = [
        (unitOverride "Requests" "short")
        (unitOverride "Failures" "short")
        (unitOverride "Tokens" "short")
        (unitOverride "List Cost" "currencyUSD")
        (unitOverride "TTFT" "ms")
        (unitOverride "Speed" "suffix: tok/s")
      ];
      sortBy = [
        {
          displayName = "List Cost";
          desc = true;
        }
      ];
    })
    (costBar {
      id = 15;
      title = "List Cost by Harness";
      pos = gridPos 12 21 6 9;
      groupBy = "harness";
    })
    (costBar {
      id = 16;
      title = "List Cost by Account";
      pos = gridPos 18 21 6 9;
      groupBy = "account";
    })
    (table {
      id = 17;
      title = "Top Sessions";
      pos = gridPos 0 30 24 8;
      url = "/analytics/sessions?${window}&limit=10";
      rootSelector = ''.sessions | map({session: .session_id, harness: (.harness // "unknown"), account: (.account.display_name // .account.label // .account.provider), models: (.models | join(", ")), last: .last_at, requests: .metrics.requests, tokens: .metrics.total_tokens, cost: .metrics.list_cost_usd})'';
      columns = [
        (column "session" "Session" "string")
        (column "harness" "Harness" "string")
        (column "account" "Account" "string")
        (column "models" "Models" "string")
        (column "last" "Last Active" "timestamp")
        (column "requests" "Requests" "number")
        (column "tokens" "Tokens" "number")
        (column "cost" "List Cost" "number")
      ];
      overrides = [
        (unitOverride "Last Active" "dateTimeFromNow")
        (unitOverride "Requests" "short")
        (unitOverride "Tokens" "short")
        (unitOverride "List Cost" "currencyUSD")
      ];
    })
  ];
  refresh = "1m";
  schemaVersion = 42;
  tags = ["usage" "llm"];
  templating.list = [
    {
      name = "bucket";
      label = "Bucket";
      type = "custom";
      query = "hour,day,week";
      current = {
        selected = true;
        text = "hour";
        value = "hour";
      };
      options = builtins.map (bucket: {
        selected = bucket == "hour";
        text = bucket;
        value = bucket;
      }) ["hour" "day" "week"];
      hide = 0;
      includeAll = false;
      multi = false;
    }
  ];
  time = {
    from = "now-7d";
    to = "now";
  };
  timepicker = {};
  timezone = "browser";
  title = "Usage";
  uid = "metered-usage";
  version = 1;
  weekStart = "";
}
