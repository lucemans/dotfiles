_: {
  flake.nixosModules.clearurlsClipboard = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.programs.clearurlsClipboard;

    rules = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/ClearURLs/Rules/11086f40512774dcadef54079f1ba023bfacf940/data.min.json";
      hash = "sha256-syjSpblbGyO6wskTQqje7j+aOCallQv54o4zL/2UzS8=";
    };

    clearurlsClipboard = pkgs.writers.writePython3Bin "clearurls-clipboard" {} ''
      import json
      import re
      import subprocess
      import sys
      from pathlib import Path
      from urllib.parse import parse_qsl, unquote, urlencode, urlsplit, urlunsplit

      RULES_PATH = "${rules}"
      PROVIDERS = json.loads(Path(RULES_PATH).read_text())["providers"].values()
      NOTIFY_SEND = "notify-send"
      WL_COPY = "wl-copy"


      def matches(pattern, value):
          return re.search(pattern, value, re.IGNORECASE) is not None


      def is_url(value):
          if (
              not value
              or value.strip() != value
              or "\x00" in value
              or "\n" in value
              or "\r" in value
          ):
              return False
          parsed = urlsplit(value)
          return parsed.scheme in {"http", "https"} and parsed.netloc


      def remove_fields(value, rules):
          fields = parse_qsl(value, keep_blank_values=True)
          cleaned = [
              field
              for field in fields
              if not any(matches(f"^(?:{rule})$", field[0]) for rule in rules)
          ]
          if cleaned == fields:
              return value
          return urlencode(cleaned, doseq=True)


      def clean_provider(url, provider):
          for rule in provider["redirections"]:
              redirect = re.search(rule, url, re.IGNORECASE)
              if redirect is not None:
                  destination = unquote(redirect.group(1))
                  if is_url(destination):
                      return destination

          if provider["completeProvider"]:
              return url

          cleaned = url
          for rule in provider["rawRules"]:
              cleaned = re.sub(rule, "", cleaned, flags=re.IGNORECASE)

          if not is_url(cleaned):
              return url

          parsed = urlsplit(cleaned)
          fields = [*provider["rules"], *provider["referralMarketing"]]
          query = remove_fields(parsed.query, fields)
          fragment = remove_fields(parsed.fragment, fields)
          return urlunsplit(
              (parsed.scheme, parsed.netloc, parsed.path, query, fragment)
          )


      def sanitize(url):
          if not is_url(url):
              return url

          for _ in range(10):
              previous = url
              for provider in PROVIDERS:
                  if not matches(provider["urlPattern"], url):
                      continue
                  if any(
                      matches(exception, url) for exception in provider["exceptions"]
                  ):
                      continue
                  url = clean_provider(url, provider)
              if url == previous:
                  return url
          return url


      def notify(clean_url):
          try:
              result = subprocess.run(
                  [
                      NOTIFY_SEND,
                      "--app-name=ClearURLs Clipboard",
                      "--expire-time=15000",
                      "--action=copy=Copy clean URL",
                      "--wait",
                      "URL was sanitized",
                      "Click Copy clean URL to replace the clipboard value.",
                  ],
                  check=False,
                  stdout=subprocess.PIPE,
                  text=True,
                  timeout=30,
              )
          except subprocess.TimeoutExpired:
              return
          if result.stdout.strip() == "copy":
              subprocess.run(
                  [WL_COPY, "--type", "text/plain;charset=utf-8"],
                  check=True,
                  input=clean_url,
                  text=True,
              )


      copied = sys.stdin.buffer.read().decode("utf-8")
      if sys.argv[1:] == ["notify"]:
          notify(copied)
      else:
          clean_url = sanitize(copied)
          if clean_url != copied:
              process = subprocess.Popen(
                  [sys.argv[0], "notify"],
                  stdin=subprocess.PIPE,
                  text=True,
              )
              process.stdin.write(clean_url)
              process.stdin.close()
    '';
  in {
    options.programs.clearurlsClipboard.enable = lib.mkEnableOption "ClearURLs clipboard sanitizer";

    config = lib.mkIf cfg.enable {
      systemd.user.services.clearurls-clipboard = {
        description = "ClearURLs clipboard sanitizer";
        path = [pkgs.libnotify pkgs.wl-clipboard];
        after = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --no-newline --type text --watch ${clearurlsClipboard}/bin/clearurls-clipboard";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };
}
