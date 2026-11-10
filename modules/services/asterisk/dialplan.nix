{
  config,
  lib,
  ...
}: let
  allowedForeignPrefixes = [];

  maxConcurrentCalls = 2;
  maxCallsPerHour = 20;

  dutchPatterns = [
    "_+31[1-57]XXXXXXXX"
    "_+316[1-58]XXXXXXX"
    "_+318[4578]XXXXXXX"
  ];

  foreignPatterns = prefix:
    map (n: "_+${prefix}${lib.concatStrings (lib.replicate n "X")}") (lib.range 4 (15 - lib.stringLength prefix));

  allowedPatterns = dutchPatterns ++ lib.concatMap foreignPatterns allowedForeignPrefixes;
in {
  sops.secrets = {
    asterisk_p0_number = {
      owner = "asterisk";
      group = "asterisk";
    };
    asterisk_p1_number = {
      owner = "asterisk";
      group = "asterisk";
    };
    asterisk_p2_number = {
      owner = "asterisk";
      group = "asterisk";
    };
  };

  sops.templates.asterisk-numbers = {
    owner = "asterisk";
    group = "asterisk";
    mode = "0400";
    content = ''
      [globals]
      P0_NUMBER=${config.sops.placeholder.asterisk_p0_number}
      P1_NUMBER=${config.sops.placeholder.asterisk_p1_number}
      P2_NUMBER=${config.sops.placeholder.asterisk_p2_number}
    '';
  };

  services.asterisk.confFiles."extensions.conf" = ''
    #include "${config.sops.templates.asterisk-numbers.path}"

    [from-trunk]
    exten => _+X.,1,NoOp(Incoming ''${EXTEN} from ''${CALLERID(num)})
    same => n,Set(CALLERID(num)=''${FILTER(+0-9,''${CALLERID(num)})})
    same => n,Gosub(cid-national,''${CALLERID(num)},1)
    same => n,Set(FROM=''${CALLERID(num)})
    same => n,Answer()
    same => n,Playback(hello-world)
    same => n,Dial(PJSIP/1001&PJSIP/1002,25,m(default))
    same => n,GotoIf($["''${DIALSTATUS}"="ANSWER"]?done)
    same => n,Set(CALLERID(num)=+''${P0_NUMBER})
    same => n,Dial(PJSIP/''${P1_NUMBER}@trunk&PJSIP/''${P2_NUMBER}@trunk,45,m(default))
    same => n,GotoIf($["''${DIALSTATUS}"="ANSWER"]?done)
    same => n,Playback(vm-nobodyavail)
    same => n,Set(RECORDING=/var/spool/asterisk/missed/''${UNIQUEID}.wav)
    same => n,Record(''${RECORDING},5,120,k)
    same => n,Hangup()
    same => n(done),Set(ANSWERED=1)
    same => n,Hangup()

    exten => h,1,GotoIf($["''${ANSWERED}"="1"]?done)
    same => n,TrySystem(${config.system.build.voicemail} "''${FROM}" "''${RECORDING}")
    same => n(done),NoOp()

    [cid-national]
    exten => _+31X.,1,Set(CALLERID(num)=0''${EXTEN:3})
    same => n,Set(CALLERID(name)=''${CALLERID(num)})
    same => n,Return()
    exten => _+X.,1,Set(CALLERID(num)=00''${EXTEN:1})
    same => n,Set(CALLERID(name)=''${CALLERID(num)})
    same => n,Return()
    exten => _.,1,Return()

    [from-internal]
    exten => 100,1,Answer()
    same => n,Wait(1)
    same => n,MusicOnHold(default,20)
    same => n,Hangup()
    exten => 1001,1,Dial(PJSIP/1001,30,m)
    same => n,Hangup()
    exten => 1002,1,Dial(PJSIP/1002,30,m)
    same => n,Hangup()

    exten => _0X.,1,Goto(trunk-out,+31''${EXTEN:1},1)
    exten => _00X.,1,Goto(trunk-out,+''${EXTEN:2},1)
    exten => _+X.,1,Goto(trunk-out,''${EXTEN},1)

    [trunk-out]
    exten => _+.,1,Log(WARNING,Outbound call to ''${EXTEN} refused for ''${CALLERID(num)} on ''${CHANNEL})
    same => n,Set(CDR(userfield)=refused)
    same => n,Answer()
    same => n,Playback(ss-noservice)
    same => n,Hangup()
    ${lib.concatMapStringsSep "\n" (pattern: "exten => ${pattern},1,Goto(trunk-dial,\${EXTEN},1)") allowedPatterns}

    [trunk-dial]
    exten => _+X.,1,Set(GROUP()=trunk-out)
    same => n,GotoIf($[''${GROUP_COUNT(trunk-out)}<=${toString maxConcurrentCalls}]?:busy)
    same => n,Set(HOUR=''${STRFTIME(''${EPOCH},,%Y%m%d%H)})
    same => n,GotoIf($["''${DB(trunk-out/hour)}"="''${HOUR}"]?count)
    same => n,Set(DB(trunk-out/calls)=0)
    same => n,Set(DB(trunk-out/hour)=''${HOUR})
    same => n(count),Set(CALLS=$[''${DB(trunk-out/calls)}+1])
    same => n,GotoIf($[''${CALLS}<=${toString maxCallsPerHour}]?:limited)
    same => n,Set(DB(trunk-out/calls)=''${CALLS})
    same => n,NoOp(Outbound ''${EXTEN})
    same => n,Set(CALLERID(num)=+''${P0_NUMBER})
    same => n,Dial(PJSIP/''${EXTEN}@trunk,60)
    same => n,NoOp(DIALSTATUS=''${DIALSTATUS} HANGUPCAUSE=''${HANGUPCAUSE})
    same => n,Hangup()
    same => n(busy),Log(WARNING,Outbound call to ''${EXTEN} refused for ''${CALLERID(num)}, ${toString maxConcurrentCalls} calls active)
    same => n,Set(CDR(userfield)=busy)
    same => n,Busy(3)
    same => n(limited),Log(WARNING,Outbound call to ''${EXTEN} refused for ''${CALLERID(num)}, ${toString maxCallsPerHour} calls this hour)
    same => n,Set(CDR(userfield)=rate-limited)
    same => n,Congestion(3)
  '';
}
