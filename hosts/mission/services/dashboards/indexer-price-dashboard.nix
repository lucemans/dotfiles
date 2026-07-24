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
      title = "Token Prices";
      type = "table";
      datasource = {
        type = "prometheus";
        uid = "mission-prometheus";
      };
      gridPos = {
        h = 18;
        w = 24;
        x = 0;
        y = 0;
      };
      fieldConfig = {
        defaults = {
          decimals = 2;
          unit = "currencyUSD";
        };
        overrides = [
          {
            matcher = {
              id = "byName";
              options = "Time";
            };
            properties = [
              {
                id = "custom.hidden";
                value = true;
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "chain";
            };
            properties = [
              {
                id = "unit";
                value = "none";
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "token";
            };
            properties = [
              {
                id = "unit";
                value = "none";
              }
            ];
          }
        ];
      };
      options = {
        cellHeight = "sm";
        footer = {
          countRows = false;
          fields = "";
          reducer = ["sum"];
          show = false;
        };
        showHeader = true;
        sortBy = [
          {
            desc = false;
            displayName = "token";
          }
        ];
      };
      targets = [
        {
          expr = ''token_price_usd{job="indexer-price"}'';
          format = "table";
          instant = true;
          range = false;
          refId = "A";
        }
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
            };
            indexByName = {
              chain = 0;
              token = 1;
              Value = 2;
            };
            renameByName = {
              Value = "Price";
              chain = "Chain";
              token = "Asset";
            };
          };
        }
      ];
    }
  ];
  refresh = "1m";
  schemaVersion = 42;
  tags = ["ethereum" "indexer" "prices"];
  time = {
    from = "now-24h";
    to = "now";
  };
  timepicker = {};
  timezone = "browser";
  title = "Indexer Prices";
  uid = "indexer-prices";
  version = 1;
  weekStart = "";
}
