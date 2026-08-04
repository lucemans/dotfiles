let
  tokenColors = {
    AAVE = "#b6509e";
    ENS = "#627eea";
    EURC = "#2775ca";
    USDC = "#2775ca";
    USDT = "#26a17b";
    WBTC = "#f09242";
    WETH = "#8a92b2";
    XAUt = "#d4af37";
    kpk_EURC_Yield = "#14b8a6";
    stETH = "#00a3ff";
  };
  tokenColorOverrides = builtins.map (token: {
    matcher = {
      id = "byName";
      options = token;
    };
    properties = [
      {
        id = "color";
        value = {
          fixedColor = tokenColors.${token};
          mode = "fixed";
        };
      }
    ];
  }) (builtins.attrNames tokenColors);
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
      title = "$token";
      type = "stat";
      datasource = {
        type = "prometheus";
        uid = "mission-prometheus";
      };
      gridPos = {
        h = 6;
        w = 4;
        x = 0;
        y = 0;
      };
      maxPerRow = 6;
      repeat = "token";
      repeatDirection = "h";
      fieldConfig = {
        defaults = {
          color.mode = "palette-classic";
          decimals = 2;
          unit = "currencyUSD";
        };
        overrides = tokenColorOverrides;
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
          expr = ''token_price_usd{job="indexer-price",token=~"$token"}'';
          legendFormat = "{{token}}";
          refId = "A";
        }
      ];
    }
    {
      id = 2;
      title = "Price Change Since Range Start";
      type = "timeseries";
      datasource = {
        type = "prometheus";
        uid = "mission-prometheus";
      };
      gridPos = {
        h = 12;
        w = 24;
        x = 0;
        y = 12;
      };
      fieldConfig = {
        defaults = {
          color.mode = "palette-classic";
          custom = {
            axisBorderShow = false;
            axisCenteredZero = true;
            axisColorMode = "text";
            axisGridShow = true;
            axisLabel = "Change";
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
          decimals = 2;
          unit = "percent";
        };
        overrides = tokenColorOverrides;
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
          expr = ''
            100 * (
              token_price_usd{job="indexer-price"}
              / on (chain, instance, job, token)
              first_over_time(token_price_usd{job="indexer-price"}[$__range] @ end())
              - 1
            )
          '';
          legendFormat = "{{token}}";
          refId = "A";
        }
      ];
    }
  ];
  refresh = "1m";
  schemaVersion = 42;
  tags = ["ethereum" "indexer" "prices"];
  templating.list = [
    {
      current = {
        selected = true;
        text = ["All"];
        value = ["$__all"];
      };
      datasource = {
        type = "prometheus";
        uid = "mission-prometheus";
      };
      definition = ''label_values(token_price_usd{job="indexer-price"}, token)'';
      hide = 2;
      includeAll = true;
      multi = true;
      name = "token";
      options = [];
      query = {
        query = ''label_values(token_price_usd{job="indexer-price"}, token)'';
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
  title = "Indexer Prices";
  uid = "indexer-prices";
  version = 3;
  weekStart = "";
}
