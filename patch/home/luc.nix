{ config, pkgs, ... }:

{
  home.username = "luc";
  home.homeDirectory = "/home/luc";

  home.stateVersion = "25.05";

  # Enable Firefox with Extensions
  programs.firefox = {
    enable = true;
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = {
          "browser.startup.homepage" = "https://v3x.company";
          "browser.search.defaultenginename" = "ddg";
          "browser.search.order.1" = "ddg";

          # Performance settings
          "gfx.webrender.all" = true;  # Enable WebRender for better performance
          "media.ffmpeg.vaapi.enabled" = true;  # Hardware video acceleration
          "browser.cache.disk.enable" = false;  # Disable disk cache (better for SSDs)
          "browser.cache.memory.enable" = true;
          "browser.cache.memory.capacity" = 524288;  # 512MB memory cache

          # Privacy settings
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.fingerprinting.enabled" = true;
          "privacy.trackingprotection.cryptomining.enabled" = true;
          "privacy.resistFingerprinting" = true;
          "privacy.donottrackheader.enabled" = true;

          # UI/UX improvements
          "browser.compactmode.show" = true;
          "browser.uidensity" = 1;  # 0=normal, 1=compact, 2=touch
          "browser.tabs.loadInBackground" = true;
          "browser.tabs.closeWindowWithLastTab" = false;

          # Quality of life
          "browser.download.useDownloadDir" = false;  # Always ask where to save files
          "browser.bookmarks.openInTabClosesMenu" = false;
          "browser.urlbar.suggest.bookmark" = true;
          "browser.urlbar.suggest.history" = true;
          "browser.urlbar.suggest.openpage" = false;
          
          # Disable built-in password manager
          "signon.rememberSignons" = false;  # Disable password save prompts
          "signon.autofillForms" = true;

          # Pin Bitwarden to toolbar
          "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":[],"nav-bar":["back-button","forward-button","stop-reload-button","home-button","urlbar-container","downloads-button","{446900e4-71c2-419f-a6a7-df9c091e268b}"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["firefox-view-button","tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["developer-button"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar"],"currentVersion":19,"newElementCount":4}'';
        };
        # Custom CSS for a cleaner UI (optional)
        userChrome = ''
          /* Hide tab bar if only one tab open */
          #tabbrowser-tabs { visibility: collapse !important; }
          #tabbrowser-tabs[count="2"] { visibility: visible !important; }

          /* Compact UI tweaks */
          :root {
            --tab-min-height: 24px !important;
            --tab-border-radius: 0 !important;
          }
        '';
        search = {
          force = true;
          default = "ddg";
          order = [ "ddg" "google" ];
          engines = {
            "Nix Packages" = {
              urls = [{
                template = "https://search.nixos.org/packages";
                params = [
                  { name = "type"; value = "packages"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }];
              icon = "https://nixos.wiki/favicon.png";
              definedAliases = [ "@np" ];
            };
            "NixOS Wiki" = {
              urls = [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
              icon = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@nw" ];
            };
            "ddg" = {
              urls = [{ template = "https://duckduckgo.com/?q={searchTerms}"; }];
              icon = "https://duckduckgo.com/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@ddg" ];
            };
            "bing".metaData.hidden = true;
            "google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          };
        };
      };
    };
    policies = {
      DisableTelemetry = true;
      BlockAboutConfig = false; # explicitly allow about:config and debugging pages
      DisableDeveloperTools = false; # explicitly allow developer tools
      ExtensionSettings = {
        # "*".installation_mode = "blocked";  # blocks all addons except the ones specified below
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {  # Bitwarden's correct extension ID
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        "sponsorBlocker@ajay.app" = {  # SponsorBlock's correct extension ID
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
          installation_mode = "force_installed";
        };
        "{77691beb-4c53-48de-ab20-6589a537717a}" = {  # Frame Companion extension ID
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/frame-extension/latest.xpi";
          installation_mode = "force_installed";
        };
        "webtweaks@v3x.company" = {
          install_url = "https://github.com/v3xlabs/webtweaks/releases/download/v0.0.1-6/webtweaks-firefox.xpi";
          installation_mode = "force_installed";
        };
      };
      # Additional preferences to ensure smooth operation
      Preferences = {
        "browser.contentblocking.category" = { Value = "strict"; Status = "locked"; };
        "extensions.pocket.enabled" = { Value = false; Status = "locked"; };
        # Set DuckDuckGo as default search engine
        "browser.search.defaultenginename" = { Value = "ddg"; Status = "locked"; };
        "browser.search.selectedEngine" = { Value = "ddg"; Status = "locked"; };
        "browser.urlbar.placeholderName" = { Value = "ddg"; Status = "locked"; };
        # Disable extension signature requirements
        "xpinstall.signatures.required" = { Value = false; Status = "default"; };
        "xpinstall.whitelist.required" = { Value = false; Status = "default"; };
      };
      # Explicitly set DuckDuckGo as default
      SearchEngines = {
        Default = "ddg";
        PreventInstalls = true;
      };
    };
  };

  # Install common packages
  home.packages = with pkgs; [
    # CLI
    neofetch
    git
    vim
    kubectl

    # Searching & Shell
    starship
    zoxide
    fzf
    bat
    eza
    ripgrep

    # Desktop Apps
    unstable.vscode
    unstable.code-cursor
    unstable.discord
    unstable.spotify
    unstable.lens # Kubernetes IDE
    thunderbird # Email
    obsidian # Note taking
    telegram-desktop
    gitkraken # Git GUI

    opencode

    # Casting
    gnomecast

    # Ethereum Wallet
    unstable.framesh

    # SDR
    rtl-sdr
    gqrx
    libusb1

    # Network Drives
    # gvfs
    # gnome.gvfs
    cifs-utils
    samba

    # Networking
    tailscale
    # mullvad
    mullvad-vpn

    # File Syncing
    syncthing

    # Rust
    rustup
    # unstable.rust-analyzer
    bacon
    gcc
    openssl
    openssl.dev
    pkg-config
    unstable.rustc
    # unstable.cargo
    # unstable.rustfmt
    # unstable.clippy

    # JS
    nodejs
    nodePackages.pnpm

    # System Tray
    # tailscale-systray

    jetbrains.datagrip

    exiftool

    ferium

    unstable.signal-desktop
    unstable.codex
  ];

  home.sessionVariables = {
    OPENSSL_DIR = "${pkgs.openssl.dev}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.pkg-config}/lib/pkgconfig";
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "luc";
    userEmail = "luc@lucemans.nl";
    extraConfig = {
      init.defaultBranch = "master";
    };
  };

  programs = {
    zsh.enable = false;  # Explicitly disable zsh
    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting # Disable greeting
        
        # Enable kubectl autocompletion
        kubectl completion fish | source
        
        # Enable better cd command with z
        zoxide init fish | source
      '';
      plugins = [
        # Plugin for better directory navigation
        {
          name = "z";
          src = pkgs.fishPlugins.z.src;
        }
        # Autosuggestions based on history
        {
          name = "autopair";
          src = pkgs.fishPlugins.autopair.src;
        }
        # Kubernetes context in prompt
        {
          name = "kubectl-completions";
          src = pkgs.fetchFromGitHub {
            owner = "evanlucas";
            repo = "fish-kubectl-completions";
            rev = "ced676392575d618d8b80b3895cdc3159be3f628";
            sha256 = "sha256-OYiYTW+g71vD9NWOcX1i2/TaQfAg+c2dJZ5ohwWSDCc=";
          };
        }
      ];
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        kubernetes = {
          disabled = false;
          format = "[$symbol$context( \($namespace\))]($style) ";
        };
        directory = {
          truncation_length = 8;
          truncate_to_repo = true;
        };
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };

    # Add zoxide for better directory navigation
    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    # Add fzf for fuzzy finding
    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    # rustup = {
    #   enable = true;
    #   # You can set the default Rust toolchain here
    #   # Possible values: "stable", "nightly", "1.77.0" (specific version)
    #   defaultToolchain = "stable"; 
    # };

    chromium = {
      enable = true;

      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      ];
    };

    # Ensure home-manager manages your shell
    home-manager.enable = true;
  };
}
