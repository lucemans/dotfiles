rec {
  zone = "v3x.host";
  acmeEmail = "luc@lucemans.nl";
  hub = "v3x-teapot";
  hubPort = 51820;
  resolver = "100.127.0.53";
  subnet = "100.127.0.0/16";
  trusted = "100.127.0.0/24";
  guests = "100.127.10.0/24";

  records = {
    "77.162.232.110" = ["wg.${zone}"];
  };

  services = {
    cache = {
      name = "cache.${zone}";
      upstream = "${hosts.v3x-teapot.address}:8082";
      access = ["f2"];
    };
    inference = {
      name = "inference.${zone}";
      upstream = "${hosts.v3x-teapot.address}:4000";
      access = ["f1" "f2"];
    };
    media = {
      name = "media.${zone}";
      upstream = "10.90.0.11:8096";
      access = ["f1" "f2"];
    };
    fmedia = {
      name = "fmedia.${zone}";
      upstream = "10.90.0.11:5055";
      access = ["f1" "f2"];
    };
  };

  hosts = {
    v3x-teapot = {
      publicKey = "8FDbnPsRkbhl/Req/KfND0pT3+6aoNjohiOiAUlXFGc=";
      endpoint = "wg.${zone}:${toString hubPort}";
      address = "100.127.0.127";
    };
    v3x-fighter = {
      publicKey = "/XYyaxvqHkggVsh8/tJSZBs6LuYk82CVhSGxYeKstj4=";
      address = "100.127.0.103";
    };
    v3x-prototype = {
      publicKey = "cMShVsxa70NeFiN2rInXgedWGXIUwecIEHVUvIj7GEg=";
      address = "100.127.0.69";
    };
    v3x-mission = {
      publicKey = "a1tn/2rRUEDHMx0nJINy8znyDCmpqCKFftalNxSJwDU=";
      address = "100.127.0.60";
    };
    v3x-b1 = {
      publicKey = "ClfVgAM5blGyKjubpsboHts5qL5jDOD3gM3S1ZexARo=";
      address = "100.127.10.1";
      group = "f1";
    };
    v3x-b2 = {
      publicKey = "srF6rfRQdpBOI2f4ln7+yyiRl0uvw10j+h66eB0mhyI=";
      address = "100.127.10.2";
      group = "f1";
    };
    v3x-line = {
      publicKey = "O7FY5DfLXXLqpJqV2M8axT5a8lC6QUaGHP+sH9stWDY=";
      address = "100.127.10.10";
      group = "f1";
    };
    v3x-tan = {
      publicKey = "j4DzO7Wq7Y9vSY+36FzVr8e2HmVlqZJkDWDUWtAcx0E=";
      address = "100.127.10.11";
      group = "f2";
    };
    v3x-son = {
      publicKey = "e63ms4WhjteP6WpotdsG5kehSiY9xqO0ABu6fTJiiSI=";
      address = "100.127.10.12";
      group = "f2";
    };
  };
}
