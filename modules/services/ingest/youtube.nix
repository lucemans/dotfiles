_: {
  flake.nixosModules.ingestarrYoutube = _: let
    channel = key: name: handle: {
      inherit key name;
      kind = "youtube";
      interval = "2h";
      youtube = {inherit handle;};
    };
  in {
    services.ingestarr = {
      settings.source = [
        (channel "youtube-linus-tech-tips" "Linus Tech Tips" "@LinusTechTips")
        (channel "youtube-wanshow" "WAN Show" "@WANShowYT")
        (channel "youtube-techlinked" "TechLinked" "@TechLinked")
        (channel "youtube-lmgclips" "LMG Clips" "@LMGClipsYT")
        (channel "youtube-shortcircuit" "ShortCircuit" "@ShortCircuit")
        (channel "youtube-craft-computing" "Craft Computing" "@CraftComputing")
        (channel "youtube-t3dotgg" "Theo t3.gg" "@t3dotgg")
        (channel "youtube-ambitionstrikes" "Ambition Strikes" "@AmbitionStrikes")
        (channel "youtube-someordinarygamers" "SomeOrdinaryGamers" "@SomeOrdinaryGamers")
        (channel "youtube-lockpickinglawyer" "LockPickingLawyer" "@LockPickingLawyer")
        (channel "youtube-hyperplexed" "Hyperplexed" "@Hyperplexed")
        (channel "youtube-randomfrankp" "RandomFrankP" "@randomfrankp")
        (channel "youtube-fern" "Fern" "@fern-tv")
        (channel "youtube-brodierobertson" "Brodie Robertson" "@BrodieRobertson")
        (channel "youtube-computerphile" "Computerphile" "@Computerphile")
        (channel "youtube-technotim" "Techno Tim" "@TechnoTim")
        (channel "youtube-learnlinuxtv" "LearnLinuxTV" "@learnlinuxtv")
        (channel "youtube-itchyboots" "Itchy Boots" "@ItchyBoots")
        (channel "youtube-whiteseastudio" "White Sea Studio" "@Whiteseastudio")
        (channel "youtube-tested" "Adam Savage's Tested" "@tested")
        (channel "youtube-fireship" "Fireship" "@Fireship")
        (channel "youtube-direwolf20" "Direwolf20" "@direwolf20")
        (channel "youtube-dreydossier" "The Drey Dossier" "@thedreydossier")
        (channel "youtube-eevblog" "EEVblog" "@EEVblog")
        (channel "youtube-xylafoxlin" "Xyla Foxlin" "@xylafoxlin")
        (channel "youtube-lubach" "Lubach" "@Lubach_official")
      ];
      collections = [
        {
          name = "youtube";
          title = "YouTube";
          kinds = ["youtube"];
        }
      ];
    };
  };
}
