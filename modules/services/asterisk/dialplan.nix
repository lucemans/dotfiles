{config, ...}: {
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

    ; analog caller ID carries digits only, present dutch national format
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

    ; outbound, dutch national and international prefixes to E.164
    exten => _0X.,1,Goto(trunk-out,+31''${EXTEN:1},1)
    exten => _00X.,1,Goto(trunk-out,+''${EXTEN:2},1)
    exten => _+X.,1,Goto(trunk-out,''${EXTEN},1)

    [trunk-out]
    exten => _+X.,1,NoOp(Outbound ''${EXTEN})
    same => n,Set(CALLERID(num)=+''${P0_NUMBER})
    same => n,Dial(PJSIP/''${EXTEN}@trunk,60)
    same => n,NoOp(DIALSTATUS=''${DIALSTATUS} HANGUPCAUSE=''${HANGUPCAUSE})
    same => n,Hangup()
  '';
}
