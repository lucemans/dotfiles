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
        (channel "youtube-adumh00man" "Adumh00man" "@Adumh00man")
        (channel "youtube-basicdevblog" "BasicDevBlog" "@BasicDevBlog")
        (channel "youtube-basicallyhomeless" "Basically Homeless" "@BasicallyHomeless")
        (channel "youtube-beneater" "Ben Eater" "@BenEater")
        (channel "youtube-bitwit" "Bitwit" "@Bitwit")
        (channel "youtube-coffeestainstudios" "CoffeeStainStudios" "@CoffeeStainStudios")
        (channel "youtube-colinandsamir" "Colin and Samir" "@ColinandSamir")
        (channel "youtube-corridorcrew" "Corridor Crew" "@CorridorCrew")
        (channel "youtube-dave2d" "Dave2D" "@Dave2D")
        (channel "youtube-deviantollam" "Deviant Ollam" "@DeviantOllam")
        (channel "youtube-facedev" "FaceDev" "@FaceDevStuff")
        (channel "youtube-kitboga" "Kitboga" "@KitbogaShow")
        (channel "youtube-kylecook" "Kyle Cook WDS" "@KyleCookWDS")
        (channel "youtube-lawrencesystems" "Lawrence Systems" "@LAWRENCESYSTEMS")
        (channel "youtube-level2jeff" "Level2Jeff" "@Level2Jeff")
        (channel "youtube-liveoverflow" "LiveOverflow" "@LiveOverflow")
        (channel "youtube-madewithlayers" "MadeWithLayers" "@MadeWithLayers")
        (channel "youtube-mentaloutlaw" "MentalOutlaw" "@MentalOutlaw")
        (channel "youtube-mikeboyd" "Mike Boyd" "@MikeBoyd")
        (channel "youtube-modernvintagegamer" "ModernVintageGamer" "@ModernVintageGamer")
        (channel "youtube-naaackers" "Naaackers" "@Naaackers")
        (channel "youtube-networkchuck" "Network Chuck" "@NetworkChuck")
        (channel "youtube-nilered" "NileRed" "@NileRed")
        (channel "youtube-pewdiepie" "PewDiePie" "@PewDiePie")
        (channel "youtube-portalrunner" "PortalRunner" "@PortalRunner")
        (channel "youtube-psychogenictechnologies" "PsychogenicTechnologies" "@PsychogenicTechnologies")
        (channel "youtube-recklessben" "Reckless Ben" "@RecklessBen")
        (channel "youtube-shannonmorse" "Shannon Morse" "@ShannonMorse")
        (channel "youtube-smarthomesolver" "SmartHomeSolver" "@SmartHomeSolver")
        (channel "youtube-sokrispymedia" "SoKrispyMedia" "@SoKrispyMedia")
        (channel "youtube-soirilab" "SoiriLab" "@SoiriLab")
        (channel "youtube-tomscottgo" "Tom Scott Go" "@TomScottGo")
        (channel "youtube-tscodingdaily" "TscodingDaily" "@TsodingDaily")
        (channel "youtube-undecidedtechnology" "Undecided Technology" "@UndecidedTechnology")
        (channel "youtube-valve" "Valve" "@Valve")
        (channel "youtube-veronicaexplains" "Veronica Explains" "@VeronicaExplains")
        (channel "youtube-webdevsimplified" "WebDevSimplified" "@WebDevSimplified")
        (channel "youtube-williamosman2" "William Osman 2" "@WilliamOsman2")
        (channel "youtube-answerinprogress" "Answer In Progress" "@answerinprogress")
        (channel "youtube-camshand" "Cam Shand" "@camshand")
        (channel "youtube-colinfurze" "Colin Furze" "@colinfurze")
        (channel "youtube-dactall" "dacctal" "@dacctal")
        (channel "youtube-dreamsofcode" "Dreams of Code" "@dreamsofcode")
        (channel "youtube-fknight" "fknight" "@fknight")
        (channel "youtube-halfasinteresting" "Half As Interesting" "@halfasinteresting")
        (channel "youtube-hass" "Home Assistant" "@home_assistant")
        (channel "youtube-hoog" "Hoog" "@hoog-youtube")
        (channel "youtube-jakkuh" "Jakkuh" "@jakkuh_t")
        (channel "youtube-kristianvtr" "Kristian" "@kristianvtr")
        (channel "youtube-ktzsystems" "KTZ Systems" "@ktzsystems")
        (channel "youtube-mkbhd" "MKBHD" "@mkbhd")
        (channel "youtube-nosplus" "NOS Plus" "@nosplus")
        (channel "youtube-penguinz0" "penguinz0" "@penguinz0")
        (channel "youtube-projectmaria" "Project Maria" "@pr0jectmaria")
        (channel "youtube-rejectconvenience" "Reject Convenience" "@rejectconvenience")
        (channel "youtube-rossmangroup" "Louis Rossman" "@rossmanngroup")
        (channel "youtube-simonegiertz" "Simone Giertz" "@simonegiertz")
        (channel "youtube-snazzy" "Snazzy Labs" "@snazzy")
        (channel "youtube-syntaxfm" "SyntaxFM" "@syntaxfm")
        (channel "youtube-synthet" "Synthet" "@synthet7")
        (channel "youtube-vimjoyer" "Vimjoyer" "@vimjoyer")
        (channel "youtube-tom-delalande" "Tom Delalande" "@tom-delalande")
        (channel "youtube-tweakers" "Tweakers" "@tweakers")
        (channel "youtube-notexttospeec" "No Text To Speech" "@notexttospeech")
        (channel "youtube-bennjordan" "Benn Jordan" "@BennJordan")
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
