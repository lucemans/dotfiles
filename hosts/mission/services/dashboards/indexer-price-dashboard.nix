{
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
          expr = ''token_price_usd{job="indexer-price",token=~"$token"}'';
          instant = true;
          range = false;
          refId = "A";
        }
      ];
    }
    {
      id = 2;
      title = "24h Price History";
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
            axisCenteredZero = false;
            axisColorMode = "text";
            axisGridShow = true;
            axisLabel = "USD";
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
          unit = "currencyUSD";
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
          expr = ''token_price_usd{job="indexer-price"}'';
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
  version = 2;
  weekStart = "";
}
